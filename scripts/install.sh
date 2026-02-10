#!/bin/bash
#
# PerfStackSuite 主安装脚本
# 统一的入口脚本，负责协调所有组件的安装
#

set -e  # 遇到错误时退出

# 获取脚本目录
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# 加载公共函数库
source "${SCRIPT_DIR}/common.sh"

# ============================================
# 显示欢迎信息
# ============================================

show_welcome() {
    echo ""
    echo "============================================"
    echo "    PerfStackSuite 安装程序"
    echo "    版本: v1.0"
    echo "============================================"
    echo ""
}

# ============================================
# 显示主菜单
# ============================================

show_menu() {
    echo "请选择操作:"
    echo "  1 - 全量安装（Prometheus + Grafana + InfluxDB + Node Exporter + JDK + JMeter）"
    echo "  2 - 仅安装监控系统"
    echo "  3 - 仅安装 JDK + JMeter"
    echo "  4 - 配置 SSH + X11"
    echo "  5 - 优化系统内核参数（TCP TIME_WAIT 处理）"
    echo "  6 - 安装中文字体（解决 JMeter GUI 乱码）"
    echo "  7 - 自定义安装"
    echo "  8 - 卸载组件"
    echo "  0 - 退出"
    echo ""
    read -p "请输入选项 [0-8]: " choice
    echo ""
}

# ============================================
# 解析命令行参数
# ============================================

parse_arguments() {
    # 简单的命令行参数解析
    while [[ $# -gt 0 ]]; do
        case $1 in
            --all)
                CHOICE=1
                shift
                ;;
            --monitoring)
                CHOICE=2
                shift
                ;;
            --jmeter)
                CHOICE=3
                shift
                ;;
            --ssh)
                CHOICE=4
                shift
                ;;
            --sysctl)
                CHOICE=5
                shift
                ;;
            --fonts)
                CHOICE=6
                shift
                ;;
            --uninstall)
                CHOICE=8
                shift
                ;;
            --help|-h)
                show_help
                exit 0
                ;;
            *)
                log_error "未知参数: $1"
                show_help
                exit 1
                ;;
        esac
    done
}

# ============================================
# 显示帮助信息
# ============================================

show_help() {
    echo "用法: $0 [选项]"
    echo ""
    echo "选项:"
    echo "  --all          全量安装所有组件"
    echo "  --monitoring    仅安装监控系统"
    echo "  --jmeter        仅安装 JDK + JMeter"
    echo "  --ssh           配置 SSH + X11"
    echo "  --sysctl        优化系统内核参数"
    echo "  --fonts         安装中文字体"
    echo "  --uninstall     卸载组件"
    echo "  --help, -h      显示此帮助信息"
    echo ""
    echo "如果不指定选项，将进入交互式菜单模式"
}

# ============================================
# 全量安装
# ============================================

install_all() {
    log_info "开始全量安装..."

    # 安装监控系统
    log_info "步骤 1/2: 安装监控系统..."
    if ! install_prometheus; then
        log_error "Prometheus 安装失败"
        read -p "是否继续安装其他组件？(y/N): " continue
        if [ "$continue" != "y" ] && [ "$continue" != "Y" ]; then
            log_info "取消安装"
            exit 1
        fi
    fi

    if ! install_grafana; then
        log_error "Grafana 安装失败"
        read -p "是否继续安装其他组件？(y/N): " continue
        if [ "$continue" != "y" ] && [ "$continue" != "Y" ]; then
            log_info "取消安装"
            exit 1
        fi
    fi

    if ! install_influxdb; then
        log_error "InfluxDB 安装失败"
        read -p "是否继续安装其他组件？(y/N): " continue
        if [ "$continue" != "y" ] && [ "$continue" != "Y" ]; then
            log_info "取消安装"
            exit 1
        fi
    fi

    if ! install_node_exporter; then
        log_error "Node Exporter 安装失败"
        read -p "是否继续安装其他组件？(y/N): " continue
        if [ "$continue" != "y" ] && [ "$continue" != "Y" ]; then
            log_info "取消安装"
            exit 1
        fi
    fi

    # 安装压测工具
    log_info "步骤 2/2: 安装压测工具..."
    if ! install_jdk; then
        log_error "JDK 安装失败"
        read -p "是否继续安装 JMeter？(y/N): " continue
        if [ "$continue" != "y" ] && [ "$continue" != "Y" ]; then
            log_info "取消安装"
            exit 1
        fi
    fi

    if ! install_jmeter; then
        log_error "JMeter 安装失败"
    fi

    log_success "全量安装完成！"
    show_summary
}

# ============================================
# 安装监控系统
# ============================================

install_monitoring() {
    log_info "开始安装监控系统..."

    if ! install_prometheus; then
        log_error "Prometheus 安装失败"
        read -p "是否继续安装其他监控组件？(y/N): " continue
        if [ "$continue" != "y" ] && [ "$continue" != "Y" ]; then
            log_info "取消安装"
            exit 1
        fi
    fi

    if ! install_grafana; then
        log_error "Grafana 安装失败"
        read -p "是否继续安装其他监控组件？(y/N): " continue
        if [ "$continue" != "y" ] && [ "$continue" != "Y" ]; then
            log_info "取消安装"
            exit 1
        fi
    fi

    if ! install_influxdb; then
        log_error "InfluxDB 安装失败"
        read -p "是否继续安装 Node Exporter？(y/N): " continue
        if [ "$continue" != "y" ] && [ "$continue" != "Y" ]; then
            log_info "取消安装"
            exit 1
        fi
    fi

    if ! install_node_exporter; then
        log_error "Node Exporter 安装失败"
    fi

    log_success "监控系统安装完成！"
    show_summary
}

# ============================================
# 安装 JDK + JMeter
# ============================================

install_jmeter_suite() {
    log_info "开始安装 JDK + JMeter..."

    if ! install_jdk; then
        log_error "JDK 安装失败"
        log_info "JMeter 依赖 JDK，取消安装"
        exit 1
    fi

    if ! install_jmeter; then
        log_error "JMeter 安装失败"
    fi

    log_success "JDK + JMeter 安装完成！"
    show_summary
}

# ============================================
# 自定义安装
# ============================================

install_custom() {
    log_info "自定义安装模式"
    echo "请选择要安装的组件（多选用空格分隔）:"
    echo "  1 - Prometheus"
    echo "  2 - Grafana"
    echo "  3 - InfluxDB"
    echo "  4 - Node Exporter"
    echo "  5 - JDK"
    echo "  6 - JMeter"
    echo "  7 - 系统内核优化"
    echo "  8 - SSH 配置"
    echo ""
    read -p "请输入组件编号: " components

    local failed_components=()

    for comp in $components; do
        case $comp in
            1)
                if ! install_prometheus; then
                    failed_components+=("Prometheus")
                fi
                ;;
            2)
                if ! install_grafana; then
                    failed_components+=("Grafana")
                fi
                ;;
            3)
                if ! install_influxdb; then
                    failed_components+=("InfluxDB")
                fi
                ;;
            4)
                if ! install_node_exporter; then
                    failed_components+=("Node Exporter")
                fi
                ;;
            5)
                if ! install_jdk; then
                    failed_components+=("JDK")
                fi
                ;;
            6)
                if ! install_jmeter; then
                    failed_components+=("JMeter")
                fi
                ;;
            7)
                if ! install_sysctl; then
                    failed_components+=("系统内核优化")
                fi
                ;;
            8)
                if ! config_ssh; then
                    failed_components+=("SSH 配置")
                fi
                ;;
            *)
                log_warn "无效的组件编号: $comp"
                ;;
        esac
    done

    # 显示安装结果
    if [ ${#failed_components[@]} -gt 0 ]; then
        log_warn "以下组件安装失败: ${failed_components[*]}"
    else
        log_success "所有组件安装成功！"
    fi

    show_summary
}

# ============================================
# 卸载组件
# ============================================

uninstall_components() {
    log_info "卸载组件模式"
    echo ""
    echo "请选择要卸载的组件（多选用空格分隔）:"
    echo "  1 - Prometheus"
    echo "  2 - Grafana"
    echo "  3 - InfluxDB"
    echo "  4 - Node Exporter"
    echo "  5 - JDK"
    echo "  6 - JMeter"
    echo "  all - 全部卸载"
    echo ""
    read -p "请输入组件编号: " components

    if [ "$components" = "all" ]; then
        components="1 2 3 4 5 6"
    fi

    local uninstalled_components=()
    local failed_components=()

    for comp in $components; do
        case $comp in
            1)
                local script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
                if [ -f "$script_dir/uninstall_prometheus.sh" ]; then
                    log_info "卸载 Prometheus..."
                    if bash "$script_dir/uninstall_prometheus.sh"; then
                        uninstalled_components+=("Prometheus")
                    else
                        failed_components+=("Prometheus")
                    fi
                else
                    log_warn "Prometheus 卸载脚本不存在，跳过"
                fi
                ;;
            2)
                if uninstall_grafana; then
                    uninstalled_components+=("Grafana")
                else
                    failed_components+=("Grafana")
                fi
                ;;
            3)
                if uninstall_influxdb; then
                    uninstalled_components+=("InfluxDB")
                else
                    failed_components+=("InfluxDB")
                fi
                ;;
            4)
                if uninstall_node_exporter; then
                    uninstalled_components+=("Node Exporter")
                else
                    failed_components+=("Node Exporter")
                fi
                ;;
            5)
                if uninstall_jdk; then
                    uninstalled_components+=("JDK")
                else
                    failed_components+=("JDK")
                fi
                ;;
            6)
                if uninstall_jmeter; then
                    uninstalled_components+=("JMeter")
                else
                    failed_components+=("JMeter")
                fi
                ;;
            *)
                log_warn "无效的组件编号: $comp"
                ;;
        esac
    done

    # 显示卸载结果
    echo ""
    if [ ${#uninstalled_components[@]} -gt 0 ]; then
        log_success "已卸载: ${uninstalled_components[*]}"
    fi

    if [ ${#failed_components[@]} -gt 0 ]; then
        log_warn "卸载失败: ${failed_components[*]}"
    fi

    if [ ${#uninstalled_components[@]} -eq 0 ] && [ ${#failed_components[@]} -eq 0 ]; then
        log_info "没有组件被卸载"
    fi
}

# ============================================
# 显示安装摘要
# ============================================

show_summary() {
    echo ""
    echo "============================================"
    echo "    安装摘要"
    echo "============================================"
    echo ""
    echo "访问地址："
    echo "  - Prometheus: http://localhost:9090"
    echo "  - Grafana:    http://localhost:3000 (admin/admin123)"
    echo "  - InfluxDB:   http://localhost:8086"
    echo ""
    echo "日志文件: $LOG_FILE"
    echo ""
    echo "============================================"
    echo ""
}

# ============================================
# 主函数
# ============================================

main() {
    # 初始化日志文件
    mkdir -p "$(dirname "$LOG_FILE")"
    touch "$LOG_FILE"

    # 显示欢迎信息
    show_welcome

    # 环境检查
    check_environment

    # 加载配置文件
    load_config

    # 如果有命令行参数，则执行对应操作
    if [ $# -gt 0 ]; then
        parse_arguments "$@"
        if [ -n "$CHOICE" ]; then
            case $CHOICE in
                1) install_all ;;
                2) install_monitoring ;;
                3) install_jmeter_suite ;;
                4) config_ssh ;;
                5) install_sysctl ;;
                6) install_chinese_fonts ;;
            esac
            exit 0
        fi
    fi

    # 交互式菜单模式
    while true; do
        show_menu
        case $choice in
            0)
                log_info "退出安装程序"
                exit 0
                ;;
            1)
                install_all
                ;;
            2)
                install_monitoring
                ;;
            3)
                install_jmeter_suite
                ;;
            4)
                config_ssh
                ;;
            5)
                install_sysctl
                ;;
            6)
                install_chinese_fonts
                ;;
            7)
                install_custom
                ;;
            8)
                uninstall_components
                ;;
            *)
                log_error "无效的选项，请重新选择"
                ;;
        esac

        # 询问是否继续
        echo ""
        read -p "按 Enter 键继续，或输入 q 退出: " continue
        if [ "$continue" = "q" ] || [ "$continue" = "Q" ]; then
            log_info "退出安装程序"
            exit 0
        fi
    done
}

# ============================================
# 脚本入口
# ============================================

main "$@"
