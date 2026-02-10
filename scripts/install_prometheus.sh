#!/bin/bash
#
# Prometheus 安装脚本
# 功能：自动部署 Prometheus 时序数据库
#

set -e  # 遇到错误时退出

# 获取脚本目录
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# 加载公共函数库
source "${SCRIPT_DIR}/common.sh"

# ============================================
# 常量定义
# ============================================

PROMETHEUS_VERSION="${PROMETHEUS_VERSION:-2.45.0}"
PROMETHEUS_PORT="${PROMETHEUS_PORT:-9090}"
PROMETHEUS_INSTALL_DIR="${INSTALL_BASE_DIR}/prometheus"
PROMETHEUS_DATA_DIR="${DATA_BASE_DIR}/prometheus"
PROMETHEUS_LOG_DIR="/var/log/prometheus"
PROMETHEUS_RETENTION="${PROMETHEUS_RETENTION_TIME:-30d}"

# ============================================
# 检查是否已安装
# ============================================

check_prometheus_installed() {
    if [ -d "$PROMETHEUS_INSTALL_DIR" ] && [ -f "$PROMETHEUS_INSTALL_DIR/prometheus" ]; then
        log_warn "Prometheus 似乎已经安装"
        read -p "是否重新安装？(y/N): " reinstall
        if [ "$reinstall" != "y" ] && [ "$reinstall" != "Y" ]; then
            log_info "取消安装"
            exit 0
        fi
        log_warn "将重新安装 Prometheus"
    fi
}

# ============================================
# 创建目录结构
# ============================================

create_directories() {
    log_info "创建 Prometheus 目录结构..."

    create_dir "$PROMETHEUS_INSTALL_DIR" 755
    create_dir "$PROMETHEUS_DATA_DIR" 755
    create_dir "$PROMETHEUS_LOG_DIR" 755

    log_success "目录结构创建完成"
}

# ============================================
# 查找并解压安装包
# ============================================

extract_prometheus() {
    log_info "查找 Prometheus 安装包..."

    # 查找安装包
    local tarball=$(find "$SOFT_DIR" -name "prometheus-*.linux-amd64.tar.gz" 2>/dev/null | head -1)

    if [ -z "$tarball" ]; then
        log_error "未找到 Prometheus 安装包"
        log_error "请将 prometheus-${PROMETHEUS_VERSION}.linux-amd64.tar.gz 放在 $SOFT_DIR 目录"
        exit 1
    fi

    log_info "找到安装包: $tarball"

    # 解压到临时目录
    local temp_dir="/tmp/prometheus_install"
    create_dir "$temp_dir" 755

    log_info "正在解压 Prometheus..."
    extract_tar "$tarball" "$temp_dir"

    # 移动到安装目录
    local extracted_dir=$(find "$temp_dir" -name "prometheus-*" -type d | head -1)
    if [ -z "$extracted_dir" ]; then
        log_error "解压后未找到 Prometheus 目录"
        exit 1
    fi

    log_info "移动文件到安装目录..."
    cp -rf "$extracted_dir"/* "$PROMETHEUS_INSTALL_DIR/"
    chmod +x "$PROMETHEUS_INSTALL_DIR/prometheus"
    chmod +x "$PROMETHEUS_INSTALL_DIR/promtool"

    # 清理临时目录
    rm -rf "$temp_dir"

    log_success "Prometheus 安装包解压完成"
}

# ============================================
# 生成配置文件
# ============================================

generate_config() {
    log_info "生成 Prometheus 配置文件..."

    local config_file="$PROMETHEUS_INSTALL_DIR/prometheus.yml"

    # 备份原有配置（如果存在）
    backup_file "$config_file"

    cat > "$config_file" <<EOF
# Prometheus 配置文件
# 自动生成时间: $(date)

# 全局配置
global:
  scrape_interval: 15s
  evaluation_interval: 15s
  external_labels:
    monitor: 'perfstack-suite'

# 告警管理配置（暂不启用）
# alerting:
#   alertmanagers:
#     - static_configs:
#         - targets:
#           - 'localhost:9093'

# 抓取配置
scrape_configs:
  # Prometheus 自身监控
  - job_name: 'prometheus'
    static_configs:
      - targets: ['localhost:9090']

  # Node Exporter（自动发现）
  # 安装 Node Exporter 后会自动添加
EOF

    log_success "配置文件生成完成: $config_file"
}

# ============================================
# 创建 systemd 服务文件
# ============================================

create_systemd_service() {
    log_info "创建 Prometheus systemd 服务..."

    local service_file="/etc/systemd/system/prometheus.service"

    backup_file "$service_file"

    cat > "$service_file" <<EOF
[Unit]
Description=Prometheus Monitoring System
Documentation=https://prometheus.io/docs/introduction/overview/
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
User=root
Group=root

# 工作目录
WorkingDirectory=${PROMETHEUS_INSTALL_DIR}

# 启动命令
ExecStart=${PROMETHEUS_INSTALL_DIR}/prometheus \\
    --config.file=${PROMETHEUS_INSTALL_DIR}/prometheus.yml \\
    --storage.tsdb.path=${PROMETHEUS_DATA_DIR} \\
    --storage.tsdb.retention.time=${PROMETHEUS_RETENTION} \\
    --web.console.templates=${PROMETHEUS_INSTALL_DIR}/consoles \\
    --web.console.libraries=${PROMETHEUS_INSTALL_DIR}/console_libraries \\
    --web.listen-address=:${PROMETHEUS_PORT} \\
    --web.external-url=http://$(get_local_ip):${PROMETHEUS_PORT}

# 重启策略
Restart=always
RestartSec=10

# 资源限制
LimitNOFILE=65536

# 安全加固
NoNewPrivileges=true

[Install]
WantedBy=multi-user.target
EOF

    # 重载 systemd
    log_info "重载 systemd 配置..."
    systemctl daemon-reload

    log_success "systemd 服务创建完成"
}

# ============================================
# 配置防火墙
# ============================================

configure_firewall() {
    log_info "配置防火墙规则..."

    local os_type=$(get_os_type)

    case "$os_type" in
        centos|kylin)
            if check_command "firewall-cmd"; then
                firewall-cmd --permanent --add-port=${PROMETHEUS_PORT}/tcp 2>/dev/null || true
                firewall-cmd --reload 2>/dev/null || true
                log_success "防火墙规则已配置（firewalld）"
            else
                log_warn "未找到 firewall-cmd，跳过防火墙配置"
            fi
            ;;
        ubuntu|debian)
            if check_command "ufw"; then
                ufw allow ${PROMETHEUS_PORT}/tcp 2>/dev/null || true
                log_success "防火墙规则已配置（ufw）"
            else
                log_warn "未找到 ufw，跳过防火墙配置"
            fi
            ;;
        *)
            log_warn "未知操作系统类型，跳过防火墙配置"
            ;;
    esac
}

# ============================================
# 启动服务
# ============================================

start_service() {
    log_info "启动 Prometheus 服务..."

    # 启用服务
    systemctl enable prometheus
    systemctl start prometheus

    # 等待服务启动
    log_info "等待 Prometheus 启动..."
    sleep 5

    # 检查服务状态
    if systemctl is-active --quiet prometheus; then
        log_success "Prometheus 服务启动成功"
    else
        log_error "Prometheus 服务启动失败"
        systemctl status prometheus
        exit 1
    fi

    # 检查端口监听
    if wait_for_port "$PROMETHEUS_PORT" 30; then
        log_success "Prometheus 端口 ${PROMETHEUS_PORT} 监听正常"
    else
        log_error "Prometheus 端口 ${PROMETHEUS_PORT} 未监听"
        exit 1
    fi
}

# ============================================
# 验证安装
# ============================================

verify_installation() {
    log_info "验证 Prometheus 安装..."

    # 检查进程
    if pgrep -f "prometheus" > /dev/null; then
        log_success "Prometheus 进程运行正常"
    else
        log_error "Prometheus 进程未运行"
        exit 1
    fi

    # 访问 Web UI
    local prometheus_url="http://localhost:${PROMETHEUS_PORT}"
    log_info "访问 Prometheus Web UI: $prometheus_url"

    if command -v curl >/dev/null 2>&1; then
        if curl -s -f "$prometheus_url" > /dev/null; then
            log_success "Prometheus Web UI 可访问"
        else
            log_error "Prometheus Web UI 不可访问"
            exit 1
        fi
    fi
}

# ============================================
# 显示安装信息
# ============================================

show_install_info() {
    echo ""
    echo "============================================"
    echo "    Prometheus 安装完成"
    echo "============================================"
    echo ""
    echo "安装信息："
    echo "  安装目录: $PROMETHEUS_INSTALL_DIR"
    echo "  数据目录: $PROMETHEUS_DATA_DIR"
    echo "  日志目录: $PROMETHEUS_LOG_DIR"
    echo "  服务端口: $PROMETHEUS_PORT"
    echo "  数据保留: $PROMETHEUS_RETENTION"
    echo ""
    echo "访问地址："
    echo "  - Web UI: http://$(get_local_ip):${PROMETHEUS_PORT}"
    echo "  - 目标: http://$(get_local_ip):${PROMETHEUS_PORT}/metrics"
    echo ""
    echo "服务管理："
    echo "  - 启动: systemctl start prometheus"
    echo "  - 停止: systemctl stop prometheus"
    echo "  - 重启: systemctl restart prometheus"
    echo "  - 状态: systemctl status prometheus"
    echo "  - 日志: journalctl -u prometheus -f"
    echo ""
    echo "配置文件："
    echo "  - $PROMETHEUS_INSTALL_DIR/prometheus.yml"
    echo ""
    echo "============================================"
    echo ""
}

# ============================================
# 主安装流程
# ============================================

main() {
    # 初始化日志
    mkdir -p "$(dirname "$LOG_FILE")"
    touch "$LOG_FILE"

    log_info "开始安装 Prometheus..."

    # 加载配置文件
    load_config

    # 检查是否已安装
    check_prometheus_installed

    # 创建目录结构
    create_directories

    # 解压安装包
    extract_prometheus

    # 生成配置文件
    generate_config

    # 创建 systemd 服务
    create_systemd_service

    # 配置防火墙
    configure_firewall

    # 启动服务
    start_service

    # 验证安装
    verify_installation

    # 显示安装信息
    show_install_info

    log_success "Prometheus 安装完成！"
}

# ============================================
# 脚本入口
# ============================================

main "$@"
