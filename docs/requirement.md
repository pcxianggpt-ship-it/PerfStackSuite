# PerfStackSuite 需求文档

## 项目概述

PerfStackSuite 是一个自动化部署压测工具及监控工具套件，旨在简化性能测试环境的搭建和管理。

## 功能需求

### 1. 监控系统部署

#### 1.1 Prometheus 部署
- 离线安装，从 `soft/` 目录读取安装包
- 自动部署 Prometheus 时序数据库
- 配置数据存储路径
- 配置数据保留时间
- 配置服务自启动
- 默认端口：9090
- 支持持久化存储配置

#### 1.2 Grafana 部署
- 离线安装，从 `soft/` 目录读取安装包
- 自动部署 Grafana 可视化平台
- 配置数据源（Prometheus、InfluxDB）
- 默认端口：3000
- 预配置常用监控面板模板
- 配置管理员账号

#### 1.3 InfluxDB 部署
- 离线安装，从 `soft/` 目录读取安装包
- 自动部署 InfluxDB 时序数据库
- 配置数据库和用户权限
- 配置数据保留策略和时长
- 默认端口：8086
- 支持数据保留策略配置
- 用于 JMeter 测试结果存储

#### 1.4 Node Exporter 部署
- 离线安装，从 `soft/` 目录读取安装包
- 在目标服务器上部署 Node Exporter
- 采集系统级指标（CPU、内存、磁盘、网络等）
- 默认端口：9100
- 配置 Prometheus 抓取目标

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
- 服务器 IP/主机名
- SSH 认证信息
- 组件部署选择

## 实现技术

- 编程语言：Shell 脚本（Bash）
- 支持系统：CentOS 7+、Ubuntu 18.04+、Debian 9+
- 架构支持：x86_64、ARM64
- 安装方式：离线安装，安装包存放在 `soft/` 目录

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
│   └── node_exporter-1.XX.linux-amd64.tar.gz
├── scripts/                   # 部署脚本目录
│   ├── install.sh             # 主安装脚本
│   ├── install_prometheus.sh  # Prometheus 安装脚本
│   ├── install_grafana.sh     # Grafana 安装脚本
│   ├── install_influxdb.sh    # InfluxDB 安装脚本
│   ├── install_node_exporter.sh # Node Exporter 安装脚本
│   ├── install_jdk.sh         # JDK 安装脚本
│   ├── install_jmeter.sh      # JMeter 安装脚本
│   ├── install_sysctl.sh      # 系统内核参数优化脚本
│   ├── config_ssh.sh          # SSH 配置脚本
│   └── common.sh              # 公共函数库
├── config/                    # 配置文件目录
│   ├── prometheus.yml         # Prometheus 配置
│   ├── grafana-datasource.yml # Grafana 数据源配置
│   └── deploy.conf            # 部署配置文件
└── docs/                      # 文档目录
    └── requirement.md         # 需求文档
```

## 交付物

1. Shell 脚本安装程序
2. 配置文件模板
3. 部署和操作文档
4. 监控面板模板（Grafana JSON）
5. JMeter 测试计划示例

## 离线安装包准备

部署前需将以下安装包放置在 `soft/` 目录：

| 组件 | 文件名示例 | 下载地址 |
|------|-----------|---------|
| JDK 1.8 | jdk-8uXXX-linux-x64.tar.gz | https://www.oracle.com/java/technologies/downloads/ |
| JMeter | apache-jmeter-5.XX.tgz | https://jmeter.apache.org/download_jmeter.cgi |
| Prometheus | prometheus-2.XX.linux-amd64.tar.gz | https://prometheus.io/download/ |
| Grafana | grafana-XX.XX.linux-amd64.tar.gz | https://grafana.com/grafana/download |
| InfluxDB | influxdb-XX.XX.x86_64.tar.gz | https://portal.influxdata.com/downloads/ |
| Node Exporter | node_exporter-1.XX.linux-amd64.tar.gz | https://prometheus.io/download/#node_exporter |

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

**功能说明：** 安装和配置 Prometheus 时序数据库。

**操作步骤：**
1. 调用公共函数检查是否已安装 Prometheus
2. 创建必要的目录结构：
   - 安装目录：`/opt/prometheus`
   - 数据目录：`/data/prometheus`
   - 日志目录：`/var/log/prometheus`
4. 从 `soft/` 目录解压 Prometheus 安装包到 `/opt/prometheus`
5. 复制配置文件：
   - 从 `config/prometheus.yml` 复制到安装目录
   - 如配置文件不存在，则生成默认配置
6. 配置数据存储路径（修改 prometheus.yml 中的 storage.tsdb.path）
7. 配置数据保留时间：
   - 设置 `--storage.tsdb.retention.time` 参数（从 deploy.conf 读取）
   - 默认值：30d（30天）
   - 支持格式：Xd（X天）、Xh（X小时）、Xw（X周）、Xy（X年）
8. 配置抓取目标（添加 Node Exporter、InfluxDB 等抓取任务）
9. 创建 systemd 服务文件 `/etc/systemd/system/prometheus.service`：
   - 设置 ExecStart 指向 prometheus 二进制文件，包含 `--storage.tsdb.retention.time` 参数
   - 配置重启策略为 always
10. 重载 systemd 配置（systemctl daemon-reload）
11. 启动 Prometheus 服务（systemctl start prometheus）
12. 设置开机自启（systemctl enable prometheus）
13. 检查服务状态和端口监听
14. 验证：访问 http://localhost:9090 确认服务正常
15. 输出安装结果信息，包括数据保留时间配置

---

### 3. install_grafana.sh（Grafana 安装脚本）

**功能说明：** 安装和配置 Grafana 可视化平台，并预配置数据源。

**操作步骤：**
1. 调用公共函数检查是否已安装 Grafana
2. 创建必要的目录结构：
   - 安装目录：`/opt/grafana`
   - 数据目录：`/data/grafana`
   - 日志目录：`/var/log/grafana`
   - 插件目录：`/data/grafana/plugins`
   - 配置目录：`/etc/grafana`
4. 从 `soft/` 目录解压 Grafana 安装包到 `/opt/grafana`
5. 生成配置文件 `/etc/grafana/grafana.ini`：
   - 设置服务器端口（默认 3000）
   - 配置数据存储路径
   - 配置日志路径
   - 设置管理员账号（从 deploy.conf 读取）
   - 配置 anonymous_enabled 以支持公共查看
6. 创建 systemd 服务文件 `/etc/systemd/system/grafana.service`
7. 重载并启动服务
9. 等待 Grafana 启动完成（sleep 10-15 秒）
10. 配置 Prometheus 数据源：
    - 调用 Grafana API 创建数据源
    - 设置类型为 Prometheus
    - 设置 URL 为 http://localhost:9090
    - 设置访问模式为 proxy
11. 配置 InfluxDB 数据源：
    - 调用 Grafana API 创建数据源
    - 设置类型为 InfluxDB
    - 设置 URL 为 http://localhost:8086
    - 配置数据库名、用户名、密码
12. 导入预置仪表板：
    - 从 `config/dashboards/` 目录读取 JSON 文件
    - 调用 Grafana API 导入仪表板
    - 关联已配置的数据源
13. 验证：访问 http://localhost:3000 确认服务正常
14. 输出默认管理员账号和访问地址

---

### 4. install_influxdb.sh（InfluxDB 安装脚本）

**功能说明：** 安装和配置 InfluxDB 时序数据库，用于存储 JMeter 测试结果。

**操作步骤：**
1. 调用公共函数检查是否已安装 InfluxDB
2. 创建必要的目录结构：
   - 安装目录：`/opt/influxdb`
   - 数据目录：`/data/influxdb/data`
   - 元数据目录：`/data/influxdb/meta`
   - 日志目录：`/var/log/influxdb`
4. 从 `soft/` 目录解压 InfluxDB 安装包到 `/opt/influxdb`
5. 生成配置文件 `/etc/influxdb/influxdb.conf`：
   - 设置 HTTP 端口（默认 8086）
   - 配置数据存储路径
   - 启用认证（auth-enabled = true）
   - 配置日志级别
   - 设置数据保留策略
6. 创建 systemd 服务文件 `/etc/systemd/system/influxdb.service`
7. 重载并启动服务
9. 等待 InfluxDB 启动完成
10. 初始化数据库和用户：
    - 创建数据库 jmeter（用于存储测试结果）
    - 创建管理员用户（用户名/密码从配置文件读取）
    - 创建普通用户 jmeter_user
    - 配置数据保留策略：
      - 策略名：默认策略或自定义策略名
      - 保留时间：从 deploy.conf 读取 INFLUXDB_RETENTION 参数
      - 默认值：30d（30天）
      - 支持格式：Xd（X天）、Xh（X小时）、Xw（X周）
      - 副本数量：1（单节点环境）
      - 设置为默认策略
11. 验证：使用 influx 命令连接并执行 SHOW DATABASES
12. 输出连接信息和数据库名称

---

### 5. install_node_exporter.sh（Node Exporter 安装脚本）

**功能说明：** 在目标服务器上安装 Node Exporter，采集系统指标。

**操作步骤：**
1. 调用公共函数检查是否已安装 Node Exporter
2. 从 `soft/` 目录解压 Node Exporter 到 `/opt/node_exporter`
4. 将 node_exporter 二进制文件复制到 `/usr/local/bin/`（或创建软链接）
5. 创建 systemd 服务文件 `/etc/systemd/system/node_exporter.service`：
   - 设置 ExecStart=/usr/local/bin/node_exporter
   - 可配置额外参数，如 --web.listen-address=:9100
6. 重载并启动服务
8. 检查服务状态
9. 配置防火墙：
   - CentOS：使用 firewall-cmd 开放 9100 端口
   - Ubuntu：使用 ufw allow 9100
10. 验证：访问 http://localhost:9100/metrics 确认指标正常输出
11. 获取本机 IP 地址
12. 将本机 IP 和端口添加到 Prometheus 配置文件的 scrape_configs 中
13. 重启 Prometheus 使配置生效
14. 输出安装信息和注册状态

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

**功能说明：** 配置 SSH 服务和 X11 Forwarding，支持 JMeter GUI 远程显示。

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
6. 配置防火墙：
   - 开放 SSH 端口（默认 22）
   - CentOS：firewall-cmd --permanent --add-service=ssh
   - Ubuntu：ufw allow ssh
7. 重启 SSH 服务使配置生效：
   - systemctl restart sshd 或 systemctl restart ssh
8. 显示 X11 Forwarding 配置状态：
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
3. 提供测试命令示例：
   - 本地使用 XShell 等工具连接时需启用 X11 转发
   - 测试命令：xclock（应显示图形界面）
4. 显示 JMeter GUI 启动方式：
   - `ssh -X user@server`
   - 连接后执行 `jmeter` 启动 GUI

---

### 9. common.sh（公共函数库）

**功能说明：** 提供所有安装脚本共享的公共函数和常量定义。

**包含内容：**

**常量定义：**
- 脚本根目录
- 安装包目录
- 配置文件目录
- 日志文件路径
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
INSTALL_BASE_DIR=/opt
DATA_BASE_DIR=/data
LOG_BASE_DIR=/var/log

# 组件版本和安装包
PROMETHEUS_VERSION=2.45.0
GRAFANA_VERSION=10.1.0
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

# 日志配置
LOG_FILE=/var/log/perfstacksuite/install.log
LOG_LEVEL=INFO
```

---
