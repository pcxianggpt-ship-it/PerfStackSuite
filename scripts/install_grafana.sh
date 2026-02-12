#!/bin/bash
#
# Grafana 安装脚本
# 功能：自动部署 Grafana 可视化监控平台
#

set -e  # 遇到错误时退出

# 获取脚本目录
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# 加载公共函数库
source "${SCRIPT_DIR}/common.sh"

# ============================================
# 常量定义
# ============================================

GRAFANA_VERSION="${GRAFANA_VERSION:-12.3.2}"
GRAFANA_PORT="${GRAFANA_PORT:-3000}"

# 检测是否为 root 用户，设置不同的安装路径
if [ "$(id -u)" -eq 0 ]; then
    # root 用户安装到系统目录
    GRAFANA_INSTALL_DIR="${INSTALL_BASE_DIR}/grafana"
    GRAFANA_DATA_DIR="${DATA_BASE_DIR}/grafana"
    GRAFANA_LOG_DIR="/var/log/grafana"
    IS_ROOT_INSTALL=true
else
    # 普通用户安装到用户目录
    GRAFANA_INSTALL_DIR="$HOME/grafana"
    GRAFANA_DATA_DIR="$HOME/grafana/data"
    GRAFANA_LOG_DIR="$HOME/grafana/logs"
    IS_ROOT_INSTALL=false
fi

GRAFANA_PLUGINS_DIR="${GRAFANA_INSTALL_DIR}/plugins"
GRAFANA_PROVISIONING_DIR="${GRAFANA_INSTALL_DIR}/provisioning"

# Grafana 默认凭据
GRAFANA_ADMIN_USER="${GRAFANA_ADMIN_USER:-admin}"
GRAFANA_ADMIN_PASSWORD="${GRAFANA_ADMIN_PASSWORD:-admin123}"

# ============================================
# 检查是否已安装
# ============================================

check_grafana_installed() {
    if [ -d "$GRAFANA_INSTALL_DIR" ] && [ -f "$GRAFANA_INSTALL_DIR/bin/grafana" ]; then
        log_warn "Grafana 似乎已经安装"
        read -p "是否重新安装？(y/N): " reinstall
        if [ "$reinstall" != "y" ] && [ "$reinstall" != "Y" ]; then
            log_info "取消安装"
            exit 0
        fi
        log_warn "将重新安装 Grafana"
    fi
}

# ============================================
# 创建目录结构
# ============================================

create_directories() {
    log_info "创建 Grafana 目录结构..."

    create_dir "$GRAFANA_INSTALL_DIR" 755
    create_dir "$GRAFANA_DATA_DIR" 755
    create_dir "$GRAFANA_LOG_DIR" 755
    create_dir "$GRAFANA_PLUGINS_DIR" 755
    create_dir "${GRAFANA_PROVISIONING_DIR}/datasources" 755
    create_dir "${GRAFANA_PROVISIONING_DIR}/dashboards" 755
    create_dir "${GRAFANA_PROVISIONING_DIR}/notifiers" 755

    log_success "目录结构创建完成"
}

# ============================================
# 查找并解压安装包
# ============================================

extract_grafana() {
    log_info "查找 Grafana 安装包..."

    # 查找安装包（支持 enterprise 和 oss 版本）
    local tarball=$(find "$SOFT_DIR" -name "grafana-*_linux_amd64.tar.gz" 2>/dev/null | head -1)

    if [ -z "$tarball" ]; then
        log_error "未找到 Grafana 安装包"
        log_error "请将 grafana-${GRAFANA_VERSION}_linux_amd64.tar.gz 放在 $SOFT_DIR 目录"
        exit 1
    fi

    log_info "找到安装包: $tarball"

    # 解压到临时目录
    local temp_dir="/tmp/grafana_install"
    create_dir "$temp_dir" 755

    log_info "正在解压 Grafana..."
    extract_tar "$tarball" "$temp_dir"

    # 移动到安装目录
    local extracted_dir=$(find "$temp_dir" -name "grafana-*" -type d | head -1)
    if [ -z "$extracted_dir" ]; then
        log_error "解压后未找到 Grafana 目录"
        exit 1
    fi

    log_info "移动文件到安装目录..."
    cp -rf "$extracted_dir"/* "$GRAFANA_INSTALL_DIR/"
    chmod +x "$GRAFANA_INSTALL_DIR/bin/grafana"

    # 清理临时目录
    rm -rf "$temp_dir"

    log_success "Grafana 安装包解压完成"
}

# ============================================
# 生成配置文件
# ============================================

generate_config() {
    log_info "生成 Grafana 配置文件..."

    local config_file="$GRAFANA_INSTALL_DIR/conf/grafana.ini"

    # 创建 conf 目录
    mkdir -p "$GRAFANA_INSTALL_DIR/conf"

    # 备份原有配置（如果存在）
    backup_file "$config_file"

    cat > "$config_file" <<EOF
# Grafana 配置文件
# 自动生成时间: $(date)

# ======================
# Server 配置
# ======================
[server]
# 协议 (http, https, socket)
protocol = http

# HTTP 端口
http_port = ${GRAFANA_PORT}

# 监听地址
http_addr = 0.0.0.0

# 域名
domain = $(get_local_ip)

# 根 URL
root_url = http://$(get_local_ip):${GRAFANA_PORT}

# ======================
# 数据库配置
# ======================
[database]
# 数据库类型 (sqlite3, mysql, postgres)
type = sqlite3

# SQLite 数据文件路径
path = ${GRAFANA_DATA_DIR}/grafana.db

# ======================
# 安全配置
# ======================
[security]
# 初始管理员用户名
admin_user = ${GRAFANA_ADMIN_USER}

# 初始管理员密码
admin_password = ${GRAFANA_ADMIN_PASSWORD}

# 禁用用户注册
disable_gravatar = true

# Cookie 用户名
cookie_username = grafana_user

# Cookie 密钥（自动生成）
cookie_secret = $(openssl rand -hex 16 2>/dev/null || echo "grafana_secret_key_change_me")

# ======================
# 日志配置
# ======================
[log]
# 日志模式 (console, file)
mode = file

# 日志级别 (trace, debug, info, warn, error, critical)
level = info

# 日志文件路径
logs_dir = ${GRAFANA_LOG_DIR}

# ======================
# 数据目录配置
# ======================
[paths]
# 数据目录
data = ${GRAFANA_DATA_DIR}

# 临时目录
temp_data_lifetime = 24h

# 插件目录
plugins = ${GRAFANA_PLUGINS_DIR}

# Provisioning 配置目录
provisioning = ${GRAFANA_PROVISIONING_DIR}

# ======================
# 分析和遥测（禁用）
# ======================
[analytics]
reporting_enabled = false
check_for_updates = false

[analytics]
check_for_plugin_updates = false

# ======================
# 用户界面配置
# ======================
[users]
# 默认主题 (dark, light)
default_theme = dark

# 首页仪表板 UID
home_dashboard_uid = perfstack_home

# ======================
# Dashboard 配置
# ======================
[dashboards]
# 默认首页仪表板
default_home_dashboard_path = ${GRAFANA_PROVISIONING_DIR}/dashboards/home.json
EOF

    log_success "配置文件生成完成: $config_file"
}

# ============================================
# 生成 Provisioning 数据源配置
# ============================================

generate_datasource_provisioning() {
    log_info "生成数据源 Provisioning 配置..."

    local datasource_file="${GRAFANA_PROVISIONING_DIR}/datasources/prometheus.yml"

    cat > "$datasource_file" <<EOF
# Grafana 数据源自动配置
# 自动生成时间: $(date)

apiVersion: 1

datasources:
  - name: Prometheus
    type: prometheus
    access: proxy
    url: http://localhost:9090
    isDefault: true
    editable: true
    jsonData:
      timeInterval: "15s"
      queryTimeout: "60s"
      httpMethod: "POST"
EOF

    log_success "Prometheus 数据源配置完成: $datasource_file"
}

# ============================================
# 创建默认仪表板配置
# ============================================

create_default_dashboard() {
    log_info "创建默认首页仪表板..."

    local dashboard_file="${GRAFANA_PROVISIONING_DIR}/dashboards/home.json"

    cat > "$dashboard_file" <<EOF
{
  "annotations": {
    "list": [
      {
        "builtIn": 1,
        "datasource": "-- Grafana --",
        "enable": true,
        "hide": true,
        "iconColor": "rgba(0, 211, 255, 1)",
        "name": "Annotations & Alerts",
        "type": "dashboard"
      }
    ]
  },
  "editable": true,
  "gnetId": null,
  "graphTooltip": 0,
  "id": null,
  "links": [],
  "panels": [
    {
      "datasource": "Prometheus",
      "fieldConfig": {
        "defaults": {
          "color": {
            "mode": "palette-classic"
          },
          "custom": {
            "axisLabel": "",
            "axisPlacement": "auto",
            "barAlignment": 0,
            "drawStyle": "line",
            "fillOpacity": 10,
            "gradientMode": "none",
            "hideFrom": {
              "tooltip": false,
              "viz": false,
              "legend": false
            },
            "lineInterpolation": "linear",
            "lineWidth": 1,
            "pointSize": 5,
            "scaleDistribution": {
              "type": "linear"
            },
            "showPoints": "never",
            "spanNulls": false
          },
          "mappings": [],
          "thresholds": {
            "mode": "absolute",
            "steps": [
              {
                "color": "green",
                "value": null
              }
            ]
          },
          "unit": "short"
        },
        "overrides": []
      },
      "gridPos": {
        "h": 8,
        "w": 12,
        "x": 0,
        "y": 0
      },
      "id": 2,
      "options": {
        "legend": {
          "calcs": [],
          "displayMode": "list",
          "placement": "bottom"
        },
        "tooltip": {
          "mode": "single"
        }
      },
      "pluginVersion": "12.3.2",
      "targets": [
        {
          "expr": "up",
          "refId": "A"
        }
      ],
      "title": "Prometheus 目标状态",
      "type": "timeseries"
    },
    {
      "datasource": "Prometheus",
      "fieldConfig": {
        "defaults": {
          "color": {
            "mode": "thresholds"
          },
          "mappings": [],
          "thresholds": {
            "mode": "absolute",
            "steps": [
              {
                "color": "red",
                "value": null
              },
              {
                "color": "green",
                "value": 1
              }
            ]
          },
          "unit": "short"
        },
        "overrides": []
      },
      "gridPos": {
        "h": 8,
        "w": 6,
        "x": 12,
        "y": 0
      },
      "id": 4,
      "options": {
        "colorMode": "background",
        "graphMode": "area",
        "justifyMode": "auto",
        "orientation": "auto",
        "reduceOptions": {
          "values": false,
          "calcs": ["lastNotNull"],
          "fields": ""
        },
        "textMode": "auto"
      },
      "pluginVersion": "12.3.2",
      "targets": [
        {
          "expr": "up{job=\"prometheus\"}",
          "refId": "A"
        }
      ],
      "title": "Prometheus 服务状态",
      "type": "stat"
    }
  ],
  "schemaVersion": 27,
  "style": "dark",
  "tags": ["perfstack"],
  "templating": {
    "list": []
  },
  "time": {
    "from": "now-1h",
    "to": "now"
  },
  "timepicker": {},
  "timezone": "",
  "title": "PerfStack Suite 监控首页",
  "uid": "perfstack_home",
  "version": 1
}
EOF

    log_success "默认仪表板创建完成: $dashboard_file"
}

# ============================================
# 创建仪表板 provisioning 配置
# ============================================

create_dashboard_provisioning() {
    log_info "创建仪表板 Provisioning 配置..."

    local dashboard_config="${GRAFANA_PROVISIONING_DIR}/dashboards/dashboards.yml"

    cat > "$dashboard_config" <<EOF
# Grafana 仪表板自动配置
# 自动生成时间: $(date)

apiVersion: 1

providers:
  - name: 'PerfStack Dashboards'
    orgId: 1
    folder: ''
    type: file
    disableDeletion: false
    updateIntervalSeconds: 10
    allowUiUpdates: true
    options:
      path: ${GRAFANA_PROVISIONING_DIR}/dashboards
EOF

    log_success "仪表板 Provisioning 配置完成: $dashboard_config"
}

# ============================================
# 创建 systemd 服务文件或启动脚本
# ============================================

create_systemd_service() {
    if [ "$IS_ROOT_INSTALL" = true ]; then
        create_system_service
    else
        create_user_service_or_scripts
    fi
}

# 创建系统级 systemd 服务（需要 root）
create_system_service() {
    log_info "创建 Grafana systemd 系统服务..."

    local service_file="/etc/systemd/system/grafana.service"

    backup_file "$service_file"

    cat > "$service_file" <<EOF
[Unit]
Description=Grafana Visualization Platform
Documentation=https://grafana.com/docs/
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
User=root
Group=root

# 工作目录
WorkingDirectory=${GRAFANA_INSTALL_DIR}

# 启动命令
ExecStart=${GRAFANA_INSTALL_DIR}/bin/grafana server \\
    --config=${GRAFANA_INSTALL_DIR}/conf/grafana.ini \\
    --homepath=${GRAFANA_INSTALL_DIR}

# 重启策略
Restart=always
RestartSec=10

# 资源限制
LimitNOFILE=65536
LimitNPROC=8192

# 环境变量
Environment=GF_PATHS_HOME=${GRAFANA_INSTALL_DIR}
Environment=GF_PATHS_DATA=${GRAFANA_DATA_DIR}
Environment=GF_PATHS_LOGS=${GRAFANA_LOG_DIR}
Environment=GF_PATHS_PLUGINS=${GRAFANA_PLUGINS_DIR}
Environment=GF_PATHS_PROVISIONING=${GRAFANA_PROVISIONING_DIR}

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
    log_info "配置 Grafana 启动方式..."

    # 尝试创建用户级 systemd 服务
    if create_user_systemd_service; then
        log_success "使用用户级 systemd 服务"
        GRAFANA_SERVICE_TYPE="user-systemd"
    else
        # 回退到启动脚本
        log_info "创建启动脚本..."
        create_startup_scripts
        GRAFANA_SERVICE_TYPE="script"
    fi
}

# 创建用户级 systemd 服务
create_user_systemd_service() {
    local user_service_dir="$HOME/.config/systemd/user"
    local service_file="$user_service_dir/grafana.service"

    # 创建目录
    mkdir -p "$user_service_dir"

    # 检查 systemd 用户服务是否支持
    if ! systemctl --user list-units &>/dev/null; then
        return 1
    fi

    cat > "$service_file" <<EOF
[Unit]
Description=Grafana Visualization Platform
Documentation=https://grafana.com/docs/
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
WorkingDirectory=${GRAFANA_INSTALL_DIR}

# 启动命令
ExecStart=${GRAFANA_INSTALL_DIR}/bin/grafana server \\
    --config=${GRAFANA_INSTALL_DIR}/conf/grafana.ini \\
    --homepath=${GRAFANA_INSTALL_DIR}

# 重启策略
Restart=always
RestartSec=10

# 资源限制
LimitNOFILE=65536
LimitNPROC=8192

# 环境变量
Environment=GF_PATHS_HOME=${GRAFANA_INSTALL_DIR}
Environment=GF_PATHS_DATA=${GRAFANA_DATA_DIR}
Environment=GF_PATHS_LOGS=${GRAFANA_LOG_DIR}
Environment=GF_PATHS_PLUGINS=${GRAFANA_PLUGINS_DIR}
Environment=GF_PATHS_PROVISIONING=${GRAFANA_PROVISIONING_DIR}

[Install]
WantedBy=default.target
EOF

    # 重载用户 systemd
    systemctl --user daemon-reload 2>/dev/null || true

    log_success "用户级 systemd 服务创建完成"
    return 0
}

# 创建启动脚本（备选方案）
create_startup_scripts() {
    # 创建启动脚本
    cat > "$GRAFANA_INSTALL_DIR/start.sh" <<'SCRIPT_EOF'
#!/bin/bash
# Grafana 启动脚本

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export GRAFANA_HOME="$SCRIPT_DIR"
export GRAFANA_DATA_DIR="$SCRIPT_DIR/data"
export GRAFANA_LOGS_DIR="$SCRIPT_DIR/logs"

# 检查是否已运行
if [ -f "$GRAFANA_DATA_DIR/grafana.pid" ]; then
    PID=$(cat "$GRAFANA_DATA_DIR/grafana.pid")
    if ps -p "$PID" > /dev/null 2>&1; then
        echo "Grafana 已在运行 (PID: $PID)"
        exit 1
    fi
fi

# 启动 Grafana
echo "启动 Grafana..."
nohup "$GRAFANA_HOME/bin/grafana" server \
    --config="$GRAFANA_HOME/conf/grafana.ini" \
    --homepath="$GRAFANA_HOME" \
    > "$GRAFANA_LOGS_DIR/grafana.out" 2>&1 &

PID=$!
echo $PID > "$GRAFANA_DATA_DIR/grafana.pid"

echo "Grafana 已启动 (PID: $PID)"
echo "日志: $GRAFANA_LOGS_DIR/grafana.out"
SCRIPT_EOF

    # 创建停止脚本
    cat > "$GRAFANA_INSTALL_DIR/stop.sh" <<'SCRIPT_EOF'
#!/bin/bash
# Grafana 停止脚本

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PID_FILE="$SCRIPT_DIR/data/grafana.pid"

if [ ! -f "$PID_FILE" ]; then
    echo "Grafana 未运行"
    exit 0
fi

PID=$(cat "$PID_FILE")

if ps -p "$PID" > /dev/null 2>&1; then
    echo "停止 Grafana (PID: $PID)..."
    kill "$PID"
    sleep 2

    # 强制杀死如果还在运行
    if ps -p "$PID" > /dev/null 2>&1; then
        echo "强制停止 Grafana..."
        kill -9 "$PID"
    fi

    rm -f "$PID_FILE"
    echo "Grafana 已停止"
else
    echo "Grafana 进程不存在"
    rm -f "$PID_FILE"
fi
SCRIPT_EOF

    # 创建状态检查脚本
    cat > "$GRAFANA_INSTALL_DIR/status.sh" <<'SCRIPT_EOF'
#!/bin/bash
# Grafana 状态检查脚本

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PID_FILE="$SCRIPT_DIR/data/grafana.pid"

if [ ! -f "$PID_FILE" ]; then
    echo "Grafana 未运行"
    exit 1
fi

PID=$(cat "$PID_FILE")

if ps -p "$PID" > /dev/null 2>&1; then
    echo "Grafana 正在运行 (PID: $PID)"
    exit 0
else
    echo "Grafana 未运行 (PID 文件存在但进程不存在)"
    exit 1
fi
SCRIPT_EOF

    # 添加执行权限
    chmod +x "$GRAFANA_INSTALL_DIR/start.sh"
    chmod +x "$GRAFANA_INSTALL_DIR/stop.sh"
    chmod +x "$GRAFANA_INSTALL_DIR/status.sh"

    log_success "启动脚本创建完成"
}

# ============================================
# 配置防火墙（仅 root 安装）
# ============================================

configure_firewall() {
    # 普通用户无法配置防火墙
    if [ "$IS_ROOT_INSTALL" = false ]; then
        log_info "普通用户安装，跳过防火墙配置"
        log_warn "注意：需要手动配置防火墙开放端口 ${GRAFANA_PORT}"
        return 0
    fi

    log_info "配置防火墙规则..."

    local os_type=$(get_os_type)

    case "$os_type" in
        centos|kylin)
            if check_command "firewall-cmd"; then
                firewall-cmd --permanent --add-port=${GRAFANA_PORT}/tcp 2>/dev/null || true
                firewall-cmd --reload 2>/dev/null || true
                log_success "防火墙规则已配置（firewalld）"
            else
                log_warn "未找到 firewall-cmd，跳过防火墙配置"
            fi
            ;;
        ubuntu|debian)
            if check_command "ufw"; then
                ufw allow ${GRAFANA_PORT}/tcp 2>/dev/null || true
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
    log_info "启动 Grafana 系统服务..."

    # 启用服务
    systemctl enable grafana
    systemctl start grafana

    # 等待服务启动
    log_info "等待 Grafana 启动..."
    sleep 10

    # 检查服务状态
    if systemctl is-active --quiet grafana; then
        log_success "Grafana 服务启动成功"
    else
        log_error "Grafana 服务启动失败"
        systemctl status grafana
        exit 1
    fi

    # 检查端口监听
    if wait_for_port "$GRAFANA_PORT" 30; then
        log_success "Grafana 端口 ${GRAFANA_PORT} 监听正常"
    else
        log_error "Grafana 端口 ${GRAFANA_PORT} 未监听"
        exit 1
    fi
}

# 启动用户级服务（普通用户）
start_user_service() {
    log_info "启动 Grafana 服务..."

    if [ "$GRAFANA_SERVICE_TYPE" = "user-systemd" ]; then
        # 使用用户级 systemd
        systemctl --user enable grafana 2>/dev/null || true
        systemctl --user start grafana

        log_info "等待 Grafana 启动..."
        sleep 10

        if systemctl --user is-active --quiet grafana; then
            log_success "Grafana 服务启动成功"
        else
            log_error "Grafana 服务启动失败"
            journalctl --user -u grafana -n 50 || true
            exit 1
        fi
    else
        # 使用启动脚本
        "$GRAFANA_INSTALL_DIR/start.sh"
        sleep 5
    fi

    # 检查端口监听
    if wait_for_port "$GRAFANA_PORT" 30; then
        log_success "Grafana 端口 ${GRAFANA_PORT} 监听正常"
    else
        log_error "Grafana 端口 ${GRAFANA_PORT} 未监听"
        log_error "请检查日志: $GRAFANA_LOG_DIR/grafana.out"
        exit 1
    fi
}

# ============================================
# 验证安装
# ============================================

verify_installation() {
    log_info "验证 Grafana 安装..."

    # 检查进程
    if pgrep -f "grafana" > /dev/null; then
        log_success "Grafana 进程运行正常"
    else
        log_error "Grafana 进程未运行"
        exit 1
    fi

    # 访问 Web UI
    local grafana_url="http://localhost:${GRAFANA_PORT}"
    log_info "访问 Grafana Web UI: $grafana_url"

    if command -v curl >/dev/null 2>&1; then
        local http_code=$(curl -s -o /dev/null -w "%{http_code}" "$grafana_url" || echo "000")
        if [ "$http_code" = "200" ] || [ "$http_code" = "302" ]; then
            log_success "Grafana Web UI 可访问 (HTTP $http_code)"
        else
            log_warn "Grafana Web UI 返回状态码: $http_code"
        fi
    fi
}

# ============================================
# 配置数据源（API 方式）
# ============================================

configure_prometheus_datasource() {
    log_info "检查 Prometheus 数据源配置..."

    local grafana_url="http://localhost:${GRAFANA_PORT}"

    # 等待 Grafana 完全启动
    log_info "等待 Grafana 完全启动..."
    sleep 5

    # 检查 Prometheus 是否运行
    if ! pgrep -f "prometheus" > /dev/null; then
        log_warn "Prometheus 未运行，跳过数据源验证"
        return
    fi

    # 测试数据源连接（通过 provisioning 已经配置）
    if command -v curl >/dev/null 2>&1; then
        # 检查数据源是否存在（健康检查端点）
        local health_check=$(curl -s "${grafana_url}/api/health" 2>/dev/null || echo "{}")

        if echo "$health_check" | grep -q "database"; then
            log_success "Grafana API 可访问，数据源已通过 Provisioning 配置"
        else
            log_warn "无法验证数据源配置，请手动检查"
        fi
    fi
}

# ============================================
# 显示安装信息
# ============================================

show_install_info() {
    echo ""
    echo "============================================"
    echo "    Grafana 安装完成"
    echo "============================================"
    echo ""
    echo "安装信息："
    echo "  安装目录: $GRAFANA_INSTALL_DIR"
    echo "  数据目录: $GRAFANA_DATA_DIR"
    echo "  日志目录: $GRAFANA_LOG_DIR"
    echo "  插件目录: $GRAFANA_PLUGINS_DIR"
    echo "  服务端口: $GRAFANA_PORT"

    if [ "$IS_ROOT_INSTALL" = true ]; then
        echo "  安装模式: 系统级安装 (root)"
    else
        echo "  安装模式: 用户级安装 ($USER)"
    fi
    echo ""

    echo "访问地址："
    echo "  - Web UI: http://$(get_local_ip):${GRAFANA_PORT}"
    echo ""

    echo "默认凭据："
    echo "  - 用户名: $GRAFANA_ADMIN_USER"
    echo "  - 密码: $GRAFANA_ADMIN_PASSWORD"
    echo "  ⚠️  重要：请在首次登录后修改默认密码！"
    echo ""

    echo "已配置数据源："
    echo "  - Prometheus (http://localhost:9090)"
    echo ""

    echo "服务管理："
    if [ "$IS_ROOT_INSTALL" = true ]; then
        echo "  - 启动: systemctl start grafana"
        echo "  - 停止: systemctl stop grafana"
        echo "  - 重启: systemctl restart grafana"
        echo "  - 状态: systemctl status grafana"
        echo "  - 日志: journalctl -u grafana -f"
    else
        if [ "$GRAFANA_SERVICE_TYPE" = "user-systemd" ]; then
            echo "  - 启动: systemctl --user start grafana"
            echo "  - 停止: systemctl --user stop grafana"
            echo "  - 重启: systemctl --user restart grafana"
            echo "  - 状态: systemctl --user status grafana"
            echo "  - 日志: journalctl --user -u grafana -f"
        else
            echo "  - 启动: $GRAFANA_INSTALL_DIR/start.sh"
            echo "  - 停止: $GRAFANA_INSTALL_DIR/stop.sh"
            echo "  - 状态: $GRAFANA_INSTALL_DIR/status.sh"
            echo "  - 日志: tail -f $GRAFANA_LOG_DIR/grafana.out"
        fi
    fi
    echo ""

    echo "配置文件："
    echo "  - $GRAFANA_INSTALL_DIR/conf/grafana.ini"
    echo "  - Provisioning: $GRAFANA_PROVISIONING_DIR"
    echo ""

    if [ "$IS_ROOT_INSTALL" = false ]; then
        echo "提示："
        echo "  - 如需开机自启，在 ~/.bash_profile 中添加:"
        echo "    $GRAFANA_INSTALL_DIR/start.sh"
        echo "  - 如需配置防火墙，请联系管理员开放端口 ${GRAFANA_PORT}"
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

    log_info "开始安装 Grafana..."

    # 加载配置文件
    load_config

    # 检查是否已安装
    check_grafana_installed

    # 创建目录结构
    create_directories

    # 解压安装包
    extract_grafana

    # 生成配置文件
    generate_config

    # 生成数据源 provisioning 配置
    generate_datasource_provisioning

    # 创建默认仪表板
    create_default_dashboard

    # 创建仪表板 provisioning 配置
    create_dashboard_provisioning

    # 创建 systemd 服务
    create_systemd_service

    # 配置防火墙
    configure_firewall

    # 启动服务
    start_service

    # 验证安装
    verify_installation

    # 配置数据源
    configure_prometheus_datasource

    # 显示安装信息
    show_install_info

    log_success "Grafana 安装完成！"
}

# ============================================
# 脚本入口
# ============================================

main "$@"
