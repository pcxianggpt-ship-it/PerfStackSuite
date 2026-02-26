#!/bin/bash
#
# 系统内核参数优化脚本
# 功能：优化操作系统内核参数，特别是 TCP TIME_WAIT 状态处理
# 版本：1.0.0
# 适用场景：高并发压测场景、性能测试环境
#

set -e  # 遇到错误时退出

# 获取脚本目录
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# 加载公共函数库
source "${SCRIPT_DIR}/common.sh"

# ============================================
# 常量定义
# ============================================

# 配置文件路径
SYSCTL_CONF_FILE="/etc/sysctl.conf"
SYSCTL_CUSTOM_CONF="/etc/sysctl.d/99-perfstack-tuning.conf"
SYSCTL_BACKUP_CONF="/etc/sysctl.conf.perfstack.bak"

# 从配置文件或使用默认值
TCP_TW_REUSE="${SYSCTL_TCP_TW_REUSE:-1}"
TCP_FIN_TIMEOUT="${SYSCTL_TCP_FIN_TIMEOUT:-30}"
TCP_MAX_TW_BUCKETS="${SYSCTL_TCP_MAX_TW_BUCKETS:-3000}"
IP_LOCAL_PORT_RANGE="${SYSCTL_IP_LOCAL_PORT_RANGE:-1024 65535}"
NF_CONNTRACK_MAX="${SYSCTL_NF_CONNTRACK_MAX:-262144}"
NF_CONNTRACK_TCP_TIMEOUT_TIME_WAIT="${SYSCTL_NF_CONNTRACK_TCP_TIMEOUT_TIME_WAIT:-30}"

# ============================================
# 显示使用说明
# ============================================

show_usage() {
    cat << EOF
用法: $0 [选项]

选项：
  --apply, -a         应用内核参数优化配置
  --show, -s          显示当前内核参数配置
  --restore, -r       恢复优化前的配置
  --backup, -b        仅备份当前配置
  --help, -h          显示此帮助信息

示例：
  $0                          # 交互式选择操作
  $0 --apply                  # 应用内核参数优化
  $0 --show                   # 显示当前配置状态
  $0 --restore                # 恢复优化前的配置

配置文件：config/deploy.conf
  可以在配置文件中设置以下变量：
  - SYSCTL_TCP_TW_REUSE: TCP TIME_WAIT 重用（默认：1）
  - SYSCTL_TCP_FIN_TIMEOUT: FIN 超时时间（默认：30）
  - SYSCTL_TCP_MAX_TW_BUCKETS: TIME_WAIT 最大桶数（默认：3000）
  - SYSCTL_IP_LOCAL_PORT_RANGE: 端口范围（默认：1024 65535）
  - SYSCTL_NF_CONNTRACK_MAX: 连接跟踪表大小（默认：262144）
  - SYSCTL_NF_CONNTRACK_TCP_TIMEOUT_TIME_WAIT: TIME_WAIT 跟踪超时（默认：30）

注意事项：
  - 此脚本需要 root 权限执行
  - 配置文件位于 /etc/sysctl.d/99-perfstack-tuning.conf
  - 某些参数需要重启网络服务或系统才能完全生效

优化说明：
  - 减少 TIME_WAIT 状态连接数量
  - 扩大可用端口范围
  - 增加连接跟踪表大小
  - 优化 TCP 缓冲区大小
  - 提高高并发场景下的网络性能
EOF
}

# ============================================
# 检查 root 权限
# ============================================

check_root_permission() {
    if [ "$(id -u)" -ne 0 ]; then
        log_error "此脚本需要 root 权限执行"
        log_error "请使用: sudo $0"
        exit 1
    fi
}

# ============================================
# 备份现有配置
# ============================================

backup_current_config() {
    log_info "备份当前内核参数配置..."

    # 备份 /etc/sysctl.conf
    if [ -f "$SYSCTL_CONF_FILE" ]; then
        backup_file "$SYSCTL_CONF_FILE"
    fi

    # 检查 /etc/sysctl.d/ 目录下的自定义配置
    if [ -d "/etc/sysctl.d" ]; then
        local custom_confs=$(find /etc/sysctl.d -name "*.conf" -type f 2>/dev/null)
        if [ -n "$custom_confs" ]; then
            log_info "发现自定义配置文件："
            echo "$custom_confs" | while read conf; do
                log_info "  - $conf"
            done
        fi
    fi

    # 创建完整配置快照
    local snapshot_file="/tmp/sysctl_snapshot_$(date +%Y%m%d%H%M%S).txt"
    log_info "创建当前参数快照: $snapshot_file"
    sysctl -a > "$snapshot_file" 2>/dev/null || true

    log_success "配置备份完成"
}

# ============================================
# 生成内核参数配置文件
# ============================================

generate_sysctl_config() {
    log_info "生成内核参数优化配置..."

    # 创建配置文件
    cat > "$SYSCTL_CUSTOM_CONF" <<'EOF'
# ============================================
# PerfStackSuite 系统内核参数优化配置
# 生成时间：$(date '+%Y-%m-%d %H:%M:%S')
# ============================================
# 此配置文件优化了 TCP TIME_WAIT 状态处理
# 主要针对高并发压测场景进行网络性能优化
# ============================================

# ----------
# TIME_WAIT 优化
# ----------

# 允许将 TIME_WAIT sockets 重新用于新的 TCP 连接
# 默认值: 0
# 推荐值: 1（开启）
# 说明: 对于高并发服务器，可以减少 TIME_WAIT 状态的影响
EOF

    echo "net.ipv4.tcp_tw_reuse = $TCP_TW_REUSE" >> "$SYSCTL_CUSTOM_CONF"

    cat >> "$SYSCTL_CUSTOM_CONF" <<'EOF'

# 减少 TIME_WAIT 超时时间
# 默认值: 60
# 推荐值: 30
# 说明: 缩短 TIME_WAIT 状态的持续时间，加快端口回收
EOF

    echo "net.ipv4.tcp_fin_timeout = $TCP_FIN_TIMEOUT" >> "$SYSCTL_CUSTOM_CONF"

    cat >> "$SYSCTL_CUSTOM_CONF" <<'EOF'

# 限制 TIME_WAIT 最大桶数
# 默认值: 根据内存自动计算（通常较大）
# 推荐值: 3000（高并发场景）
# 说明: 当 TIME_WAIT 连接数超过此值时，系统会强制回收最旧的连接
#       防止 TIME_WAIT 连接过多占用系统资源
EOF

    echo "net.ipv4.tcp_max_tw_buckets = $TCP_MAX_TW_BUCKETS" >> "$SYSCTL_CUSTOM_CONF"

    cat >> "$SYSCTL_CUSTOM_CONF" <<'EOF'

# ----------
# 端口范围优化
# ----------

# 扩大临时端口范围
# 默认值: 32768 60999
# 推荐值: 1024 65535
# 说明: 增加可用端口数量，支持更多并发连接
EOF

    echo "net.ipv4.ip_local_port_range = $IP_LOCAL_PORT_RANGE" >> "$SYSCTL_CUSTOM_CONF"

    cat >> "$SYSCTL_CUSTOM_CONF" <<'EOF'

# ----------
# TCP 连接跟踪优化
# ----------

# 增加 TCP 连接跟踪表大小
# 默认值: 根据内存自动计算
# 推荐值: 262144（或更高）
# 说明: 增加连接跟踪容量，支持更多并发连接
EOF

    echo "net.netfilter.nf_conntrack_max = $NF_CONNTRACK_MAX" >> "$SYSCTL_CUSTOM_CONF"

    cat >> "$SYSCTL_CUSTOM_CONF" <<'EOF'

# 减少连接跟踪 TIME_WAIT 超时时间
# 默认值: 120
# 推荐值: 30
# 说明: 加快 TIME_WAIT 连接的跟踪表项回收
EOF

    echo "net.netfilter.nf_conntrack_tcp_timeout_time_wait = $NF_CONNTRACK_TCP_TIMEOUT_TIME_WAIT" >> "$SYSCTL_CUSTOM_CONF"

    cat >> "$SYSCTL_CUSTOM_CONF" <<'EOF'

# 减少连接跟踪 CLOSE_WAIT 超时时间
# 默认值: 60
# 推荐值: 15
EOF
    echo "net.netfilter.nf_conntrack_tcp_timeout_close_wait = 15" >> "$SYSCTL_CUSTOM_CONF"

    cat >> "$SYSCTL_CUSTOM_CONF" <<'EOF'

# 减少连接跟踪 FIN_WAIT 超时时间
# 默认值: 120
# 推荐值: 30
EOF
    echo "net.netfilter.nf_conntrack_tcp_timeout_fin_wait = 30" >> "$SYSCTL_CUSTOM_CONF"

    cat >> "$SYSCTL_CUSTOM_CONF" <<'EOF'

# ----------
# TCP 缓冲区优化
# ----------

# 增加 TCP 接收缓冲区大小（最小值、默认值、最大值）
# 默认值: 4096 87380 6291456
# 推荐值: 4096 87380 16777216
EOF
    echo "net.ipv4.tcp_rmem = 4096 87380 16777216" >> "$SYSCTL_CUSTOM_CONF"

    cat >> "$SYSCTL_CUSTOM_CONF" <<'EOF'

# 增加 TCP 发送缓冲区大小（最小值、默认值、最大值）
# 默认值: 4096 65536 4194304
# 推荐值: 4096 65536 16777216
EOF
    echo "net.ipv4.tcp_wmem = 4096 65536 16777216" >> "$SYSCTL_CUSTOM_CONF"

    cat >> "$SYSCTL_CUSTOM_CONF" <<'EOF'

# 增加 TCP 全局接收缓冲区最大值
# 默认值: 124928
# 推荐值: 16777216
EOF
    echo "net.core.rmem_max = 16777216" >> "$SYSCTL_CUSTOM_CONF"

    cat >> "$SYSCTL_CUSTOM_CONF" <<'EOF'

# 增加 TCP 全局发送缓冲区最大值
# 默认值: 124928
# 推荐值: 16777216
EOF
    echo "net.core.wmem_max = 16777216" >> "$SYSCTL_CUSTOM_CONF"

    cat >> "$SYSCTL_CUSTOM_CONF" <<'EOF'

# 增加网络设备队列最大长度
# 默认值: 1000
# 推荐值: 5000
# 说明: 在高并发场景下增加网络队列长度
EOF
    echo "net.core.netdev_max_backlog = 5000" >> "$SYSCTL_CUSTOM_CONF"

    cat >> "$SYSCTL_CUSTOM_CONF" <<'EOF'

# ----------
# 其他 TCP 优化
# ----------

# 启用 TCP 窗口缩放
# 默认值: 1
# 推荐值: 1（开启）
# 说明: 支持大于 64KB 的 TCP 窗口，提高传输效率
net.ipv4.tcp_window_scaling = 1

# 启用选择性确认
# 默认值: 1
# 推荐值: 1（开启）
# 说明: 提高 TCP 传输效率
net.ipv4.tcp_sack = 1

# 启用 SYN cookies
# 默认值: 1
# 推荐值: 1（开启）
# 说明: 防止 SYN 攻击
net.ipv4.tcp_syncookies = 1

# 增加 SYN 队列长度
# 默认值: 512 或 1024
# 推荐值: 8192
# 说明: 提高处理大量并发连接的能力
net.ipv4.tcp_max_syn_backlog = 8192

# 减少 SYN-ACK 重试次数
# 默认值: 5
# 推荐值: 2
# 说明: 加快失败连接的超时
net.ipv4.tcp_synack_retries = 2

# ============================================
# 配置说明
# ============================================
# 1. 这些优化主要针对高并发压测场景
# 2. 生产环境使用前请充分测试
# 3. 配置会自动在系统重启后生效
# 4. 如需恢复优化前的配置，请删除此文件并重新加载
# ============================================
EOF

    log_success "配置文件生成完成: $SYSCTL_CUSTOM_CONF"
}

# ============================================
# 应用内核参数配置
# ============================================

apply_sysctl_config() {
    log_info "应用内核参数配置..."

    # 检查配置文件是否存在
    if [ ! -f "$SYSCTL_CUSTOM_CONF" ]; then
        log_error "配置文件不存在: $SYSCTL_CUSTOM_CONF"
        log_error "请先运行: $0 --apply"
        exit 1
    fi

    # 应用配置
    log_info "正在加载配置文件..."
    sysctl -p "$SYSCTL_CUSTOM_CONF" 2>/dev/null || {
        log_error "应用配置失败"
        exit 1
    }

    log_success "内核参数配置已应用"

    # 显示关键参数的当前值
    log_info "验证配置生效情况..."
    echo ""
    echo "关键参数当前值："
    echo "----------------------------------------"
    printf "%-45s %s\n" "参数" "值"
    echo "----------------------------------------"
    printf "%-45s %s\n" "net.ipv4.tcp_tw_reuse:" "$(sysctl -n net.ipv4.tcp_tw_reuse)"
    printf "%-45s %s\n" "net.ipv4.tcp_fin_timeout:" "$(sysctl -n net.ipv4.tcp_fin_timeout)"
    printf "%-45s %s\n" "net.ipv4.tcp_max_tw_buckets:" "$(sysctl -n net.ipv4.tcp_max_tw_buckets)"
    printf "%-45s %s\n" "net.ipv4.ip_local_port_range:" "$(sysctl -n net.ipv4.ip_local_port_range)"
    printf "%-45s %s\n" "net.netfilter.nf_conntrack_max:" "$(sysctl -n net.netfilter.nf_conntrack_max 2>/dev/null || echo 'N/A')"
    echo "----------------------------------------"
}

# ============================================
# 显示当前配置状态
# ============================================

show_current_config() {
    log_info "当前内核参数配置状态"
    echo ""

    echo "TIME_WAIT 相关参数："
    echo "----------------------------------------"
    printf "%-50s %s\n" "参数" "当前值"
    echo "----------------------------------------"
    printf "%-50s %s\n" "net.ipv4.tcp_tw_reuse:" "$(sysctl -n net.ipv4.tcp_tw_reuse)"
    printf "%-50s %s\n" "net.ipv4.tcp_fin_timeout:" "$(sysctl -n net.ipv4.tcp_fin_timeout)"
    printf "%-50s %s\n" "net.ipv4.tcp_max_tw_buckets:" "$(sysctl -n net.ipv4.tcp_max_tw_buckets)"
    echo ""

    echo "端口范围参数："
    echo "----------------------------------------"
    printf "%-50s %s\n" "net.ipv4.ip_local_port_range:" "$(sysctl -n net.ipv4.ip_local_port_range)"
    echo ""

    echo "连接跟踪参数："
    echo "----------------------------------------"
    printf "%-50s %s\n" "net.netfilter.nf_conntrack_max:" "$(sysctl -n net.netfilter.nf_conntrack_max 2>/dev/null || echo 'N/A')"
    printf "%-50s %s\n" "net.netfilter.nf_conntrack_tcp_timeout_time_wait:" "$(sysctl -n net.netfilter.nf_conntrack_tcp_timeout_time_wait 2>/dev/null || echo 'N/A')"
    echo ""

    # 检查是否有自定义配置文件
    if [ -f "$SYSCTL_CUSTOM_CONF" ]; then
        echo "PerfStackSuite 优化配置状态："
        echo "----------------------------------------"
        echo "✓ 优化配置文件已存在: $SYSCTL_CUSTOM_CONF"
        echo "✓ 配置将在系统重启后自动生效"
    else
        echo "PerfStackSuite 优化配置状态："
        echo "----------------------------------------"
        echo "✗ 优化配置文件不存在"
        echo "  提示：运行 $0 --apply 应用优化配置"
    fi
    echo ""

    # 显示连接统计信息
    echo "当前连接统计："
    echo "----------------------------------------"
    if command -v ss >/dev/null 2>&1; then
        ss -s | head -10
    else
        echo "（无法显示连接统计，ss 命令不可用）"
        echo " 提示：安装 iproute2 包以获取 ss 命令"
        echo "  CentOS/RHEL: yum install -y iproute"
        echo "  Ubuntu/Debian: apt-get install -y iproute2"
    fi
    echo ""

    # 显示连接跟踪统计
    if [ -f /proc/sys/net/netfilter/nf_conntrack_count ]; then
        local conntrack_count=$(cat /proc/sys/net/netfilter/nf_conntrack_count)
        local conntrack_max=$(sysctl -n net.netfilter.nf_conntrack_max 2>/dev/null || echo "N/A")
        echo "连接跟踪表使用情况："
        echo "----------------------------------------"
        echo "当前连接数: $conntrack_count"
        echo "最大连接数: $conntrack_max"
        if [ "$conntrack_max" != "N/A" ]; then
            local usage_percent=$((conntrack_count * 100 / conntrack_max))
            echo "使用率: $usage_percent%"
        fi
        echo ""
    fi
}

# ============================================
# 恢复原始配置
# ============================================

restore_original_config() {
    log_warn "恢复原始内核参数配置..."

    # 检查备份文件是否存在
    if [ ! -f "$SYSCTL_BACKUP_CONF" ]; then
        log_error "备份文件不存在: $SYSCTL_BACKUP_CONF"
        log_error "无法恢复配置"
        exit 1
    fi

    # 确认恢复操作
    echo ""
    echo "警告：此操作将删除 PerfStackSuite 优化配置并恢复原始配置"
    read -p "确认继续？(y/N): " confirm
    if [ "$confirm" != "y" ] && [ "$confirm" != "Y" ]; then
        log_info "取消恢复操作"
        return 0
    fi

    # 删除自定义配置文件
    if [ -f "$SYSCTL_CUSTOM_CONF" ]; then
        log_info "删除优化配置文件: $SYSCTL_CUSTOM_CONF"
        rm -f "$SYSCTL_CUSTOM_CONF"
    fi

    # 重新加载默认配置
    log_info "重新加载系统默认配置..."
    sysctl -p /etc/sysctl.conf 2>/dev/null || true
    sysctl --system 2>/dev/null || true

    log_success "已恢复原始配置"
    log_info "提示：某些参数可能需要重启网络服务或系统才能完全恢复"
}

# ============================================
# 交互式菜单
# ============================================

show_interactive_menu() {
    echo ""
    echo "============================================"
    echo "    系统内核参数优化"
    echo "============================================"
    echo ""
    echo "请选择操作："
    echo "  1 - 应用内核参数优化"
    echo "  2 - 显示当前配置状态"
    echo "  3 - 恢复优化前的配置"
    echo "  0 - 退出"
    echo ""
    read -p "请输入选项 [0-3]: " choice

    case "$choice" in
        1)
            backup_current_config
            generate_sysctl_config
            apply_sysctl_config
            ;;
        2)
            show_current_config
            ;;
        3)
            restore_original_config
            ;;
        0)
            log_info "退出"
            exit 0
            ;;
        *)
            log_error "无效选项"
            exit 1
            ;;
    esac
}

# ============================================
# 解析命令行参数
# ============================================

parse_arguments() {
    # 如果没有参数，显示交互式菜单
    if [ $# -eq 0 ]; then
        show_interactive_menu
        return
    fi

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --apply|-a)
                backup_current_config
                generate_sysctl_config
                apply_sysctl_config
                shift
                ;;
            --show|-s)
                show_current_config
                shift
                ;;
            --restore|-r)
                restore_original_config
                shift
                ;;
            --backup|-b)
                backup_current_config
                shift
                ;;
            --help|-h)
                show_usage
                exit 0
                ;;
            *)
                echo "未知参数: $1"
                show_usage
                exit 1
                ;;
        esac
    done
}

# ============================================
# 主安装流程
# ============================================

main() {
    # 初始化日志
    mkdir -p "$(dirname "$LOG_FILE")"
    touch "$LOG_FILE"

    # 检查 root 权限
    check_root_permission

    # 加载配置文件
    load_config

    # 解析命令行参数
    parse_arguments "$@"
}

# ============================================
# 脚本入口
# ============================================

main "$@"
