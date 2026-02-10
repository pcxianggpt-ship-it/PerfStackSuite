#!/bin/bash
#
# 配置加载测试脚本
# 用于验证配置文件加载是否正常
#

set -e

# 获取脚本目录
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# 加载公共函数库
source "${SCRIPT_DIR}/common.sh"

echo "============================================"
echo "    配置加载测试"
echo "============================================"
echo ""

# 初始化日志
mkdir -p "$(dirname "$LOG_FILE")"
touch "$LOG_FILE"

# 加载配置
log_info "测试配置文件加载..."
load_config

echo ""
echo "============================================"
echo "    配置值验证"
echo "============================================"
echo ""

# 显示关键配置值
echo "基础配置："
echo "  INSTALL_BASE_DIR = ${INSTALL_BASE_DIR:-未设置}"
echo "  DATA_BASE_DIR = ${DATA_BASE_DIR:-未设置}"
echo "  SOFT_DIR = ${SOFT_DIR:-未设置}"
echo ""

echo "Prometheus 配置："
echo "  PROMETHEUS_VERSION = ${PROMETHEUS_VERSION:-未设置}"
echo "  PROMETHEUS_PORT = ${PROMETHEUS_PORT:-未设置}"
echo "  PROMETHEUS_RETENTION_TIME = ${PROMETHEUS_RETENTION_TIME:-未设置}"
echo "  PROMETHEUS_INSTALL_DIR = ${INSTALL_BASE_DIR}/prometheus"
echo "  PROMETHEUS_DATA_DIR = ${DATA_BASE_DIR}/prometheus"
echo ""

echo "Grafana 配置："
echo "  GRAFANA_VERSION = ${GRAFANA_VERSION:-未设置}"
echo "  GRAFANA_PORT = ${GRAFANA_PORT:-未设置}"
echo "  GRAFANA_ADMIN_USER = ${GRAFANA_ADMIN_USER:-未设置}"
echo ""

echo "InfluxDB 配置："
echo "  INFLUXDB_VERSION = ${INFLUXDB_VERSION:-未设置}"
echo "  INFLUXDB_PORT = ${INFLUXDB_PORT:-未设置}"
echo ""

echo "JMeter 配置："
echo "  JDK_VERSION = ${JDK_VERSION:-未设置}"
echo "  JMETER_VERSION = ${JMETER_VERSION:-未设置}"
echo ""

echo "============================================"
echo "    测试完成"
echo "============================================"
echo ""
