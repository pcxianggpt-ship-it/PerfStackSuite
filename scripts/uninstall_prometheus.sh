#!/bin/bash
#
# Prometheus 卸载脚本
# 功能：完全卸载 Prometheus 及相关组件
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

# ============================================
# 显示卸载信息
# ============================================

show_uninstall_info() {
    echo ""
    echo "============================================"
    echo "    Prometheus 卸载程序"
    echo "============================================"
    echo ""
    echo "将卸载以下内容："
    echo "  - 服务: prometheus"
    echo "  - 安装目录: $PROMETHEUS_INSTALL_DIR"
    echo "  - 数据目录: $PROMETHEUS_DATA_DIR"
    echo "  - 日志目录: $PROMETHEUS_LOG_DIR"
    echo "  - systemd 服务: /etc/systemd/system/prometheus.service"
    echo ""
    echo "⚠️  警告：此操作不可逆！"
    echo ""
}

# ============================================
# 确认卸载
# ============================================

confirm_uninstall() {
    read -p "是否确认卸载 Prometheus？(yes/NO): " confirm

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
# 检查 Prometheus 是否安装
# ============================================

check_prometheus_installed() {
    if [ ! -d "$PROMETHEUS_INSTALL_DIR" ] && [ ! -f "/etc/systemd/system/prometheus.service" ]; then
        log_warn "Prometheus 似乎未安装"
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
    log_info "停止 Prometheus 服务..."

    # 检查服务是否存在
    if systemctl list-unit-files | grep -q "^prometheus.service"; then
        # 停止服务
        if systemctl is-active --quiet prometheus; then
            systemctl stop prometheus
            log_success "Prometheus 服务已停止"
        else
            log_info "Prometheus 服务未运行"
        fi

        # 禁用服务
        if systemctl is-enabled --quiet prometheus 2>/dev/null; then
            systemctl disable prometheus
            log_success "Prometheus 服务已禁用"
        fi
    else
        log_warn "未找到 Prometheus systemd 服务"
    fi
}

# ============================================
# 删除 systemd 服务文件
# ============================================

remove_systemd_service() {
    log_info "删除 systemd 服务文件..."

    local service_file="/etc/systemd/system/prometheus.service"

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

# ============================================
# 删除防火墙规则
# ============================================

remove_firewall_rules() {
    log_info "删除防火墙规则..."

    local os_type=$(get_os_type)

    case "$os_type" in
        centos|kylin)
            if check_command "firewall-cmd"; then
                firewall-cmd --permanent --remove-port=${PROMETHEUS_PORT}/tcp 2>/dev/null || true
                firewall-cmd --reload 2>/dev/null || true
                log_success "防火墙规则已删除（firewalld）"
            else
                log_warn "未找到 firewall-cmd，跳过防火墙配置"
            fi
            ;;
        ubuntu|debian)
            if check_command "ufw"; then
                ufw delete allow ${PROMETHEUS_PORT}/tcp 2>/dev/null || true
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

    if [ -d "$PROMETHEUS_INSTALL_DIR" ]; then
        rm -rf "$PROMETHEUS_INSTALL_DIR"
        log_success "安装目录已删除: $PROMETHEUS_INSTALL_DIR"
    else
        log_warn "安装目录不存在: $PROMETHEUS_INSTALL_DIR"
    fi
}

# ============================================
# 删除数据目录
# ============================================

remove_data_dir() {
    if [ "$DELETE_DATA" = true ]; then
        log_info "删除数据目录..."

        if [ -d "$PROMETHEUS_DATA_DIR" ]; then
            rm -rf "$PROMETHEUS_DATA_DIR"
            log_success "数据目录已删除: $PROMETHEUS_DATA_DIR"
        else
            log_warn "数据目录不存在: $PROMETHEUS_DATA_DIR"
        fi
    else
        log_info "保留数据目录: $PROMETHEUS_DATA_DIR"
    fi
}

# ============================================
# 删除日志目录
# ============================================

remove_log_dir() {
    log_info "删除日志目录..."

    if [ -d "$PROMETHEUS_LOG_DIR" ]; then
        rm -rf "$PROMETHEUS_LOG_DIR"
        log_success "日志目录已删除: $PROMETHEUS_LOG_DIR"
    else
        log_warn "日志目录不存在: $PROMETHEUS_LOG_DIR"
    fi
}

# ============================================
# 验证卸载
# ============================================

verify_uninstall() {
    log_info "验证卸载结果..."

    # 检查进程
    if pgrep -f "prometheus" > /dev/null; then
        log_error "Prometheus 进程仍在运行"
        log_info "请手动检查并清理进程"
    else
        log_success "Prometheus 进程已停止"
    fi

    # 检查端口
    if check_port "$PROMETHEUS_PORT"; then
        log_warn "端口 ${PROMETHEUS_PORT} 仍在监听"
    else
        log_success "端口 ${PROMETHEUS_PORT} 已释放"
    fi

    # 检查目录
    local remaining_items=()

    if [ -d "$PROMETHEUS_INSTALL_DIR" ]; then
        remaining_items+=("安装目录: $PROMETHEUS_INSTALL_DIR")
    fi

    if [ "$DELETE_DATA" = true ] && [ -d "$PROMETHEUS_DATA_DIR" ]; then
        remaining_items+=("数据目录: $PROMETHEUS_DATA_DIR")
    fi

    if [ -d "$PROMETHEUS_LOG_DIR" ]; then
        remaining_items+=("日志目录: $PROMETHEUS_LOG_DIR")
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
    echo "    Prometheus 卸载完成"
    echo "============================================"
    echo ""

    if [ "$DELETE_DATA" = false ]; then
        echo "保留数据："
        echo "  - 数据目录: $PROMETHEUS_DATA_DIR"
        echo ""
        echo "如需删除数据，请手动执行："
        echo "  rm -rf $PROMETHEUS_DATA_DIR"
        echo ""
    fi

    echo "备份文件位置："
    echo "  - /etc/systemd/system/prometheus.service.bak.*"
    echo ""

    echo "日志文件："
    echo "  - $LOG_FILE"
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
    check_prometheus_installed

    # 确认卸载
    confirm_uninstall

    log_info "开始卸载 Prometheus..."

    # 停止服务
    stop_service

    # 删除 systemd 服务
    remove_systemd_service

    # 删除防火墙规则
    remove_firewall_rules

    # 删除安装目录
    remove_install_dir

    # 删除数据目录
    remove_data_dir

    # 删除日志目录
    remove_log_dir

    # 验证卸载
    verify_uninstall

    # 显示完成信息
    show_completion_info

    log_success "Prometheus 卸载完成！"
}

# ============================================
# 脚本入口
# ============================================

main "$@"
