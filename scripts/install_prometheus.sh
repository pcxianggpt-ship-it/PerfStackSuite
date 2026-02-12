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

PROMETHEUS_VERSION="${PROMETHEUS_VERSION:-3.5.1}"
PROMETHEUS_PORT="${PROMETHEUS_PORT:-9090}"

# 检测是否为 root 用户，设置不同的安装路径
if [ "$(id -u)" -eq 0 ]; then
    # root 用户安装到系统目录
    PROMETHEUS_INSTALL_DIR="${INSTALL_BASE_DIR}/prometheus"
    PROMETHEUS_DATA_DIR="${DATA_BASE_DIR}/prometheus"
    PROMETHEUS_LOG_DIR="/var/log/prometheus"
    IS_ROOT_INSTALL=true
else
    # 普通用户安装到用户目录
    PROMETHEUS_INSTALL_DIR="$HOME/prometheus"
    PROMETHEUS_DATA_DIR="$HOME/prometheus/data"
    PROMETHEUS_LOG_DIR="$HOME/prometheus/logs"
    IS_ROOT_INSTALL=false
fi

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
# 创建 systemd 服务文件或启动脚本
# ============================================

create_systemd_service() {
    if [ "$IS_ROOT_INSTALL" = true ]; then
        create_system_service_file
    else
        create_user_service_or_scripts
    fi
}

# 创建系统级 systemd 服务（需要 root）
create_system_service_file() {
    log_info "创建 Prometheus systemd 系统服务..."

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

# 环境变量
Environment=GF_PATHS_HOME=${PROMETHEUS_INSTALL_DIR}
Environment=GF_PATHS_DATA=${PROMETHEUS_DATA_DIR}
Environment=GF_PATHS_LOGS=${PROMETHEUS_LOG_DIR}

[Install]
WantedBy=multi-user.target
EOF

    # 重载 systemd
    log_info "重载 systemd 配置..."
    systemctl daemon-reload

    log_success "systemd 服务创建完成"
}

# 创建用户级服务或启动脚本（普通用户）
create_user_service_or_scripts() {
    log_info "配置 Prometheus 启动方式..."

    # 尝试创建用户级 systemd 服务
    if create_user_systemd_service; then
        log_success "使用用户级 systemd 服务"
        GRAFANA_SERVICE_TYPE="user-systemd"
    else
        log_warn "systemctl --user 不可用，请手动启动服务"
        GRAFANA_SERVICE_TYPE="manual"
    fi
}

# 创建用户级 systemd 服务
create_user_systemd_service() {
    local user_service_dir="$HOME/.config/systemd/user"
    local service_file="$user_service_dir/prometheus.service"

    # 创建目录
    mkdir -p "$user_service_dir"

    # 检查 systemd 用户服务是否支持
    if ! systemctl --user list-units &>/dev/null; then
        return 1
    fi

    cat > "$service_file" <<EOF
[Unit]
Description=Prometheus Monitoring System
Documentation=https://prometheus.io/docs/introduction/overview/
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
WorkingDirectory=${PROMETHEUS_INSTALL_DIR}

# 启动命令
ExecStart=${PROMETHEUS_INSTALL_DIR}/prometheus \\
    --config.file=${PROMETHEUS_INSTALL_DIR}/prometheus.yml \\
    --storage.tsdb.path=${PROMETHEUS_DATA_DIR} \\
    --storage.tsdb.retention.time=${PROMETHEUS_RETENTION} \\
    --web.listen-address=:${PROMETHEUS_PORT} \\
    --web.external-url=http://$(get_local_ip):${PROMETHEUS_PORT}

# 重启策略
Restart=always
RestartSec=10

# 资源限制
LimitNOFILE=65536

# 环境变量
Environment=GF_PATHS_HOME=${PROMETHEUS_INSTALL_DIR}
Environment=GF_PATHS_DATA=${PROMETHEUS_DATA_DIR}
Environment=GF_PATHS_LOGS=${PROMETHEUS_LOG_DIR}

[Install]
WantedBy=default.target
EOF

    # 重载用户 systemd
    systemctl --user daemon-reload 2>/dev/null || true

    log_success "用户级 systemd 服务创建完成"
    return 0
}

# 创建启动脚本（备选方案）
create_startup_scripts() {
    # 创建启动脚本
    cat > "$PROMETHEUS_INSTALL_DIR/start.sh" <<'SCRIPT_EOF'
#!/bin/bash
# Prometheus 启动脚本

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# 检查是否已运行
if [ -f "$SCRIPT_DIR/prometheus.pid" ]; then
    PID=$(cat "$SCRIPT_DIR/prometheus.pid")
    if ps -p "$PID" > /dev/null 2>&1; then
        echo "Prometheus 已在运行 (PID: $PID)"
        exit 1
    fi
fi

# 启动 Prometheus
echo "启动 Prometheus..."
nohup "$SCRIPT_DIR/prometheus" \\
    --config.file="$SCRIPT_DIR/prometheus.yml" \\
    --storage.tsdb.path="$SCRIPT_DIR/data" \\
    --storage.tsdb.retention.time=${PROMETHEUS_RETENTION} \\
    --web.listen-address=:${PROMETHEUS_PORT} \\
    > "$SCRIPT_DIR/prometheus.out" 2>&1 &

PID=$!
echo $PID > "$SCRIPT_DIR/prometheus.pid"

echo "Prometheus 已启动 (PID: $PID)"
echo "日志: $SCRIPT_DIR/prometheus.out"
SCRIPT_EOF

    # 创建停止脚本
    cat > "$PROMETHEUS_INSTALL_DIR/stop.sh" <<'SCRIPT_EOF'
#!/bin/bash
# Prometheus 停止脚本

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PID_FILE="$SCRIPT_DIR/prometheus.pid"

if [ ! -f "$PID_FILE" ]; then
    echo "Prometheus 未运行"
    exit 0
fi

PID=$(cat "$PID_FILE")

if ps -p "$PID" > /dev/null 2>&1; then
    echo "停止 Prometheus (PID: $PID)..."
    kill "$PID"
    sleep 2

    # 强制杀死如果还在运行
    if ps -p "$PID" > /dev/null 2>&1; then
        echo "强制停止 Prometheus..."
        kill -9 "$PID"
    fi

    rm -f "$PID_FILE"
    echo "Prometheus 已停止"
else
    echo "Prometheus 进程不存在"
    rm -f "$PID_FILE"
fi
SCRIPT_EOF

    # 创建状态检查脚本
    cat > "$PROMETHEUS_INSTALL_DIR/status.sh" <<'SCRIPT_EOF'
#!/bin/bash
# Prometheus 状态检查脚本

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PID_FILE="$SCRIPT_DIR/prometheus.pid"

if [ ! -f "$PID_FILE" ]; then
    echo "Prometheus 未运行"
    exit 1
fi

PID=$(cat "$PID_FILE")

if ps -p "$PID" > /dev/null 2>&1; then
    echo "Prometheus 正在运行 (PID: $PID)"
    exit 0
else
    echo "Prometheus 未运行 (PID 文件存在但进程不存在)"
    exit 1
fi
SCRIPT_EOF

    # 添加执行权限
    chmod +x "$PROMETHEUS_INSTALL_DIR/start.sh"
    chmod +x "$PROMETHEUS_INSTALL_DIR/stop.sh"
    chmod +x "$PROMETHEUS_INSTALL_DIR/status.sh"

    log_success "启动脚本创建完成"
}

# ============================================
# 配置防火墙（仅 root 安装）
# ============================================

configure_firewall() {
    # 普通用户无法配置防火墙
    if [ "$IS_ROOT_INSTALL" = false ]; then
        log_info "普通用户安装，跳过防火墙配置"
        log_warn "注意：需要手动配置防火墙开放端口 ${PROMETHEUS_PORT}"
        return 0
    fi

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
    if [ "$IS_ROOT_INSTALL" = true ]; then
        start_system_service
    else
        start_user_service
    fi
}

# 启动系统级服务（root）
start_system_service() {
    log_info "启动 Prometheus 系统服务..."

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

# 启动用户级服务（普通用户）
start_user_service() {
    log_info "Prometheus 普通用户安装，使用 systemctl --user 启动服务"
    log_info "启动命令："
    log_info "  systemctl --user start prometheus"
    log_info "  停止: systemctl --user stop prometheus"
    log_info "  重启: systemctl --user restart prometheus"
    log_info "  状态: systemctl --user status prometheus"
    log_info "  日志: journalctl --user -u prometheus -f"
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

    if [ "$IS_ROOT_INSTALL" = true ]; then
        echo "  安装模式: 系统级安装"
    else
        echo "  安装模式: 用户级安装 ($USER)"
    fi
    echo ""

    echo "访问地址："
    echo "  - Web UI: http://$(get_local_ip):${PROMETHEUS_PORT}"
    echo "  - 目标: http://$(get_local_ip):${PROMETHEUS_PORT}/metrics"
    echo ""

    echo "服务管理："
    if [ "$IS_ROOT_INSTALL" = true ]; then
        echo "  - 启动: systemctl start prometheus"
        echo "  - 停止: systemctl stop prometheus"
        echo "  - 重启: systemctl restart prometheus"
        echo "  - 状态: systemctl status prometheus"
        echo "  - 日志: journalctl -u prometheus -f"
    else
        echo "  普通用户安装，使用 systemctl --user 管理服务"
        echo "  - 启动: systemctl --user start prometheus"
        echo "  - 停止: systemctl --user stop prometheus"
        echo "  - 重启: systemctl --user restart prometheus"
        echo "  - 状态: systemctl --user status prometheus"
        echo "  - 日志: journalctl --user -u prometheus -f"
    fi
    echo ""

    echo "配置文件："
    echo "  - $PROMETHEUS_INSTALL_DIR/prometheus.yml"
    echo ""

    if [ "$IS_ROOT_INSTALL" = false ]; then
        echo "提示："
        echo "  - 如需开机自启，在 ~/.bash_profile 中添加启动命令"
        echo "  - 如需配置防火墙，请联系管理员开放端口 ${PROMETHEUS_PORT}"
        echo ""
    fi

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
