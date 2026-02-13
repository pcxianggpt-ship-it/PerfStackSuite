#!/bin/bash
#
# InfluxDB 卸载脚本
# 功能：完全卸载 InfluxDB 1.8.10 及相关组件
# 版本：InfluxDB 1.8.10 (1.x 系列 LTS 版本)
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

# 二进制文件实际位置
INFLUXDB_BIN_DIR="$INFLUXDB_INSTALL_DIR/usr/bin"

# 检测是否为 root 用户
if [ "$(id -u)" -eq 0 ]; then
    IS_ROOT_INSTALL=true
else
    IS_ROOT_INSTALL=false
fi

# ============================================
# 显示卸载信息
# ============================================

show_uninstall_info() {
    echo ""
    echo "============================================"
    echo "    InfluxDB 1.8.10 卸载程序"
    echo "============================================"
    echo ""
    echo "将卸载以下内容："
    echo "  - 服务: influxdb"
    echo "  - 版本: InfluxDB 1.8.10"
    echo "  - 安装目录: $INFLUXDB_INSTALL_DIR"
    echo "  - 数据目录: $INFLUXDB_DATA_DIR"
    echo "  - 元数据目录: $INFLUXDB_META_DIR"
    echo "  - 日志目录: $INFLUXDB_LOG_DIR"
    echo "  - 配置目录: $INFLUXDB_CONF_DIR"

    if [ "$IS_ROOT_INSTALL" = true ]; then
        echo "  - systemd 服务: /etc/systemd/system/influxdb.service"
    else
        echo "  - 用户服务: ~/.config/systemd/user/influxdb.service"
    fi

    echo ""
    echo "⚠️  警告：此操作不可逆！"
    echo ""
}

# ============================================
# 确认卸载
# ============================================

confirm_uninstall() {
    read -p "是否确认卸载 InfluxDB？(yes/NO): " confirm

    if [ "$confirm" != "yes" ] && [ "$confirm" != "YES" ] && [ "$confirm" != "y" ]; then
        log_info "取消卸载"
        exit 0
    fi

    # 询问是否删除数据
    echo ""
    read -p "是否删除监控数据？(y/N): " delete_data
    if [ "$delete_data" = "y" ] || [ "$delete_data" = "Y" ]; then
        DELETE_DATA=true
        log_warn "将删除所有监控数据"
    else
        DELETE_DATA=false
        log_info "保留监控数据"
    fi

    echo ""
}

# ============================================
# 检查 InfluxDB 是否安装
# ============================================

check_influxdb_installed() {
    if [ ! -d "$INFLUXDB_INSTALL_DIR" ] && [ ! -f "/etc/systemd/system/influxdb.service" ] && [ ! -f "$HOME/.config/systemd/user/influxdb.service" ]; then
        log_warn "InfluxDB 似乎未安装"
        read -p "是否继续？(y/N): " continue
        if [ "$continue" != "y" ] && [ "$continue" != "Y" ]; then
            log_info "取消卸载"
            exit 0
        fi
    fi
}

# ============================================
# 停止服务
# ============================================

stop_service() {
    log_info "停止 InfluxDB 服务..."

    if [ "$IS_ROOT_INSTALL" = true ]; then
        # root 安装：停止系统服务
        if systemctl list-unit-files | grep -q "^influxdb.service"; then
            if systemctl is-active --quiet influxdb; then
                systemctl stop influxdb
                log_success "InfluxDB 服务已停止"
            else
                log_info "InfluxDB 服务未运行"
            fi

            if systemctl is-enabled --quiet influxdb 2>/dev/null; then
                systemctl disable influxdb
                log_success "InfluxDB 服务已禁用"
            fi
        else
            log_warn "未找到 InfluxDB systemd 服务"
        fi
    else
        # 普通用户安装：停止用户服务
        # 尝试用户级 systemd
        if systemctl --user list-units &>/dev/null; then
            if systemctl --user is-active --quiet influxdb 2>/dev/null; then
                systemctl --user stop influxdb
                log_success "InfluxDB 服务已停止"
            fi
            if systemctl --user is-enabled --quiet influxdb 2>/dev/null; then
                systemctl --user disable influxdb 2>/dev/null || true
            fi
        fi

        # 使用启动脚本停止
        # 注意：当前实现可能没有创建启动脚本
        pkill -f "influxd" 2>/dev/null || true
        sleep 2

        # 手动杀死进程
        pkill -9 -f "influxd" 2>/dev/null || true
    fi
}

# ============================================
# 删除 systemd 服务文件
# ============================================

remove_systemd_service() {
    if [ "$IS_ROOT_INSTALL" = true ]; then
        remove_system_service_file
    else
        remove_user_service_file
    fi
}

# 删除系统级服务文件（需要 root）
remove_system_service_file() {
    log_info "删除 systemd 系统服务文件..."

    local service_file="/etc/systemd/system/influxdb.service"

    if [ -f "$service_file" ]; then
        # 备份服务文件
        backup_file "$service_file"

        # 删除服务文件
        rm -f "$service_file"
        log_success "systemd 服务文件已删除"

        # 重载 systemd
        systemctl daemon-reload
        log_info "systemd 配置已重载"
    else
        log_warn "未找到 systemd 服务文件"
    fi
}

# 删除用户级服务文件（普通用户）
remove_user_service_file() {
    log_info "删除 systemd 用户服务文件..."

    local user_service_dir="$HOME/.config/systemd/user"
    local service_file="$user_service_dir/influxdb.service"

    if [ -f "$service_file" ]; then
        rm -f "$service_file"
        log_success "用户级 systemd 服务文件已删除"

        # 重载用户 systemd
        systemctl --user daemon-reload 2>/dev/null || true
        log_info "用户 systemd 配置已重载"
    fi
}

# ============================================
# 删除防火墙规则
# ============================================

remove_firewall_rules() {
    # 普通用户无法配置防火墙
    if [ "$IS_ROOT_INSTALL" = false ]; then
        log_info "普通用户安装，跳过防火墙配置"
        return 0
    fi

    log_info "删除防火墙规则..."

    local os_type=$(get_os_type)

    case "$os_type" in
        centos|kylin)
            if check_command "firewall-cmd"; then
                firewall-cmd --permanent --remove-port=${INFLUXDB_PORT}/tcp 2>/dev/null || true
                firewall-cmd --reload 2>/dev/null || true
                log_success "防火墙规则已删除（firewalld）"
            else
                log_warn "未找到 firewall-cmd，跳过防火墙配置"
            fi
            ;;
        ubuntu|debian)
            if check_command "ufw"; then
                ufw delete allow ${INFLUXDB_PORT}/tcp 2>/dev/null || true
                log_success "防火墙规则已删除（ufw）"
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
# 删除安装目录
# ============================================

remove_install_dir() {
    log_info "删除安装目录..."

    if [ -d "$INFLUXDB_INSTALL_DIR" ]; then
        rm -rf "$INFLUXDB_INSTALL_DIR"
        log_success "安装目录已删除: $INFLUXDB_INSTALL_DIR"
    else
        log_warn "安装目录不存在: $INFLUXDB_INSTALL_DIR"
    fi
}

# ============================================
# 删除数据目录
# ============================================

remove_data_dir() {
    if [ "$DELETE_DATA" = true ]; then
        log_info "删除数据目录..."

        if [ -d "$INFLUXDB_DATA_DIR" ]; then
            rm -rf "$INFLUXDB_DATA_DIR"
            log_success "数据目录已删除: $INFLUXDB_DATA_DIR"
        else
            log_warn "数据目录不存在: $INFLUXDB_DATA_DIR"
        fi

        # 删除元数据目录
        if [ -d "$INFLUXDB_META_DIR" ]; then
            rm -rf "$INFLUXDB_META_DIR"
            log_success "元数据目录已删除: $INFLUXDB_META_DIR"
        fi
    else
        log_info "保留数据目录: $INFLUXDB_DATA_DIR"
    fi
}

# ============================================
# 删除日志目录
# ============================================

remove_log_dir() {
    log_info "删除日志目录..."

    if [ -d "$INFLUXDB_LOG_DIR" ]; then
        rm -rf "$INFLUXDB_LOG_DIR"
        log_success "日志目录已删除: $INFLUXDB_LOG_DIR"
    else
        log_warn "日志目录不存在: $INFLUXDB_LOG_DIR"
    fi
}

# ============================================
# 删除配置目录
# ============================================

remove_conf_dir() {
    log_info "删除配置目录..."

    if [ -d "$INFLUXDB_CONF_DIR" ]; then
        rm -rf "$INFLUXDB_CONF_DIR"
        log_success "配置目录已删除: $INFLUXDB_CONF_DIR"
    else
        log_warn "配置目录不存在: $INFLUXDB_CONF_DIR"
    fi
}

# ============================================
# 清理符号链接
# ============================================

remove_symlinks() {
    log_info "清理符号链接..."

    # 删除可能的符号链接
    if [ -L "$INFLUXDB_INSTALL_DIR/influxd" ]; then
        rm -f "$INFLUXDB_INSTALL_DIR/influxd"
        log_success "已删除 influxd 符号链接"
    fi

    if [ -L "$INFLUXDB_INSTALL_DIR/influx" ]; then
        rm -f "$INFLUXDB_INSTALL_DIR/influx"
        log_success "已删除 influx 符号链接"
    fi
}

# ============================================
# 清理环境变量配置
# ============================================

remove_path_config() {
    log_info "清理 PATH 环境变量配置..."

    local config_file=""
    if [ -f "$HOME/.bashrc" ]; then
        config_file="$HOME/.bashrc"
    elif [ -f "$HOME/.bash_profile" ]; then
        config_file="$HOME/.bash_profile"
    else
        log_info "未找到配置文件，跳过 PATH 清理"
        return 0
    fi

    # 检查是否配置过
    if ! grep -q "InfluxDB 1.8.10" "$config_file" 2>/dev/null; then
        log_info "PATH 未配置过，跳过"
        return 0
    fi

    # 备份配置文件
    backup_file "$config_file"

    # 移除 InfluxDB PATH 配置
    sed -i '/# InfluxDB 1.8.10 环境变量/,/export PATH="$INFLUXDB_INSTALL_DIR\/usr\/bin:\$PATH"/d' "$config_file" 2>/dev/null || \
    sed -i '' '/# InfluxDB 1.8.10 环境变量/,/export PATH="$INFLUXDB_INSTALL_DIR\/usr\/bin:\$PATH"/d' "$config_file" 2>/dev/null || true

    if grep -q "InfluxDB 1.8.10" "$config_file" 2>/dev/null; then
        log_warn "PATH 配置可能未完全清理，请手动检查: $config_file"
    else
        log_success "PATH 配置已清理"
        log_info "请执行以下命令使配置生效："
        log_info "  source $config_file"
        log_info "或者重新登录系统"
    fi
}

# ============================================
# 验证卸载
# ============================================

verify_uninstall() {
    log_info "验证卸载结果..."

    # 检查进程
    if pgrep -f "influx" > /dev/null; then
        log_error "InfluxDB 进程仍在运行"
        log_info "请手动检查并清理进程"
    else
        log_success "InfluxDB 进程已停止"
    fi

    # 检查端口
    if check_port "$INFLUXDB_PORT"; then
        log_warn "端口 ${INFLUXDB_PORT} 仍在监听"
    else
        log_success "端口 ${INFLUXDB_PORT} 已释放"
    fi

    # 检查目录
    local remaining_items=()

    if [ -d "$INFLUXDB_INSTALL_DIR" ]; then
        remaining_items+=("安装目录: $INFLUXDB_INSTALL_DIR")
    fi

    if [ "$DELETE_DATA" = true ]; then
        if [ -d "$INFLUXDB_DATA_DIR" ]; then
            remaining_items+=("数据目录: $INFLUXDB_DATA_DIR")
        fi

        if [ -d "$INFLUXDB_META_DIR" ]; then
            remaining_items+=("元数据目录: $INFLUXDB_META_DIR")
        fi
    fi

    if [ -d "$INFLUXDB_LOG_DIR" ]; then
        remaining_items+=("日志目录: $INFLUXDB_LOG_DIR")
    fi

    if [ -d "$INFLUXDB_CONF_DIR" ]; then
        remaining_items+=("配置目录: $INFLUXDB_CONF_DIR")
    fi

    # 检查二进制文件
    if [ -f "$INFLUXDB_BIN_DIR/influxd" ] || [ -f "$INFLUXDB_BIN_DIR/influx" ]; then
        remaining_items+=("二进制文件: $INFLUXDB_BIN_DIR/")
    fi

    # 检查符号链接
    if [ -L "$INFLUXDB_INSTALL_DIR/influxd" ] || [ -L "$INFLUXDB_INSTALL_DIR/influx" ]; then
        remaining_items+=("符号链接: $INFLUXDB_INSTALL_DIR/")
    fi

    if [ ${#remaining_items[@]} -gt 0 ]; then
        log_warn "以下项目仍存在:"
        for item in "${remaining_items[@]}"; do
            echo "  - $item"
        done
    else
        log_success "所有组件已成功卸载"
    fi
}

# ============================================
# 显示卸载完成信息
# ============================================

show_completion_info() {
    echo ""
    echo "============================================"
    echo "    InfluxDB 1.8.10 卸载完成"
    echo "============================================"
    echo ""

    if [ "$DELETE_DATA" = false ]; then
        echo "保留数据："
        echo "  - 数据目录: $INFLUXDB_DATA_DIR"
        echo "  - 元数据目录: $INFLUXDB_META_DIR"
        echo ""
        echo "如需删除数据，请手动执行："
        echo "  rm -rf $INFLUXDB_DATA_DIR"
        echo "  rm -rf $INFLUXDB_META_DIR"
        echo ""
    fi

    echo "备份文件位置："
    if [ "$IS_ROOT_INSTALL" = true ]; then
        echo "  - /etc/systemd/system/influxdb.service.bak.*"
        echo "  - $INFLUXDB_CONF_DIR/influxdb.conf.bak.*"
    else
        echo "  - ~/.config/systemd/user/influxdb.service.bak.*"
        echo "  - $INFLUXDB_CONF_DIR/influxdb.conf.bak.*"
        echo "  - ~/.bashrc.bak.* 或 ~/.bash_profile.bak.* (PATH 配置)"
    fi
    echo ""

    echo "日志文件："
    echo "  - $LOG_FILE"
    echo ""

    echo "环境变量清理："
    echo "  - 已从 ~/.bashrc 或 ~/.bash_profile 移除 PATH 配置"
    echo "  - 请执行以下命令使配置生效："
    echo "    source ~/.bashrc"
    echo "    或重新登录系统"
    echo ""

    echo "提示："
    echo "  - InfluxDB 1.8.10 已完全卸载"
    echo "  - 如需重新安装，运行: bash scripts/install_influxdb.sh"
    echo ""

    echo "============================================"
    echo ""
}

# ============================================
# 主卸载流程
# ============================================

main() {
    # 初始化日志
    mkdir -p "$(dirname "$LOG_FILE")"
    touch "$LOG_FILE"

    # 加载配置
    load_config

    # 显示卸载信息
    show_uninstall_info

    # 检查是否已安装
    check_influxdb_installed

    # 确认卸载
    confirm_uninstall

    log_info "开始卸载 InfluxDB 1.8.10..."

    # 停止服务
    stop_service

    # 删除 systemd 服务
    remove_systemd_service

    # 删除防火墙规则
    remove_firewall_rules

    # 清理符号链接
    remove_symlinks

    # 清理环境变量配置
    remove_path_config

    # 删除安装目录
    remove_install_dir

    # 删除数据目录
    remove_data_dir

    # 删除日志目录
    remove_log_dir

    # 删除配置目录
    remove_conf_dir

    # 验证卸载
    verify_uninstall

    # 显示完成信息
    show_completion_info

    log_success "InfluxDB 1.8.10 卸载完成！"
}

# ============================================
# 脚本入口
# ============================================

main "$@"
