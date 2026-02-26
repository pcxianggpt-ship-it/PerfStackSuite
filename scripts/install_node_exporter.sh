#!/bin/bash
#
# Node Exporter 安装脚本
# 功能：远程批量部署 Node Exporter（极简5步法）
# 版本：2.0.0
#

# 获取脚本目录
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# 加载公共函数库
source "${SCRIPT_DIR}/common.sh"

# ============================================
# 常量定义
# ============================================

NODE_EXPORTER_PORT="${NODE_EXPORTER_PORT:-9100}"
SOFT_DIR="${SCRIPT_DIR}/../soft"
NODE_EXPORTER_INSTALL_DIR="$HOME/node_exporter"

# ============================================
# 显示使用说明
# ============================================

show_usage() {
    cat << EOF
用法: $0 [选项]

选项：
  --help, -h           显示此帮助信息

配置文件：config/deploy.conf
  在 TARGET_SERVERS 数组中配置服务器信息
  格式：server_name,192.168.1.100,user,22[,password]

部署流程（极简5步法）：
  1. 验证安装状态（检查 9100/metrics 端点）
  2. 配置免密登录（优先 sshpass，支持 expect）
  3. 分发安装包（从 soft 目录）
  4. 配置 systemd 服务（区分 root 和普通用户）
  5. 验证安装结果（确认 metrics 端点可用）

功能说明：
  - 远程批量部署 Node Exporter
  - 自动配置 SSH 免密登录
  - 自动注册到 Prometheus
  - 错误隔离：单台失败不影响其他服务器
EOF
}

# ============================================
# 步骤1：验证安装状态
# ============================================

check_metrics_endpoint() {
    local ip="$1"
    local port="${2:-9100}"

    if curl -s "http://${ip}:${port}/metrics" --connect-timeout 3 >/dev/null 2>&1; then
        return 0  # 已安装
    else
        return 1  # 未安装
    fi
}

verify_installation_status() {
    local servers_config=("$@")
    local servers_to_install=()

    echo "==========================================" >&2
    echo "[INFO] 步骤1：验证安装状态" >&2
    echo "==========================================" >&2
    echo "" >&2

    local index=1
    for server_config in "${servers_config[@]}"; do
        [[ "$server_config" =~ ^#.*$ ]] && continue
        [ -z "$server_config" ] && continue

        IFS=',' read -r name ip user port password <<< "$server_config"
        port="${port:-22}"

        printf "  [%2d/%2d] 检查 %s (%s)..." "$index" "${#servers_config[@]}" "$name" "$ip" >&2

        if check_metrics_endpoint "$ip" "$NODE_EXPORTER_PORT"; then
            echo -e " \033[32m已安装\033[0m" >&2
        else
            echo -e " \033[31m待安装\033[0m" >&2
            servers_to_install+=("$server_config")
        fi

        ((index++))
    done

    echo "" >&2
    echo "[INFO] 总服务器: ${#servers_config[@]}, 已安装: $(( ${#servers_config[@]} - ${#servers_to_install[@]} )), 待安装: ${#servers_to_install[@]}" >&2

    if [ ${#servers_to_install[@]} -gt 0 ]; then
        echo "" >&2
        echo "[INFO] 待部署服务器列表：" >&2
        for server_info in "${servers_to_install[@]}"; do
            IFS=',' read -r name ip user port password <<< "$server_info"
            echo "  - $name ($ip)" >&2
        done
    fi
    echo "" >&2

    # 返回待安装服务器列表到 stdout（仅这个被 mapfile 捕获）
    printf '%s\n' "${servers_to_install[@]}"
}

# ============================================
# 步骤2：配置免密登录
# ============================================

test_ssh_key_auth() {
    local ip="$1"
    local user="$2"
    local port="${3:-22}"

    if ssh -o BatchMode=yes -o ConnectTimeout=5 -o StrictHostKeyChecking=no \
        -p "$port" "${user}@${ip}" "echo 'key_auth_test'" >/dev/null 2>&1; then
        return 0  # 免密登录已配置
    else
        return 1  # 需要配置免密登录
    fi
}

setup_ssh_key_auth() {
    local ip="$1"
    local user="$2"
    local port="${3:-22}"
    local password="$4"

    log_info "配置免密登录: ${user}@${ip}"

    # 检查本地是否有 SSH 密钥
    if [ ! -f ~/.ssh/id_rsa ]; then
        log_info "生成 SSH 密钥..."
        ssh-keygen -t rsa -b 4096 -f ~/.ssh/id_rsa -N "" >/dev/null 2>&1
    fi

    # 复制公钥到目标服务器
    if [ -n "$password" ] && check_command "sshpass"; then
        sshpass -p "$password" ssh-copy-id -o StrictHostKeyChecking=no -p "$port" "${user}@${ip}" >/dev/null 2>&1
    elif check_command "expect"; then
        expect "$SCRIPT_DIR/ssh_copy_id.exp" "$user" "$ip" "$port" "$password" >/dev/null 2>&1
    else
        ssh-copy-id -o StrictHostKeyChecking=no -p "$port" "${user}@${ip}"
    fi

    # 验证免密登录
    if test_ssh_key_auth "$ip" "$user" "$port"; then
        log_success "免密登录配置成功"
        return 0
    else
        log_error "免密登录配置失败"
        return 1
    fi
}

ensure_ssh_key_auth() {
    local server_config="$1"

    IFS=',' read -r name ip user port password <<< "$server_config"
    port="${port:-22}"

    printf "  检查免密登录 %s..." "$name"

    if test_ssh_key_auth "$ip" "$user" "$port"; then
        echo -e " \033[32m已配置\033[0m"
        return 0
    fi

    echo -e " \033[31m未配置\033[0m"

    if setup_ssh_key_auth "$ip" "$user" "$port" "$password"; then
        return 0
    else
        return 1
    fi
}

# ============================================
# 步骤3：分发安装包
# ============================================

distribute_package() {
    local server_config="$1"

    IFS=',' read -r name ip user port password <<< "$server_config"
    port="${port:-22}"

    log_info "分发安装包到 $name ($ip)"

    # 查找安装包
    local package=$(find "$SOFT_DIR" -name "node_exporter-*.linux-amd64.tar.gz" 2>/dev/null | head -1)

    if [ -z "$package" ]; then
        log_error "未找到 Node Exporter 安装包"
        log_info "请将 node_exporter-*.linux-amd64.tar.gz 放入 $SOFT_DIR 目录"
        return 1
    fi

    log_info "找到安装包: $(basename "$package")"

    # 通过 SCP 复制到远程服务器
    if scp -o StrictHostKeyChecking=no -P "$port" "$package" "${user}@${ip}:/tmp/"; then
        log_success "安装包分发成功"
        return 0
    else
        log_error "安装包分发失败"
        return 1
    fi
}

# ============================================
# 步骤4：配置 systemd 服务
# ============================================

install_on_remote_server() {
    local server_config="$1"

    IFS=',' read -r name ip user port password <<< "$server_config"
    port="${port:-22}"

    log_info "开始安装到 $name ($ip)"

    # 检测是否为 root 用户
    local is_root="false"
    if ssh -o BatchMode=yes -o ConnectTimeout=5 -p "$port" "${user}@${ip}" "[[ \$(id -u) -eq 0 ]]" 2>/dev/null; then
        is_root="true"
        log_info "检测到 root 用户"
    else
        log_info "检测到普通用户"
    fi

    # 生成远程安装脚本
    local install_script="/tmp/node_exporter_install.sh"

    if [ "$is_root" = "true" ]; then
        # root 用户安装脚本
        ssh -o BatchMode=yes -o ConnectTimeout=5 -p "$port" "${user}@${ip}" "
            # 创建安装目录
            mkdir -p $NODE_EXPORTER_INSTALL_DIR

            # 解压安装包
            tar -xzf /tmp/node_exporter-*.linux-amd64.tar.gz -C $NODE_EXPORTER_INSTALL_DIR/ --strip-components=1

            # 创建 systemd 服务文件
            cat > /etc/systemd/system/node_exporter.service << 'EOF'
[Unit]
Description=Node Exporter
After=network.target

[Service]
Type=simple
ExecStart=$NODE_EXPORTER_INSTALL_DIR/node_exporter
Restart=always
RestartSec=3

[Install]
WantedBy=multi-user.target
EOF

            # 重载并启动服务
            systemctl daemon-reload
            systemctl enable node_exporter
            systemctl start node_exporter

            # 清理临时文件
            rm -f /tmp/node_exporter-*.tar.gz
        " 2>&1
    else
        # 普通用户安装脚本
        ssh -o BatchMode=yes -o ConnectTimeout=5 -p "$port" "${user}@${ip}" "
            # 设置运行时目录
            export XDG_RUNTIME_DIR=/run/user/\$(id -u)

            # 创建安装目录
            mkdir -p $NODE_EXPORTER_INSTALL_DIR

            # 解压安装包
            tar -xzf /tmp/node_exporter-*.linux-amd64.tar.gz -C $NODE_EXPORTER_INSTALL_DIR/ --strip-components=1

            # 创建 systemd 用户服务目录
            mkdir -p ~/.config/systemd/user

            # 创建 systemd 服务文件
            cat > ~/.config/systemd/user/node_exporter.service << 'EOF'
[Unit]
Description=Node Exporter
After=network.target

[Service]
Type=simple
ExecStart=$NODE_EXPORTER_INSTALL_DIR/node_exporter
Restart=always
RestartSec=3

[Install]
WantedBy=default.target
EOF

            # 重载并启动服务
            systemctl --user daemon-reload
            systemctl --user enable node_exporter
            systemctl --user start node_exporter

            # 清理临时文件
            rm -f /tmp/node_exporter-*.tar.gz
        " 2>&1
    fi

    if [ $? -eq 0 ]; then
        log_success "远程安装成功"
        return 0
    else
        log_error "远程安装失败"
        return 1
    fi
}

# ============================================
# 步骤5：验证安装结果
# ============================================

verify_installation() {
    local server_config="$1"

    IFS=',' read -r name ip user port password <<< "$server_config"
    port="${port:-22}"

    printf "  验证 %s (%s)..." "$name" "$ip"

    # 等待服务启动
    sleep 3

    if check_metrics_endpoint "$ip" "$NODE_EXPORTER_PORT"; then
        echo -e " \033[32m成功\033[0m"
        return 0
    else
        echo -e " \033[31m失败\033[0m"
        return 1
    fi
}

# ============================================
# 注册到 Prometheus
# ============================================

register_to_prometheus() {
    local ip="$1"

    local prometheus_config="$HOME/prometheus/prometheus.yml"

    if [ ! -f "$prometheus_config" ]; then
        log_info "Prometheus 配置文件不存在，跳过注册"
        return 0
    fi

    if grep -q "$ip:$NODE_EXPORTER_PORT" "$prometheus_config"; then
        log_info "已在 Prometheus 中注册"
        return 0
    fi

    log_info "注册到 Prometheus: $ip:$NODE_EXPORTER_PORT"

    # TODO: 实际的注册逻辑需要根据 prometheus.yml 格式实现
    return 0
}

# ============================================
# 单台服务器完整部署流程
# ============================================

deploy_to_single_server() {
    local server_config="$1"
    local success=false

    IFS=',' read -r name ip user port password <<< "$server_config"
    port="${port:-22}"

    echo ""
    log_info "=========================================="
    log_info "开始部署到 $name ($ip)"
    log_info "=========================================="
    echo ""

    # 步骤2：配置免密登录
    log_info "步骤2：配置免密登录"
    if ! ensure_ssh_key_auth "$server_config"; then
        log_error "免密登录配置失败，跳过此服务器"
        return 1
    fi
    echo ""

    # 步骤3：分发安装包
    log_info "步骤3：分发安装包"
    if ! distribute_package "$server_config"; then
        log_error "安装包分发失败，跳过此服务器"
        return 1
    fi
    echo ""

    # 步骤4：配置 systemd 服务
    log_info "步骤4：配置 systemd 服务"
    if ! install_on_remote_server "$server_config"; then
        log_error "远程安装失败，跳过此服务器"
        return 1
    fi
    echo ""

    # 步骤5：验证安装结果
    log_info "步骤5：验证安装结果"
    if verify_installation "$server_config"; then
        success=true
        register_to_prometheus "$ip"
    else
        success=false
    fi
    echo ""

    if [ "$success" = "true" ]; then
        log_success "部署成功: $name ($ip)"
        return 0
    else
        log_error "部署失败: $name ($ip)"
        return 1
    fi
}

# ============================================
# 显示运维命令
# ============================================

show_operations_commands() {
    local success_servers=("$@")

    echo ""
    log_info "=========================================="
    log_info "运维命令"
    log_info "=========================================="
    echo ""

    # 从第一台成功服务器获取用户类型示例
    local first_server="${success_servers[0]}"
    IFS=',' read -r name ip user port password <<< "$first_server"

    # 检测用户类型
    local is_root="false"
    if ssh -o BatchMode=yes -o ConnectTimeout=5 -p "$port" "${user}@${ip}" "[[ \$(id -u) -eq 0 ]]" 2>/dev/null; then
        is_root="true"
    fi

    if [ "$is_root" = "true" ]; then
        cat << 'EOF'
[服务管理命令]
  启动服务:    systemctl start node_exporter
  停止服务:    systemctl stop node_exporter
  重启服务:    systemctl restart node_exporter
  查看状态:    systemctl status node_exporter
  开机自启:    systemctl enable node_exporter
  取消自启:    systemctl disable node_exporter

[日志查看命令]
  查看日志:    journalctl -u node_exporter -f
  查看最近:    journalctl -u node_exporter --since "1 hour ago"

[测试命令]
  测试端点:    curl http://localhost:9100/metrics
  查看进程:    ps aux | grep node_exporter
  查看端口:    ss -tlnp | grep 9100

[配置文件位置]
  服务文件:    /etc/systemd/system/node_exporter.service
  安装目录:    $HOME/node_exporter
EOF
    else
        cat << 'EOF'
[服务管理命令]
  启动服务:    systemctl --user start node_exporter
  停止服务:    systemctl --user stop node_exporter
  重启服务:    systemctl --user restart node_exporter
  查看状态:    systemctl --user status node_exporter
  开机自启:    systemctl --user enable node_exporter
  取消自启:    systemctl --user disable node_exporter

[日志查看命令]
  查看日志:    systemctl --user status node_exporter
  查看日志:    journalctl --user -u node_exporter -f

[测试命令]
  测试端点:    curl http://localhost:9100/metrics
  查看进程:    ps aux | grep node_exporter
  查看端口:    ss -tlnp | grep 9100

[配置文件位置]
  服务文件:    ~/.config/systemd/user/node_exporter.service
  安装目录:    $HOME/node_exporter

[注意]
  普通用户使用 systemd 需要设置环境变量：
  export XDG_RUNTIME_DIR=/run/user/$(id -u)
EOF
    fi

    echo ""
    log_info "已部署服务器列表："
    for server_config in "${success_servers[@]}"; do
        IFS=',' read -r name ip user port password <<< "$server_config"
        echo "  - $name: ssh -p $port ${user}@$ip"
    done
    echo ""
}

# ============================================
# 批量部署
# ============================================

batch_deploy() {
    local servers_config=("$@")

    if [ ${#servers_config[@]} -eq 0 ]; then
        log_error "没有需要部署的服务器"
        return 1
    fi

    log_info "=========================================="
    log_info "Node Exporter 批量部署"
    log_info "=========================================="
    log_info "配置文件: $CONFIG_FILE"
    echo ""

    # 步骤1：验证安装状态
    local servers_to_install=()
    mapfile -t servers_to_install < <(verify_installation_status "${servers_config[@]}")

    if [ ${#servers_to_install[@]} -eq 0 ]; then
        log_success "所有服务器已安装 Node Exporter"
        return 0
    fi

    # 确认是否继续
    read -p "是否继续安装? [y/N] " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        log_info "取消安装"
        return 0
    fi

    # 批量部署（错误隔离）
    local success_list=()
    local fail_list=()

    for server_config in "${servers_to_install[@]}"; do
        if deploy_to_single_server "$server_config"; then
            success_list+=("$server_config")
        else
            fail_list+=("$server_config")
        fi
    done

    # 显示部署报告
    echo ""
    log_info "=========================================="
    log_info "部署报告"
    log_info "=========================================="
    echo ""
    log_success "成功: ${#success_list[@]} 台"
    for server_config in "${success_list[@]}"; do
        IFS=',' read -r name ip user port password <<< "$server_config"
        echo "  ✓ $name ($ip)"
    done
    echo ""

    if [ ${#fail_list[@]} -gt 0 ]; then
        log_error "失败: ${#fail_list[@]} 台"
        for server_config in "${fail_list[@]}"; do
            IFS=',' read -r name ip user port password <<< "$server_config"
            echo "  ✗ $name ($ip)"
        done
        echo ""
    fi

    # 显示运维命令
    if [ ${#success_list[@]} -gt 0 ]; then
        show_operations_commands "${success_list[@]}"
    fi

    return 0
}

# ============================================
# 主函数
# ============================================

main() {
    # 解析参数
    while [[ $# -gt 0 ]]; do
        case "$1" in
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

    # 加载配置文件
    load_config

    if [ ${#TARGET_SERVERS[@]} -eq 0 ]; then
        log_error "未配置服务器"
        log_info "请在 $CONFIG_FILE 中配置 TARGET_SERVERS 数组"
        exit 1
    fi

    # 执行批量部署
    batch_deploy "${TARGET_SERVERS[@]}"
}

# 执行主函数
main "$@"
