#!/bin/bash
#
# JDK 安装脚本
# 功能：自动部署 JDK（支持 JDK 8/11/17/21 等多个版本）
# 版本：1.0.0
# 适用场景：JMeter 等需要 Java 环境的工具
#

set -e  # 遇到错误时退出

# 获取脚本目录
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# 加载公共函数库
source "${SCRIPT_DIR}/common.sh"

# ============================================
# 常量定义
# ============================================

# JDK 版本配置
JDK_VERSION="${JDK_VERSION:-8u481}"

# 统一目录架构：root 和普通用户都使用 $HOME/java 结构
JAVA_BASE_DIR="$HOME/java"
JAVA_INSTALL_DIR="$JAVA_BASE_DIR/jdk-${JDK_VERSION}"

# 检测是否为 root 用户
if [ "$(id -u)" -eq 0 ]; then
    IS_ROOT_INSTALL=true
    log_info "检测到 root 用户，安装目录：/root/java"
else
    IS_ROOT_INSTALL=false
    log_info "检测到普通用户，安装目录：$HOME/java"
fi

# ============================================
# 显示使用说明
# ============================================

show_usage() {
    cat << EOF
用法: $0 [选项]

选项：
  --version, -v       指定 JDK 版本（默认：8u481）
                      支持版本：8u481, 11.0.20, 17.0.8, 21.0.1
  --help, -h          显示此帮助信息

示例：
  $0                          # 安装默认版本 JDK 8u481
  $0 --version 11.0.20        # 安装 JDK 11.0.20
  $0 -v 17.0.8                # 安装 JDK 17.0.8

配置文件：config/deploy.conf
  可以在配置文件中设置 JDK_VERSION 变量

支持的 JDK 版本：
  - JDK 8 (8u481)   - LTS 版本，广泛使用
  - JDK 11 (11.0.20) - LTS 版本
  - JDK 17 (17.0.8)  - LTS 版本
  - JDK 21 (21.0.1)  - 最新 LTS 版本

安装包位置：
  请将 JDK 安装包（tar.gz）放在 $SOFT_DIR 目录
  支持 OpenJDK 或 Oracle JDK
EOF
}

# ============================================
# 检查是否已安装
# ============================================

check_jdk_installed() {
    if [ -d "$JAVA_INSTALL_DIR" ] && [ -f "$JAVA_INSTALL_DIR/bin/java" ]; then
        log_warn "JDK ${JDK_VERSION} 似乎已经安装"
        read -p "是否重新安装？(y/N): " reinstall
        if [ "$reinstall" != "y" ] && [ "$reinstall" != "Y" ]; then
            log_info "取消安装"
            exit 0
        fi
        log_warn "将重新安装 JDK ${JDK_VERSION}"
    fi
}

# ============================================
# 查找 JDK 安装包
# ============================================

find_jdk_package() {
    log_info "查找 JDK ${JDK_VERSION} 安装包..."

    # 可能的包名模式
    local patterns=(
        "jdk-${JDK_VERSION}-linux-x64.tar.gz"
        "jdk-${JDK_VERSION}_linux-x64_bin.tar.gz"
        "openjdk-${JDK_VERSION}-linux-x64.tar.gz"
        "*jdk*${JDK_VERSION}*.tar.gz"
    )

    # 查找安装包
    local tarball=""
    for pattern in "${patterns[@]}"; do
        tarball=$(find "$SOFT_DIR" -name "$pattern" 2>/dev/null | head -1)
        if [ -n "$tarball" ]; then
            break
        fi
    done

    if [ -z "$tarball" ]; then
        log_error "未找到 JDK ${JDK_VERSION} 安装包"
        log_error ""
        log_error "请将 JDK 安装包放在 $SOFT_DIR 目录"
        log_error ""
        log_error "支持的包名格式："
        log_error "  - jdk-${JDK_VERSION}-linux-x64.tar.gz"
        log_error "  - jdk-${JDK_VERSION}_linux-x64_bin.tar.gz"
        log_error "  - openjdk-${JDK_VERSION}-linux-x64.tar.gz"
        log_error ""
        log_error "下载地址："
        log_error "  - Oracle JDK: https://www.oracle.com/java/technologies/downloads/"
        log_error "  - OpenJDK: https://adoptium.net/"
        exit 1
    fi

    log_info "找到安装包: $(basename "$tarball")"
    echo "$tarball"
}

# ============================================
# 创建目录结构
# ============================================

create_directories() {
    log_info "创建 JDK 目录结构..."

    create_dir "$JAVA_BASE_DIR" 755

    log_success "目录结构创建完成"
}

# ============================================
# 解压 JDK 安装包
# ============================================

extract_jdk() {
    log_info "解压 JDK 安装包..."

    local tarball=$(find_jdk_package)

    # 解压到临时目录
    local temp_dir="/tmp/jdk_install"
    create_dir "$temp_dir" 755

    log_info "正在解压 JDK..."
    extract_tar "$tarball" "$temp_dir"

    # 查找解压后的 JDK 目录（排除临时目录本身）
    log_info "查找解压后的 JDK 目录..."

    # 列出临时目录下的所有子目录，找到包含 bin/java 的那个
    local extracted_dir=""
    for dir in "$temp_dir"/*/; do
        # 检查是否包含 bin/java 可执行文件
        if [ -f "${dir}bin/java" ] || [ -f "${dir}jre/bin/java" ]; then
            extracted_dir="${dir%/}"  # 去掉末尾的 /
            break
        fi
    done

    if [ -z "$extracted_dir" ]; then
        log_error "解压后未找到有效的 JDK 目录"
        log_info "实际解压内容："
        ls -la "$temp_dir"
        exit 1
    fi

    log_info "找到解压目录: $(basename "$extracted_dir")"

    # 删除旧的安装目录（如果存在）
    if [ -d "$JAVA_INSTALL_DIR" ]; then
        log_warn "删除已存在的安装目录: $JAVA_INSTALL_DIR"
        rm -rf "$JAVA_INSTALL_DIR"
    fi

    # 创建安装目录
    mkdir -p "$JAVA_INSTALL_DIR"

    # 移动文件到安装目录（移动解压目录的内容，而不是目录本身）
    log_info "移动文件到安装目录..."
    mv "$extracted_dir"/* "$JAVA_INSTALL_DIR/"

    # 如果有隐藏文件（如 .java），也移动过去
    mv "$extracted_dir"/.[!.]* "$JAVA_INSTALL_DIR/" 2>/dev/null || true

    # 设置执行权限
    log_info "设置 JDK 执行权限..."
    find "$JAVA_INSTALL_DIR/bin" -type f -exec chmod +x {} \; 2>/dev/null || true
    if [ -d "$JAVA_INSTALL_DIR/jre/bin" ]; then
        find "$JAVA_INSTALL_DIR/jre/bin" -type f -exec chmod +x {} \; 2>/dev/null || true
    fi

    # 清理临时目录
    rm -rf "$temp_dir"

    log_success "JDK 安装包解压完成"
}

# ============================================
# 配置环境变量
# ============================================

configure_environment() {
    log_info "配置环境变量..."

    local config_file=""
    if [ -f "$HOME/.bashrc" ]; then
        config_file="$HOME/.bashrc"
    elif [ -f "$HOME/.bash_profile" ]; then
        config_file="$HOME/.bash_profile"
    else
        config_file="$HOME/.bashrc"
    fi

    # 检查是否已经配置过
    if grep -q "JDK ${JDK_VERSION}" "$config_file" 2>/dev/null; then
        log_info "环境变量已配置，重新加载..."

        # 自动使配置文件生效
        source "$config_file" 2>/dev/null || true

        # 设置当前会话环境变量
        export JAVA_HOME="$JAVA_INSTALL_DIR"
        export PATH="$JAVA_HOME/bin:$PATH"

        log_success "环境变量已重新加载"
        log_info "JAVA_HOME=$JAVA_HOME"
        return 0
    fi

    # 备份配置文件
    backup_file "$config_file"

    # 移除旧的 JDK 配置（如果存在）
    sed -i '/# JDK Environment/,/export JAVA_HOME=/d' "$config_file" 2>/dev/null || true

    # 添加环境变量配置
    cat >> "$config_file" <<EOF

# ============================================
# JDK ${JDK_VERSION} 环境变量
# ============================================
export JAVA_HOME=$JAVA_INSTALL_DIR
export PATH=\$JAVA_HOME/bin:\$PATH
EOF

    log_success "环境变量配置完成"

    # 自动使配置文件生效
    log_info "正在加载环境变量..."
    source "$config_file" 2>/dev/null || true

    # 再次设置环境变量以确保当前会话生效
    export JAVA_HOME="$JAVA_INSTALL_DIR"
    export PATH="$JAVA_HOME/bin:$PATH"

    log_success "环境变量已生效"
    log_info "JAVA_HOME=$JAVA_HOME"

    return 0
}

# ============================================
# 验证安装
# ============================================

verify_installation() {
    log_info "验证 JDK 安装..."

    # 检查目录
    if [ ! -d "$JAVA_INSTALL_DIR" ]; then
        log_error "JDK 安装目录不存在: $JAVA_INSTALL_DIR"
        exit 1
    fi

    # 检查 java 命令
    if [ ! -f "$JAVA_INSTALL_DIR/bin/java" ]; then
        log_error "java 命令不存在"
        exit 1
    fi

    # 使用完整路径测试 java 命令
    local java_version=$("$JAVA_INSTALL_DIR/bin/java" -version 2>&1 | head -1)
    if [ $? -eq 0 ]; then
        log_success "Java 命令测试成功"
        log_info "版本信息: $java_version"
    else
        log_error "Java 命令测试失败"
        exit 1
    fi

    log_success "JDK 安装验证成功"
}

# ============================================
# 显示安装信息
# ============================================

show_install_info() {
    local java_version=$("$JAVA_INSTALL_DIR/bin/java" -version 2>&1 | head -1)

    echo ""
    echo "============================================"
    echo "    JDK 安装完成"
    echo "============================================"
    echo ""
    echo "安装信息："
    echo "  JDK 版本: ${JDK_VERSION}"
    echo "  版本信息: $java_version"
    echo "  安装目录: $JAVA_INSTALL_DIR"

    if [ "$IS_ROOT_INSTALL" = true ]; then
        echo "  安装模式: 系统级安装 (root)"
    else
        echo "  安装模式: 用户级安装 ($USER)"
    fi
    echo ""

    echo "环境变量："
    echo "  JAVA_HOME=$JAVA_INSTALL_DIR"
    echo "  PATH=\$JAVA_HOME/bin:\$PATH"
    echo ""

    echo "环境变量状态："
    echo "  ✓ 当前会话已生效"
    echo "  ℹ 新开终端窗口需执行: source ~/.bashrc"
    echo ""

    echo "验证安装："
    echo "  java -version"
    echo "  javac -version"
    echo ""

    echo "安装位置："
    echo "  - JDK 主目录: $JAVA_INSTALL_DIR"
    echo "  - Java 命令: $JAVA_INSTALL_DIR/bin/java"
    echo "  - Javac 命令: $JAVA_INSTALL_DIR/bin/javac"
    echo ""

    echo "多版本管理："
    echo "  - 安装其他版本: bash $0 --version <version>"
    echo "  - 切换版本: 修改 ~/.bashrc 中的 JAVA_HOME 和 PATH"
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
                # 更新安装目录变量
                JAVA_INSTALL_DIR="$JAVA_BASE_DIR/jdk-${JDK_VERSION}"
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
# 主安装流程
# ============================================

main() {
    # 初始化日志
    mkdir -p "$(dirname "$LOG_FILE")"
    touch "$LOG_FILE"

    # 解析命令行参数
    parse_arguments "$@"

    log_info "============================================"
    log_info "开始安装 JDK ${JDK_VERSION}..."
    log_info "============================================"

    # 加载配置文件
    load_config

    # 检查是否已安装
    check_jdk_installed

    # 创建目录结构
    create_directories

    # 解压 JDK
    extract_jdk

    # 配置环境变量
    configure_environment

    # 验证安装
    verify_installation

    # 显示安装信息
    show_install_info

    log_success "JDK ${JDK_VERSION} 安装完成！"
}

# ============================================
# 脚本入口
# ============================================

main "$@"
