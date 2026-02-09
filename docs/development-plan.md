# PerfStackSuite 开发计划

## 项目概述

PerfStackSuite 是一个自动化部署压测工具及监控工具套件，使用 Shell 脚本实现一键部署监控系统、压测工具和系统优化。

**开发周期**：预计 4-6 周
**开发模式**：敏捷开发，按模块迭代
**开发语言**：Bash Shell
**目标系统**：CentOS 7+、Ubuntu 18.04+、Debian 9+、麒麟 V10+

---

## 开发阶段划分

### 阶段 1：项目准备与环境搭建（第 1 周）

#### 1.1 基础架构设计
- [ ] 创建目录结构（soft/、scripts/、config/、docs/、soft/fonts/）
- [ ] 编写 common.sh 公共函数库框架
  - 日志函数（log_info、log_warn、log_error、log_success）
  - 系统检测函数（get_os_type、get_arch、is_root）
    - 支持 CentOS/Ubuntu/Debian/麒麟 V10 检测
    - 麒麟 V10 基于 CentOS，需要特殊识别逻辑
  - 基础工具函数（backup_file、create_dir）
  - 字体管理函数（详见需求文档）
- [ ] 创建 deploy.conf 配置文件模板
- [ ] 编写 install.sh 主脚本框架

**交付物**：
- 项目骨架代码
- 公共函数库 v1.0
- 配置文件模板

**验收标准**：
- 脚本可在 CentOS、Ubuntu、麒麟 V10 上正常运行
- 日志输出格式统一
- 配置文件可正常加载
- OS 类型检测函数正确识别麒麟 V10

---

### 阶段 2：监控系统部署（第 2-3 周）

#### 2.1 Prometheus 部署脚本（3 天）
- [ ] 编写 install_prometheus.sh
  - [ ] 安装包检查和解压
  - [ ] 目录结构创建（/opt/prometheus、/data/prometheus）
  - [ ] 配置文件生成（prometheus.yml）
  - [ ] 数据保留时间配置（--storage.tsdb.retention.time）
  - [ ] systemd 服务文件创建
  - [ ] 服务启动和自启动配置
  - [ ] 防火墙规则配置
  - [ ] 安装验证（端口、Web UI）

- [ ] 编写 prometheus.yml 配置模板
  - [ ] 全局配置
  - [ ] 抓取间隔配置
  - [ ] Node Exporter 预配置
  - [ ] 数据存储路径配置

**验收标准**：
- Prometheus 服务正常启动
- Web UI 可访问（http://localhost:9090）
- 服务配置开机自启
- 数据保留时间配置生效

#### 2.2 Grafana 部署脚本（3 天）
- [ ] 编写 install_grafana.sh
  - [ ] 安装包检查和解压
  - [ ] 目录结构创建（/opt/grafana、/data/grafana）
  - [ ] 配置文件生成（grafana.ini）
  - [ ] systemd 服务文件创建
  - [ ] 服务启动和自启动配置
  - [ ] 防火墙规则配置
  - [ ] 等待服务就绪
  - [ ] 数据源配置（Prometheus、InfluxDB）
  - [ ] 监控面板导入（API 调用）
  - [ ] 安装验证

- [ ] 编写 grafana.ini 配置模板
- [ ] 准备监控面板 JSON 模板
  - [ ] Node Exporter 系统监控面板
  - [ ] Prometheus 监控面板
  - [ ] JMeter 性能测试面板

**验收标准**：
- Grafana 服务正常启动
- Web UI 可访问（http://localhost:3000）
- 数据源配置成功
- 监控面板显示正常

#### 2.3 InfluxDB 部署脚本（3 天）
- [ ] 编写 install_influxdb.sh
  - [ ] 安装包检查和解压
  - [ ] 目录结构创建（/opt/influxdb、/data/influxdb）
  - [ ] 配置文件生成（influxdb.conf）
  - [ ] systemd 服务文件创建
  - [ ] 服务启动和自启动配置
  - [ ] 防火墙规则配置
  - [ ] 数据库初始化
    - [ ] 创建 jmeter 数据库
    - [ ] 创建管理员和普通用户
    - [ ] 配置数据保留策略（INFLUXDB_RETENTION）
  - [ ] 安装验证（influx 命令测试）

**验收标准**：
- InfluxDB 服务正常启动
- 数据库创建成功
- 用户权限配置正确
- 数据保留策略生效

#### 2.4 Node Exporter 部署脚本（2 天）
- [ ] 编写 install_node_exporter.sh
  - [ ] 安装包检查和解压
  - [ ] 二进制文件部署到 /usr/local/bin/
  - [ ] systemd 服务文件创建
  - [ ] 服务启动和自启动配置
  - [ ] 防火墙规则配置（端口 9100）
  - [ ] 获取本机 IP
  - [ ] 自动注册到 Prometheus
  - [ ] 重启 Prometheus 使配置生效
  - [ ] 安装验证（Metrics 访问）

**验收标准**：
- Node Exporter 服务正常启动
- Metrics 可访问（http://localhost:9100/metrics）
- Prometheus 成功抓取目标
- Grafana 监控面板显示数据

---

### 阶段 3：JDK 与 JMeter 部署（第 4 周）

#### 3.1 JDK 安装脚本（2 天）
- [ ] 编写 install_jdk.sh
  - [ ] Java 版本检测（是否已安装）
  - [ ] 安装包检查和解压
  - [ ] JDK 目录部署（/opt/java/jdk1.8.0_xxx）
  - [ ] 软链接创建（/opt/java/jdk1.8）
  - [ ] 环境变量配置（/etc/profile.d/java.sh）
    - [ ] JAVA_HOME
    - [ ] JRE_HOME
    - [ ] CLASSPATH
    - [ ] PATH 更新
  - [ ] 环境变量生效（source）
  - [ ] 安装验证（java -version、javac -version）

**验收标准**：
- JDK 安装成功
- java -version 显示 1.8
- 环境变量配置正确
- 新会话环境变量自动生效

#### 3.2 JMeter 安装脚本（3 天）
- [ ] 编写 install_jmeter.sh
  - [ ] JDK 依赖检查
  - [ ] 安装包检查和解压
  - [ ] JMeter 目录部署
  - [ ] 软链接创建（/opt/jmeter/current）
  - [ ] 环境变量配置（/etc/profile.d/jmeter.sh）
  - [ ] jmeter.properties 配置
    - [ ] 时间戳格式
    - [ ] 输出格式
    - [ ] 字符编码
    - [ ] **HTTP 连接回收参数配置**
  - [ ] InfluxDB 后端监听器插件安装
  - [ ] InfluxDB 连接配置（influxdb.properties）
  - [ ] JVM 堆内存配置（HEAP 参数）
  - [ ] 命令行快捷方式（/usr/local/bin/）
  - [ ] 安装验证（jmeter -v）

**验收标准**：
- JMeter 安装成功
- jmeter -v 显示版本信息
- HTTP 连接回收参数配置正确
- InfluxDB 插件安装成功

---

### 阶段 4：系统优化与 SSH 配置（第 5 周）

#### 4.1 系统内核参数优化脚本（2 天）
- [ ] 编写 install_sysctl.sh
  - [ ] 现有配置备份（/etc/sysctl.conf）
  - [ ] 优化配置文件生成（/etc/sysctl.d/99-perfstack-tuning.conf）
    - [ ] TIME_WAIT 优化（tcp_tw_reuse、tcp_fin_timeout）
    - [ ] 端口范围优化（ip_local_port_range）
    - [ ] TCP 连接跟踪优化（nf_conntrack_*）
    - [ ] TCP 缓冲区优化（tcp_rmem、tcp_wmem）
    - [ ] 其他优化（tcp_window_scaling、tcp_sack、tcp_syncookies）
  - [ ] 配置应用（sysctl -p）
  - [ ] 参数验证
  - [ ] 效果验证（netstat、ss 命令）

**验收标准**：
- 内核参数配置成功
- sysctl -p 无错误
- 参数值正确生效
- TIME_WAIT 连接数优化效果明显

#### 4.2 SSH 配置脚本（2 天）
- [ ] 编写 config_ssh.sh
  - [ ] SSH 服务状态检查
  - [ ] SSH 服务安装（如需要）
  - [ ] SSH 配置文件备份
  - [ ] SSH 配置修改（/etc/ssh/sshd_config）
    - [ ] 启用 X11Forwarding
    - [ ] 配置 X11UseLocalhost
    - [ ] 调整 MaxSessions
    - [ ] 配置认证方式
  - [ ] X11 依赖库安装
    - [ ] CentOS：xauth、xorg-x11-fonts-*、libX11、libXext、libXtst
    - [ ] Ubuntu：xauth、x11-apps、libx11-6、libxext6、libxtst6
  - [ ] **中文字体安装（解决 JMeter GUI 乱码）**
    - [ ] 检测系统已安装字体
    - [ ] CentOS 字体安装：
      - [ ] 安装中文字体包：fonts-chinese、fonts-wqy-zenhei、fonts-wqy-microhei
      - [ ] 可选：fonts-arphic-uming、fonts-arphic-ukai
      - [ ] 创建字体缓存目录：/usr/share/fonts/chinese
      - [ ] 复制中文字体到字体目录（如 soft/fonts/ 下的字体文件）
      - [ ] 执行 fc-cache -fv 更新字体缓存
      - [ ] 验证字体安装：fc-list :lang=zh
    - [ ] Ubuntu 字体安装：
      - [ ] 安装中文字体包：fonts-wqy-zenhei、fonts-wqy-microhei、fonts-noto-cjk
      - [ ] 可选：fonts-arphic-uming、fonts-arphic-ukai
      - [ ] 创建字体缓存目录：/usr/share/fonts/truetype/chinese
      - [ ] 复制中文字体到字体目录（如 soft/fonts/ 下的字体文件）
      - [ ] 执行 fc-cache -fv 更新字体缓存
      - [ ] 验证字体安装：fc-list :lang=zh
  - [ ] **JMeter 字体配置**
    - [ ] 修改 JMeter 启动脚本（jmeter）
    - [ ] 添加 JVM 字体参数：`-Dfile.encoding=UTF-8`
    - [ ] 可选：指定默认字体 `-Dswing.defaultfont=SansSerif`
  - [ ] 防火墙规则配置（SSH 端口）
  - [ ] SSH 服务重启
  - [ ] X11 Forwarding 验证
  - [ ] **字体显示验证**
    - [ ] 启动 JMeter GUI 验证中文显示
    - [ ] 创建测试计划并添加中文元素名称
    - [ ] 检查界面中文是否正常显示
  - [ ] SSH 密钥生成（可选）
  - [ ] 公钥分发（可选）

**验收标准**：
- SSH 服务正常运行
- X11 Forwarding 配置成功
- xclock 测试显示图形界面
- JMeter GUI 可通过 SSH X11 转发启动
- **JMeter 界面中文正常显示，无乱码**
- fc-list 能列出中文字体

---

### 阶段 5：集成测试与文档完善（第 6 周）

#### 5.1 主安装脚本完善（2 天）
- [ ] 完善 install.sh 主脚本
  - [ ] 命令行参数解析
    - [ ] 全量安装
    - [ ] 单独安装组件
    - [ ] 自定义安装
    - [ ] 卸载模式
  - [ ] 交互式菜单实现
    - [ ] 1 - 全量安装
    - [ ] 2 - 仅安装监控系统
    - [ ] 3 - 仅安装 JDK + JMeter
    - [ ] 4 - 配置 SSH + X11
    - [ ] 5 - 优化系统内核参数（TCP TIME_WAIT 处理）
    - [ ] 6 - **安装中文字体（解决 JMeter GUI 乱码）**
    - [ ] 7 - 自定义安装
    - [ ] 8 - 卸载组件
    - [ ] 0 - 退出
  - [ ] 安装前环境检查
    - [ ] 操作系统检测
    - [ ] 系统架构检测
    - [ ] Root 权限检查
    - [ ] 必要命令检查
  - [ ] 安装包完整性检查
    - [ ] 检查 soft/fonts/ 目录下的字体文件
  - [ ] 组件安装顺序编排
  - [ ] 安装日志记录
  - [ ] 安装结果汇总输出
  - [ ] 错误处理和回滚机制

**验收标准**：
- 菜单交互友好
- 安装流程顺畅
- 错误处理完善
- 日志记录详细

#### 5.2 集成测试（3 天）
- [ ] 准备测试环境
  - [ ] CentOS 7 虚拟机
  - [ ] Ubuntu 18.04 虚拟机
  - [ ] 麒麟 V10 虚拟机（如条件允许）
  - [ ] 准备完整离线安装包

- [ ] 全量安装测试
  - [ ] 一键安装所有组件
  - [ ] 验证所有服务启动
  - [ ] 验证所有端口监听
  - [ ] 验证监控数据流

- [ ] 单独安装测试
  - [ ] 仅安装监控系统
  - [ ] 仅安装 JDK + JMeter
  - [ ] 仅配置 SSH + X11
  - [ ] 仅优化系统内核

- [ ] 功能验证测试
  - [ ] Prometheus 数据保留时间
  - [ ] InfluxDB 数据保留策略
  - [ ] Grafana 监控面板
  - [ ] JMeter HTTP 连接回收
  - [ ] TIME_WAIT 连接优化
  - [ ] SSH X11 Forwarding
  - [ ] **JMeter GUI 中文字体显示**
    - [ ] 远程启动 JMeter GUI
    - [ ] 创建测试计划并添加中文命名
    - [ ] 检查界面中文是否正常显示
    - [ ] 验证菜单、按钮、提示信息无乱码
    - [ ] 测试不同字体渲染效果

- [ ] 兼容性测试
  - [ ] CentOS 7/8 测试
  - [ ] Ubuntu 18.04/20.04 测试
  - [ ] Debian 9/10 测试
  - [ ] 麒麟 V10 测试（如条件允许）
  - [ ] x86_64 架构测试
  - [ ] ARM64 架构测试（如条件允许）

- [ ] 问题修复和回归测试

**验收标准**：
- 所有组件安装成功
- 所有功能验证通过
- 多系统兼容性良好
- 无阻塞性 Bug

#### 5.3 文档编写（2 天）
- [ ] 用户使用手册
  - [ ] 环境准备说明
  - [ ] 安装包准备清单
  - [ ] 快速开始指南
  - [ ] 详细安装步骤
  - [ ] 配置说明
  - [ ] 常见问题 FAQ

- [ ] 开发文档
  - [ ] 代码结构说明
  - [ ] 函数接口文档
  - [ ] 扩展开发指南

- [ ] 运维文档
  - [ ] 服务启停操作
  - [ ] 配置修改说明
  - [ ] 日志查看方法
  - [ ] 故障排查指南
  - [ ] 备份恢复流程

**验收标准**：
- 文档完整清晰
- 步骤可执行
- 截图示例齐全

---

## 依赖关系

```
阶段 1（项目准备）
    ↓
阶段 2（监控系统）←────┐
    ├─ Prometheus       │
    ├─ Grafana ────────┘（依赖 Prometheus 和 InfluxDB）
    └─ InfluxDB
    └─ Node Exporter ───┐
                       │
阶段 3（JDK/JMeter）    │
    ├─ JDK             │
    └─ JMeter ─────────┘（依赖 InfluxDB）
                       │
阶段 4（系统优化）      │（独立）         │
    ├─ 内核优化         │
    └─ SSH 配置        │
                       │
阶段 5（集成测试）◄─────┘
    ├─ 主脚本完善
    ├─ 集成测试
    └─ 文档编写
```

**关键路径**：阶段 1 → 阶段 2（Prometheus + InfluxDB）→ 阶段 3（JMeter）→ 阶段 5

---

## 里程碑

| 里程碑 | 时间点 | 交付内容 | 完成标志 |
|--------|--------|----------|----------|
| M1：项目启动 | 第 1 周末 | 项目框架、公共函数库 | 脚本骨架可运行 |
| M2：监控系统完成 | 第 3 周末 | Prometheus、Grafana、InfluxDB、Node Exporter | 监控数据流打通 |
| M3：压测环境完成 | 第 4 周末 | JDK、JMeter、HTTP 连接回收配置 | JMeter 可正常运行 |
| M4：系统优化完成 | 第 5 周末 | 内核优化、SSH 配置 | TIME_WAIT 优化生效 |
| M5：项目发布 | 第 6 周末 | 完整安装程序、文档 | 全量安装测试通过 |

---

## 任务分配建议

### 开发角色
- **后端开发**（Shell 脚本开发）：2 人
- **测试工程师**：1 人
- **文档工程师**：1 人（可兼职）

### 工作量估算
| 阶段 | 开发 | 测试 | 文档 | 总人日 |
|------|------|------|------|--------|
| 阶段 1 | 5 | 1 | 2 | 8 |
| 阶段 2 | 11 | 3 | 3 | 17 |
| 阶段 3 | 5 | 2 | 2 | 9 |
| 阶段 4 | 4 | 2 | 1 | 7 |
| 阶段 5 | 5 | 5 | 5 | 15 |
| **总计** | **30** | **13** | **13** | **56** |

---

## 风险管理

### 技术风险

| 风险项 | 可能性 | 影响 | 应对措施 |
|--------|--------|------|----------|
| 不同 Linux 发行版兼容性问题 | 高 | 高 | 早期多系统测试，抽象公共函数 |
| 麒麟 V10 系统适配问题 | 中 | 中 | 麒麟 V10 基于 CentOS，复用 CentOS 逻辑 |
| InfluxDB 2.x API 变化 | 中 | 中 | 明确版本依赖，使用稳定版本 |
| systemd 服务配置差异 | 中 | 中 | 针对 OS 类型分别处理 |
| Grafana API 认证失败 | 低 | 中 | 充分测试，提供手动配置方案 |
| SSH X11 Forwarding 配置复杂 | 中 | 低 | 详细文档，提供测试命令 |

### 进度风险

| 风险项 | 可能性 | 影响 | 应对措施 |
|--------|--------|------|----------|
| 安装包下载准备不足 | 中 | 高 | 提前准备，提供下载脚本 |
| 测试环境资源不足 | 低 | 中 | 使用虚拟机，并行测试 |
| 需求变更 | 低 | 中 | 需求评审，变更控制 |

### 质量风险

| 风险项 | 可能性 | 影响 | 应对措施 |
|--------|--------|------|----------|
| Shell 脚本编码问题（CRLF） | 高 | 高 | 开发规范、pre-commit 检查、dos2unix |
| 权限配置错误 | 中 | 高 | 详细文档、权限检查函数 |
| 配置文件格式错误 | 中 | 中 | 配置验证函数、错误提示 |

---

## 质量保证

### 代码规范
- 所有 Shell 脚本必须使用 Unix 风格换行符（LF）
- 遵循 Shell 脚本最佳实践（ShellCheck）
- 函数命名采用小写+下划线（如：log_info）
- 变量命名采用大写+下划线（如：JAVA_HOME）
- 所有函数必须添加注释说明
- OS 类型检测必须支持麒麟 V10（检测 /etc/kylin-release 或 /etc/.kyinfo）

### 代码审查
- 每个脚本完成后进行代码审查
- 使用 ShellCheck 工具检查代码质量
- 重点审查：错误处理、权限检查、路径处理

### 测试策略
- **单元测试**：每个公共函数单独测试
- **集成测试**：组件间联调测试
- **系统测试**：完整安装流程测试
- **兼容性测试**：
  - CentOS 7/8
  - Ubuntu 18.04/20.04
  - Debian 9/10
  - 麒麟 V10（如条件允许）
  - x86_64 和 ARM64 架构

### 版本控制
- 使用 Git 进行版本控制
- 主分支：main
- 开发分支：dev
- 功能分支：feature/xxx
- 修复分支：fix/xxx
- 提交信息规范：feat/fix/docs/style/refactor/test/chore

---

## 交付清单

### 代码交付
- [ ] Shell 脚本安装程序
  - [ ] install.sh（主安装脚本）
  - [ ] install_prometheus.sh
  - [ ] install_grafana.sh
  - [ ] install_influxdb.sh
  - [ ] install_node_exporter.sh
  - [ ] install_jdk.sh
  - [ ] install_jmeter.sh
  - [ ] install_sysctl.sh
  - [ ] config_ssh.sh（包含字体安装功能）
  - [ ] common.sh（公共函数库，包含字体管理函数）

- [ ] 配置文件模板
  - [ ] deploy.conf
  - [ ] prometheus.yml
  - [ ] grafana.ini
  - [ ] influxdb.conf

- [ ] Grafana 监控面板模板
  - [ ] Node Exporter 系统监控面板
  - [ ] Prometheus 监控面板
  - [ ] JMeter 性能测试面板

- [ ] 中文字体包
  - [ ] soft/fonts/ 目录
  - [ ] 推荐字体：
    - [ ] wqy-zenhei.ttc（文泉驿正黑）
    - [ ] wqy-microhei.ttc（文泉驿微米黑）
    - [ ] NotoSansCJK-Regular.ttc（Google Noto 字体）
    - [ ] 可选：其他中文字体文件
  - [ ] 字体说明文档（fonts/README.md）

### 文档交付
- [ ] 需求文档（requirement.md）✅
- [ ] 开发计划（development-plan.md）✅
- [ ] 用户使用手册（user-guide.md）
- [ ] 部署操作手册（deployment-guide.md）
- [ ] 常见问题 FAQ（faq.md）
- [ ] 更新日志（CHANGELOG.md）

### 其他交付
- [ ] 离线安装包清单
- [ ] 安装包下载脚本
- [ ] 示例 JMeter 测试计划

---

## 后续优化方向

### 第一阶段优化（发布后 1-2 月）
- [ ] 支持容器化部署（Docker Compose）
- [ ] 添加健康检查脚本
- [ ] 添加自动备份功能
- [ ] 支持配置文件热更新

### 第二阶段优化（发布后 3-6 月）
- [ ] Web 管理界面
- [ ] 支持 Kubernetes 部署
- [ ] 添加邮件/钉钉告警
- [ ] 性能测试报告自动生成

### 第三阶段优化（长期）
- [ ] 支持更多监控组件（如 Loki、Tempo）
- [ ] 支持分布式压测
- [ ] 支持监控数据导出
- [ ] 提供 SaaS 服务版本

---

## 附录

### A. 麒麟 V10 系统适配说明

**系统识别**：
- 麒麟 V10 有两种识别方式：
  1. 检查 `/etc/kylin-release` 文件是否存在
  2. 检查 `/etc/.kyinfo` 文件获取系统信息

**特点**：
- 基于 CentOS 7/8 构建
- 大部分命令和包管理与 CentOS 兼容
- 使用 yum 作为包管理器
- systemd 服务管理方式与 CentOS 一致

**适配要点**：
1. 在 `get_os_type()` 函数中优先检测麒麟系统
2. 检测为麒麟系统后，使用 CentOS 的处理逻辑
3. 特殊的麒麟软件源配置（如有需要）
4. 注意麒麟系统的安全机制（如 SELinux 配置）

**示例代码**：
```bash
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
```

**测试建议**：
- 如有条件，至少在一个麒麟 V10 环境中进行完整测试
- 重点测试 systemd 服务配置和防火墙规则
- 验证 X11 Forwarding 在麒麟系统上的兼容性

### B. JMeter GUI 中文字体支持方案

**问题描述**：
在使用 SSH X11 Forwarding 远程启动 JMeter GUI 时，如果服务器缺少中文字体支持，JMeter 界面会显示乱码（方块字符）。

**解决方案**：

#### 1. 系统字体包安装
**CentOS / 麒麟 V10：**
```bash
# 安装中文字体包
yum install -y fonts-chinese
yum install -y fonts-wqy-zenhei
yum install -y fonts-wqy-microhei
```

**Ubuntu / Debian：**
```bash
# 安装中文字体包
apt-get install -y fonts-wqy-zenhei
apt-get install -y fonts-wqy-microhei
apt-get install -y fonts-noto-cjk
```

#### 2. 自定义字体文件安装
从 `soft/fonts/` 目录安装字体文件：

```bash
# 创建字体目录
mkdir -p /usr/share/fonts/chinese

# 复制字体文件
cp soft/fonts/*.ttf /usr/share/fonts/chinese/
cp soft/fonts/*.ttc /usr/share/fonts/chinese/

# 设置字体权限
chmod 644 /usr/share/fonts/chinese/*

# 更新字体缓存
fc-cache -fv

# 验证字体安装
fc-list :lang=zh
```

#### 3. JMeter 字体配置
在 JMeter 启动脚本中添加字体参数：

```bash
# 编辑 /opt/jmeter/current/bin/jmeter
JVM_ARGS="-Dfile.encoding=UTF-8"
# 可选：指定默认字体
# JVM_ARGS="$JVM_ARGS -Dswing.defaultfont=SansSerif"
```

#### 4. 验证方法
**测试步骤：**
1. 通过 SSH X11 Forwarding 连接服务器：`ssh -X user@server`
2. 启动 JMeter GUI：`jmeter`
3. 创建测试计划，添加 HTTP 请求
4. 将请求命名为中文（如："测试请求"）
5. 查看界面是否正常显示中文

**验证命令：**
```bash
# 检查字体是否安装
fc-list :lang=zh

# 查看字体详情
fc-query /usr/share/fonts/chinese/wqy-zenhei.ttc

# 测试 X11 转发
xclock  # 应显示图形界面
```

#### 5. 推荐字体
| 字体名称 | 文件名 | 说明 |
|---------|--------|------|
| 文泉驿正黑 | wqy-zenhei.ttc | 开源中文字体，覆盖全面 |
| 文泉驿微米黑 | wqy-microhei.ttc | 现代无衬线字体 |
| Noto Sans CJK | NotoSansCJK-Regular.ttc | Google 开源字体 |
| 文鼎PL简中文名 | arphic_uming.ttc | 传统中文字体 |

#### 6. 故障排查
**问题 1：字体安装后仍显示乱码**
- 检查字体缓存是否更新：`fc-cache -fv`
- 验证字体是否正确安装：`fc-list :lang=zh`
- 重启 JMeter 使配置生效

**问题 2：fc-list 命令不存在**
- 安装 fontconfig 包：
  - CentOS：`yum install -y fontconfig`
  - Ubuntu：`apt-get install -y fontconfig`

**问题 3：X11 转发不工作**
- 检查 SSH 配置：`X11Forwarding yes`
- 安装 xauth：`yum install -y xauth` 或 `apt-get install -y xauth`
- 使用 `ssh -X` 参数连接

#### 7. 自动化实现
脚本函数示例：

```bash
# 安装中文字体
install_chinese_fonts() {
    local os_type=$(get_os_type)

    log_info "开始安装中文字体..."

    # 安装系统字体包
    if [ "$os_type" = "centos" ] || [ "$os_type" = "kylin" ]; then
        yum install -y fonts-wqy-zenhei fonts-wqy-microhei
    elif [ "$os_type" = "ubuntu" ] || [ "$os_type" = "debian" ]; then
        apt-get install -y fonts-wqy-zenhei fonts-wqy-microhei fonts-noto-cjk
    fi

    # 安装自定义字体文件
    if [ -d "$SOFT_DIR/fonts" ]; then
        mkdir -p /usr/share/fonts/chinese
        cp $SOFT_DIR/fonts/*.{ttf,ttc} /usr/share/fonts/chinese/
        chmod 644 /usr/share/fonts/chinese/*
        fc-cache -fv
    fi

    # 验证字体安装
    if fc-list :lang=zh | grep -q "WenQuanYi"; then
        log_success "中文字体安装成功"
        return 0
    else
        log_error "中文字体安装失败"
        return 1
    fi
}
```

**系统识别**：
- 麒麟 V10 有两种识别方式：
  1. 检查 `/etc/kylin-release` 文件是否存在
  2. 检查 `/etc/.kyinfo` 文件获取系统信息

**特点**：
- 基于 CentOS 7/8 构建
- 大部分命令和包管理与 CentOS 兼容
- 使用 yum 作为包管理器
- systemd 服务管理方式与 CentOS 一致

**适配要点**：
1. 在 `get_os_type()` 函数中优先检测麒麟系统
2. 检测为麒麟系统后，使用 CentOS 的处理逻辑
3. 特殊的麒麟软件源配置（如有需要）
4. 注意麒麟系统的安全机制（如 SELinux 配置）

**示例代码**：
```bash
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
```

**测试建议**：
- 如有条件，至少在一个麒麟 V10 环境中进行完整测试
- 重点测试 systemd 服务配置和防火墙规则
- 验证 X11 Forwarding 在麒麟系统上的兼容性

### B. 参考资料
- [Prometheus 官方文档](https://prometheus.io/docs/)
- [Grafana 官方文档](https://grafana.com/docs/)
- [InfluxDB 官方文档](https://docs.influxdata.com/)
- [JMeter 官方文档](https://jmeter.apache.org/usermanual/index.html)
- [Shell 脚本最佳实践](https://github.com/koalaman/shellcheck)

### C. 工具清单
- **开发工具**：vim、VS Code
- **测试工具**：ShellCheck、虚拟机（VirtualBox/VMware）
- **版本控制**：Git
- **文档工具**：Markdown、Typora
- **调试工具**：bash -x、strace

### D. 联系方式
- **项目负责人**：[待填写]
- **技术支持**：[待填写]
- **问题反馈**：GitHub Issues

---

**文档版本**：v1.1
**创建日期**：2025-01-09
**最后更新**：2025-01-09
**文档状态**：待审核
**更新记录**：
- v1.1：添加麒麟 V10 系统支持
- v1.0：初始版本
