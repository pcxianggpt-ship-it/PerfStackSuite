#!/bin/bash
#
# 系统内核参数优化配置卸载脚本
# 功能：移除 PerfStackSuite 的内核参数优化配置，恢复系统默认值
# 版本：1.0.0
#

set -e  # 遇到错误时退出

# 获取脚本目录
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# 加载公共函数库
source "${SCRIPT_DIR}/common.sh"

# ============================================
# 常量定义
# ============================================

SYSCTL_CUSTOM_CONF="/etc/sysctl.d/99-perfstack-tuning.conf"
SYSCTL_BACKUP_CONF="/etc/sysctl.conf.perfstack.bak"

# ============================================
# 显示使用说明
# ============================================

show_usage() {
    cat << EOF
用法: $0 [选项]

选项：
  --remove, -r         移除内核参数优化配置
  --help, -h          显示此帮助信息

示例：
  $0                          # 交互式选择操作
  $0 --remove                  # 移除优化配置

说明：
  - 此脚本需要 root 权限执行
  - 卸载后会删除 /etc/sysctl.d/99-perfstack-tuning.conf
  - 系统将恢复为默认内核参数
  - 某些参数可能需要重启网络服务或系统才能完全恢复
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
# 检查配置是否存在
# ============================================

check_config_exists() {
    if [ ! -f "$SYSCTL_CUSTOM_CONF" ]; then
        log_warn "优化配置文件不存在: $SYSCTL_CUSTOM_CONF"
        log_info "系统未安装 PerfStackSuite 内核参数优化"
        exit 0
    fi
}

# ============================================
# 移除优化配置
# ============================================

remove_sysctl_config() {
    log_info "移除 PerfStackSuite 内核参数优化配置..."

    # 检查配置文件是否存在
    if [ ! -f "$SYSCTL_CUSTOM_CONF" ]; then
        log_warn "配置文件不存在: $SYSCTL_CUSTOM_CONF"
        return 0
    fi

    # 确认卸载操作
    echo ""
    echo "警告：此操作将移除 PerfStackSuite 的内核参数优化配置"
    echo "      系统将恢复为默认内核参数"
    echo ""
    read -p "确认继续？(y/N): " confirm
    if [ "$confirm" != "y" ] && [ "$confirm" != "Y" ]; then
        log_info "取消卸载操作"
        return 0
    fi

    # 备份当前配置（以防需要恢复）
    log_info "备份当前配置..."
    if [ -f "$SYSCTL_CUSTOM_CONF" ]; then
        cp "$SYSCTL_CUSTOM_CONF" "${SYSCTL_CUSTOM_CONF}.bak.$(date +%Y%m%d%H%M%S)"
        log_success "配置已备份到: ${SYSCTL_CUSTOM_CONF}.bak.$(date +%Y%m%d%H%M%S)"
    fi

    # 删除自定义配置文件
    log_info "删除优化配置文件..."
    rm -f "$SYSCTL_CUSTOM_CONF"

    # 重新加载系统默认配置
    log_info "重新加载系统默认配置..."
    sysctl -p /etc/sysctl.conf 2>/dev/null || true
    sysctl --system 2>/dev/null || true

    log_success "优化配置已移除"
    echo ""
    log_info "提示："
    log_info "  1. 系统已恢复为默认内核参数"
    log_info "  2. 某些参数可能需要重启网络服务或系统才能完全生效"
    log_info "  3. 如需重新应用优化，请运行: bash scripts/install_sysctl.sh --apply"
}

# ============================================
# 显示配置状态
# ============================================

show_config_status() {
    echo ""
    echo "当前配置状态："
    echo "============================================"

    if [ -f "$SYSCTL_CUSTOM_CONF" ]; then
        echo "✓ PerfStackSuite 优化配置已安装"
        echo "  配置文件: $SYSCTL_CUSTOM_CONF"
        echo ""
        echo "关键参数当前值："
        echo "----------------------------------------"
        printf "%-45s %s\n" "参数" "当前值"
        echo "----------------------------------------"
        printf "%-45s %s\n" "net.ipv4.tcp_tw_reuse:" "$(sysctl -n net.ipv4.tcp_tw_reuse)"
        printf "%-45s %s\n" "net.ipv4.tcp_fin_timeout:" "$(sysctl -n net.ipv4.tcp_fin_timeout)"
        printf "%-45s %s\n" "net.ipv4.ip_local_port_range:" "$(sysctl -n net.ipv4.ip_local_port_range)"
        echo "----------------------------------------"
    else
        echo "✗ PerfStackSuite 优化配置未安装"
        echo "  系统使用默认内核参数"
    fi
    echo ""
    echo "============================================"
}

# ============================================
# 交互式菜单
# ============================================

show_interactive_menu() {
    echo ""
    echo "============================================"
    echo "    系统内核参数优化 - 卸载"
    echo "============================================"
    echo ""
    show_config_status
    echo ""
    echo "请选择操作："
    echo "  1 - 移除优化配置"
    echo "  0 - 退出"
    echo ""
    read -p "请输入选项 [0-1]: " choice

    case "$choice" in
        1)
            check_config_exists
            remove_sysctl_config
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
            --remove|-r)
                check_config_exists
                remove_sysctl_config
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
# 主流程
# ============================================

main() {
    # 初始化日志
    mkdir -p "$(dirname "$LOG_FILE")"
    touch "$LOG_FILE"

    # 检查 root 权限
    check_root_permission

    log_info "============================================"
    log_info "开始卸载系统内核参数优化配置..."
    log_info "============================================"

    # 解析命令行参数
    parse_arguments "$@"

    log_success "卸载操作完成"
}

# ============================================
# 脚本入口
# ============================================

main "$@"
