# PerfStackSuite 快速开始指南

## 项目简介

PerfStackSuite 是一个自动化部署压测工具及监控工具套件，可以一键部署：
- **监控系统**：Prometheus、Grafana、InfluxDB、Node Exporter
- **压测工具**：JDK 1.8、JMeter
- **系统优化**：内核参数优化、SSH 配置、中文字体

## 📁 项目结构

```
PerfStackSuite/
├── scripts/              # 部署脚本
│   ├── install.sh       # 主安装脚本 ⭐
│   └── common.sh        # 公共函数库
├── config/              # 配置文件
│   ├── deploy.conf      # 部署配置
│   └── target_servers.conf  # 目标服务器配置
├── soft/                # 离线安装包（需自行准备）
│   └── fonts/           # 中文字体（可选）
└── docs/               # 文档
    ├── requirement.md
    └── development-plan.md
```

## 🚀 快速开始

### 第一步：准备离线安装包（可选）

如果您有离线安装包，请放置在 `soft/` 目录下：

```bash
# 所需安装包列表
soft/jdk-8uXXX-linux-x64.tar.gz
soft/apache-jmeter-5.XX.tgz
soft/prometheus-2.XX.linux-amd64.tar.gz
soft/grafana-XX.XX.linux-amd64.tar.gz
soft/influxdb-XX.XX.x86_64.tar.gz
soft/node_exporter-1.XX.linux-amd64.tar.gz
```

**注意**：当前版本为框架验证阶段，所有安装包都是可选的。

### 第二步：上传到服务器

将整个 `PerfStackSuite` 目录上传到目标服务器：

```bash
# 使用 scp 上传（推荐）
scp -r PerfStackSuite root@your-server:/opt/

# 或使用 rsync
rsync -avz PerfStackSuite/ root@your-server:/opt/PerfStackSuite/
```

### 第三步：运行安装脚本

登录服务器后，进入项目目录并运行：

```bash
cd /opt/PerfStackSuite
sudo bash scripts/install.sh
```

### 第四步：选择功能

您将看到交互式菜单：

```
============================================
    PerfStackSuite 安装程序
    版本: v1.0
============================================

请选择操作:
  1 - 全量安装（Prometheus + Grafana + InfluxDB + Node Exporter + JDK + JMeter）
  2 - 仅安装监控系统
  3 - 仅安装 JDK + JMeter
  4 - 配置 SSH + X11
  5 - 优化系统内核参数（TCP TIME_WAIT 处理）
  6 - 安装中文字体（解决 JMeter GUI 乱码）
  7 - 自定义安装
  8 - 卸载组件
  0 - 退出
```

**当前阶段**：由于这是框架验证版本，选择任何选项都会提示"功能开发中"，但您可以验证：
- ✅ 菜单系统正常工作
- ✅ 环境检查功能正常
- ✅ 日志记录功能正常
- ✅ 配置文件加载正常

## 📋 命令行模式

您也可以使用命令行模式：

```bash
# 全量安装
sudo bash scripts/install.sh --all

# 仅安装监控系统
sudo bash scripts/install.sh --monitoring

# 仅安装 JDK + JMeter
sudo bash scripts/install.sh --jmeter

# 查看帮助
sudo bash scripts/install.sh --help
```

## 🔍 验证安装框架

运行安装脚本后，您应该看到：

1. **欢迎信息**正常显示
2. **环境检查**通过：
   - ✅ Root 用户检查
   - ✅ 操作系统检测
   - ✅ 系统架构检测
   - ✅ 必要命令检查
3. **菜单交互**正常
4. **日志文件**生成：`/var/log/perfstacksuite/install.log`

查看日志：

```bash
cat /var/log/perfstacksuite/install.log
```

## 📝 当前开发状态

### ✅ 已完成（阶段 1）
- [x] 项目目录结构
- [x] common.sh 公共函数库框架
- [x] 主安装脚本框架
- [x] 配置文件模板
- [x] 环境检查功能
- [x] 日志记录功能
- [x] 交互式菜单系统

### 🔄 开发中（阶段 2-5）
- [ ] Prometheus 安装脚本
- [ ] Grafana 安装脚本
- [ ] InfluxDB 安装脚本
- [ ] Node Exporter 安装脚本
- [ ] JDK 安装脚本
- [ ] JMeter 安装脚本
- [ ] 系统内核参数优化
- [ ] SSH 配置脚本
- [ ] 中文字体安装

## 🎯 下一步

1. **验证框架**：在测试服务器上运行 `install.sh`，确认基础功能正常
2. **组件开发**：按照开发计划逐个实现各组件安装脚本
3. **集成测试**：完成所有组件后进行全量安装测试

## 📚 文档

- [需求文档](docs/requirement.md) - 详细的系统需求和设计说明
- [开发计划](docs/development-plan.md) - 完整的开发计划和任务分解

## 🐛 问题反馈

如遇到问题，请检查：
1. 是否使用 root 用户运行
2. 系统是否为 CentOS 7+、Ubuntu 18.04+ 或麒麟 V10
3. 查看日志文件：`/var/log/perfstacksuite/install.log`

---

**版本**：v1.0-alpha
**状态**：框架验证阶段
**最后更新**：2025-01-09
