#!/bin/bash
#
# SSH 配置脚本
# 功能：配置 SSH 服务、X11 Forwarding 和安装中文字体
# 版本：1.0.0
# 适用场景：支持 JMeter GUI 远程显示，解决界面乱码问题
#

set -e  # 遇到错误时退出

# 获取脚本目录
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# 加载公共函数库
source "${SCRIPT_DIR}/common.sh"

# ============================================
# 常量定义
# ============================================

SSH_CONFIG_FILE="/etc/ssh/sshd_config"
SSH_CONFIG_BACKUP="/etc/ssh/sshd_config.perfstack.bak"
FONT_DIR_CENTOS="/usr/share/fonts/chinese"
FONT_DIR_UBUNTU="/usr/share/fonts/truetype/chinese"
SOFT_FONT_DIR="${PROJECT_DIR}/soft/fonts"

# ============================================
# 显示使用说明
# ============================================

show_usage() {
    cat << EOF
用法: $0 [选项]

选项：
  --ssh, -s           配置 SSH 服务和 X11 Forwarding
  --font, -f          安装中文字体
  --key, -k           配置 SSH 密钥
  --all, -a           执行所有配置（SSH + 字体 + 密钥）
  --verify, -v        验证配置状态
  --help, -h          显示此帮助信息

示例：
  $0                          # 交互式选择操作
  $0 --all                    # 执行所有配置
  $0 --ssh                    # 仅配置 SSH 服务
  $0 --font                   # 仅安装中文字体
  $0 --verify                 # 验证配置状态

注意事项：
  - 此脚本需要 root 权限执行
  - SSH 配置需要重启 sshd 服务
  - 字体文件需放置在 soft/fonts/ 目录
  - 支持的字体格式：.ttf, .ttc, .otf
  - 建议在测试环境充分验证后再应用到生产环境

配置说明：
  SSH 服务配置：
    - 启用 X11 Forwarding（支持图形界面转发）
    - 优化 SSH 会话参数
    - 配置防火墙规则

  中文字体安装：
    - 从 soft/fonts/ 目录安装字体文件
    - 支持格式：.ttf（TrueType）、.ttc（TrueType Collection）、.otf（OpenType）
    - 配置 JMeter 字体参数

  SSH 密钥配置：
    - 生成 RSA 4096 位密钥对
    - 配置免密登录
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
# 检测操作系统类型
# ============================================

detect_os_type() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        OS_TYPE="$ID"
        OS_VERSION="$VERSION_ID"
    elif [ -f /etc/redhat-release ]; then
        OS_TYPE="centos"
    elif [ -f /etc/debian_version ]; then
        OS_TYPE="debian"
    else
        OS_TYPE="other"
    fi

    log_info "检测到操作系统: $OS_TYPE $OS_VERSION"
}

# ============================================
# 配置 SSH 服务
# ============================================

configure_ssh_service() {
    log_info "开始配置 SSH 服务..."

    # 1. 备份 SSH 配置文件
    if [ -f "$SSH_CONFIG_FILE" ]; then
        backup_file "$SSH_CONFIG_FILE"
    fi

    # 2. 编辑 SSH 配置文件
    log_info "编辑 SSH 配置文件: $SSH_CONFIG_FILE"

    # 检查并启用 X11Forwarding
    if grep -q "^#X11Forwarding" "$SSH_CONFIG_FILE" || grep -q "^X11Forwarding no" "$SSH_CONFIG_FILE"; then
        sed -i 's/^#X11Forwarding.*/X11Forwarding yes/' "$SSH_CONFIG_FILE"
        sed -i 's/^X11Forwarding no/X11Forwarding yes/' "$SSH_CONFIG_FILE"
        log_success "已启用 X11Forwarding"
    elif grep -q "^X11Forwarding yes" "$SSH_CONFIG_FILE"; then
        log_info "X11Forwarding 已启用"
    else
        echo "X11Forwarding yes" >> "$SSH_CONFIG_FILE"
        log_success "已添加 X11Forwarding 配置"
    fi

    # 检查并启用 X11UseLocalhost
    if grep -q "^#X11UseLocalhost" "$SSH_CONFIG_FILE" || ! grep -q "^X11UseLocalhost" "$SSH_CONFIG_FILE"; then
        echo "X11UseLocalhost yes" >> "$SSH_CONFIG_FILE"
        log_success "已添加 X11UseLocalhost 配置"
    fi

    # 配置 MaxSessions
    if grep -q "^#MaxSessions" "$SSH_CONFIG_FILE" || ! grep -q "^MaxSessions" "$SSH_CONFIG_FILE"; then
        echo "MaxSessions 10" >> "$SSH_CONFIG_FILE"
        log_success "已设置 MaxSessions = 10"
    fi

    # 确保 PubkeyAuthentication 启用
    if grep -q "^#PubkeyAuthentication" "$SSH_CONFIG_FILE" || grep -q "^PubkeyAuthentication no" "$SSH_CONFIG_FILE"; then
        sed -i 's/^#PubkeyAuthentication.*/PubkeyAuthentication yes/' "$SSH_CONFIG_FILE"
        sed -i 's/^PubkeyAuthentication no/PubkeyAuthentication yes/' "$SSH_CONFIG_FILE"
        log_success "已启用 PubkeyAuthentication"
    fi

    # 3. 安装 X11 依赖库
    log_info "安装 X11 依赖库..."
    case "$OS_TYPE" in
        centos|rhel|kylin)
            yum install -y xauth xorg-x11-fonts-* libX11 libXext libXtst 2>/dev/null || {
                log_warn "部分 X11 依赖包安装失败，可能需要手动安装"
            }
            ;;
        ubuntu|debian)
            apt-get update -qq
            apt-get install -y xauth x11-apps libx11-6 libxext6 libxtst6 2>/dev/null || {
                log_warn "部分 X11 依赖包安装失败，可能需要手动安装"
            }
            ;;
        *)
            log_warn "未知的操作系统类型，跳过 X11 依赖安装"
            ;;
    esac

    # 4. 配置防火墙
    log_info "配置防火墙规则..."
    configure_firewall_ssh

    # 5. 重启 SSH 服务
    log_info "重启 SSH 服务..."
    if systemctl is-active --quiet sshd || systemctl is-active --quiet ssh; then
        if systemctl restart sshd 2>/dev/null || systemctl restart ssh 2>/dev/null; then
            log_success "SSH 服务重启成功"
        else
            log_error "SSH 服务重启失败"
            return 1
        fi
    else
        log_warn "SSH 服务未运行，请手动启动"
    fi

    # 6. 显示配置状态
    display_ssh_config_status

    log_success "SSH 服务配置完成"
}

# ============================================
# 配置防火墙
# ============================================

configure_firewall_ssh() {
    local ssh_port=${SSH_PORT:-22}

    # 检测防火墙类型并开放端口
    if command -v firewall-cmd >/dev/null 2>&1; then
        # CentOS/RHEL/firewalld
        if firewall-cmd --list-services | grep -q ssh; then
            log_info "防火墙已开放 SSH 服务"
        else
            firewall-cmd --permanent --add-service=ssh 2>/dev/null && {
                firewall-cmd --reload 2>/dev/null
                log_success "已开放防火墙 SSH 服务"
            } || log_warn "防火墙配置失败"
        fi
    elif command -v ufw >/dev/null 2>&1; then
        # Ubuntu/Debian/ufw
        if ufw status | grep -q "22.*ALLOW"; then
            log_info "防火墙已开放 SSH 端口"
        else
            ufw allow ssh 2>/dev/null && {
                log_success "已开放防火墙 SSH 端口"
            } || log_warn "防火墙配置失败"
        fi
    else
        log_warn "未检测到防火墙（firewalld/ufw），请手动开放 SSH 端口 $ssh_port"
    fi
}

# ============================================
# 显示 SSH 配置状态
# ============================================

display_ssh_config_status() {
    echo ""
    echo "SSH 配置状态："
    echo "----------------------------------------"

    # 显示 X11Forwarding 状态
    if grep -q "^X11Forwarding yes" "$SSH_CONFIG_FILE"; then
        echo "✓ X11Forwarding: 已启用"
    else
        echo "✗ X11Forwarding: 未启用"
    fi

    # 显示 X11UseLocalhost 状态
    if grep -q "^X11UseLocalhost yes" "$SSH_CONFIG_FILE"; then
        echo "✓ X11UseLocalhost: 已启用"
    else
        echo "✗ X11UseLocalhost: 未启用"
    fi

    # 显示 MaxSessions 状态
    local max_sessions=$(grep "^MaxSessions" "$SSH_CONFIG_FILE" | awk '{print $2}')
    if [ -n "$max_sessions" ]; then
        echo "✓ MaxSessions: $max_sessions"
    else
        echo "✗ MaxSessions: 未配置（使用默认值）"
    fi

    # 显示 PubkeyAuthentication 状态
    if grep -q "^PubkeyAuthentication yes" "$SSH_CONFIG_FILE"; then
        echo "✓ PubkeyAuthentication: 已启用"
    else
        echo "✗ PubkeyAuthentication: 未启用"
    fi

    echo "----------------------------------------"
    echo ""
}

# ============================================
# 安装中文字体（实际实现）
# ============================================

# 安装自定义字体文件
install_custom_fonts() {
    # 确定字体目录
    local font_dir
    if [ "$OS_TYPE" = "ubuntu" ] || [ "$OS_TYPE" = "debian" ]; then
        font_dir="$FONT_DIR_UBUNTU"
    else
        font_dir="$FONT_DIR_CENTOS"
    fi

    # 创建字体目录
    mkdir -p "$font_dir" 2>/dev/null || {
        log_error "创建字体目录失败: $font_dir"
        return 1
    }

    # 复制字体文件
    log_info "复制字体文件到 $font_dir"
    local copied_count=0

    # 使用 find 命令查找字体文件
    while IFS= read -r -d '' font_file; do
        if [ -f "$font_file" ]; then
            local font_name=$(basename "$font_file")
            cp "$font_file" "$font_dir/" && {
                chmod 644 "$font_dir/$font_name"
                log_info "  ✓ $font_name"
                ((copied_count++)) 2>/dev/null || true
            } || log_warn "  ✗ 复制失败: $font_name"
        fi
    done < <(find "$SOFT_FONT_DIR" -type f \( -name "*.ttf" -o -name "*.ttc" -o -name "*.otf" \) -print0 2>/dev/null)

    if [ "$copied_count" -gt 0 ]; then
        log_success "已复制 $copied_count 个字体文件"
    else
        log_error "未找到字体文件（.ttf/.ttc/.otf）"
        return 1
    fi
}

# 更新字体缓存
update_font_cache() {
    log_info "更新字体缓存..."
    if command -v fc-cache >/dev/null 2>&1; then
        fc-cache -fv >/dev/null 2>&1 && log_success "字体缓存更新成功" || log_warn "字体缓存更新失败"
    else
        log_warn "fc-cache 命令不可用"
    fi
}

# 主字体安装函数
install_fonts_and_config_jmeter() {
    log_info "开始安装中文字体..."

    # 检测系统已安装字体
    if command -v fc-list >/dev/null 2>&1; then
        local font_count=$(fc-list :lang=zh 2>/dev/null | wc -l)
        log_info "当前已安装中文字体数量: $font_count"
        if [ "$font_count" -gt 0 ]; then
            log_info "已安装的中文字体示例："
            fc-list :lang=zh 2>/dev/null | head -3 | while read line; do
                echo "  - $line"
            done
        fi
    else
        log_warn "fc-list 命令不可用，无法检测字体"
    fi

    # 安装字体文件
    if [ -d "$SOFT_FONT_DIR" ] && [ -n "$(ls -A $SOFT_FONT_DIR 2>/dev/null)" ]; then
        log_info "发现自定义字体目录: $SOFT_FONT_DIR"
        install_custom_fonts
    else
        log_error "自定义字体目录不存在或为空: $SOFT_FONT_DIR"
        log_error "请将字体文件（.ttf/.ttc/.otf）放置到 $SOFT_FONT_DIR 目录"
        return 1
    fi

    # 更新字体缓存
    update_font_cache

    # 配置 JMeter 字体参数
    configure_jmeter_font

    log_success "中文字体配置完成"
}

# ============================================
# 配置 JMeter 字体参数
# ============================================

configure_jmeter_font() {
    # 查找 JMeter 安装目录
    local jmeter_bin=""
    if [ -n "$JMETER_HOME" ]; then
        jmeter_bin="$JMETER_HOME/bin/jmeter"
    elif [ -f "/opt/jmeter/current/bin/jmeter" ]; then
        jmeter_bin="/opt/jmeter/current/bin/jmeter"
    elif [ -f "$HOME/jmeter/bin/jmeter" ]; then
        jmeter_bin="$HOME/jmeter/bin/jmeter"
    else
        log_info "未找到 JMeter 安装，跳过字体参数配置"
        return 0
    fi

    log_info "配置 JMeter 字体参数: $jmeter_bin"

    # 备份 JMeter 启动脚本
    backup_file "$jmeter_bin"

    # 检查是否已配置 JVM 参数
    if grep -q "-Dfile.encoding=UTF-8" "$jmeter_bin"; then
        log_info "JMeter 已配置 UTF-8 编码"
    else
        # 在 JVM_ARGS 类似的位置添加参数
        sed -i '/^JVM_ARGS=/ s/"$/ -Dfile.encoding=UTF-8"/' "$jmeter_bin" 2>/dev/null && {
            log_success "已添加 JMeter UTF-8 编码参数"
        } || {
            # 如果没有找到 JVM_ARGS，直接添加
            echo 'JVM_ARGS="$JVM_ARGS -Dfile.encoding=UTF-8"' >> "$jmeter_bin"
            log_success "已添加 JMeter UTF-8 编码参数"
        }
    fi
}

# ============================================
# 配置 SSH 密钥
# ============================================

configure_ssh_key() {
    log_info "配置 SSH 密钥..."

    # 检查是否已存在 SSH 密钥对
    if [ -f ~/.ssh/id_rsa ]; then
        log_info "检测到已存在的 SSH 密钥: ~/.ssh/id_rsa"
        read -p "是否重新生成密钥？(y/N): " confirm
        if [ "$confirm" != "y" ] && [ "$confirm" != "Y" ]; then
            log_info "保留现有密钥"
            return 0
        fi
        backup_file ~/.ssh/id_rsa
    fi

    # 创建 .ssh 目录
    mkdir -p ~/.ssh
    chmod 700 ~/.ssh

    # 生成 SSH 密钥对
    log_info "生成 SSH 密钥对 (RSA 4096 位)..."
    if ssh-keygen -t rsa -b 4096 -f ~/.ssh/id_rsa -N "" -C "perfstacksuite@$(hostname)" <<< "" >/dev/null 2>&1; then
        log_success "SSH 密钥生成成功"
    else
        log_error "SSH 密钥生成失败"
        return 1
    fi

    # 配置 authorized_keys
    if [ ! -f ~/.ssh/authorized_keys ]; then
        cp ~/.ssh/id_rsa.pub ~/.ssh/authorized_keys
        chmod 600 ~/.ssh/authorized_keys
        log_success "已配置 authorized_keys"
    else
        log_info "authorized_keys 已存在"
        read -p "是否追加公钥到 authorized_keys？(y/N): " confirm
        if [ "$confirm" = "y" ] || [ "$confirm" = "Y" ]; then
            cat ~/.ssh/id_rsa.pub >> ~/.ssh/authorized_keys
            log_success "已追加公钥到 authorized_keys"
        fi
    fi

    # 显示公钥内容
    echo ""
    echo "SSH 公钥内容："
    echo "----------------------------------------"
    cat ~/.ssh/id_rsa.pub
    echo "----------------------------------------"
    echo ""
    log_info "可以将此公钥添加到其他服务器的 ~/.ssh/authorized_keys 中以实现免密登录"

    log_success "SSH 密钥配置完成"
}

# ============================================
# 验证配置状态
# ============================================

verify_configuration() {
    log_info "验证配置状态..."
    echo ""

    # 1. 显示 SSH 配置摘要
    echo "========================================"
    echo "  SSH 配置摘要"
    echo "========================================"
    display_ssh_config_status

    # 2. 显示 X11 Forwarding 状态
    echo "========================================"
    echo "  X11 Forwarding 状态"
    echo "========================================"
    if grep -q "^X11Forwarding yes" "$SSH_CONFIG_FILE"; then
        echo "✓ X11 Forwarding 已启用"
        echo "  测试命令：ssh -X user@server xclock"
    else
        echo "✗ X11 Forwarding 未启用"
    fi
    echo ""

    # 3. 验证字体安装
    echo "========================================"
    echo "  字体安装状态"
    echo "========================================"
    if command -v fc-list >/dev/null 2>&1; then
        local font_count=$(fc-list :lang=zh 2>/dev/null | wc -l)
        echo "已安装中文字体数量: $font_count"
        if [ "$font_count" -gt 0 ]; then
            echo ""
            echo "中文字体列表（前 5 个）："
            fc-list :lang=zh 2>/dev/null | head -5 | while read line; do
                echo "  - $line"
            done
            echo ""
            echo "✓ 字体安装成功"
        else
            echo "✗ 未检测到中文字体"
        fi
    else
        echo "✗ fc-list 命令不可用，无法验证字体"
    fi
    echo ""

    # 4. SSH 密钥状态
    echo "========================================"
    echo "  SSH 密钥状态"
    echo "========================================"
    if [ -f ~/.ssh/id_rsa ]; then
        echo "✓ SSH 私钥存在: ~/.ssh/id_rsa"
        local key_info=$(ssh-keygen -l -f ~/.ssh/id_rsa 2>/dev/null)
        echo "  密钥信息: $key_info"
    else
        echo "✗ SSH 密钥不存在"
    fi

    if [ -f ~/.ssh/id_rsa.pub ]; then
        echo "✓ SSH 公钥存在: ~/.ssh/id_rsa.pub"
    else
        echo "✗ SSH 公钥不存在"
    fi
    echo ""

    # 5. 测试建议
    echo "========================================"
    echo "  测试建议"
    echo "========================================"
    echo "1. SSH X11 Forwarding 测试："
    echo "   ssh -X $USER@$(hostname) xclock"
    echo ""
    echo "2. JMeter GUI 字体测试："
    echo "   ssh -X $USER@$(hostname)"
    echo "   jmeter"
    echo "   创建测试计划并添加中文元素，检查是否显示正常"
    echo ""
}

# ============================================
# 交互式菜单
# ============================================

show_interactive_menu() {
    echo ""
    echo "============================================"
    echo "    SSH 配置脚本"
    echo "============================================"
    echo ""
    echo "请选择操作："
    echo "  1 - 配置 SSH 服务和安装中文字体"
    echo "  2 - 配置 SSH 密钥"
    echo "  3 - 执行所有配置"
    echo "  4 - 验证配置状态"
    echo "  0 - 退出"
    echo ""
    read -p "请输入选项 [0-4]: " choice

    case "$choice" in
        1)
            detect_os_type
            configure_ssh_service
            install_fonts_and_config_jmeter
            ;;
        2)
            configure_ssh_key
            ;;
        3)
            detect_os_type
            configure_ssh_service
            install_fonts_and_config_jmeter
            configure_ssh_key
            ;;
        4)
            detect_os_type
            verify_configuration
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
            --ssh|-s)
                detect_os_type
                configure_ssh_service
                shift
                ;;
            --font|-f)
                detect_os_type
                install_fonts_and_config_jmeter
                shift
                ;;
            --key|-k)
                configure_ssh_key
                shift
                ;;
            --all|-a)
                detect_os_type
                configure_ssh_service
                install_fonts_and_config_jmeter
                configure_ssh_key
                shift
                ;;
            --verify|-v)
                detect_os_type
                verify_configuration
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
