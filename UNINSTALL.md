# Prometheus 卸载功能使用说明

## 概述

提供了完整的 Prometheus 卸载脚本，支持：
- 停止并禁用 Prometheus 服务
- 删除 systemd 服务文件
- 删除防火墙规则
- 删除安装目录、数据目录、日志目录
- 可选保留监控数据
- 完整的卸载验证

## 使用方法

### 方法 1: 通过主安装脚本卸载（推荐）

```bash
# 进入交互式菜单
cd /opt/PerfStackSuite
sudo bash scripts/install.sh

# 选择 8 - 卸载组件
# 然后选择要卸载的组件编号（例如：1 表示 Prometheus）
```

### 方法 2: 直接运行卸载脚本

```bash
# 直接卸载 Prometheus
cd /opt/PerfStackSuite
sudo bash scripts/uninstall_prometheus.sh
```

### 方法 3: 命令行模式

```bash
# 进入卸载模式
sudo bash scripts/install.sh --uninstall
```

## 卸载流程

### 1. 显示卸载信息

脚本会显示将要删除的内容：

```
============================================
    Prometheus 卸载程序
============================================

将卸载以下内容：
  - 服务: prometheus
  - 安装目录: /opt/prometheus
  - 数据目录: /data/prometheus
  - 日志目录: /var/log/prometheus
  - systemd 服务: /etc/systemd/system/prometheus.service

⚠️  警告：此操作不可逆！
```

### 2. 确认卸载

需要输入 `yes` 确认卸载：

```bash
是否确认卸载 Prometheus？(yes/NO):
```

### 3. 选择是否保留数据

```bash
是否删除监控数据？:
- 输入 y 或 Y: 删除所有监控数据（推荐用于完全清理）
- 输入 n 或 N: 保留数据目录，只删除程序
```

### 4. 执行卸载

脚本自动执行以下步骤：

1. ✅ 停止 Prometheus 服务
2. ✅ 禁用开机自启
3. ✅ 删除 systemd 服务文件
4. ✅ 重载 systemd 配置
5. ✅ 删除防火墙规则（firewalld/ufw）
6. ✅ 删除安装目录
7. ✅ 删除/保留数据目录（根据用户选择）
8. ✅ 删除日志目录
9. ✅ 验证卸载结果

### 5. 验证卸载

脚本会验证：
- Prometheus 进程是否已停止
- 端口 9090 是否已释放
- 相关目录是否已删除

## 卸载后的状态

### 成功卸载后

```
============================================
    Prometheus 卸载完成
============================================

保留数据：
  - 数据目录: /data/prometheus

如需删除数据，请手动执行：
  rm -rf /data/prometheus

备份文件位置：
  - /etc/systemd/system/prometheus.service.bak.*

日志文件：
  - /var/log/perfstacksuite/install.log

============================================
```

### 如果选择删除数据

数据目录 `/data/prometheus` 也会被删除，所有监控数据将无法恢复。

## 安全特性

### 1. 配置文件备份

systemd 服务文件会自动备份：

```bash
/etc/systemd/system/prometheus.service.bak.20250110153045
```

### 2. 二次确认

需要输入 `yes`（不能简写为 `y`）来确认卸载，防止误操作。

### 3. 可选保留数据

可以选择保留监控数据，只删除程序文件。

### 4. 错误检查

- 检查服务是否存在
- 检查进程是否停止
- 检查端口是否释放
- 检查目录是否删除

## 支持的操作系统

- ✅ CentOS 7+
- ✅ Ubuntu 18.04+
- ✅ 麒麟 V10

## 防火墙支持

### CentOS / 麒麟（firewalld）

```bash
firewall-cmd --permanent --remove-port=9090/tcp
firewall-cmd --reload
```

### Ubuntu / Debian（ufw）

```bash
ufw delete allow 9090/tcp
```

## 批量卸载

### 卸载多个组件

```bash
sudo bash scripts/install.sh --uninstall
# 选择多个组件编号，用空格分隔
# 例如：1 2 3 表示卸载 Prometheus、Grafana、InfluxDB
```

### 卸载所有组件

```bash
sudo bash scripts/install.sh --uninstall
# 输入: all
```

## 故障排查

### 问题 1: 服务停止失败

**症状**: 显示 "Prometheus 服务停止失败"

**解决方法**:
```bash
# 手动停止服务
sudo systemctl stop prometheus

# 强制杀死进程
sudo pkill -9 prometheus

# 重新运行卸载脚本
sudo bash scripts/uninstall_prometheus.sh
```

### 问题 2: 端口仍被占用

**症状**: 显示 "端口 9090 仍在监听"

**解决方法**:
```bash
# 查找占用端口的进程
sudo lsof -i :9090

# 或
sudo netstat -tulpn | grep 9090

# 杀死进程
sudo kill -9 <PID>

# 验证端口已释放
sudo netstat -tulpn | grep 9090
```

### 问题 3: 目录无法删除

**症状**: 显示 "目录删除失败"

**解决方法**:
```bash
# 检查权限
ls -ld /opt/prometheus
ls -ld /data/prometheus

# 手动删除
sudo rm -rf /opt/prometheus
sudo rm -rf /data/prometheus
sudo rm -rf /var/log/prometheus
```

### 问题 4: 防火墙规则删除失败

**症状**: 显示 "防火墙规则删除失败"

**解决方法**:
```bash
# CentOS / 麒麟
sudo firewall-cmd --permanent --remove-port=9090/tcp
sudo firewall-cmd --reload

# Ubuntu
sudo ufw delete allow 9090/tcp

# 验证规则已删除
sudo firewall-cmd --list-ports  # CentOS
sudo ufw status                 # Ubuntu
```

## 完全清理（包括数据）

如果您需要完全清理所有痕迹：

```bash
# 1. 运行卸载脚本并选择删除数据
sudo bash scripts/uninstall_prometheus.sh

# 2. 手动检查并删除残留文件
sudo rm -rf /opt/prometheus
sudo rm -rf /data/prometheus
sudo rm -rf /var/log/prometheus
sudo rm -f /etc/systemd/system/prometheus.service*
sudo systemctl daemon-reload

# 3. 删除防火墙规则（CentOS）
sudo firewall-cmd --permanent --remove-port=9090/tcp
sudo firewall-cmd --reload

# 4. 删除防火墙规则（Ubuntu）
sudo ufw delete allow 9090/tcp

# 5. 清理日志
sudo rm -f /var/log/perfstacksuite/install.log
```

## 重新安装

卸载后可以随时重新安装：

```bash
# 重新安装 Prometheus
sudo bash scripts/install.sh --monitoring

# 或只安装 Prometheus（自定义安装）
sudo bash scripts/install.sh
# 选择 7 - 自定义安装
# 输入: 1
```

## 注意事项

⚠️ **重要提醒**:

1. **数据无法恢复**: 删除监控数据后，历史数据将无法恢复
2. **不可逆操作**: 卸载操作不可撤销，请谨慎操作
3. **备份重要数据**: 卸载前建议备份重要的配置和数据
4. **依赖关系**: 如果有其他组件依赖 Prometheus（如 Grafana），需要更新配置

## 日志查看

所有卸载操作都会记录到日志文件：

```bash
# 查看卸载日志
sudo cat /var/log/perfstacksuite/install.log

# 实时查看日志
sudo tail -f /var/log/perfstacksuite/install.log
```

## 相关文档

- [安装指南](QUICKSTART.md)
- [需求文档](docs/requirement.md)
- [开发计划](docs/development-plan.md)
