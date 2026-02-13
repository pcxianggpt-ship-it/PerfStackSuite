#!/bin/bash
#
# InfluxDB 安装脚本
# 功能：自动部署 InfluxDB 1.8.10 时序数据库
# 版本：InfluxDB 1.8.10 (1.x 系列 LTS 版本)
# 适用场景：JMeter 性能监控（原生支持 InfluxDB 1.x）
#

set -e  # 遇到错误时退出

# 获取脚本目录
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# 加载公共函数库
source "${SCRIPT_DIR}/common.sh"

# ============================================
# 常量定义
# ============================================

INFLUXDB_VERSION="${INFLUXDB_VERSION:-1.8.10}"
INFLUXDB_PORT="${INFLUXDB_PORT:-8086}"

# 统一目录架构：root 和普通用户都使用 $HOME/xx 结构
INFLUXDB_INSTALL_DIR="$HOME/influxdb"
INFLUXDB_DATA_DIR="$HOME/influxdb/data"
INFLUXDB_META_DIR="$HOME/influxdb/meta"
INFLUXDB_LOG_DIR="$HOME/influxdb/logs"
INFLUXDB_CONF_DIR="$HOME/influxdb/conf"

INFLUXDB_RETENTION="${INFLUXDB_RETENTION:-30d}"
INFLUXDB_DB_NAME="${INFLUXDB_DB_NAME:-jmeter}"

# 检测是否为 root 用户
if [ "$(id -u)" -eq 0 ]; then
    IS_ROOT_INSTALL=true
    log_info "检测到 root 用户，安装目录：/root/influxdb"
else
    IS_ROOT_INSTALL=false
    log_info "检测到普通用户，安装目录：$HOME/influxdb"
fi

# ============================================
# 检查是否已安装
# ============================================

check_influxdb_installed() {
    if [ -d "$INFLUXDB_INSTALL_DIR" ] && [ -f "$INFLUXDB_INSTALL_DIR/influxd" ]; then
        log_warn "InfluxDB 似乎已经安装"
        read -p "是否重新安装？(y/N): " reinstall
        if [ "$reinstall" != "y" ] && [ "$reinstall" != "Y" ]; then
            log_info "取消安装"
            exit 0
        fi
        log_warn "将重新安装 InfluxDB"
    fi
}

# ============================================
# 创建目录结构
# ============================================

create_directories() {
    log_info "创建 InfluxDB 目录结构..."

    create_dir "$INFLUXDB_INSTALL_DIR" 755
    create_dir "$INFLUXDB_DATA_DIR" 755
    create_dir "$INFLUXDB_META_DIR" 755
    create_dir "$INFLUXDB_LOG_DIR" 755
    create_dir "$INFLUXDB_CONF_DIR" 755

    log_success "目录结构创建完成"
}

# ============================================
# 查找并解压安装包
# ============================================

extract_influxdb() {
    log_info "查找 InfluxDB 安装包..."

    # 查找安装包（InfluxDB 1.8.10）
    local tarball=$(find "$SOFT_DIR" -name "influxdb-1.8.10_linux_amd64.tar.gz" 2>/dev/null | head -1)

    if [ -z "$tarball" ]; then
        log_error "未找到 InfluxDB 1.8.10 安装包"
        log_error "请将 influxdb-${INFLUXDB_VERSION}_linux_amd64.tar.gz 放在 $SOFT_DIR 目录"
        log_error ""
        log_error "下载命令："
        log_error "  cd $SOFT_DIR"
        log_error "  wget https://dl.influxdata.com/influxdb/releases/influxdb-${INFLUXDB_VERSION}_linux_amd64.tar.gz"
        exit 1
    fi

    log_info "找到安装包: $tarball"

    # 解压到临时目录
    local temp_dir="/tmp/influxdb_install"
    create_dir "$temp_dir" 755

    log_info "正在解压 InfluxDB..."
    extract_tar "$tarball" "$temp_dir"

    # 查找解压后的目录（InfluxDB 1.8.10 解压后目录名：influxdb-1.8.10-1）
    local extracted_dir=$(find "$temp_dir" -maxdepth 1 -type d -name "influxdb-*" | head -1)
    if [ -z "$extracted_dir" ]; then
        log_error "解压后未找到 InfluxDB 1.8.10 目录"
        log_error "期望目录名: influxdb-${INFLUXDB_VERSION}-1"
        log_info "实际解压内容："
        ls -la "$temp_dir"
        exit 1
    fi

    log_info "找到解压目录: $(basename "$extracted_dir")"
    log_info "复制文件到安装目录..."

    # 统一处理：直接复制所有文件到安装目录根目录
    # 无论 influxd 在根目录还是 usr/bin/ 下，都能正确处理
    cp -rf "$extracted_dir"/* "$INFLUXDB_INSTALL_DIR/"

    # 确保二进制文件可执行
    # InfluxDB 1.8.10 二进制文件在 usr/bin/ 子目录
    if [ -f "$INFLUXDB_INSTALL_DIR/usr/bin/influxd" ]; then
        chmod +x "$INFLUXDB_INSTALL_DIR/usr/bin/influxd"
        log_info "已设置 influxd 执行权限"
    fi

    if [ -f "$INFLUXDB_INSTALL_DIR/usr/bin/influx" ]; then
        chmod +x "$INFLUXDB_INSTALL_DIR/usr/bin/influx"
        log_info "已设置 influx 执行权限"
    fi

    # 创建符号链接到 PATH（方便用户直接使用 influx 命令）
    # 如果系统不支持软链接，则尝试添加到 PATH 环境变量
    if [ -f "$INFLUXDB_INSTALL_DIR/usr/bin/influxd" ] && [ ! -L "$INFLUXDB_INSTALL_DIR/influxd" ]; then
        if ln -sf "$INFLUXDB_INSTALL_DIR/usr/bin/influxd" "$INFLUXDB_INSTALL_DIR/influxd" 2>/dev/null; then
            log_info "已创建 influxd 符号链接"
        else
            log_warn "符号链接创建失败，将使用 alias 方式"
            # 软链接失败，不创建链接，依赖 PATH 环境变量
        fi
    fi

    if [ -f "$INFLUXDB_INSTALL_DIR/usr/bin/influx" ] && [ ! -L "$INFLUXDB_INSTALL_DIR/influx" ]; then
        if ln -sf "$INFLUXDB_INSTALL_DIR/usr/bin/influx" "$INFLUXDB_INSTALL_DIR/influx" 2>/dev/null; then
            log_info "已创建 influx 符号链接"
        else
            log_warn "符号链接创建失败，将使用 alias 方式"
            # 软链接失败，不创建链接，依赖 PATH 环境变量
        fi
    fi

    # 清理临时目录
    rm -rf "$temp_dir"

    log_success "InfluxDB 1.8.10 安装包解压完成"
}

# ============================================
# 生成配置文件
# ============================================

generate_config() {
    log_info "生成 InfluxDB 1.8.10 配置文件..."

    local config_file="$INFLUXDB_CONF_DIR/influxdb.conf"

    # 备份原有配置（如果存在）
    backup_file "$config_file"

    cat > "$config_file" <<EOF
# InfluxDB 1.8.10 配置文件
# 自动生成时间: $(date)
#
# InfluxDB 1.8.10 配置参考：
# https://docs.influxdata.com/influxdb/v1.8/administration/config/

# ============================================
# 元数据存储配置
# ============================================
[meta]
  # 元数据存储目录
  dir = "$INFLUXDB_META_DIR"

# ============================================
# 数据存储配置
# ============================================
[data]
  # 数据存储目录
  dir = "$INFLUXDB_DATA_DIR"

  # 存储引擎：tsm1 (Time-Structured Merge Tree)
  engine = "tsm1"

  # WAL (Write-Ahead Log) 目录
  wal-dir = "$INFLUXDB_DATA_DIR/wal"

  # 查询超时时间（秒）
  # query-log-enabled = true

  # 缓存设置
  # cache-max-memory-size = 1073741824
  # cache-snapshot-memory-size = 26214400


# ============================================
# 日志配置
# ============================================
[logging]
  # 日志格式：auto, json, text
  format = "auto"

  # 日志级别：debug, info, warn, error
  level = "info"

  # 是否显示 Logo
  suppress-logo = false

# ============================================
# HTTP API 配置
# ============================================
[http]
  # 启用 HTTP API
  enabled = true

  # 监听地址和端口
  bind-address = ":${INFLUXDB_PORT}"

  # 启用认证（强烈推荐）
  auth-enabled = true

  # 启用 HTTP 日志
  log-enabled = true

  # 最大连接数（0 = 无限制）
  max-connection-limit = 0

  # 最大请求体大小（字节，默认 25MB）
  max-body-size = 25000000

# ============================================
# 持续性查询配置（可选）
# ============================================
[continuous_queries]
  # 是否启用持续查询日志
  log-enabled = true

# ============================================
# 监控端点（可选）
# ============================================
# [monitor]
#   store-enabled = true
EOF

    log_success "InfluxDB 1.8.10 配置文件生成完成: $config_file"
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
    log_info "创建 InfluxDB systemd 系统服务..."

    local service_file="/etc/systemd/system/influxdb.service"

    backup_file "$service_file"

    cat > "$service_file" <<EOF
[Unit]
Description=InfluxDB Time Series Database
Documentation=https://docs.influxdata.com/
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
User=root
Group=root

# 工作目录
WorkingDirectory=${INFLUXDB_INSTALL_DIR}

# 启动命令
ExecStart=${INFLUXDB_INSTALL_DIR}/influxd \\
    --config ${INFLUXDB_CONF_DIR}/influxdb.conf \\
    --pidfile /var/run/influxdb/influxdb.pid

# 重启策略
Restart=always
RestartSec=10

# 资源限制
LimitNOFILE=65536

# 安全加固

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
    log_info "配置 InfluxDB 启动方式..."

    # 尝试创建用户级 systemd 服务
    if create_user_systemd_service; then
        log_success "使用用户级 systemd 服务"
    else
        log_warn "systemctl --user 不可用，请手动启动服务"
    fi
}

# 创建用户级 systemd 服务
create_user_systemd_service() {
    local user_service_dir="$HOME/.config/systemd/user"
    local service_file="$user_service_dir/influxdb.service"

    # 创建目录
    mkdir -p "$user_service_dir"

    # 检查 systemd 用户服务是否支持
    # 使用 XDG_RUNTIME_DIR 检查用户 systemd 是否运行
    if [ -z "$XDG_RUNTIME_DIR" ]; then
        log_warn "未检测到用户 systemd 运行环境（XDG_RUNTIME_DIR 未设置）"
        return 1
    fi

    # 尝试列出用户服务（可能因为 pager 权限问题失败，忽略）
    if ! SYSTEMD_PAGER= systemctl --user list-units &>/dev/null; then
        log_warn "systemctl --user 不可用"
        return 1
    fi

    cat > "$service_file" <<EOF
[Unit]
Description=InfluxDB 1.8.10 Time Series Database
Documentation=https://docs.influxdata.com/influxdb/v1.8/
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
#User=$USER
#Group=$USER
WorkingDirectory=${INFLUXDB_INSTALL_DIR}

# 启动命令
ExecStart=${INFLUXDB_INSTALL_DIR}/usr/bin/influxd \\
    --config ${INFLUXDB_CONF_DIR}/influxdb.conf \\

# 环境变量
Environment="HOME=$HOME"
Environment="USER=$USER"

# 重启策略
Restart=always
RestartSec=10

# 资源限制
LimitNOFILE=65536

# 标准输出/错误输出
StandardOutput=append:${INFLUXDB_LOG_DIR}/influxdb.stdout.log
StandardError=append:${INFLUXDB_LOG_DIR}/influxdb.stderr.log

[Install]
WantedBy=default.target
EOF

    # 重载用户 systemd（禁用 pager 避免权限问题）
    SYSTEMD_PAGER= systemctl --user daemon-reload 2>/dev/null || true

    log_success "用户级 systemd 服务创建完成"
    return 0
}

# ============================================
# 配置环境变量 PATH
# ============================================

configure_path() {
    log_info "配置 InfluxDB 环境变量..."

    local bin_dir="$INFLUXDB_INSTALL_DIR/usr/bin"

    # 确定配置文件
    local config_file=""
    if [ -f "$HOME/.bashrc" ]; then
        config_file="$HOME/.bashrc"
    elif [ -f "$HOME/.bash_profile" ]; then
        config_file="$HOME/.bash_profile"
    else
        config_file="$HOME/.bashrc"
    fi

    # 检查是否已经配置过
    if grep -q "InfluxDB 1.8.10" "$config_file" 2>/dev/null; then
        log_info "PATH 已配置，跳过"
        return 0
    fi

    # 添加 PATH 配置
    cat >> "$config_file" <<EOF

# ============================================
# InfluxDB 1.8.10 环境变量
# ============================================
export PATH="$bin_dir:\$PATH"
EOF

    log_success "已将 $bin_dir 添加到 PATH"
    log_info "请执行以下命令使配置生效："
    log_info "  source $config_file"
    log_info "或者重新登录系统"

    # 为当前会话添加 PATH
    export PATH="$bin_dir:$PATH"

    return 0
}

# ============================================
# 配置防火墙（仅 root 安装）
# ============================================

configure_firewall() {
    # 普通用户无法配置防火墙
    if [ "$IS_ROOT_INSTALL" = false ]; then
        log_info "普通用户安装，跳过防火墙配置"
        log_warn "注意：需要手动配置防火墙开放端口 ${INFLUXDB_PORT}"
        return 0
    fi

    log_info "配置防火墙规则..."

    local os_type=$(get_os_type)

    case "$os_type" in
        centos|kylin)
            if check_command "firewall-cmd"; then
                firewall-cmd --permanent --add-port=${INFLUXDB_PORT}/tcp 2>/dev/null || true
                firewall-cmd --reload 2>/dev/null || true
                log_success "防火墙规则已配置（firewalld）"
            else
                log_warn "未找到 firewall-cmd，跳过防火墙配置"
            fi
            ;;
        ubuntu|debian)
            if check_command "ufw"; then
                ufw allow ${INFLUXDB_PORT}/tcp 2>/dev/null || true
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
    log_info "启动 InfluxDB 系统服务..."

    # 启用服务
    systemctl enable influxdb

    # 启动服务
    systemctl start influxdb

    # 等待服务启动
    log_info "等待 InfluxDB 启动..."
    sleep 5

    # 检查服务状态
    if systemctl is-active --quiet influxdb; then
        log_success "InfluxDB 服务启动成功"
    else
        log_error "InfluxDB 服务启动失败"
        systemctl status influxdb
        exit 1
    fi

    # 检查端口监听
    if wait_for_port "$INFLUXDB_PORT" 30; then
        log_success "InfluxDB 端口 ${INFLUXDB_PORT} 监听正常"
    else
        log_error "InfluxDB 端口 ${INFLUXDB_PORT} 未监听"
        exit 1
    fi
}

# 启动用户级服务（普通用户）
start_user_service() {
    log_info "尝试启动 InfluxDB 用户级服务..."

    # 设置环境变量避免 pager 权限问题
    export SYSTEMD_PAGER=

    # 尝试启用并启动用户服务
    if systemctl --user daemon-reload &>/dev/null 2>&1; then
        # systemd 用户服务可用
        if systemctl --user enable influxdb &>/dev/null 2>&1; then
            log_success "InfluxDB 用户服务已启用"
        fi

        if systemctl --user start influxdb 2>&1; then
            log_success "InfluxDB 用户服务启动成功"

            # 等待服务启动
            sleep 3

            # 检查服务状态（禁用 pager 避免权限问题）
            if SYSTEMD_PAGER= systemctl --user is-active --quiet influxdb 2>/dev/null; then
                log_success "InfluxDB 服务运行正常"
            fi
        else
            log_warn "systemctl --user start 失败，将创建手动启动脚本"
            create_startup_script
        fi
    else
        log_warn "systemctl --user 不可用，创建手动启动脚本"
        create_startup_script
    fi

    # 显示服务管理命令
    log_info ""
    log_info "服务管理命令："
    log_info "  systemctl --user start influxdb      # 启动服务"
    log_info "  systemctl --user stop influxdb       # 停止服务"
    log_info "  systemctl --user restart influxdb     # 重启服务"
    log_info "  SYSTEMD_PAGER= systemctl --user status influxdb  # 查看状态（避免 pager 错误）"
    log_info "  journalctl --user -u influxdb -f   # 查看日志"
}

# 创建手动启动脚本（备选方案）
create_startup_script() {
    log_info "创建 InfluxDB 手动启动脚本..."

    # 创建启动脚本
    cat > "$INFLUXDB_INSTALL_DIR/start.sh" <<'SCRIPT_EOF'
#!/bin/bash
# InfluxDB 1.8.10 manual start script

# InfluxDB installation directory
INFLUXDB_INSTALL_DIR="$HOME/influxdb"
INFLUXDB_CONF_DIR="$HOME/influxdb/conf"
INFLUXDB_LOG_DIR="$HOME/influxdb/logs"
PID_FILE="$INFLUXDB_LOG_DIR/influxdb.pid"

# Check if already running
if [ -f "$PID_FILE" ]; then
    PID=$(cat "$PID_FILE")
    if ps -p "$PID" > /dev/null 2>&1; then
        echo "InfluxDB is already running (PID: $PID)"
        exit 0
    fi
fi

# Start InfluxDB
echo "Starting InfluxDB 1.8.10..."
# 使用符号链接，实际指向 usr/bin/influxd
nohup "$INFLUXDB_INSTALL_DIR/influxd" \
    --config "$INFLUXDB_CONF_DIR/influxdb.conf" \
    --pidfile "$INFLUXDB_LOG_DIR/influxdb.pid" \
    >> "$INFLUXDB_LOG_DIR/influxdb.stdout.log" 2>&1 &

PID=$!
echo $PID > "$PID_FILE"
echo "InfluxDB started (PID: $PID)"
echo "Log file: $INFLUXDB_LOG_DIR/influxdb.stdout.log"
SCRIPT_EOF

    # 创建停止脚本
    cat > "$INFLUXDB_INSTALL_DIR/stop.sh" <<'SCRIPT_EOF'
#!/bin/bash
# InfluxDB 1.8.10 manual stop script

PID_FILE="$HOME/influxdb/logs/influxdb.pid"

if [ ! -f "$PID_FILE" ]; then
    echo "InfluxDB is not running"
    exit 0
fi

PID=$(cat "$PID_FILE")

if ps -p "$PID" > /dev/null 2>&1; then
    echo "Stopping InfluxDB (PID: $PID)..."
    kill "$PID"
    sleep 2

    # Force kill if still running
    if ps -p "$PID" > /dev/null 2>&1; then
        echo "Force stopping InfluxDB..."
        kill -9 "$PID"
    fi

    rm -f "$PID_FILE"
    echo "InfluxDB stopped"
else
    echo "InfluxDB process does not exist"
    rm -f "$PID_FILE"
fi
SCRIPT_EOF

    # 创建状态检查脚本
    cat > "$INFLUXDB_INSTALL_DIR/status.sh" <<'SCRIPT_EOF'
#!/bin/bash
# InfluxDB 1.8.10 status check script

PID_FILE="$HOME/influxdb/logs/influxdb.pid"

if [ ! -f "$PID_FILE" ]; then
    echo "InfluxDB is not running"
    exit 1
fi

PID=$(cat "$PID_FILE")

if ps -p "$PID" > /dev/null 2>&1; then
    echo "InfluxDB is running (PID: $PID)"
    exit 0
else
    echo "InfluxDB is not running (PID file exists but process not found)"
    exit 1
fi
SCRIPT_EOF

    # 添加执行权限
    chmod +x "$INFLUXDB_INSTALL_DIR/start.sh"
    chmod +x "$INFLUXDB_INSTALL_DIR/stop.sh"
    chmod +x "$INFLUXDB_INSTALL_DIR/status.sh"

    log_success "Manual startup scripts created"
    log_info "  - Start: $INFLUXDB_INSTALL_DIR/start.sh"
    log_info "  - Stop: $INFLUXDB_INSTALL_DIR/stop.sh"
    log_info "  - Status: $INFLUXDB_INSTALL_DIR/status.sh"
}

# ============================================
# 初始化数据库和用户
# ============================================

init_database() {
    log_info "等待 InfluxDB 1.8.10 完全启动..."

    # 等待端口监听
    if ! wait_for_port "$INFLUXDB_PORT" 30; then
        log_error "InfluxDB 1.8.10 启动超时，端口 ${INFLUXDB_PORT} 未监听"
        log_error "请检查 InfluxDB 日志: tail -f $INFLUXDB_LOG_DIR/influxd.log"
        exit 1
    fi

    log_info "初始化 InfluxDB 1.8.10 数据库和用户..."

    # 等待几秒让服务完全启动
    sleep 3

    # 使用 influx CLI 执行命令（InfluxDB 1.x 语法）
    # 优先使用完整路径，确保无需依赖 PATH
    local influx_cmd="$INFLUXDB_INSTALL_DIR/usr/bin/influx"

    if [ ! -f "$influx_cmd" ]; then
        log_error "未找到 influx CLI 工具"
        log_error "请确认 InfluxDB 1.8.10 安装正确"
        log_error "influx 二进制位置: $influx_cmd"
        exit 1
    fi

    # 创建数据库（InfluxDB 1.x 语法）
    log_info "创建数据库: ${INFLUXDB_DB_NAME}"
    local create_db_result=$(echo "CREATE DATABASE ${INFLUXDB_DB_NAME}" | "$influx_cmd" 2>&1)
    if echo "$create_db_result" | grep -q "Created"; then
        log_success "数据库 ${INFLUXDB_DB_NAME} 创建成功"
    else
        log_warn "数据库创建返回: $create_db_result"
    fi

    # 从配置文件读取管理员账号
    local admin_user="${INFLUXDB_ADMIN_USER:-admin}"
    local admin_password="${INFLUXDB_ADMIN_PASSWORD:-admin123}"

    # 创建管理员用户（InfluxDB 1.x 语法）
    log_info "创建管理员用户: ${admin_user}"
    local create_admin_result=$(echo "CREATE USER ${admin_user} WITH PASSWORD '${admin_password}' WITH ALL PRIVILEGES" | "$influx_cmd" 2>&1)
    if echo "$create_admin_result" | grep -q "Created"; then
        log_success "管理员用户 ${admin_user} 创建成功"
    else
        log_warn "管理员用户创建返回: $create_admin_result"
    fi

    # 从配置文件读取普通用户信息
    local jmeter_user="${INFLUXDB_JMETER_USER:-jmeter}"
    local jmeter_password="${INFLUXDB_JMETER_PASSWORD:-jmeter123}"

    # 创建 JMeter 用户（InfluxDB 1.x 语法）
    log_info "创建 JMeter 用户: ${jmeter_user}"
    local create_jmeter_result=$(echo "CREATE USER ${jmeter_user} WITH PASSWORD '${jmeter_password}'" | "$influx_cmd" 2>&1)
    if echo "$create_jmeter_result" | grep -q "Created"; then
        log_success "JMeter 用户 ${jmeter_user} 创建成功"
    else
        log_warn "JMeter 用户创建返回: $create_jmeter_result"
    fi

    # 设置数据保留策略（InfluxDB 1.x 语法）
    # DURATION: 数据保留时间（如 30d = 30天）
    # REPLICATION: 副本数（单节点设为 1）
    # DEFAULT: 设为默认策略
    log_info "设置数据保留策略: ${INFLUXDB_RETENTION}"
    local retention_result=$(echo "CREATE RETENTION POLICY \"${INFLUXDB_RETENTION}\" ON \"${INFLUXDB_DB_NAME}\" DURATION ${INFLUXDB_RETENTION} REPLICATION 1 DEFAULT" | "$influx_cmd" 2>&1)
    if echo "$retention_result" | grep -q "Created"; then
        log_success "数据保留策略 ${INFLUXDB_RETENTION} 创建成功"
    else
        log_warn "数据保留策略创建返回: $retention_result"
    fi
}

# ============================================
# 验证安装
# ============================================

verify_installation() {
    log_info "验证 InfluxDB 安装..."

    # 检查进程
    if pgrep -f "influxd" > /dev/null; then
        log_success "InfluxDB 进程运行正常"
    else
        log_error "InfluxDB 进程未运行"
        exit 1
    fi

    # 检查端口
    if check_port "$INFLUXDB_PORT"; then
        log_success "端口 ${INFLUXDB_PORT} 监听正常"
    else
        log_error "端口 ${INFLUXDB_PORT} 未监听"
        exit 1
    fi

    # 验证数据库
    local influx_cmd="$INFLUXDB_INSTALL_DIR/usr/bin/influx"
    if [ -f "$influx_cmd" ]; then
        local db_check=$(echo "SHOW DATABASES" | "$influx_cmd" 2>&1)
        if echo "$db_check" | grep -q "$INFLUXDB_DB_NAME"; then
            log_success "数据库 ${INFLUXDB_DB_NAME} 存在"
        else
            log_warn "数据库 ${INFLUXDB_DB_NAME} 未找到"
        fi
    else
        log_warn "influx CLI 不可用，跳过数据库验证"
    fi
}

# ============================================
# 显示安装信息
# ============================================

show_install_info() {
    echo ""
    echo "============================================"
    echo "    InfluxDB 1.8.10 安装完成"
    echo "============================================"
    echo ""
    echo "安装信息："
    echo "  版本: InfluxDB 1.8.10 (1.x LTS)"
    echo "  安装目录: $INFLUXDB_INSTALL_DIR"
    echo "  数据目录: $INFLUXDB_DATA_DIR"
    echo "  元数据目录: $INFLUXDB_META_DIR"
    echo "  日志目录: $INFLUXDB_LOG_DIR"
    echo "  配置目录: $INFLUXDB_CONF_DIR"
    echo "  服务端口: $INFLUXDB_PORT"
    echo "  数据库名称: $INFLUXDB_DB_NAME"
    echo "  数据保留: $INFLUXDB_RETENTION"

    if [ "$IS_ROOT_INSTALL" = true ]; then
        echo "  安装模式: 系统级安装 (root)"
    else
        echo "  安装模式: 用户级安装 ($USER)"
    fi
    echo ""

    echo "访问地址："
    echo "  - HTTP API: http://$(get_local_ip):${INFLUXDB_PORT}"
    echo "  - 管理界面: http://$(get_local_ip):${INFLUXDB_PORT}/debug/vars"
    echo ""

    echo "数据库连接（InfluxDB 1.x 语法）："
    echo "  - 数据库: ${INFLUXDB_DB_NAME}"
    echo "  - 管理员用户: ${INFLUXDB_ADMIN_USER:-admin}"
    echo "  - 管理员密码: ${INFLUXDB_ADMIN_PASSWORD:-admin123}"
    echo "  - JMeter 用户: ${INFLUXDB_JMETER_USER:-jmeter}"
    echo "  - JMeter 密码: ${INFLUXDB_JMETER_PASSWORD:-jmeter123}"
    echo ""

    echo "CLI 工具使用（InfluxDB 1.x）："
    echo "  # 使用完整路径（推荐，无需配置环境变量）"
    echo "  $INFLUXDB_INSTALL_DIR/usr/bin/influx -username ${INFLUXDB_JMETER_USER:-jmeter} -password ${INFLUXDB_JMETER_PASSWORD:-jmeter123}"
    echo "  $INFLUXDB_INSTALL_DIR/usr/bin/influx -execute 'SHOW DATABASES'"
    echo ""
    echo "  # 或直接使用命令（需要先执行 source ~/.bashrc 或重新登录）"
    echo "  influx -username ${INFLUXDB_JMETER_USER:-jmeter} -password ${INFLUXDB_JMETER_PASSWORD:-jmeter123}"
    echo "  influx -execute 'SHOW DATABASES'"
    echo ""

    echo "二进制文件位置："
    echo "  - 服务器进程: $INFLUXDB_INSTALL_DIR/usr/bin/influxd"
    echo "  - CLI 工具: $INFLUXDB_INSTALL_DIR/usr/bin/influx"
    echo ""

    echo "环境变量配置："
    echo "  - PATH 已添加: $INFLUXDB_INSTALL_DIR/usr/bin"
    echo "  - 配置文件: ~/.bashrc 或 ~/.bash_profile"
    echo "  - 使配置生效: source ~/.bashrc"
    echo ""

    echo "服务管理："
    if [ "$IS_ROOT_INSTALL" = true ]; then
        echo "  - 启动: systemctl start influxdb"
        echo "  - 停止: systemctl stop influxdb"
        echo "  - 重启: systemctl restart influxdb"
        echo "  - 状态: systemctl status influxdb"
        echo "  - 日志: journalctl -u influxdb -f"
    else
        echo "  普通用户安装，使用 systemctl --user 管理服务"
        echo "  - 启动: systemctl --user start influxdb"
        echo "  - 停止: systemctl --user stop influxdb"
        echo "  - 重启: systemctl --user restart influxdb"
        echo "  - 状态: systemctl --user status influxdb"
        echo "  - 日志: journalctl --user -u influxdb -f"
    fi
    echo ""

    echo "配置文件："
    echo "  - $INFLUXDB_CONF_DIR/influxdb.conf"
    echo ""

    echo "JMeter Backend Listener 配置："
    echo "  influxdbUrl = http://$(get_local_ip):${INFLUXDB_PORT}/write?db=${INFLUXDB_DB_NAME}"
    echo "  influxdbUser = ${INFLUXDB_JMETER_USER:-jmeter}"
    echo "  influxdbPassword = ${INFLUXDB_JMETER_PASSWORD:-jmeter123}"
    echo ""

    if [ "$IS_ROOT_INSTALL" = false ]; then
        echo "提示："
        echo "  - 如需开机自启，在 ~/.bash_profile 中添加启动命令"
        echo "  - 如需配置防火墙，请联系管理员开放端口 ${INFLUXDB_PORT}"
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

    log_info "============================================"
    log_info "开始安装 InfluxDB 1.8.10..."
    log_info "============================================"

    # 加载配置文件
    load_config

    # 检查是否已安装
    check_influxdb_installed

    # 创建目录结构
    create_directories

    # 解压安装包
    extract_influxdb

    # 生成配置文件
    generate_config

    # 创建 systemd 服务
    create_systemd_service

    # 配置环境变量 PATH
    configure_path

    # 配置防火墙
    configure_firewall

    # 启动服务
    start_service

    # 初始化数据库和用户
    init_database

    # 验证安装
    verify_installation

    # 显示安装信息
    show_install_info

    log_success "InfluxDB 1.8.10 安装完成！"
    log_info "适用于 JMeter 性能监控"
}

# ============================================
# 脚本入口
# ============================================

main "$@"
