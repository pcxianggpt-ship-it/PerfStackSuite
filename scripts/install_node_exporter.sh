#!/bin/bash
#
# Node Exporter 安装脚本
# 功能：本地或远程部署 Node Exporter，支持 systemd 服务管理
# 版本：1.8.2
#

set -e  # 遇到错误时退出

# 获取脚本目录
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# 加载公共函数库
source "${SCRIPT_DIR}/common.sh"

# ============================================
# 常量定义
# ============================================

# 从配置文件读取版本和端口（默认值）
NODE_EXPORTER_VERSION="${NODE_EXPORTER_VERSION:-1.8.2}"
NODE_EXPORTER_PORT="${NODE_EXPORTER_PORT:-9100}"

# 统一目录架构：所有用户都使用 $HOME/xx 结构
NODE_EXPORTER_INSTALL_DIR="$HOME/node_exporter"
NODE_EXPORTER_BIN_DIR="$HOME/node_exporter/bin"

# 远程部署相关变量
REMOTE_DEPLOY_MODE=false
TARGET_SERVER=""
REMOTE_USER=""
REMOTE_IP=""
REMOTE_PORT="22"
REMOTE_PASSWORD=""

# ============================================
# 解析命令行参数
# ============================================

parse_arguments() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --remote|-r)
                REMOTE_DEPLOY_MODE=true
                log_info "启用远程部署模式"
                shift
                ;;
            --target|-t)
                if [ -z "$2" ]; then
                    log_error "选项 --target 需要参数"
                    show_usage
                    exit 1
                fi
                TARGET_SERVER="$2"
                shift 2
                ;;
            --help|-h)
                show_usage
                exit 0
                ;;
            *)
                log_error "未知参数: $1"
                show_usage
                exit 1
                ;;
        esac
    done
}

# ============================================
# 显示使用说明
# ============================================

show_usage() {
    echo "用法: $0 [选项]"
    echo ""
    echo "选项："
    echo "  --remote, -r          启用远程部署模式"
    echo "  --target, -t <name>  指定目标服务器名称"
    echo "  --help, -h           显示此帮助信息"
    echo ""
    echo "示例："
    echo "  # 本地安装"
    echo "  $0"
    echo ""
    echo "  # 远程部署（交互式选择服务器）"
    echo "  $0 --remote"
    echo ""
    echo "  # 远程部署到指定服务器"
    echo "  $0 --remote --target server1"
    echo ""
    echo "配置文件：config/deploy.conf"
    echo "  在 TARGET_SERVERS 数组中配置服务器信息"
    echo "  格式：server_name,192.168.1.100,user,22[,password]"
    echo ""
    echo "功能说明："
    echo "  - 本地模式：在本地服务器安装 Node Exporter"
    echo "  - 远程模式：通过 SSH 在远程服务器部署 Node Exporter"
    echo "  - 自动注册：将 Node Exporter 自动添加到 Prometheus 配置"
}

# ============================================
# 显示远程部署菜单
# ============================================

show_remote_deploy_menu() {
    echo ""
    echo "============================================"
    echo "  Node Exporter 远程部署"
    echo "============================================"
    echo ""
    echo "请选择目标服务器："
    echo ""

    # 从配置文件中的 TARGET_SERVERS 数组读取服务器列表
    local servers=()
    local index=1

    if [ ${#TARGET_SERVERS[@]} -eq 0 ]; then
        log_error "未配置远程服务器"
        log_info "请在 config/deploy.conf 的 TARGET_SERVERS 数组中添加服务器"
        log_info "格式：server_name,192.168.1.100,user,22[,password]"
        log_info "示例："
        log_info "  TARGET_SERVERS=(\""
        log_info "    web-01,192.168.1.100,deployer,22"
        log_info "    web-02,192.168.1.101,deployer,22,mypassword"
        log_info "  )"
        exit 1
    fi

    for server_config in "${TARGET_SERVERS[@]}"; do
        # 跳过注释和空行
        [[ "$server_config" =~ ^#.*$ ]] && continue
        [ -z "$server_config" ] && continue

        IFS=',' read -r name ip user port password <<< "$server_config"

        servers+=("$name|$ip|$user|$port|$password")
        local auth_info="密钥认证"
        [ -n "$password" ] && auth_info="密码认证"
        echo "  $index) $name - $ip ($user) [$auth_info]"
        ((index++))
    done

    echo "  0) 取消"
    echo ""

    if [ ${#servers[@]} -eq 0 ]; then
        log_error "未找到有效的服务器配置"
        log_error "请检查 config/deploy.conf 中的 TARGET_SERVERS 配置"
        exit 1
    fi

    read -p "请输入服务器编号 (0-${#servers[@]}): " choice

    if [ "$choice" = "0" ] || [ -z "$choice" ]; then
        log_info "取消部署"
        exit 0
    fi

    if [ "$choice" -lt 1 ] || [ "$choice" -gt ${#servers[@]} ]; then
        log_error "无效的选择"
        exit 1
    fi

    # 解析选择的服务器信息
    local server_info="${servers[$((choice-1))]}"
    IFS='|' read -r name ip user port password <<< "$server_info"

    TARGET_SERVER="$name"
    REMOTE_USER="$user"
    REMOTE_IP="$ip"
    REMOTE_PORT="${port:-22}"
    REMOTE_PASSWORD="$password"

    log_info "选择目标服务器：$name ($ip)"
    log_info "远程用户：$REMOTE_USER"
    log_info "SSH 端口：$REMOTE_PORT"
    if [ -n "$password" ]; then
        log_info "认证方式：密码认证"
    else
        log_info "认证方式：SSH 密钥认证"
    fi
    echo ""
}

# ============================================
# SSH 密码认证辅助函数
# ============================================

# 执行 SSH 命令（支持密码认证）
ssh_cmd() {
    local cmd="$1"
    local ssh_opts="-o ConnectTimeout=5 -o StrictHostKeyChecking=no"

    if [ -n "$REMOTE_PASSWORD" ]; then
        # 使用 sshpass 自动提供密码
        if check_command "sshpass"; then
            sshpass -p "$REMOTE_PASSWORD" ssh -p "$REMOTE_PORT" $ssh_opts "${REMOTE_USER}@${REMOTE_IP}" "$cmd"
        else
            log_error "未安装 sshpass 工具"
            log_error "请安装: yum install -y sshpass 或 apt-get install -y sshpass"
            log_error "或者配置 SSH 密钥认证（推荐）"
            return 1
        fi
    else
        # 使用 SSH 密钥认证或交互式密码输入
        ssh -p "$REMOTE_PORT" $ssh_opts "${REMOTE_USER}@${REMOTE_IP}" "$cmd"
    fi
}

# 执行 SCP 命令（支持密码认证）
scp_cmd() {
    local source="$1"
    local dest="$2"
    local scp_opts="-o ConnectTimeout=5 -o StrictHostKeyChecking=no"

    if [ -n "$REMOTE_PASSWORD" ]; then
        # 使用 sshpass 自动提供密码
        if check_command "sshpass"; then
            sshpass -p "$REMOTE_PASSWORD" scp -P "$REMOTE_PORT" $scp_opts "$source" "$dest"
        else
            log_error "未安装 sshpass 工具"
            log_error "请安装: yum install -y sshpass 或 apt-get install -y sshpass"
            log_error "或者配置 SSH 密钥认证（推荐）"
            return 1
        fi
    else
        # 使用 SSH 密钥认证或交互式密码输入
        scp -P "$REMOTE_PORT" $scp_opts "$source" "$dest"
    fi
}

# ============================================
# 远程部署到目标服务器
# ============================================

deploy_to_remote_server() {
    log_info "=========================================="
    log_info "开始远程部署 Node Exporter 到 $TARGET_SERVER"
    log_info "=========================================="

    # 测试 SSH 连接
    log_info "测试 SSH 连接..."
    if ! ssh_cmd "echo 'SSH connection successful'" 2>/dev/null; then
        log_error "SSH 连接失败"
        log_error "请检查："
        log_error "  1. 网络连通性: ping $REMOTE_IP"
        log_error "  2. SSH 访问: ssh -p $REMOTE_PORT ${REMOTE_USER}@${REMOTE_IP}"
        if [ -n "$REMOTE_PASSWORD" ]; then
            log_error "  3. 安装 sshpass: yum install -y sshpass 或 apt-get install -y sshpass"
        else
            log_error "  3. SSH 密钥配置: ssh-copy-id -p $REMOTE_PORT ~/.ssh/id_rsa.pub ${REMOTE_USER}@${REMOTE_IP}"
        fi
        exit 1
    fi
    log_success "SSH 连接测试成功"

    # 检查远程服务器是否已安装（优先验证 Metrics 端点）
    log_info "检查远程服务器 Node Exporter 安装状态..."

    # 方式1：优先检查 metrics 端点是否可访问
    local metrics_check=$(ssh_cmd "curl -s -o /dev/null -w '%{http_code}' http://localhost:9100/metrics --connect-timeout 5 2>/dev/null || echo '000'" 2>&1)

    if [ "$metrics_check" = "200" ]; then
        log_success "远程服务器 Node Exporter 已安装并运行（Metrics 可访问）"
        log_info "跳过安装，将在本地 Prometheus 中注册"
        echo ""
        register_remote_node_exporter
        return 0
    fi

    log_info "Metrics 端点不可访问（HTTP $metrics_check），检查进程状态..."

    # 方式2：检查进程和二进制文件
    local remote_check=$(ssh_cmd "
        if pgrep -f node_exporter > /dev/null 2>&1; then
            echo 'RUNNING'
        elif [ -f \$HOME/node_exporter/bin/node_exporter ]; then
            echo 'INSTALLED'
        else
            echo 'NOT_INSTALLED'
        fi
    " 2>&1)

    if [ "$remote_check" = "RUNNING" ]; then
        log_warn "检测到 Node Exporter 进程运行，但 metrics 端点不可访问"
        log_info "可能端口未监听或服务异常"
        read -p "是否重新部署？(y/N): " redeploy
        if [ "$redeploy" != "y" ] && [ "$redeploy" != "Y" ]; then
            log_info "跳过安装，将在本地 Prometheus 中注册"
            echo ""
            register_remote_node_exporter
            return 0
        fi
        log_info "将重新部署..."
    elif [ "$remote_check" = "INSTALLED" ]; then
        log_warn "远程服务器已安装 Node Exporter（未运行）"
        read -p "是否启动服务？(y/N): " start_service
        if [ "$start_service" = "y" ] || [ "$start_service" = "Y" ]; then
            log_info "启动远程 Node Exporter 服务..."
            ssh_cmd "systemctl --user start node_exporter 2>/dev/null || systemctl start node_exporter 2>/dev/null || \$HOME/node_exporter/bin/node_exporter --web.listen-address=:9100 &"
            sleep 3

            # 重新检查 metrics 端点
            local metrics_check_after=$(ssh_cmd "curl -s -o /dev/null -w '%{http_code}' http://localhost:9100/metrics --connect-timeout 5 2>/dev/null || echo '000'" 2>&1)
            if [ "$metrics_check_after" = "200" ]; then
                log_success "Node Exporter 服务已启动"
                echo ""
                register_remote_node_exporter
                return 0
            else
                log_error "Node Exporter 服务启动失败或 metrics 不可访问"
                read -p "是否重新部署？(y/N): " redeploy
                if [ "$redeploy" != "y" ] && [ "$redeploy" != "Y" ]; then
                    log_info "跳过安装"
                    return 0
                fi
                log_info "将重新部署..."
            fi
        else
            log_info "跳过安装，将在本地 Prometheus 中注册"
            echo ""
            register_remote_node_exporter
            return 0
        fi
    fi

    # 传输安装包
    log_info "传输安装包到远程服务器..."
    local tarball=$(find "$SOFT_DIR" -name "node_exporter-*.*linux-amd64.tar.gz" 2>/dev/null | head -1)

    if [ -z "$tarball" ]; then
        log_error "未找到 Node Exporter 安装包"
        log_error "请将安装包放在 $SOFT_DIR 目录"
        exit 1
    fi

    log_info "找到安装包: $(basename "$tarball")"

    # 创建远程临时目录并传输安装包
    ssh_cmd "mkdir -p /tmp/node_exporter_install"

    log_info "正在传输安装包..."
    if ! scp_cmd "$tarball" "${REMOTE_USER}@${REMOTE_IP}:/tmp/node_exporter_install/"; then
        log_error "安装包传输失败"
        exit 1
    fi
    log_success "安装包传输成功"

    # 生成 systemd 服务文件（根据目标服务器用户类型）
    log_info "生成 systemd 服务文件..."
    local remote_user_type=$(ssh_cmd "
        if [ \$(id -u) -eq 0 ]; then
            echo 'root'
        else
            echo 'user'
        fi
    " 2>&1)

    local service_file=""
    if [ "$remote_user_type" = "root" ]; then
        # 系统级服务文件
        service_file="/tmp/node_exporter_install/node_exporter.service"
        cat > "$service_file" <<EOF
[Unit]
Description=Node Exporter
After=network.target

[Service]
Type=simple
User=\$(whoami)
Environment="HOME=/root"
ExecStart=/root/node_exporter/bin/node_exporter \\
    --web.listen-address=:9100 \\
    --path.procfs=/proc \\
    --path.sysfs=/sys \\
    --collector.filesystem.mount-points-exclude=^/(sys|proc|dev|host|etc)(/|\$)
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF
    else
        # 用户级服务文件
        service_file="/tmp/node_exporter_install/node_exporter.service"
        cat > "$service_file" <<EOF
[Unit]
Description=Node Exporter
After=network.target

[Service]
Type=simple
ExecStart=%h/node_exporter/bin/node_exporter \\
    --web.listen-address=:9100 \\
    --path.procfs=/proc \\
    --path.sysfs=/sys \\
    --collector.filesystem.mount-points-exclude=^/(sys|proc|dev|host|etc)(/|\$)
Restart=on-failure
RestartSec=5

[Install]
WantedBy=default.target
EOF
    fi

    log_info "正在传输服务文件..."
    if ! scp_cmd "$service_file" "${REMOTE_USER}@${REMOTE_IP}:/tmp/node_exporter_install/"; then
        log_error "服务文件传输失败"
        exit 1
    fi
    log_success "服务文件传输成功"

    # 远程执行安装
    log_info "在远程服务器上执行安装..."
    ssh_cmd bash <<'REMOTE_SCRIPT'
set -e

echo "[REMOTE] 开始安装 Node Exporter..."

# 创建目录
mkdir -p $HOME/node_exporter/bin

# 解压安装包
echo "[REMOTE] 解压安装包..."
tar -xzf /tmp/node_exporter_install/node_exporter-*.tar.gz -C /tmp/node_exporter_install/

# 部署二进制文件
echo "[REMOTE] 部署二进制文件..."
cp -f /tmp/node_exporter_install/node_exporter*/node_exporter $HOME/node_exporter/bin/
chmod +x $HOME/node_exporter/bin/node_exporter

# 安装 systemd 服务文件
echo "[REMOTE] 安装 systemd 服务文件..."
if [ "$(id -u)" -eq 0 ]; then
    # root 用户：安装系统级服务
    cp -f /tmp/node_exporter_install/node_exporter.service /etc/systemd/system/
    systemctl daemon-reload
    systemctl enable node_exporter
    echo "[REMOTE] 系统级服务已安装"
else
    # 普通用户：安装用户级服务
    mkdir -p ~/.config/systemd/user/
    cp -f /tmp/node_exporter_install/node_exporter.service ~/.config/systemd/user/
    systemctl --user daemon-reload
    systemctl --user enable node_exporter
    # 确保用户服务在登出后继续运行
    loginctl enable-linger $(whoami) 2>/dev/null || true
    echo "[REMOTE] 用户级服务已安装"
fi

# 清理临时文件
rm -rf /tmp/node_exporter_install

echo "[REMOTE] Node Exporter 安装完成"
echo "SUCCESS"
REMOTE_SCRIPT

    if [ $? -ne 0 ]; then
        log_error "远程安装失败"
        exit 1
    fi

    log_success "远程服务器 Node Exporter 安装完成"
    echo ""

    # 启动远程 Node Exporter 服务
    log_info "启动远程 Node Exporter 服务..."
    ssh_cmd "
        if [ \$(id -u) -eq 0 ]; then
            systemctl start node_exporter
        else
            systemctl --user start node_exporter
        fi
    " 2>&1 | sed 's/^/[REMOTE] /'

    if [ $? -eq 0 ]; then
        log_success "远程 Node Exporter 服务已启动"
    else
        log_warn "远程 Node Exporter 服务启动失败，请手动检查"
    fi

    echo ""

    # 验证服务启动
    log_info "验证 Node Exporter 服务状态..."
    sleep 3

    local metrics_check_final=$(ssh_cmd "curl -s -o /dev/null -w '%{http_code}' http://localhost:9100/metrics --connect-timeout 5 2>/dev/null || echo '000'" 2>&1)

    if [ "$metrics_check_final" = "200" ]; then
        log_success "Node Exporter Metrics 端点可访问 (HTTP 200)"
    else
        log_warn "Metrics 端点不可访问 (HTTP $metrics_check_final)"
        log_info "请检查服务状态："
        log_info "  ssh -p $REMOTE_PORT ${REMOTE_USER}@${REMOTE_IP} 'systemctl status node_exporter'"
        log_info "  ssh -p $REMOTE_PORT ${REMOTE_USER}@${REMOTE_IP} 'journalctl -u node_exporter -f'"
    fi

    echo ""

    # 注册到本地 Prometheus
    register_remote_node_exporter
}

# ============================================
# 注册远程 Node Exporter 到本地 Prometheus
# ============================================

register_remote_node_exporter() {
    log_info "=========================================="
    log_info "注册远程 Node Exporter 到本地 Prometheus"
    log_info "=========================================="
    echo ""

    # 查找本地 Prometheus 配置文件
    local prometheus_config=""
    if [ -f "$HOME/prometheus/prometheus.yml" ]; then
        prometheus_config="$HOME/prometheus/prometheus.yml"
    elif [ -f "${INSTALL_BASE_DIR}/prometheus/prometheus.yml" ]; then
        prometheus_config="${INSTALL_BASE_DIR}/prometheus/prometheus.yml"
    fi

    if [ -z "$prometheus_config" ]; then
        log_error "未找到本地 Prometheus 配置文件"
        log_error "请先安装 Prometheus"
        log_info "或安装 Prometheus: bash scripts/install_prometheus.sh"
        return 1
    fi

    log_info "本地 Prometheus 配置: $prometheus_config"
    echo ""

    # 检查是否已经配置过
    if grep -q "$REMOTE_IP:$NODE_EXPORTER_PORT" "$prometheus_config" 2>/dev/null; then
        log_warn "Prometheus 配置中已存在此节点"
        log_info "  IP: $REMOTE_IP:$NODE_EXPORTER_PORT"
        log_info "  如需重新配置，请手动编辑: $prometheus_config"
        return 0
    fi

    # 备份 Prometheus 配置文件
    backup_file "$prometheus_config"
    log_success "已备份 Prometheus 配置文件"
    echo ""

    # 添加远程 Node Exporter 到 Prometheus 配置
    log_info "添加远程 Node Exporter 到 Prometheus 配置..."

    if grep -q "scrape_configs:" "$prometheus_config"; then
        # scrape_configs 已存在，添加新 job
        cat >> "$prometheus_config" <<EOF

  # Node Exporter（$TARGET_SERVER - 远程自动添加）
  - job_name: 'node_exporter'
    static_configs:
      - targets: ['${REMOTE_IP}:${NODE_EXPORTER_PORT}']
        labels:
          instance: '${REMOTE_IP}'
          server_name: '${TARGET_SERVER}'
          monitor: 'perfstack-suite'
EOF
        log_success "已添加到 Prometheus 配置"
    else
        log_error "未找到 scrape_configs 配置段，请手动添加"
        return 1
    fi

    # 重启 Prometheus 使配置生效
    log_info "重启 Prometheus 使配置生效..."
    if pgrep -f "prometheus" > /dev/null; then
        if [ -n "$XDG_RUNTIME_DIR" ]; then
            SYSTEMD_PAGER= systemctl --user restart prometheus 2>/dev/null || true
            sleep 3
            if systemctl --user is-active --quiet prometheus 2>/dev/null; then
                log_success "Prometheus 已重启并运行正常"
            else
                log_warn "Prometheus 重启失败，请手动重启"
                log_info "  手动命令: systemctl --user restart prometheus"
            fi
        fi
    else
        log_warn "Prometheus 未运行，请手动启动"
        log_info "  手动命令: systemctl --user start prometheus"
    fi
    echo ""

    # 验证配置
    log_info "等待 Prometheus 重新加载配置..."
    sleep 3

    log_success "=========================================="
    log_success "远程部署完成！"
    log_success "=========================================="
    echo ""
    echo "远程服务器：$TARGET_SERVER ($REMOTE_IP)"
    echo "Metrics 地址：http://${REMOTE_IP}:${NODE_EXPORTER_PORT}/metrics"
    echo "已添加到本地 Prometheus 配置"
    echo ""
    echo "验证命令："
    echo "  curl http://${REMOTE_IP}:${NODE_EXPORTER_PORT}/metrics"
    echo ""
}

# ============================================
# 检查 Node Exporter 是否已运行
# ============================================

check_node_exporter_running() {
    log_info "检查 Node Exporter 是否已运行..."

    # 检查进程是否存在
    if pgrep -f "node_exporter" > /dev/null; then
        local pid=$(pgrep -f "node_exporter" | head -1)
        log_warn "检测到 Node Exporter 进程正在运行 (PID: $pid)"

        # 检查端口是否监听
        if check_port "$NODE_EXPORTER_PORT"; then
            log_success "Node Exporter 端口 ${NODE_EXPORTER_PORT} 已在监听"
            echo ""
            echo "============================================"
            echo "Node Exporter 运行状态"
            echo "============================================"
            echo ""
            echo "进程 PID: $pid"
            echo "监听端口: $NODE_EXPORTER_PORT"
            echo "Metrics 地址: http://$(get_local_ip):${NODE_EXPORTER_PORT}/metrics"
            echo ""
            log_info "跳过安装，Node Exporter 已运行"
            exit 0
        else
            log_warn "Node Exporter 进程存在但端口未监听，将继续安装"
        fi
    else
        log_info "未检测到 Node Exporter 进程，继续安装"
    fi
}

# ============================================
# 检查是否已安装
# ============================================

check_node_exporter_installed() {
    if [ -f "$NODE_EXPORTER_BIN_DIR/node_exporter" ]; then
        log_warn "Node Exporter 似乎已经安装"
        log_info "二进制文件: $NODE_EXPORTER_BIN_DIR/node_exporter"

        # 检查进程是否运行
        if pgrep -f "node_exporter" > /dev/null; then
            log_info "Node Exporter 正在运行，跳过安装"
            exit 0
        fi

        read -p "是否重新安装？(y/N): " reinstall
        if [ "$reinstall" != "y" ] && [ "$reinstall" != "Y" ]; then
            log_info "取消安装"
            exit 0
        fi
        log_warn "将重新安装 Node Exporter"
    fi
}

# ============================================
# 创建目录结构
# ============================================

create_directories() {
    log_info "创建 Node Exporter 目录结构..."

    create_dir "$NODE_EXPORTER_INSTALL_DIR" 755
    create_dir "$NODE_EXPORTER_BIN_DIR" 755

    log_success "目录结构创建完成"
}

# ============================================
# 查找并解压安装包
# ============================================

extract_node_exporter() {
    log_info "查找 Node Exporter 安装包..."

    # 查找安装包
    local tarball=$(find "$SOFT_DIR" -name "node_exporter-*.*linux-amd64.tar.gz" 2>/dev/null | head -1)

    if [ -z "$tarball" ]; then
        log_error "未找到 Node Exporter 安装包"
        log_error "请将 node_exporter-${NODE_EXPORTER_VERSION}.linux-amd64.tar.gz 放在 $SOFT_DIR 目录"
        log_error ""
        log_error "下载命令："
        log_error "  cd $SOFT_DIR"
        log_error "  wget https://github.com/prometheus/node_exporter/releases/download/v${NODE_EXPORTER_VERSION}/node_exporter-${NODE_EXPORTER_VERSION}.linux-amd64.tar.gz"
        exit 1
    fi

    log_info "找到安装包: $tarball"

    # 解压到临时目录
    local temp_dir="/tmp/node_exporter_install"
    create_dir "$temp_dir" 755

    log_info "正在解压 Node Exporter..."
    extract_tar "$tarball" "$temp_dir"

    # 查找解压后的二进制文件
    local extracted_dir=$(find "$temp_dir" -maxdepth 1 -type d -name "node_exporter-*" | head -1)
    if [ -z "$extracted_dir" ]; then
        log_error "解压后未找到 Node Exporter 目录"
        log_info "实际解压内容："
        ls -la "$temp_dir"
        exit 1
    fi

    # Node Exporter 只有一个二进制文件，直接复制到目标位置
    log_info "复制二进制文件到 $NODE_EXPORTER_BIN_DIR..."
    cp -f "$extracted_dir/node_exporter" "$NODE_EXPORTER_BIN_DIR/"
    chmod +x "$NODE_EXPORTER_BIN_DIR/node_exporter"

    log_success "二进制文件已部署: $NODE_EXPORTER_BIN_DIR/node_exporter"

    # 清理临时目录
    rm -rf "$temp_dir"

    log_success "Node Exporter 安装包解压完成"
}

# ============================================
# 创建 systemd 服务文件
# ============================================

create_systemd_service() {
    log_info "创建 systemd 服务文件..."

    local service_file=""

    if [ "$(id -u)" -eq 0 ]; then
        # root 用户：创建系统级服务
        service_file="/etc/systemd/system/node_exporter.service"
        cat > "$service_file" <<EOF
[Unit]
Description=Node Exporter
After=network.target

[Service]
Type=simple
User=root
Environment="HOME=/root"
ExecStart=/root/node_exporter/bin/node_exporter \\
    --web.listen-address=:${NODE_EXPORTER_PORT} \\
    --path.procfs=/proc \\
    --path.sysfs=/sys \\
    --collector.filesystem.mount-points-exclude=^/(sys|proc|dev|host|etc)(/|$)
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF
        log_success "系统级服务文件已创建: $service_file"
    else
        # 普通用户：创建用户级服务
        local user_service_dir="$HOME/.config/systemd/user"
        mkdir -p "$user_service_dir"
        service_file="$user_service_dir/node_exporter.service"
        cat > "$service_file" <<EOF
[Unit]
Description=Node Exporter
After=network.target

[Service]
Type=simple
ExecStart=%h/node_exporter/bin/node_exporter \\
    --web.listen-address=:${NODE_EXPORTER_PORT} \\
    --path.procfs=/proc \\
    --path.sysfs=/sys \\
    --collector.filesystem.mount-points-exclude=^/(sys|proc|dev|host|etc)(/|$)
Restart=on-failure
RestartSec=5

[Install]
WantedBy=default.target
EOF
        log_success "用户级服务文件已创建: $service_file"
    fi
}

# ============================================
# 主安装流程（本地模式）
# ============================================

main_local_install() {
    log_info "开始本地安装 Node Exporter..."

    # 加载配置文件
    load_config

    # 检查 Node Exporter 是否已运行
    check_node_exporter_running

    # 检查是否已安装
    check_node_exporter_installed

    # 创建目录结构
    create_directories

    # 解压安装包
    extract_node_exporter

    # 创建 systemd 服务文件
    create_systemd_service

    # 启用并启动服务
    log_info "启用并启动 Node Exporter 服务..."
    if [ "$(id -u)" -eq 0 ]; then
        systemctl daemon-reload
        systemctl enable node_exporter
        systemctl start node_exporter
        log_success "系统级服务已启动"
    else
        systemctl --user daemon-reload
        systemctl --user enable node_exporter
        loginctl enable-linger $(whoami) 2>/dev/null || true
        systemctl --user start node_exporter
        log_success "用户级服务已启动"
    fi

    # 验证服务启动
    sleep 3
    if pgrep -f "node_exporter" > /dev/null; then
        log_success "Node Exporter 服务已启动"
    else
        log_error "Node Exporter 服务启动失败"
        log_info "请检查服务状态："
        if [ "$(id -u)" -eq 0 ]; then
            log_info "  systemctl status node_exporter"
            log_info "  journalctl -u node_exporter -n 50"
        else
            log_info "  systemctl --user status node_exporter"
            log_info "  journalctl --user -u node_exporter -n 50"
        fi
        exit 1
    fi

    log_success "=========================================="
    log_success "Node Exporter 本地安装完成！"
    log_success "=========================================="
    echo ""
    echo "安装目录: $NODE_EXPORTER_INSTALL_DIR"
    echo "二进制文件: $NODE_EXPORTER_BIN_DIR/node_exporter"
    echo "服务端口: $NODE_EXPORTER_PORT"
    echo "Metrics 地址: http://$(get_local_ip):${NODE_EXPORTER_PORT}/metrics"
    echo ""
    echo "服务管理命令："
    if [ "$(id -u)" -eq 0 ]; then
        echo "  启动: systemctl start node_exporter"
        echo "  停止: systemctl stop node_exporter"
        echo "  重启: systemctl restart node_exporter"
        echo "  状态: systemctl status node_exporter"
    else
        echo "  启动: systemctl --user start node_exporter"
        echo "  停止: systemctl --user stop node_exporter"
        echo "  重启: systemctl --user restart node_exporter"
        echo "  状态: systemctl --user status node_exporter"
    fi
    echo ""
}

# ============================================
# 主流程
# ============================================

main() {
    # 初始化日志
    mkdir -p "$(dirname "$LOG_FILE")"
    touch "$LOG_FILE"

    # 解析命令行参数
    parse_arguments "$@"

    # 远程部署模式
    if [ "$REMOTE_DEPLOY_MODE" = true ]; then
        if [ -z "$TARGET_SERVER" ]; then
            # 交互式选择服务器
            show_remote_deploy_menu
        else
            # 使用指定的服务器
            log_info "使用指定服务器: $TARGET_SERVER"
            # 从配置文件中的 TARGET_SERVERS 数组读取服务器信息
            for server_config in "${TARGET_SERVERS[@]}"; do
                IFS=',' read -r name ip user port password <<< "$server_config"

                [[ "$name" =~ ^#.*$ ]] && continue
                [ -z "$name" ] && continue

                if [ "$name" = "$TARGET_SERVER" ]; then
                    REMOTE_USER="$user"
                    REMOTE_IP="$ip"
                    REMOTE_PORT="${port:-22}"
                    REMOTE_PASSWORD="$password"
                    break
                fi
            done

            if [ -z "$REMOTE_IP" ]; then
                log_error "未找到服务器: $TARGET_SERVER"
                log_error "请在 config/deploy.conf 的 TARGET_SERVERS 数组中配置此服务器"
                exit 1
            fi

            log_info "目标服务器：$TARGET_SERVER ($REMOTE_IP)"
            if [ -n "$REMOTE_PASSWORD" ]; then
                log_info "认证方式：密码认证"
            else
                log_info "认证方式：SSH 密钥认证"
            fi
        fi

        # 执行远程部署
        deploy_to_remote_server
    else
        # 本地安装模式
        main_local_install
    fi
}

# ============================================
# 脚本入口
# ============================================

main "$@"
