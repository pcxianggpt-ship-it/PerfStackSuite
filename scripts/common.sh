#!/bin/bash
#
# PerfStackSuite - 公共函数库
# 提供所有安装脚本共享的公共函数和常量定义
#

set -e  # 遇到错误时退出

# ============================================
# 常量定义
# ============================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
SOFT_DIR="${PROJECT_DIR}/soft"
CONFIG_DIR="${PROJECT_DIR}/config"
LOG_FILE="/var/log/perfstacksuite/install.log"

# 颜色输出常量
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# ============================================
# 日志函数
# ============================================

# 输出信息级别日志（绿色）
log_info() {
    local msg="$1"
    echo -e "${GREEN}[INFO]${NC} $msg"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [INFO] $msg" >> "$LOG_FILE"
}

# 输出警告级别日志（黄色）
log_warn() {
    local msg="$1"
    echo -e "${YELLOW}[WARN]${NC} $msg"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [WARN] $msg" >> "$LOG_FILE"
}

# 输出错误级别日志（红色）
log_error() {
    local msg="$1"
    echo -e "${RED}[ERROR]${NC} $msg"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [ERROR] $msg" >> "$LOG_FILE"
}

# 输出成功信息（绿色）
log_success() {
    local msg="$1"
    echo -e "${GREEN}[SUCCESS]${NC} $msg"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [SUCCESS] $msg" >> "$LOG_FILE"
}

# ============================================
# 系统检测函数
# ============================================

# 检测操作系统类型
get_os_type() {
    if [ -f /etc/kylin-release ]; then
        echo "kylin"
    elif [ -f /etc/.kyinfo ]; then
        echo "kylin"
    elif [ -f /etc/redhat-release ]; then
        echo "centos"
    elif [ -f /etc/debian_version ]; then
        if [ -f /etc/ubuntu_version ]; then
            echo "ubuntu"
        else
            echo "debian"
        fi
    else
        echo "other"
    fi
}

# 检测系统架构
get_arch() {
    echo "$(uname -m)"
}

# 检查是否为 root 用户
is_root() {
    [ "$(id -u)" -eq 0 ]
}

# 检查命令是否存在
check_command() {
    local cmd="$1"
    command -v "$cmd" >/dev/null 2>&1
}

# ============================================
# 文件操作函数
# ============================================

# 备份文件
backup_file() {
    local file="$1"
    if [ -f "$file" ]; then
        local backup="${file}.bak.$(date +%Y%m%d%H%M%S)"
        cp "$file" "$backup"
        log_info "已备份文件: $file -> $backup"
    fi
}

# 创建目录并设置权限
create_dir() {
    local dir="$1"
    local perms="${2:-755}"
    if [ ! -d "$dir" ]; then
        mkdir -p "$dir"
        chmod "$perms" "$dir"
        log_info "已创建目录: $dir"
    fi
}

# 解压 tar.gz/tgz 文件
extract_tar() {
    local tarfile="$1"
    local dest_dir="${2:-.}"

    if [ ! -f "$tarfile" ]; then
        log_error "文件不存在: $tarfile"
        return 1
    fi

    log_info "正在解压: $tarfile"
    tar -xzf "$tarfile" -C "$dest_dir"
    if [ $? -eq 0 ]; then
        log_success "解压成功: $tarfile"
        return 0
    else
        log_error "解压失败: $tarfile"
        return 1
    fi
}

# ============================================
# 基础工具函数
# ============================================

# 获取本机 IP 地址
get_local_ip() {
    hostname -I | awk '{print $1}'
}

# 检查端口是否被占用
check_port() {
    local port="$1"
    if netstat -tuln 2>/dev/null | grep -q ":${port}"; then
        return 0  # 端口被占用
    else
        return 1  # 端口可用
    fi
}

# 等待端口监听
wait_for_port() {
    local port="$1"
    local timeout="${2:-30}"
    local count=0

    while [ $count -lt $timeout ]; do
        if check_port "$port"; then
            return 0
        fi
        sleep 1
        count=$((count + 1))
    done

    return 1
}

# ============================================
# 环境检查函数
# ============================================

# 环境预检查
check_environment() {
    log_info "开始环境检查..."

    # 检查是否为 root 用户
    if ! is_root; then
        log_error "请使用 root 用户执行此脚本"
        exit 1
    fi

    # 检查操作系统类型
    local os_type=$(get_os_type)
    log_info "检测到操作系统: $os_type"

    if [ "$os_type" = "other" ]; then
        log_warn "未识别的操作系统类型，可能会出现兼容性问题"
    fi

    # 检查系统架构
    local arch=$(get_arch)
    log_info "检测到系统架构: $arch"

    # 检查必要命令
    local required_commands=("tar" "systemctl" "netstat")
    for cmd in "${required_commands[@]}"; do
        if ! check_command "$cmd"; then
            log_error "缺少必要命令: $cmd"
            exit 1
        fi
    done

    log_success "环境检查完成"
}

# ============================================
# 配置文件处理函数
# ============================================

# 加载配置文件
load_config() {
    local config_file="${1:-$CONFIG_DIR/deploy.conf}"

    if [ ! -f "$config_file" ]; then
        log_warn "配置文件不存在: $config_file，使用默认值"
        return 1
    fi

    # 加载配置文件
    source "$config_file"
    log_info "已加载配置文件: $config_file"

    # 验证关键配置项
    if [ -z "$INSTALL_BASE_DIR" ]; then
        log_warn "INSTALL_BASE_DIR 未配置，使用默认值: /opt"
        export INSTALL_BASE_DIR=/opt
    fi

    if [ -z "$DATA_BASE_DIR" ]; then
        log_warn "DATA_BASE_DIR 未配置，使用默认值: /data"
        export DATA_BASE_DIR=/data
    fi

    return 0
}

# ============================================
# 占位函数（后续实现）
# ============================================

install_prometheus() {
    local script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    local prometheus_script="${script_dir}/install_prometheus.sh"

    if [ ! -f "$prometheus_script" ]; then
        log_error "Prometheus 安装脚本不存在: $prometheus_script"
        return 1
    fi

    log_info "开始安装 Prometheus..."
    bash "$prometheus_script"
    return $?
}

install_grafana() {
    log_info "Grafana 安装功能开发中..."
    return 1
}

install_influxdb() {
    log_info "InfluxDB 安装功能开发中..."
    return 1
}

install_node_exporter() {
    log_info "Node Exporter 安装功能开发中..."
    return 1
}

install_jdk() {
    log_info "JDK 安装功能开发中..."
    return 1
}

install_jmeter() {
    log_info "JMeter 安装功能开发中..."
    return 1
}

install_sysctl() {
    log_info "系统内核参数优化功能开发中..."
    return 1
}

config_ssh() {
    log_info "SSH 配置功能开发中..."
    return 1
}

install_chinese_fonts() {
    log_info "中文字体安装功能开发中..."
    return 1
}

# ============================================
# 卸载函数（后续实现）
# ============================================

uninstall_grafana() {
    log_info "Grafana 卸载功能开发中..."
    return 1
}

uninstall_influxdb() {
    log_info "InfluxDB 卸载功能开发中..."
    return 1
}

uninstall_node_exporter() {
    log_info "Node Exporter 卸载功能开发中..."
    return 1
}

uninstall_jdk() {
    log_info "JDK 卸载功能开发中..."
    return 1
}

uninstall_jmeter() {
    log_info "JMeter 卸载功能开发中..."
    return 1
}
