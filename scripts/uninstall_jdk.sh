#!/bin/bash
#
# JDK 卸载脚本
# 功能：完全卸载 JDK 及相关配置
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

JDK_VERSION="${JDK_VERSION:-}"
JAVA_BASE_DIR="$HOME/java"
JAVA_CURRENT_LINK="$JAVA_BASE_DIR/current"

# 检测是否为 root 用户
if [ "$(id -u)" -eq 0 ]; then
    IS_ROOT_INSTALL=true
else
    IS_ROOT_INSTALL=false
fi

# ============================================
# 显示使用说明
# ============================================

show_usage() {
    cat << EOF
用法: $0 [选项]

选项：
  --version, -v       指定要卸载的 JDK 版本
                      如果不指定，将卸载所有 JDK 版本
  --help, -h          显示此帮助信息

示例：
  $0                          # 交互式选择要卸载的 JDK
  $0 --version 8u481          # 卸载 JDK 8u481
  $0 -v 11.0.20               # 卸载 JDK 11.0.20

注意：
  - 此脚本将删除 JDK 安装目录和相关配置
  - 环境变量配置将从 ~/.bashrc 或 ~/.bash_profile 中移除
  - 请确保没有其他程序依赖此 JDK
EOF
}

# ============================================
# 列出已安装的 JDK 版本
# ============================================

list_installed_jdks() {
    log_info "检测已安装的 JDK 版本..."

    local found_jdk=false

    if [ -d "$JAVA_BASE_DIR" ]; then
        echo ""
        echo "已安装的 JDK 版本："
        echo ""

        # 查找所有 JDK 目录
        local jdk_dirs=($(find "$JAVA_BASE_DIR" -maxdepth 1 -type d -name "jdk-*" 2>/dev/null | sort))

        if [ ${#jdk_dirs[@]} -eq 0 ]; then
            log_warn "未找到已安装的 JDK"
            return 1
        fi

        local index=1
        for jdk_dir in "${jdk_dirs[@]}"; do
            local jdk_name=$(basename "$jdk_dir")

            # 检查是否包含 java 命令
            if [ -f "$jdk_dir/bin/java" ]; then
                local version=$("$jdk_dir/bin/java" -version 2>&1 | head -1)
                echo "  [$index] $jdk_name"
                echo "      路径: $jdk_dir"
                echo "      版本: $version"

                # 检查是否为当前激活的版本
                if [ -L "$JAVA_CURRENT_LINK" ]; then
                    local link_target=$(readlink "$JAVA_CURRENT_LINK")
                    if [ "$link_target" = "$jdk_dir" ]; then
                        echo "      状态: 当前激活"
                    fi
                fi

                echo ""
                ((index++))
                found_jdk=true
            fi
        done
    fi

    if [ "$found_jdk" = false ]; then
        log_warn "未找到已安装的 JDK"
        return 1
    fi

    return 0
}

# ============================================
# 显示卸载信息
# ============================================

show_uninstall_info() {
    echo ""
    echo "============================================"
    echo "    JDK 卸载程序"
    echo "============================================"
    echo ""

    if [ -n "$JDK_VERSION" ]; then
        echo "将卸载以下内容："
        echo "  - JDK 版本: ${JDK_VERSION}"
        echo "  - 安装目录: $JAVA_BASE_DIR/jdk-${JDK_VERSION}"
        echo ""
    else
        echo "将卸载所有 JDK 版本"
        echo "  - JDK 基础目录: $JAVA_BASE_DIR"
        echo ""
    fi

    echo "⚠️  警告：此操作不可逆！"
    echo ""
}

# ============================================
# 确认卸载
# ============================================

confirm_uninstall() {
    read -p "是否确认卸载 JDK？(yes/NO): " confirm

    if [ "$confirm" != "yes" ] && [ "$confirm" != "YES" ] && [ "$confirm" != "y" ]; then
        log_info "取消卸载"
        exit 0
    fi

    echo ""
}

# ============================================
# 交互式选择 JDK 版本
# ============================================

select_jdk_version() {
    if [ -n "$JDK_VERSION" ]; then
        return 0
    fi

    # 列出已安装的 JDK
    if ! list_installed_jdks; then
        log_error "未找到可卸载的 JDK"
        exit 1
    fi

    # 获取 JDK 列表
    local jdk_dirs=($(find "$JAVA_BASE_DIR" -maxdepth 1 -type d -name "jdk-*" 2>/dev/null | sort))

    if [ ${#jdk_dirs[@]} -eq 0 ]; then
        log_error "未找到可卸载的 JDK"
        exit 1
    fi

    # 如果只有一个版本，直接卸载
    if [ ${#jdk_dirs[@]} -eq 1 ]; then
        local jdk_dir="${jdk_dirs[0]}"
        JDK_VERSION=$(basename "$jdk_dir" | sed 's/^jdk-//')
        log_info "自动选择唯一安装的版本: $JDK_VERSION"
        return 0
    fi

    # 多个版本，让用户选择
    echo "请选择要卸载的 JDK 版本："
    local index=1
    for jdk_dir in "${jdk_dirs[@]}"; do
        local jdk_name=$(basename "$jdk_dir")
        if [ -f "$jdk_dir/bin/java" ]; then
            echo "  [$index] $jdk_name"
            ((index++))
        fi
    done
    echo "  [all] 所有版本"

    read -p "请输入选项 [1-$((${#jdk_dirs[@]})) or all]: " choice

    if [ "$choice" = "all" ] || [ "$choice" = "ALL" ]; then
        JDK_VERSION=""
        log_info "将卸载所有 JDK 版本"
    else
        # 验证输入
        if ! [[ "$choice" =~ ^[0-9]+$ ]] || [ "$choice" -lt 1 ] || [ "$choice" -gt "${#jdk_dirs[@]}" ]; then
            log_error "无效的选择"
            exit 1
        fi

        local selected_jdk="${jdk_dirs[$((choice-1))]}"
        JDK_VERSION=$(basename "$selected_jdk" | sed 's/^jdk-//')
        log_info "已选择: $JDK_VERSION"
    fi

    echo ""
}

# ============================================
# 检查 JDK 是否在使用
# ============================================

check_jdk_in_use() {
    log_info "检查 JDK 是否在使用中..."

    # 检查 Java 进程
    local java_processes=$(pgrep -f "java" 2>/dev/null || true)

    if [ -n "$java_processes" ]; then
        log_warn "检测到正在运行的 Java 进程："
        ps -p $java_processes -o pid,cmd 2>/dev/null || true
        echo ""
        read -p "是否继续卸载？(y/N): " continue
        if [ "$continue" != "y" ] && [ "$continue" != "Y" ]; then
            log_info "取消卸载"
            exit 0
        fi
    fi
}

# ============================================
# 删除符号链接
# ============================================

remove_symlinks() {
    log_info "删除符号链接..."

    # 删除 current 链接（如果指向要卸载的版本）
    if [ -L "$JAVA_CURRENT_LINK" ]; then
        if [ -n "$JDK_VERSION" ]; then
            # 检查链接是否指向要卸载的版本
            local link_target=$(readlink "$JAVA_CURRENT_LINK")
            if [ "$link_target" = "$JAVA_BASE_DIR/jdk-${JDK_VERSION}" ]; then
                rm -f "$JAVA_CURRENT_LINK"
                log_success "已删除符号链接: $JAVA_CURRENT_LINK"
            else
                log_info "符号链接未指向要卸载的版本，保留"
            fi
        else
            # 删除所有版本的链接
            rm -f "$JAVA_CURRENT_LINK"
            log_success "已删除符号链接: $JAVA_CURRENT_LINK"
        fi
    else
        log_info "未找到符号链接: $JAVA_CURRENT_LINK"
    fi
}

# ============================================
# 删除 JDK 安装目录
# ============================================

remove_jdk_directories() {
    log_info "删除 JDK 安装目录..."

    if [ -n "$JDK_VERSION" ]; then
        # 删除指定版本
        local jdk_dir="$JAVA_BASE_DIR/jdk-${JDK_VERSION}"
        if [ -d "$jdk_dir" ]; then
            rm -rf "$jdk_dir"
            log_success "已删除目录: $jdk_dir"
        else
            log_warn "目录不存在: $jdk_dir"
        fi
    else
        # 删除所有版本
        if [ -d "$JAVA_BASE_DIR" ]; then
            rm -rf "$JAVA_BASE_DIR"
            log_success "已删除目录: $JAVA_BASE_DIR"
        else
            log_warn "目录不存在: $JAVA_BASE_DIR"
        fi
    fi
}

# ============================================
# 清理环境变量配置
# ============================================

remove_environment_config() {
    log_info "清理环境变量配置..."

    local config_file=""
    if [ -f "$HOME/.bashrc" ]; then
        config_file="$HOME/.bashrc"
    elif [ -f "$HOME/.bash_profile" ]; then
        config_file="$HOME/.bash_profile"
    else
        log_info "未找到配置文件，跳过环境变量清理"
        return 0
    fi

    # 检查是否配置过
    if ! grep -q "JDK" "$config_file" 2>/dev/null; then
        log_info "未配置过 JDK 环境变量，跳过"
        return 0
    fi

    # 备份配置文件
    backup_file "$config_file"

    # 移除 JDK 环境变量配置
    if [ -n "$JDK_VERSION" ]; then
        # 删除特定版本的配置
        sed -i "/# JDK ${JDK_VERSION} 环境变量/,/export PATH=\$JAVA_HOME\/bin:\\\$PATH/d" "$config_file" 2>/dev/null || true
        log_success "已删除 JDK ${JDK_VERSION} 环境变量配置"
    else
        # 删除所有 JDK 配置
        sed -i '/# JDK Environment/,/export JAVA_HOME=/d' "$config_file" 2>/dev/null || true
        log_success "已删除所有 JDK 环境变量配置"
    fi

    # 验证清理结果
    if grep -q "JAVA_HOME" "$config_file" 2>/dev/null; then
        log_warn "环境变量配置可能未完全清理"
        log_info "请手动检查: $config_file"
    else
        log_success "环境变量配置已清理"
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

    local remaining_items=()

    if [ -n "$JDK_VERSION" ]; then
        # 检查指定版本是否删除
        local jdk_dir="$JAVA_BASE_DIR/jdk-${JDK_VERSION}"
        if [ -d "$jdk_dir" ]; then
            remaining_items+=("安装目录: $jdk_dir")
        fi
    else
        # 检查是否所有版本已删除
        if [ -d "$JAVA_BASE_DIR" ]; then
            remaining_items+=("JDK 基础目录: $JAVA_BASE_DIR")
        fi
    fi

    # 检查符号链接
    if [ -L "$JAVA_CURRENT_LINK" ]; then
        remaining_items+=("符号链接: $JAVA_CURRENT_LINK")
    fi

    if [ ${#remaining_items[@]} -gt 0 ]; then
        log_warn "以下项目仍存在:"
        for item in "${remaining_items[@]}"; do
            echo "  - $item"
        done
    else
        log_success "JDK 已成功卸载"
    fi
}

# ============================================
# 显示卸载完成信息
# ============================================

show_completion_info() {
    echo ""
    echo "============================================"
    echo "    JDK 卸载完成"
    echo "============================================"
    echo ""

    if [ -n "$JDK_VERSION" ]; then
        echo "已卸载: JDK ${JDK_VERSION}"
    else
        echo "已卸载: 所有 JDK 版本"
    fi
    echo ""

    echo "备份文件位置："
    echo "  - ~/.bashrc.bak.* 或 ~/.bash_profile.bak.* (环境变量配置)"
    echo ""

    echo "环境变量清理："
    echo "  - 已从配置文件中移除 JAVA_HOME 和 PATH 配置"
    echo "  - 请执行以下命令使配置生效："
    echo "    source ~/.bashrc"
    echo "    或重新登录系统"
    echo ""

    echo "重新安装："
    echo "  如需重新安装 JDK，运行："
    echo "  bash scripts/install_jdk.sh"
    echo ""

    echo "============================================"
    echo ""
}

# ============================================
# 解析命令行参数
# ============================================

parse_arguments() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --version|-v)
                JDK_VERSION="$2"
                shift 2
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
# 主卸载流程
# ============================================

main() {
    # 初始化日志
    mkdir -p "$(dirname "$LOG_FILE")"
    touch "$LOG_FILE"

    # 解析命令行参数
    parse_arguments "$@"

    # 加载配置
    load_config

    # 如果没有指定版本，交互式选择
    if [ -z "$JDK_VERSION" ]; then
        select_jdk_version
    fi

    # 显示卸载信息
    show_uninstall_info

    # 确认卸载
    confirm_uninstall

    log_info "开始卸载 JDK..."

    # 检查是否在使用
    check_jdk_in_use

    # 删除符号链接
    remove_symlinks

    # 删除安装目录
    remove_jdk_directories

    # 清理环境变量配置
    remove_environment_config

    # 验证卸载
    verify_uninstall

    # 显示完成信息
    show_completion_info

    log_success "JDK 卸载完成！"
}

# ============================================
# 脚本入口
# ============================================

main "$@"
