# PerfStackSuite 需求文档

## 项目概述

PerfStackSuite 是一个自动化部署压测工具及监控工具套件，旨在简化性能测试环境的搭建和管理。

## 功能需求

### 1. 监控系统部署

#### 1.1 Prometheus 部署
- 离线安装，从 `soft/` 目录读取安装包
- 自动部署 Prometheus 时序数据库
- **统一目录架构**（root 和普通用户使用相同的目录结构）：
  - 安装目录：`$HOME/prometheus`
    - root 用户：`/root/prometheus`
    - 普通用户：`/home/username/prometheus`
  - 数据目录：`$HOME/prometheus/data`
  - 日志目录：`$HOME/prometheus/logs`
  - 服务管理：根据用户类型自动适配
    - root 用户：systemd 系统服务（`/etc/systemd/system/prometheus.service`）
    - 普通用户：systemd 用户服务（`~/.config/systemd/user/prometheus.service`）
  - 防火墙配置：root 自动配置，普通用户提示手动配置
- **无专用用户创建**：使用当前用户（root 或普通用户）直接运行
- **无权限管理**：不进行 chown 等权限操作，文件创建者即所有者
- 配置数据存储路径
- 配置数据保留时间（默认 30d）
- 配置服务自启动（root 用户：systemctl enable；普通用户：需手动配置 ~/.bash_profile）
- 默认端口：9090
- 支持持久化存储配置

#### 1.2 Grafana 部署
- 离线安装，从 `soft/` 目录读取安装包
- 自动部署 Grafana 可视化平台
- **统一目录架构**（root 和普通用户使用相同的目录结构）：
  - 安装目录：`$HOME/grafana`
    - root 用户：`/root/grafana`
    - 普通用户：`/home/username/grafana`
  - 数据目录：`$HOME/grafana/data`
  - 日志目录：`$HOME/grafana/logs`
  - 配置目录：`$HOME/grafana/conf`
  - 插件目录：`$HOME/grafana/plugins`
  - Provisioning 目录：`$HOME/grafana/conf/provisioning/`
  - 服务管理：根据用户类型自动适配
    - root 用户：systemd 系统服务（`/etc/systemd/system/grafana.service`）
    - 普通用户：systemd 用户服务（`~/.config/systemd/user/grafana.service`）
  - 防火墙配置：root 自动配置，普通用户提示手动配置
- **无专用用户创建**：使用当前用户（root 或普通用户）直接运行
- **无权限管理**：不进行 chown 等权限操作，文件创建者即所有者
- 配置数据源（Prometheus、InfluxDB）通过 Provisioning 自动配置
- 默认端口：3000
- 预配置常用监控面板模板（通过 dashboards provisioning）
- 配置管理员账号（默认 admin/admin123）

#### 1.3 InfluxDB 部署
- 离线安装，从 `soft/` 目录读取安装包
- 自动部署 InfluxDB 时序数据库
- **统一目录架构**（root 和普通用户使用相同的目录结构）：
  - 安装目录：`$HOME/influxdb`
    - root 用户：`/root/influxdb`
    - 普通用户：`/home/username/influxdb`
  - 数据目录：`$HOME/influxdb/data`
  - 元数据目录：`$HOME/influxdb/meta`
  - 日志目录：`$HOME/influxdb/logs`
  - 配置目录：`$HOME/influxdb/conf`
  - 服务管理：根据用户类型自动适配
    - root 用户：systemd 系统服务（`/etc/systemd/system/influxdb.service`）
    - 普通用户：systemd 用户服务（`~/.config/systemd/user/influxdb.service`）
  - 防火墙配置：root 自动配置，普通用户提示手动配置
- **无专用用户创建**：使用当前用户（root 或普通用户）直接运行
- **无权限管理**：不进行 chown 等权限操作，文件创建者即所有者
- 配置数据库和用户权限
- 配置数据保留策略和时长
- 默认端口：8086
- 支持数据保留策略配置（默认 30d）
- 用于 JMeter 测试结果存储

#### 1.4 Node Exporter 部署
- 离线安装，从 `soft/` 目录读取安装包
- **统一目录架构**（root 和普通用户使用相同的目录结构）：
  - 安装目录：`$HOME/node_exporter`
    - root 用户：`/root/node_exporter`
    - 普通用户：`/home/username/node_exporter`
  - 二进制文件：`$HOME/node_exporter/node_exporter`
  - 服务管理：根据用户类型自动适配
    - root 用户：systemd 系统服务（`/etc/systemd/system/node_exporter.service`）
    - 普通用户：systemd 用户服务（`~/.config/systemd/user/node_exporter.service`）
  - 防火墙配置：root 自动配置，普通用户提示手动配置
- **支持远程分布式部署**：
  - 通过 SSH/SCP 自动分发到多台目标服务器
  - 支持批量部署和并行安装
  - 目标服务器统一使用相同目录结构
  - 远程服务器自动适配 systemd 服务类型
- 采集系统级指标（CPU、内存、磁盘、网络等）
- 默认端口：9100
- 自动注册到 Prometheus 抓取目标
- 支持目标服务器列表配置
- **无专用用户创建**：使用当前用户（root 或普通用户）直接运行
- **无权限管理**：不进行 chown 等权限操作，文件创建者即所有者

#### 1.5 监控集成
- Prometheus 自动发现 Node Exporter 目标
- Grafana 预配置服务器监控仪表板
- 支持多目标服务器监控

### 2. SSH 及 X11 Forwarding 配置

#### 2.1 SSH 服务配置
- 自动配置 SSH 服务
- 支持密钥认证和密码认证
- 配置防火墙规则开放 SSH 端口（默认 22）
- 支持 SSH 密钥自动生成和分发

#### 2.2 X11 Forwarding 支持
- 启用 SSH X11 Forwarding 功能
- 配置 X11 转发参数
- 支持 JMeter GUI 远程显示
- 自动安装必要的 X11 依赖库

#### 2.3 JMeter 远程使用
- 通过 SSH X11 Forwarding 启动 JMeter GUI
- 图形界面自动转发到本地显示
- 支持脚本编辑和调试
- 支持测试计划可视化配置

### 3. JDK 1.8 环境配置

#### 3.1 JDK 安装
- 离线安装，从 `soft/` 目录读取安装包
- 自动安装 JDK 1.8
- 配置 JAVA_HOME 环境变量
- 配置 PATH 环境变量
- 支持 Oracle JDK 和 OpenJDK

#### 3.2 JMeter 安装
- 离线安装，从 `soft/` 目录读取安装包
- 自动安装 JMeter
- 配置 JMETER_HOME 环境变量
- 集成 InfluxDB 后端监听器插件
- 配置 JMeter 性能参数

#### 3.3 环境验证
- 自动验证 Java 版本
- 自动验证 JMeter 安装
- 提供环境检查命令

#### 3.4 网络连接自动回收配置
- 配置 HTTP 连接池回收策略
- 支持连接超时自动回收
- 配置空闲连接清理参数
- 防止连接泄漏和资源耗尽

#### 3.5 操作系统内核参数优化
- 优化 TCP TIME_WAIT 状态处理
- 配置端口重用和快速回收
- 调整 TCP 连接跟踪表大小
- 优化系统网络栈性能

## 非功能需求

### 4.1 易用性
- 提供命令行工具进行一键部署
- 支持配置文件自定义部署参数
- 提供详细的部署日志和错误提示

### 4.2 兼容性
- 支持主流 Linux 发行版（CentOS、Ubuntu、Debian 等）
- 支持 x86_64 和 ARM64 架构
- **支持 root 用户和普通用户安装**（无需 sudo 权限）
  - 真实场景：只有普通用户权限的服务器环境
  - 无需 root 密码或 sudo 权限即可完成安装
  - 自动检测用户类型并适配安装路径和服务管理方式

### 4.3 可维护性
- 模块化设计，各组件可独立部署
- 支持服务启停、重启、卸载操作
- 提供配置备份和恢复功能

### 4.4 安全性
- 支持配置服务访问认证
- 支持 HTTPS/TLS 加密通信
- 敏感信息加密存储

## 部署架构

```
┌─────────────────────────────────────────────────────────┐
│                      管理节点                            │
│  ┌──────────┐  ┌──────────┐  ┌──────────┐             │
│  │Prometheus│  │ Grafana  │  │ InfluxDB │             │
│  │  :9090   │  │  :3000   │  │  :8086   │             │
│  └──────────┘  └──────────┘  └──────────┘             │
└─────────────────────────────────────────────────────────┘
                         │
                         ▼
┌─────────────────────────────────────────────────────────┐
│                      目标服务器                          │
│  ┌──────────────┐  ┌──────────┐  ┌──────────┐         │
│  │Node Exporter │  │  JMeter  │  │  JDK1.8  │         │
│  │   :9100      │  │   GUI    │  │          │         │
│  └──────────────┘  └──────────┘  └──────────┘         │
│                                                      │
│         SSH + X11 Forwarding → JMeter GUI            │
└─────────────────────────────────────────────────────────┘
```

## 数据流向

```
JMeter 测试执行 → InfluxDB 存储结果 → Grafana 可视化
                                            ↑
Node Exporter 采集指标 → Prometheus 抓取 ────┘
```

## 配置文件设计

### 部署配置
- 监控组件安装路径
- 数据存储路径
- 数据保留时间（Prometheus、InfluxDB）
- 端口配置
- 认证信息

### 目标服务器配置
- 服务器 IP/主机名列表
- SSH 端口（默认 22）
- SSH 认证方式（密钥/密码）
- SSH 用户名和密码/密钥路径
- 组件部署选择（Node Exporter、JMeter 等）
- 服务器分组标签（如：web-server、db-server）
- 并发部署数量限制

## 实现技术

- 编程语言：Shell 脚本（Bash）
- 支持系统：CentOS 7+、Ubuntu 18.04+、Debian 9+、麒麟 V10
- 架构支持：x86_64、ARM64
- 安装方式：离线安装，安装包存放在 `soft/` 目录

## 双模式安装架构

PerfStackSuite 采用双模式安装架构，支持 root 用户和普通用户两种安装场景，满足真实环境中的不同权限需求。

### 设计原则

1. **目录架构统一**：root 和普通用户使用完全相同的目录结构（`$HOME/xx`）
2. **代码极简化**：通过统一架构消除 if-else 判断，降低维护复杂度
3. **服务管理分离**：root 使用系统级 systemd，普通用户使用用户级 systemd
4. **权限简化**：不创建专用用户，不进行 chown 操作
5. **日志统一**：所有用户日志统一存放在项目目录

### 模式对比表

**目录架构统一说明：** Root 用户和普通用户使用完全相同的目录结构，唯一的区别在于 `$HOME` 环境变量的值不同。

| 项目 | Root 用户模式 | 普通用户模式 |
|------|-------------|-------------|
| **$HOME 值** | `/root` | `/home/username` |
| **Prometheus 安装目录** | `$HOME/prometheus` → `/root/prometheus` | `$HOME/prometheus` → `/home/username/prometheus` |
| **Prometheus 数据目录** | `$HOME/prometheus/data` | `$HOME/prometheus/data` |
| **Prometheus 日志目录** | `$HOME/prometheus/logs` | `$HOME/prometheus/logs` |
| **Prometheus 服务文件** | `/etc/systemd/system/prometheus.service` | `~/.config/systemd/user/prometheus.service` |
| **Grafana 安装目录** | `$HOME/grafana` → `/root/grafana` | `$HOME/grafana` → `/home/username/grafana` |
| **Grafana 数据目录** | `$HOME/grafana/data` | `$HOME/grafana/data` |
| **Grafana 日志目录** | `$HOME/grafana/logs` | `$HOME/grafana/logs` |
| **Grafana 配置目录** | `$HOME/grafana/conf` | `$HOME/grafana/conf` |
| **Grafana 服务文件** | `/etc/systemd/system/grafana.service` | `~/.config/systemd/user/grafana.service` |
| **InfluxDB 安装目录** | `$HOME/influxdb` → `/root/influxdb` | `$HOME/influxdb` → `/home/username/influxdb` |
| **InfluxDB 数据目录** | `$HOME/influxdb/data` | `$HOME/influxdb/data` |
| **InfluxDB 元数据目录** | `$HOME/influxdb/meta` | `$HOME/influxdb/meta` |
| **InfluxDB 日志目录** | `$HOME/influxdb/logs` | `$HOME/influxdb/logs` |
| **InfluxDB 配置目录** | `$HOME/influxdb/conf` | `$HOME/influxdb/conf` |
| **InfluxDB 服务文件** | `/etc/systemd/system/influxdb.service` | `~/.config/systemd/user/influxdb.service` |
| **Node Exporter 安装目录** | `$HOME/node_exporter` → `/root/node_exporter` | `$HOME/node_exporter` → `/home/username/node_exporter` |
| **Node Exporter 二进制** | `$HOME/node_exporter/node_exporter` | `$HOME/node_exporter/node_exporter` |
| **Node Exporter 服务文件** | `/etc/systemd/system/node_exporter.service` | `~/.config/systemd/user/node_exporter.service` |
| **日志文件位置** | `./log/install.log`（项目目录） | `./log/install.log`（项目目录） |
| **服务启动命令** | `systemctl start <service>` | `systemctl --user start <service>` |
| **防火墙配置** | 自动配置（firewall-cmd/ufw） | 提示手动配置 |
| **开机自启** | `systemctl enable`（自动） | 需手动配置 ~/.bash_profile |
| **用户创建** | 不创建（使用 root） | 不创建（使用当前用户） |
| **权限管理** | 无需 chown | 无需 chown |

**关键优势：**
- ✅ 代码极简：目录设置只需一行代码 `PROMETHEUS_INSTALL_DIR="$HOME/prometheus"`
- ✅ 架构统一：root 和普通用户使用完全相同的目录结构
- ✅ 易于维护：不需要维护两套路径逻辑

### 实现模式

采用统一目录架构后，安装脚本得到极大简化：

**通用模式（所有组件统一）：**
```bash
# 统一设置路径（root 和普通用户使用相同结构）
PROMETHEUS_INSTALL_DIR="$HOME/prometheus"
PROMETHEUS_DATA_DIR="$HOME/prometheus/data"
PROMETHEUS_LOG_DIR="$HOME/prometheus/logs"

GRAFANA_INSTALL_DIR="$HOME/grafana"
GRAFANA_DATA_DIR="$HOME/grafana/data"
GRAFANA_LOG_DIR="$HOME/grafana/logs"
GRAFANA_CONF_DIR="$HOME/grafana/conf"

INFLUXDB_INSTALL_DIR="$HOME/influxdb"
INFLUXDB_DATA_DIR="$HOME/influxdb/data"
INFLUXDB_META_DIR="$HOME/influxdb/meta"
INFLUXDB_LOG_DIR="$HOME/influxdb/logs"
INFLUXDB_CONF_DIR="$HOME/influxdb/conf"

NODE_EXPORTER_INSTALL_DIR="$HOME/node_exporter"
NODE_EXPORTER_BIN="$HOME/node_exporter/node_exporter"

# 只在服务创建时需要判断用户类型
create_systemd_service() {
    if [ "$(id -u)" -eq 0 ]; then
        create_system_service_file  # 系统级服务
    else
        create_user_service_file  # 用户级服务
    fi
}
```

**代码简化对比：**

| 项目 | 之前（分离模式） | 现在（统一模式） |
|------|----------------|----------------|
| **路径设置代码行数** | ~30 行（if-else 判断） | ~10 行（直接赋值） |
| **需要判断的次数** | 每个组件 2-3 次 | 仅服务创建时 1 次 |
| **维护复杂度** | 高（两套路径） | 低（一套路径） |
| **新增组件时** | 需复制所有 if-else 逻辑 | 只需定义目录变量 |

### 真实场景应用

**场景描述：**
企业环境中，通常只有一台服务器，且只提供一个普通用户账号（无 sudo 权限，无 root 密码）。

**解决方案：**
1. 使用普通用户登录服务器
2. 上传 PerfStackSuite 项目到用户目录
3. 执行安装脚本，自动以普通用户模式安装
4. 所有组件统一安装在家目录下：
   - Prometheus: `$HOME/prometheus` → `/home/username/prometheus`
   - Grafana: `$HOME/grafana` → `/home/username/grafana`
   - InfluxDB: `$HOME/influxdb` → `/home/username/influxdb`
   - Node Exporter: `$HOME/node_exporter` → `/home/username/node_exporter`
5. 使用 `systemctl --user` 管理所有服务
6. 服务在用户会话中运行，无需 root 权限
7. 联系管理员开放防火墙端口（9090、3000、8086、9100）

**Root 用户场景（如需要）：**
1. 使用 root 用户登录服务器
2. 执行相同的安装脚本
3. 所有组件安装到 `/root` 目录下：
   - Prometheus: `$HOME/prometheus` → `/root/prometheus`
   - Grafana: `$HOME/grafana` → `/root/grafana`
   - InfluxDB: `$HOME/influxdb` → `/root/influxdb`
   - Node Exporter: `$HOME/node_exporter` → `/root/node_exporter`
4. 使用 `systemctl` 管理所有服务（系统级）
5. 自动配置防火墙规则

**远程部署场景：**
在多台服务器上部署 Node Exporter 时：
1. 目标服务器自动使用统一的目录结构
2. 根据目标服务器用户权限自动适配服务类型：
   - root 目标服务器：系统级 systemd 服务
   - 普通用户目标服务器：用户级 systemd 服务
3. 所有成功部署的节点自动注册到 Prometheus
4. 无需手动干预，完全自动化

### 注意事项

1. **Root 用户 /root 目录空间**：
   - root 用户安装时，所有组件在 `/root` 目录下
   - 某些系统 `/root` 分区空间较小（如 1GB）
   - 建议在安装前检查 `/root` 分区空间：`df -h /root`
   - 如空间不足，可以创建软链接：`ln -s /data/prometheus /root/prometheus`

2. **用户级 systemd 前提条件**：
   - 需要 systemd 版本 >= 232（支持用户级服务）
   - 需要执行 `loginctl enable-linger` 使服务在用户登出后继续运行
   - 或在 `~/.bash_profile` 中添加启动命令实现开机自启

3. **防火墙配置**：
   - 普通用户无法配置防火墙
   - 需要联系管理员开放所需端口（9090、3000、8086、9100）
   - 或使用其他端口转发方案

4. **资源限制**：
   - 普通用户模式下，进程受系统用户资源限制（ulimit）影响
   - 必要时需要在 `/etc/security/limits.conf` 中调整限制

5. **服务持久化**：
   - root 用户：服务自动持久化，开机自启
   - 普通用户：需配置 linger 或手动启动

6. **Node Exporter 远程部署**：
   - 目标服务器统一使用相同的目录结构
   - 远程部署时需确保目标服务器允许 SSH 连接
   - 根据目标服务器用户类型自动适配服务类型

7. **端口冲突**：
   - 普通用户模式下，如果端口被占用，需要手动停止占用进程
   - 无法使用 `netstat -tulpn` 查看所有进程（需要 root）
   - 可使用 `netstat -tupn` 或 `lsof -i:<port>` 查看当前用户的端口占用

## 开发注意事项

### 编码问题
- 所有 Shell 脚本必须使用 Unix 风格换行符（LF）
- 在 Windows 上开发时需使用编辑器将 CRLF 转换为 LF
- 可使用以下工具转换：
  - VS Code：右下角点击 CRLF，选择 LF
  - Notepad++：编辑 → EOL 转换 → Unix (LF)
  - Git：`git config core.autocrlf input`
  - dos2unix：`dos2unix script.sh`

### 目录结构
```
PerfStackSuite/
├── soft/                      # 离线安装包目录
│   ├── jdk-8uXXX-linux-x64.tar.gz
│   ├── apache-jmeter-5.XX.tgz
│   ├── prometheus-2.XX.linux-amd64.tar.gz
│   ├── grafana-XX.XX.linux-amd64.tar.gz
│   ├── influxdb-XX.XX.x86_64.tar.gz
│   ├── node_exporter-1.XX.linux-amd64.tar.gz
│   └── fonts/                 # 中文字体文件目录（解决 JMeter GUI 乱码）
│       ├── wqy-zenhei.ttc     # 文泉驿正黑字体
│       ├── wqy-microhei.ttc   # 文泉驿微米黑字体
│       ├── NotoSansCJK-Regular.ttc  # Google Noto 字体
│       └── README.md          # 字体说明文档
├── scripts/                   # 部署脚本目录
│   ├── install.sh             # 主安装脚本
│   ├── install_prometheus.sh  # Prometheus 安装脚本
│   ├── install_grafana.sh     # Grafana 安装脚本
│   ├── install_influxdb.sh    # InfluxDB 安装脚本
│   ├── install_node_exporter.sh # Node Exporter 安装脚本
│   ├── install_jdk.sh         # JDK 安装脚本
│   ├── install_jmeter.sh      # JMeter 安装脚本
│   ├── install_sysctl.sh      # 系统内核参数优化脚本
│   ├── config_ssh.sh          # SSH 配置脚本（包含字体安装功能）
│   └── common.sh              # 公共函数库（包含字体管理函数）
├── config/                    # 配置文件目录
│   ├── prometheus.yml         # Prometheus 配置
│   ├── grafana.ini            # Grafana 配置文件模板
│   ├── grafana-datasource.yml # Grafana 数据源配置
│   ├── influxdb.conf          # InfluxDB 配置文件模板
│   ├── deploy.conf            # 部署配置文件
│   ├── target_servers.conf    # 目标服务器列表配置（用于远程部署）
│   └── dashboards/            # Grafana 监控面板模板
│       ├── node-exporter-dashboard.json
│       ├── prometheus-dashboard.json
│       └── jmeter-dashboard.json
└── docs/                      # 文档目录
    ├── requirement.md         # 需求文档
    ├── development-plan.md    # 开发计划
    ├── user-guide.md          # 用户使用手册
    ├── deployment-guide.md    # 部署操作手册
    └── faq.md                 # 常见问题 FAQ
```

## 交付物

1. Shell 脚本安装程序
2. 配置文件模板
3. 部署和操作文档
4. 监控面板模板（Grafana JSON）
5. JMeter 测试计划示例
6. 中文字体包（soft/fonts/）
   - 文泉驿正黑字体
   - 文泉驿微米黑字体
   - Google Noto CJK 字体
   - 字体说明文档

## 离线安装包准备

部署前需将以下安装包放置在 `soft/` 目录：

### 软件安装包

| 组件 | 文件名示例 | 下载地址 |
|------|-----------|---------|
| JDK 1.8 | jdk-8uXXX-linux-x64.tar.gz | https://www.oracle.com/java/technologies/downloads/ |
| JMeter | apache-jmeter-5.XX.tgz | https://jmeter.apache.org/download_jmeter.cgi |
| Prometheus | prometheus-2.XX.linux-amd64.tar.gz | https://prometheus.io/download/ |
| Grafana | grafana-XX.XX.linux-amd64.tar.gz | https://grafana.com/grafana/download |
| InfluxDB | influxdb-XX.XX.x86_64.tar.gz | https://portal.influxdata.com/downloads/ |
| Node Exporter | node_exporter-1.XX.linux-amd64.tar.gz | https://prometheus.io/download/#node_exporter |

### 中文字体包（可选，解决 JMeter GUI 乱码）

放置在 `soft/fonts/` 目录：

| 字体名称 | 文件名 | 说明 | 下载地址 |
|---------|--------|------|---------|
| 文泉驿正黑 | wqy-zenhei.ttc | 开源中文字体，覆盖全面 | https://github.com/adobe-fonts/source-han-sans |
| 文泉驿微米黑 | wqy-microhei.ttc | 现代无衬线字体 | https://github.com/adobe-fonts/source-han-sans |
| Google Noto CJK | NotoSansCJK-Regular.ttc | Google 开源字体 | https://fonts.google.com/noto |

**字体获取方式**：
1. 从系统字体库复制（如 CentOS：`/usr/share/fonts/wqy-zenhei/wqy-zenhei.ttc`）
2. 从官方网站下载
3. 从字体项目 GitHub 仓库下载

**注意**：字体文件为可选，如果系统已安装中文字体包可跳过

---

## 脚本详细设计

### 1. install.sh（主安装脚本）

**功能说明：** 统一的入口脚本，负责协调所有组件的安装，提供交互式菜单选择。

**操作步骤：**
1. 解析命令行参数，支持全量安装、单独安装组件、卸载等模式
2. 加载 `common.sh` 公共函数库
3. 读取 `config/deploy.conf` 配置文件，获取安装路径、端口等参数
4. 执行系统环境检查：
   - 检测操作系统类型（CentOS/Ubuntu/Debian）
   - 检测系统架构（x86_64/ARM64）
   - 检查是否为 root 用户
   - 检查必要命令是否存在（tar、systemctl 等）
5. 检查 `soft/` 目录下的安装包完整性
6. 显示主菜单，供用户选择：
   - 1 - 全量安装（Prometheus + Grafana + InfluxDB + Node Exporter + JDK + JMeter）
   - 2 - 仅安装监控系统
   - 3 - 仅安装 JDK + JMeter
   - 4 - 配置 SSH + X11
   - 5 - 优化系统内核参数（TCP TIME_WAIT 处理）
   - 6 - 自定义安装
   - 7 - 卸载组件
   - 0 - 退出
7. 根据用户选择，按顺序调用对应的安装脚本
8. 记录安装日志到 `/var/log/perfstacksuite/install.log`
9. 安装完成后显示各组件访问地址和默认账号信息

---

### 2. install_prometheus.sh（Prometheus 安装脚本）

**功能说明：** 安装和配置 Prometheus 时序数据库，支持 root 用户和普通用户双模式安装，采用统一目录架构。

**操作步骤：**
1. 设置统一路径（root 和普通用户使用相同结构）：
   ```bash
   PROMETHEUS_INSTALL_DIR="$HOME/prometheus"
   PROMETHEUS_DATA_DIR="$HOME/prometheus/data"
   PROMETHEUS_LOG_DIR="$HOME/prometheus/logs"
   # root 用户：/root/prometheus, /root/prometheus/data, /root/prometheus/logs
   # 普通用户：/home/username/prometheus, /home/username/prometheus/data, ...
   ```
2. 调用公共函数检查是否已安装 Prometheus
3. 创建必要的目录结构（使用当前用户权限）
4. 从 `soft/` 目录解压 Prometheus 安装包到安装目录
5. 生成配置文件 `prometheus.yml`：
   - 包含基本的全局配置（scrape_interval、evaluation_interval）
   - 配置 Prometheus 自身监控（job_name: 'prometheus'）
   - 预留 Node Exporter 自动发现配置
6. 根据用户类型创建 systemd 服务：
   - **root 用户**：创建系统级 systemd 服务（`/etc/systemd/system/prometheus.service`）
   - **普通用户**：创建用户级 systemd 服务（`~/.config/systemd/user/prometheus.service`）
7. 配置防火墙（仅 root 用户）：
   - CentOS/麒麟：使用 `firewall-cmd` 开放 9090 端口
   - Ubuntu/Debian：使用 `ufw allow` 开放 9090 端口
   - 普通用户：提示需要手动配置防火墙或联系管理员
8. 启动 Prometheus 服务：
   - **root 用户**：`systemctl enable prometheus && systemctl start prometheus`
   - **普通用户**：显示 `systemctl --user` 命令提示
9. 验证安装：
   - 检查 Prometheus 进程：`pgrep -f prometheus`
   - 访问 Web UI：`http://localhost:9090`
   - 验证端口监听：调用 `check_port` 函数
10. 显示安装信息：
    - 安装目录、数据目录、日志目录
    - 服务端口（9090）
    - 数据保留时间（默认 30d）
    - Web UI 访问地址
    - 服务管理命令（根据用户类型显示相应命令）

**关键实现细节：**
- 代码极简：路径设置只需一行代码 `PROMETHEUS_INSTALL_DIR="$HOME/prometheus"`
- 不创建专用用户，使用当前用户运行
- 不进行权限管理（chown），文件创建者即所有者
- 配置文件自动生成，包含时间戳注释
- 服务文件包含外部 URL（使用 `get_local_ip` 获取本机 IP）

---

### 3. install_grafana.sh（Grafana 安装脚本）

**功能说明：** 安装和配置 Grafana 可视化平台，支持 root 用户和普通用户双模式安装，采用统一目录架构，通过 Provisioning 自动配置数据源和仪表板。

**操作步骤：**
1. 设置统一路径（root 和普通用户使用相同结构）：
   ```bash
   GRAFANA_INSTALL_DIR="$HOME/grafana"
   GRAFANA_DATA_DIR="$HOME/grafana/data"
   GRAFANA_LOG_DIR="$HOME/grafana/logs"
   GRAFANA_CONF_DIR="$HOME/grafana/conf"
   # root 用户：/root/grafana, /root/grafana/data, ...
   # 普通用户：/home/username/grafana, /home/username/grafana/data, ...
   ```
2. 调用公共函数检查是否已安装 Grafana
3. 创建必要的目录结构（使用当前用户权限）
4. 从 `soft/` 目录解压 Grafana 安装包到安装目录
5. 生成配置文件 `grafana.ini`：
   - 设置服务器端口（默认 3000）
   - 配置数据存储路径、日志路径、插件目录、Provisioning 目录
   - 设置管理员账号（从 deploy.conf 读取，默认 admin/admin123）
6. 配置数据源 Provisioning（自动配置，无需 API 调用）：
   - 创建 `provisioning/datasources/` 目录
   - 生成 Prometheus 和 InfluxDB 数据源配置文件
7. 配置仪表板 Provisioning（自动导入）：
   - 创建 `provisioning/dashboards/` 目录
   - 复制仪表板 JSON 文件到安装目录
8. 根据用户类型创建 systemd 服务：
   - **root 用户**：创建系统级 systemd 服务（`/etc/systemd/system/grafana.service`）
   - **普通用户**：创建用户级 systemd 服务（`~/.config/systemd/user/grafana.service`）
9. 配置防火墙（仅 root 用户）：
   - CentOS/麒麟：使用 `firewall-cmd` 开放 3000 端口
   - Ubuntu/Debian：使用 `ufw allow` 开放 3000 端口
   - 普通用户：提示需要手动配置防火墙或联系管理员
10. 启动 Grafana 服务：
    - **root 用户**：`systemctl enable grafana && systemctl start grafana`
    - **普通用户**：显示 `systemctl --user` 命令提示
11. 验证安装：
    - 检查 Grafana 进程：`pgrep -f grafana`
    - 访问 Web UI：`http://localhost:3000`
    - 验证数据源自动配置和仪表板导入
12. 显示安装信息：
    - 安装目录、数据目录、日志目录
    - 服务端口（3000）
    - Web UI 访问地址
    - 默认管理员账号和密码
    - 服务管理命令

**关键实现细节：**
- 代码极简：路径设置只需一行代码 `GRAFANA_INSTALL_DIR="$HOME/grafana"`
- 使用 Grafana Provisioning 机制自动配置数据源和仪表板，无需 API 调用
- 不创建专用用户，使用当前用户运行
- 不进行权限管理（chown），文件创建者即所有者
- 配置文件自动生成，包含时间戳注释

---

### 4. install_influxdb.sh（InfluxDB 安装脚本）

**功能说明：** 安装和配置 InfluxDB 时序数据库，用于存储 JMeter 测试结果，支持 root 用户和普通用户双模式安装，采用统一目录架构。

**操作步骤：**
1. 设置统一路径（root 和普通用户使用相同结构）：
   ```bash
   INFLUXDB_INSTALL_DIR="$HOME/influxdb"
   INFLUXDB_DATA_DIR="$HOME/influxdb/data"
   INFLUXDB_META_DIR="$HOME/influxdb/meta"
   INFLUXDB_LOG_DIR="$HOME/influxdb/logs"
   INFLUXDB_CONF_DIR="$HOME/influxdb/conf"
   # root 用户：/root/influxdb, /root/influxdb/data, ...
   # 普通用户：/home/username/influxdb, /home/username/influxdb/data, ...
   ```
2. 调用公共函数检查是否已安装 InfluxDB
3. 创建必要的目录结构（使用当前用户权限）
4. 从 `soft/` 目录解压 InfluxDB 安装包到安装目录
5. 生成配置文件 `influxdb.conf`：
   - 设置 HTTP 端口（默认 8086）
   - 启用认证（auth-enabled = true）
   - 配置数据存储路径、元数据路径、日志路径
   - 设置日志级别（info）
6. 根据用户类型创建 systemd 服务：
   - **root 用户**：创建系统级 systemd 服务（`/etc/systemd/system/influxdb.service`）
   - **普通用户**：创建用户级 systemd 服务（`~/.config/systemd/user/influxdb.service`）
7. 配置防火墙（仅 root 用户）：
   - CentOS/麒麟：使用 `firewall-cmd` 开放 8086 端口
   - Ubuntu/Debian：使用 `ufw allow` 开放 8086 端口
   - 普通用户：提示需要手动配置防火墙或联系管理员
8. 启动 InfluxDB 服务：
   - **root 用户**：`systemctl enable influxdb && systemctl start influxdb`
   - **普通用户**：显示 `systemctl --user` 命令提示
9. 初始化数据库和用户：
   - 创建数据库 jmeter（用于存储测试结果）
   - 创建管理员用户和普通用户 jmeter_user
   - 配置数据保留策略（默认 30d）
10. 验证安装：
    - 检查 InfluxDB 进程：`pgrep -f influxdb`
    - 使用 influx 命令连接并执行 SHOW DATABASES
    - 验证端口监听：调用 `check_port` 函数
11. 显示安装信息：
    - 安装目录、数据目录、日志目录
    - 服务端口（8086）
    - 数据库名称（jmeter）
    - 连接信息和管理员账号
    - 服务管理命令
    - 数据保留时间配置

**关键实现细节：**
- 代码极简：路径设置只需一行代码 `INFLUXDB_INSTALL_DIR="$HOME/influxdb"`
- 不创建专用用户，使用当前用户运行
- 不进行权限管理（chown），文件创建者即所有者
- 配置文件自动生成，包含时间戳注释
- 使用 InfluxDB CLI 或 API 进行初始化操作

---

### 5. install_node_exporter.sh（Node Exporter 安装脚本）

**功能说明：** 在本地或远程目标服务器上安装 Node Exporter，采集系统指标，支持分布式部署，采用统一目录架构。

**操作步骤：**

**本地安装（统一架构）：**
1. 设置统一路径（root 和普通用户使用相同结构）：
   ```bash
   NODE_EXPORTER_INSTALL_DIR="$HOME/node_exporter"
   NODE_EXPORTER_BIN="$HOME/node_exporter/node_exporter"
   # root 用户：/root/node_exporter, /root/node_exporter/node_exporter
   # 普通用户：/home/username/node_exporter, ...
   ```
2. 调用公共函数检查是否已安装 Node Exporter
3. 从 `soft/` 目录解压 Node Exporter 到安装目录
4. 根据用户类型创建 systemd 服务：
   - **root 用户**：创建系统级 systemd 服务（`/etc/systemd/system/node_exporter.service`）
   - **普通用户**：创建用户级 systemd 服务（`~/.config/systemd/user/node_exporter.service`）
5. 配置防火墙（仅 root 用户）：
   - CentOS/麒麟：使用 `firewall-cmd` 开放 9100 端口
   - Ubuntu/Debian：使用 `ufw allow` 开放 9100 端口
   - 普通用户：提示需要手动配置防火墙或联系管理员
6. 启动 Node Exporter 服务：
   - **root 用户**：`systemctl enable node_exporter && systemctl start node_exporter`
   - **普通用户**：显示 `systemctl --user` 命令提示
7. 验证安装：
   - 访问 http://localhost:9100/metrics 确认指标正常输出
   - 检查 Node Exporter 进程：`pgrep -f node_exporter`
   - 验证端口监听：调用 `check_port` 函数
8. 注册到 Prometheus：
   - 获取本机 IP 地址（调用 `get_local_ip` 函数）
   - 将本机 IP 和端口添加到 Prometheus 配置文件
   - 重启 Prometheus 使配置生效
9. 输出安装信息和注册状态

**远程部署（分布式 + 统一架构）：**
1. 读取目标服务器配置文件（`config/target_servers.conf`）
2. 验证 SSH 连接并检测目标服务器用户类型
3. 并发分发安装包到目标服务器
4. 远程执行安装（使用统一路径结构）
5. 根据目标服务器用户类型自动适配服务类型：
   - root 目标服务器：系统级 systemd 服务
   - 普通用户目标服务器：用户级 systemd 服务
6. 验证远程安装并批量注册到 Prometheus
7. 生成部署报告（成功/失败列表）

**关键实现细节：**
- 代码极简：路径设置只需一行代码 `NODE_EXPORTER_INSTALL_DIR="$HOME/node_exporter"`
- 远程部署时目标服务器使用相同的目录结构
- 根据目标服务器用户类型自动适配服务类型
- 不创建专用用户，使用当前连接用户运行
- 不进行权限管理（chown），文件创建者即所有者

---

### 6. install_jdk.sh（JDK 安装脚本）

**功能说明：** 安装 JDK 1.8 并配置环境变量。

**操作步骤：**
1. 检测当前系统是否已安装 Java：
   - 执行 java -version
   - 检查 JAVA_HOME 环境变量
2. 如果已安装且版本为 1.8，询问是否继续安装
3. 创建安装目录 `/opt/java`
4. 从 `soft/` 目录解压 JDK 安装包：
   - 支持格式：.tar.gz
   - 自动识别解压后的目录名
5. 将解压后的 JDK 目录移动到 `/opt/java/jdk1.8.0_xxx`
6. 创建软链接 `/opt/java/jdk1.8` 指向实际版本目录
7. 配置环境变量：
   - 在 `/etc/profile.d/` 下创建 `java.sh` 文件
   - 设置 JAVA_HOME=/opt/java/jdk1.8
   - 设置 JRE_HOME=$JAVA_HOME/jre
   - 设置 CLASSPATH=.:$JAVA_HOME/lib:$JRE_HOME/lib
   - 将 $JAVA_HOME/bin 和 $JRE_HOME/bin 添加到 PATH
8. 执行 source /etc/profile.d/java.sh 使环境变量生效
9. 验证安装：
   - 执行 java -version 确认版本
   - 执行 javac -version 确认编译器可用
   - 执行 echo $JAVA_HOME 确认环境变量
10. 输出安装路径和版本信息
11. 提示用户重新登录或执行 source 命令使环境变量生效

---

### 7. install_jmeter.sh（JMeter 安装脚本）

**功能说明：** 安装 JMeter 并配置 InfluxDB 后端监听器。

**操作步骤：**
1. 检查 JDK 是否已安装（依赖 install_jdk.sh）
2. 如果未安装 JDK，提示用户先安装 JDK
3. 创建安装目录 `/opt/jmeter`
4. 从 `soft/` 目录解压 JMeter 安装包：
   - 支持格式：.tgz 或 .tar.gz
5. 将解压后的 JMeter 目录移动到 `/opt/apache-jmeter-5.x.x`
6. 创建软链接 `/opt/jmeter/current` 指向实际版本目录
7. 配置环境变量：
   - 在 `/etc/profile.d/` 下创建 `jmeter.sh` 文件
   - 设置 JMETER_HOME=/opt/jmeter/current
   - 将 $JMETER_HOME/bin 添加到 PATH
8. 执行 source 使环境变量生效
9. 配置 JMeter：
   - 编辑 `jmeter.properties`：
     - 设置 jmeter.save.saveservice.timestamp_format=yyyy/MM/dd HH:mm:ss.SSS
     - 设置 jmeter.save.saveservice.output_format=xml
     - 配置 sampleresult.default.encoding=UTF-8
     - **配置网络连接回收参数：**
       - `httpclient4.idle_timeout=60000` - 空闲连接超时时间（毫秒）
       - `httpclient4.validate_after_inactivity=2000` - 连接验证间隔（毫秒）
       - `httpclient4.time_to_live=60000` - 连接最大生存时间（毫秒）
       - `httpclient4.max_retries=1` - 失败重试次数
       - `httpclient4.request_sent_retry_enabled=false` - 请求发送失败是否重试
       - `httpclient4.stale_checking_enabled=true` - 启用过期连接检查
10. 安装 InfluxDB 后端监听器插件：
    - 下载或从本地复制插件 JAR 文件到 `lib/ext/` 目录
    - 插件文件：`influxdb2-listener-2.x.x.jar`
11. 配置 InfluxDB 后端监听器：
    - 编辑 `influxdb.properties` 或创建配置文件
    - 设置 InfluxDB URL：http://localhost:8086
    - 设置数据库名：jmeter
    - 设置用户名和密码
    - 设置事件标签（application, test_name 等）
12. 设置 JMeter 启动脚本快捷方式：
    - 创建 jmeter 和 jmeter-server 软链接到 `/usr/local/bin/`
13. 配置 JVM 参数：
    - 编辑 `jmeter` 脚本，设置 HEAP=-Xms1g -Xmx4g
    - 根据系统内存调整堆内存大小
14. 验证安装：
    - 执行 jmeter -v 显示版本
    - 测试 GUI 启动（headless 模式下跳过）
15. 输出安装信息和常用命令提示

---

### 8. install_sysctl.sh（系统内核参数优化脚本）

**功能说明：** 优化操作系统内核参数，特别是 TCP TIME_WAIT 状态处理，提高高并发场景下的网络性能。

**操作步骤：**

**备份现有配置：**
1. 检查 `/etc/sysctl.conf` 文件是否存在
2. 如果存在，备份到 `/etc/sysctl.conf.bak`
3. 检查 `/etc/sysctl.d/` 目录下是否有自定义配置

**生成内核参数配置文件：**
1. 创建配置文件 `/etc/sysctl.d/99-perfstack-tuning.conf`
2. 写入以下优化参数：

   **TIME_WAIT 优化：**
   ```bash
   # 允许将 TIME_WAIT sockets 快速重用（对新的 TCP 连接）
   net.ipv4.tcp_tw_reuse = 1

   # 开启 TCP 连接快速回收（注意：可能引起 NAT 环境问题）
   net.ipv4.tcp_tw_recycle = 0  # 默认关闭，NAT 环境下必须关闭

   # 减少 TIME_WAIT 超时时间（默认 60 秒，可调整为 30 秒）
   net.ipv4.tcp_fin_timeout = 30
   ```

   **端口范围优化：**
   ```bash
   # 扩大临时端口范围（默认 32768-60999，扩大到 1024-65535）
   net.ipv4.ip_local_port_range = 1024 65535
   ```

   **TCP 连接跟踪优化：**
   ```bash
   # 增加 TCP 连接跟踪表大小（默认根据内存计算）
   net.netfilter.nf_conntrack_max = 262144

   # 减少连接跟踪超时时间
   net.netfilter.nf_conntrack_tcp_timeout_time_wait = 30
   net.netfilter.nf_conntrack_tcp_timeout_close_wait = 15
   net.netfilter.nf_conntrack_tcp_timeout_fin_wait = 30
   ```

   **TCP 缓冲区优化：**
   ```bash
   # 增加 TCP 接收缓冲区大小
   net.ipv4.tcp_rmem = 4096 87380 16777216

   # 增加 TCP 发送缓冲区大小
   net.ipv4.tcp_wmem = 4096 65536 16777216

   # 增加 TCP 全缓冲区大小
   net.core.rmem_max = 16777216
   net.core.wmem_max = 16777216
   net.core.netdev_max_backlog = 5000
   ```

   **其他优化：**
   ```bash
   # 启用 TCP 窗口缩放
   net.ipv4.tcp_window_scaling = 1

   # 启用选择性确认
   net.ipv4.tcp_sack = 1

   # 优化 SYN 握手
   net.ipv4.tcp_syncookies = 1
   net.ipv4.tcp_max_syn_backlog = 8192
   net.ipv4.tcp_synack_retries = 2
   ```

**应用配置：**
1. 执行 `sysctl -p /etc/sysctl.d/99-perfstack-tuning.conf` 应用配置
2. 执行 `sysctl -a | grep tcp` 验证参数是否生效
3. 输出当前内核参数值供用户确认

**验证效果：**
1. 执行 `netstat -an | grep TIME_WAIT | wc -l` 查看 TIME_WAIT 连接数
2. 执行 `ss -s` 查看连接统计信息
3. 执行 `cat /proc/sys/net/netfilter/nf_conntrack_count` 查看当前连接跟踪数
4. 输出配置前后的对比说明

**注意事项：**
1. 警告用户 `tcp_tw_recycle` 在 NAT 环境下可能导致连接问题，默认关闭
2. 提示某些参数需要重启网络服务或重启系统才能完全生效
3. 说明这些优化主要针对高并发压测场景
4. 提供恢复原始配置的方法（删除配置文件并重新加载）

**配置持久化：**
1. 配置文件会自动在系统重启后生效
2. 配置文件位于 `/etc/sysctl.d/` 目录，会被 systemd-sysctl 自动加载

---

### 9. config_ssh.sh（SSH 配置脚本）

**功能说明：** 配置 SSH 服务和 X11 Forwarding，支持 JMeter GUI 远程显示，并安装中文字体解决 JMeter 界面乱码问题。

**操作步骤：**

**SSH 服务配置：**
1. 检查 SSH 服务状态：
   - 检测操作系统类型
   - CentOS 检查 sshd 服务，Ubuntu 检查 ssh 服务
2. 如果 SSH 服务未安装：
   - CentOS：yum install -y openssh-server
   - Ubuntu：apt-get install -y openssh-server
3. 备份 SSH 配置文件 `/etc/ssh/sshd_config` 到 `/etc/ssh/sshd_config.bak`
4. 编辑 SSH 配置文件：
   - 启用 X11Forwarding yes
   - 启用 X11UseLocalhost yes
   - 设置 MaxSessions 10（允许更多会话）
   - 配置允许的认证方式（PubkeyAuthentication yes）
   - 可选：禁用密码登录（PasswordAuthentication no）
5. 安装 X11 依赖库：
   - CentOS：yum install -y xauth xorg-x11-fonts-* libX11 libXext libXtst
   - Ubuntu：apt-get install -y xauth x11-apps libx11-6 libxext6 libxtst6

**中文字体安装（解决 JMeter GUI 乱码）：**
6. 检测系统已安装字体：执行 `fc-list :lang=zh`
7. 安装中文字体包：
   - CentOS/麒麟 V10：
     - yum install -y fonts-chinese
     - yum install -y fonts-wqy-zenhei fonts-wqy-microhei
     - 可选：yum install -y fonts-arphic-uming fonts-arphic-ukai
   - Ubuntu：
     - apt-get install -y fonts-wqy-zenhei fonts-wqy-microhei
     - apt-get install -y fonts-noto-cjk
     - 可选：apt-get install -y fonts-arphic-uming fonts-arphic-ukai
8. 安装自定义字体文件（如 soft/fonts/ 目录存在）：
   - 创建字体缓存目录：
     - CentOS：`/usr/share/fonts/chinese`
     - Ubuntu：`/usr/share/fonts/truetype/chinese`
   - 复制字体文件到字体目录
   - 设置字体权限：`chmod 644`
   - 更新字体缓存：`fc-cache -fv`
   - 验证字体安装：`fc-list :lang=zh`
9. 配置 JMeter 字体参数：
   - 编辑 JMeter 启动脚本：`/opt/jmeter/current/bin/jmeter`
   - 添加 JVM 参数：`-Dfile.encoding=UTF-8`
   - 可选：指定默认字体：`-Dswing.defaultfont=SansSerif`
10. 防火墙配置：
   - 开放 SSH 端口（默认 22）
   - CentOS：firewall-cmd --permanent --add-service=ssh
   - Ubuntu：ufw allow ssh
11. 重启 SSH 服务使配置生效：
   - systemctl restart sshd 或 systemctl restart ssh
12. 显示 X11 Forwarding 配置状态：
   - 执行 grep 查看配置是否生效

**SSH 密钥配置（可选）：**
1. 检查是否已存在 SSH 密钥对
2. 如果不存在，生成 SSH 密钥对：
   - 使用 ssh-keygen -t rsa -b 4096
   - 设置密钥注释
   - 不设置密码短语（或使用配置文件中的密码）
3. 将公钥添加到 authorized_keys：
   - 创建 `~/.ssh/` 目录（如果不存在）
   - 设置目录权限为 700
   - 将公钥追加到 `~/.ssh/authorized_keys`
   - 设置文件权限为 600
4. 输出公钥内容供用户复制到其他服务器

**验证测试：**
1. 显示当前 SSH 配置摘要
2. 显示 X11 Forwarding 状态
3. 验证字体安装：
   - 执行 `fc-list :lang=zh` 查看中文字体
   - 检查是否包含 WenQuanYi 或 Noto 字体
4. 提供测试命令示例：
   - 本地使用 XShell 等工具连接时需启用 X11 转发
   - 测试命令：xclock（应显示图形界面）
5. JMeter GUI 字体显示验证：
   - 通过 SSH X11 Forwarding 连接：`ssh -X user@server`
   - 启动 JMeter GUI：`jmeter`
   - 创建测试计划并添加中文命名的元素
   - 检查界面中文是否正常显示，无乱码
6. 输出测试结果和字体配置信息

---

### 9. common.sh（公共函数库）

**功能说明：** 提供所有安装脚本共享的公共函数和常量定义。

**包含内容：**

**常量定义：**
- 脚本根目录（SCRIPT_DIR）
- 项目目录（PROJECT_DIR）
- 安装包目录（SOFT_DIR）
- 配置文件目录（CONFIG_DIR）
- **日志文件路径（LOG_FILE）**：统一使用 `${PROJECT_DIR}/log/install.log`
  - root 用户和普通用户都将日志存放在项目目录中
  - 避免普通用户无权限写入 `/var/log/` 目录
  - 自动创建日志目录
- 颜色输出常量（RED、GREEN、YELLOW）

**日志函数：**
- `log_info`：输出信息级别日志（绿色）
- `log_warn`：输出警告级别日志（黄色）
- `log_error`：输出错误级别日志（红色）
- `log_success`：输出成功信息（绿色）
- 所有日志同时输出到控制台和日志文件

**系统检测函数：**
- `get_os_type`：检测操作系统类型（返回 centos/ubuntu/debian/other）
- `get_arch`：检测系统架构（返回 x86_64/aarch64）
- `is_root`：检查是否为 root 用户
- `check_command`：检查命令是否存在

**服务管理函数：**
- `is_installed`：检查组件是否已安装（检查目录或服务）
- `is_service_running`：检查服务是否运行
- `start_service`：启动服务
- `stop_service`：停止服务
- `restart_service`：重启服务
- `enable_service`：设置开机自启

**文件操作函数：**
- `backup_file`：备份文件（自动添加 .bak 时间戳）
- `create_dir`：创建目录并设置权限
- `download_check`：检查安装包是否存在
- `extract_tar`：解压 tar.gz/tgz 文件

**用户管理函数：**
- `set_ownership`：递归设置目录所有者（使用 root 用户）

**防火墙函数：**
- `firewall_open_port`：开放指定端口
- `firewall_close_port`：关闭指定端口

**网络函数：**
- `get_local_ip`：获取本机 IP 地址
- `check_port`：检查端口是否被占用
- `wait_for_port`：等待端口监听

**远程部署函数：**
- `load_target_servers`：加载目标服务器配置文件
- `validate_ssh_connection`：验证 SSH 连接（接受服务器、端口、认证信息）
- `scp_upload`：通过 SCP 上传文件到远程服务器（支持重试）
- `ssh_execute`：通过 SSH 在远程服务器执行命令
- `parallel_deploy`：并发部署到多台服务器（使用 xargs -P 或后台任务）
- `remote_install`：远程安装 Node Exporter 的完整流程
- `collect_server_ips`：收集所有成功部署的服务器 IP
- `batch_register_prometheus`：批量注册到 Prometheus
- `generate_deploy_report`：生成部署报告（成功/失败列表）
- `cleanup_failed_deploy`：清理部署失败的服务器上的临时文件

**字体管理函数：**
- `check_font`：检查字体是否已安装（接受字体名称参数）
- `install_font_package`：安装系统字体包（根据 OS 类型选择包管理器）
- `install_font_files`：从 soft/fonts/ 目录安装字体文件到系统字体目录
- `update_font_cache`：更新字体缓存（执行 fc-cache -fv）
- `verify_font_installation`：验证字体安装（使用 fc-list :lang=zh 检查）
- `install_chinese_fonts`：完整的中文安装流程（组合上述函数）

**配置文件处理函数：**
- `load_config`：加载配置文件（读取 deploy.conf）
- `get_config_value`：获取配置项的值
- `update_config`：更新配置文件中的值
- `configure_http_recycling`：配置 JMeter HTTP 连接回收参数
  - 读取 deploy.conf 中的网络回收配置
  - 自动更新 jmeter.properties 文件
  - 验证参数有效性
- `configure_prometheus_retention`：配置 Prometheus 数据保留时间
  - 读取 PROMETHEUS_RETENTION_TIME 参数
  - 更新 systemd 服务文件中的启动参数
  - 验证时间格式（支持 d/h/w/y 后缀）
- `configure_influxdb_retention`：配置 InfluxDB 数据保留策略
  - 读取 INFLUXDB_RETENTION 参数
  - 执行 InfluxDB 命令创建保留策略
  - 验证时间格式（支持 d/h/w 后缀）

**交互函数：**
- `confirm`：确认提示（是/否）
- `select_option`：菜单选择
- `input_value`：输入值（带默认值和验证）

**清理函数：**
- `cleanup_on_error`：出错时清理临时文件
- `cleanup_on_exit`：退出时清理

**错误处理：**
- 使用 `set -e` 确保脚本遇到错误时退出
- 使用 trap 捕获中断信号，执行清理
- 定义错误码常量

---

### 10. 部署配置文件（deploy.conf）

**功能说明：** 存储所有安装脚本共用的配置参数。

**包含内容：**

```ini
# 基础配置
# 采用统一目录架构：root 和普通用户都使用 $HOME/xx 结构
# root 用户：$HOME = /root，安装到 /root/prometheus, /root/grafana 等
# 普通用户：$HOME = /home/username，安装到 /home/username/prometheus 等
INSTALL_BASE_DIR=$HOME
DATA_BASE_DIR=$HOME/data
LOG_BASE_DIR=$HOME/log

# 组件版本和安装包
PROMETHEUS_VERSION=3.5.1
GRAFANA_VERSION=12.3.2
INFLUXDB_VERSION=2.7.4
NODE_EXPORTER_VERSION=1.6.1
JDK_VERSION=8u381
JMETER_VERSION=5.6.2

# 端口配置
PROMETHEUS_PORT=9090
GRAFANA_PORT=3000
INFLUXDB_PORT=8086
NODE_EXPORTER_PORT=9100
SSH_PORT=22

# 服务账号
GRAFANA_ADMIN_USER=admin
GRAFANA_ADMIN_PASSWORD=admin123
INFLUXDB_ADMIN_USER=admin
INFLUXDB_ADMIN_PASSWORD=admin123
INFLUXDB_JMETER_USER=jmeter
INFLUXDB_JMETER_PASSWORD=jmeter123

# InfluxDB 配置
INFLUXDB_DB_NAME=jmeter
INFLUXDB_RETENTION=30d

# Prometheus 配置
PROMETHEUS_RETENTION_TIME=30d

# JMeter 网络连接回收配置
JMETER_HTTP_IDLE_TIMEOUT=60000
JMETER_HTTP_VALIDATE_INACTIVITY=2000
JMETER_HTTP_TIME_TO_LIVE=60000
JMETER_HTTP_MAX_RETRIES=1
JMETER_HTTP_REQUEST_SENT_RETRY=false
JMETER_HTTP_STALE_CHECKING=true

# 系统内核参数优化配置
SYSCTL_TCP_TW_REUSE=1
SYSCTL_TCP_TW_RECYCLE=0
SYSCTL_TCP_FIN_TIMEOUT=30
SYSCTL_IP_LOCAL_PORT_RANGE="1024 65535"
SYSCTL_NF_CONNTRACK_MAX=262144
SYSCTL_NF_CONNTRACK_TCP_TIMEOUT_TIME_WAIT=30

# 安装包路径
SOFT_DIR=./soft
CONFIG_DIR=./config

# 远程部署配置
TARGET_SERVERS_CONFIG=./config/target_servers.conf
DEPLOY_PARALLEL_NUM=5
DEPLOY_TIMEOUT=600
SSH_CONNECT_TIMEOUT=30
SCP_RETRY_COUNT=3

# 日志配置
LOG_FILE=./log/install.log
LOG_LEVEL=INFO
```

**配置说明：**
- **INSTALL_BASE_DIR=$HOME**：统一使用 $HOME，root 为 /root，普通用户为 /home/username
- **DATA_BASE_DIR=$HOME/data**：数据统一在 $HOME/data 下
- **LOG_FILE=./log/install.log**：日志统一存放在项目目录
- **代码简化**：所有组件路径设置只需一行代码，无需 if-else 判断
- **自动适配**：$HOME 环境变量自动适配 root 和普通用户场景

### target_servers.conf 配置文件示例

```ini
# 远程部署目标服务器配置文件
# 格式：IP|SSH用户|SSH端口|认证类型|认证信息|服务器分组

# 认证类型：key（密钥）或 password（密码）
# 服务器分组：用于 Prometheus 的 job_name 分类

# 示例 1：使用 SSH 密钥认证
192.168.1.10|root|22|key|/root/.ssh/id_rsa|web_servers
192.168.1.11|root|22|key|/root/.ssh/id_rsa|web_servers

# 示例 2：使用密码认证
192.168.1.20|root|22|password|your_password|db_servers
192.168.1.21|root|22|password|your_password|db_servers

# 示例 3：使用非标准 SSH 端口
192.168.1.30|deploy|2222|key|/home/deploy/.ssh/id_rsa|app_servers

# 示例 4：INI 格式（可选）
[web_servers]
server_group=web
servers=192.168.1.10,192.168.1.11,192.168.1.12
ssh_user=root
ssh_port=22
auth_type=key
ssh_key_path=/root/.ssh/id_rsa

[db_servers]
server_group=db
servers=192.168.1.20,192.168.1.21
ssh_user=root
ssh_port=22
auth_type=password
ssh_password=your_password
```

---
