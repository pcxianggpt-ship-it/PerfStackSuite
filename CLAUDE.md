# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## 项目概述

PerfStackSuite 是一个自动部署压测工具及监控工具。

## 开发命令

项目刚初始化，尚未配置构建和测试命令。

## 代码架构

### 目录结构

```
PerfStackSuite/
├── scripts/           # Shell 脚本目录
│   ├── common.sh      # 公共函数库
│   ├── install_*.sh   # 各组件安装脚本
│   └── uninstall_*.sh # 各组件卸载脚本
├── config/            # 配置文件目录
│   └── deploy.conf    # 部署配置文件
├── soft/              # 安装包存放目录
├── docs/              # 文档目录
└── log/               # 日志目录
```

### 开发规范

**重要：所有 Shell 脚本必须使用 Unix 风格换行符（LF）**

- 在 Windows 环境下创建或编辑 Shell 脚本后，必须转换为 Unix 格式
- 使用 `sed -i 's/\r$//' script.sh` 命令转换文件
- 或使用 `dos2unix script.sh` 命令（如果已安装）
- 创建新脚本后，使用 `file script.sh` 验证文件格式
- 正确格式应显示：`UTF-8 text executable`（不应包含 "with CRLF line terminators"）

**脚本命名规范：**
- 安装脚本：`install_<组件名>.sh`
- 卸载脚本：`uninstall_<组件名>.sh`
- 所有脚本必须添加执行权限：`chmod +x scripts/*.sh`

**脚本结构要求：**
1. 加载公共函数库：`source "${SCRIPT_DIR}/common.sh"`
2. 使用统一的日志函数：`log_info`, `log_warn`, `log_error`, `log_success`
3. 使用统一的目录结构：`$HOME/<组件名>`
4. 支持 root 和普通用户安装
5. 提供完整的帮助信息：`--help` 参数

待补充：
- 构建命令
- 测试命令
- 主要模块和组件
