# OpenWild Agent

**低成本野外智能体平台 — 基于 ESP32-S3 + ESP-Claw 的开源野生动物 AI 监护解决方案**

[![ESP-IDF](https://img.shields.io/badge/ESP--IDF-5.3+-green.svg)](https://github.com/espressif/esp-idf)
[![License](https://img.shields.io/badge/License-Apache--2.0-blue.svg)](./LICENSE)
[![Platform](https://img.shields.io/badge/Platform-ESP32--S3-orange.svg)](https://github.com/espressif/esp-idf)

> 开源地址：[github.com/liluwei-star/OpenWild-Agent](https://github.com/liluwei-star/OpenWild-Agent)

## 目录

- [项目概述](#项目概述)
- [硬件清单](#硬件清单)
- [软件架构](#软件架构)
- [模块依赖关系](#模块依赖关系)
- [六大核心能力](#六大核心能力)
- [五大功能实例](#五大功能实例)
- [快速上手](#快速上手)
- [目录结构](#目录结构)
- [论文附件说明](#论文附件说明)
- [开源协议](#开源协议)

---

## 项目概述

OpenWild Agent 基于乐鑫 ESP-Claw 框架，在 ESP32-S3 受限开发板上实现了完整的 AI Agent 架构。平台以单块 ESP32-S3 开发板为核心，用 12 个 Lua 模块协同工作，在 84KB 程序空间内实现了"感知—决策—执行—记忆—学习"闭环，支撑 5+N 个功能实例并发运行。

### 项目定位

- **不是单一监测设备，而是野外智能体"操作系统"**
- 以百元级硬件成本（475 元），实现原本需要专业级设备（>5000 元）才能完成的野外智能任务
- 代码与文档全部开源，促进生态共建

### 技术指标

| 指标 | 数值 |
|:-----|:-----|
| 主控芯片 | ESP32-S3（240MHz / 512KB RAM / 4MB PSRAM） |
| 程序总规模 | 84,260 字节（12 个 Lua 模块） |
| 图像识别准确率 | 92%（10 种测试动物） |
| 端到端识别延迟 | < 10 秒（含拍照 + 云端 LLM + 飞书推送） |
| 平台稳定运行 | 连续 5 天无崩溃 |
| 气象数据采集 | 单日最多 720 条记录 |
| AI 识别成功率 | 100%（云端视觉方案） |
| 连续触发稳定性 | 10 次连续触发无崩溃 |
| 硬件成本 | 475 元（USB 供电版）|

---

## 硬件清单

> 完整内容见论文附件 4。

| 组件 | 型号 | 单价 | 数量 | 说明 |
|:-----|:-----|-----:|:----:|:-----|
| 主控板 | ESP32-S3-DevKitC | 35 元 | 1 | 核心主控 |
| 红外对射传感器 | 槽型光电 | 5 元 | 1 | 动物门口触发 |
| 雷达传感器 | HLK-LD112 | 3 元 | 1 | 巢穴内动物检测 |
| 温湿度传感器 | DHT11 | 5 元 | 1 | 巢穴环境监测 |
| 加热片 | 5V 1.5A | 18 元 | 1 | 温度调控 |
| 风扇 | 5V 200mA | 10 元 | 1 | 温度调控 |
| 雾化器 | 5V 500mA | 8 元 | 1 | 湿度调控 |
| LED 灯 | WS2812B | 4 元 | 1 | 状态指示 |
| USB 摄像头 | UVC 协议 | 15 元 | 1 | 动物拍照 |
| OLED 屏幕 | 2 寸 SPI | 12 元 | 1 | 本地状态显示 |
| 气象仪 | DFRobot EDU0157 | 300 元 | 1 | 六要素气象数据 |
| 散件 | 三极管/电阻等 | 20 元 | 1 套 | 辅助电路 |
| 18650 锂电池 ×2 | 3.7V 6800mAh 并联 | 40 元 | 2 节 | 野外供电 |
| **合计** | | **475 元** | | |

> 野外版另加光伏供电系统（两块 5V 太阳能板 + 保护电路），整套预算约 550 元，可长期无人值守运行。

### 接线说明

ESP32-S3 GPIO 分配（完整版）：

| GPIO | 功能 | 组件 |
|:----:|:-----|:-----|
| GPIO5 | 雷达信号输入 | HLK-LD112 多普勒雷达 |
| GPIO6 | OLED SCL | I2C 时钟 |
| GPIO7 | OLED SDA | I2C 数据 |
| GPIO9 | DHT11 数据 | 温湿度传感器 |
| GPIO10 | 红外触发输入 | 槽型光电红外对射传感器 |
| GPIO13 | 风扇控制 | PWM 调速 |
| GPIO14 | 加热片控制 | PWM 调速 |
| GPIO17 | 气象仪 TX | UART 发送 |
| GPIO18 | 气象仪 RX | UART 接收 |
| GPIO21 | 雾化器控制 | 开关控制 |

![GPIO 分配表](docs/images/OpenWild-Agent-图6-GPIO分配表.png)

---

## 软件架构

> 完整内容见论文附件 5、附件 6。

### 12 个 Lua 模块清单

| 类别 | 模块 | 大小 | 版本 | 关键作用 |
|:-----|:-----|-----:|:----:|:---------|
| **主控** | `main.lua` | 9,913B | V17b | UART 气象仪 + 红外触发调度 + AGENT 模块加载 |
| **主控** | `yeshengdongwu17a/b.lua` | 16,862B | V17b | 动物识别 + PSRAM 修复 + 云端视觉 |
| **AGENT** | `agent_memory.lua` | 8,457B | V7.7 | 记忆模块：气象数据 2 天保留 + 物种记录不清理 |
| **AGENT** | `agent_learning.lua` | 12,733B | V7.5 | 学习模块：5 核心问题自适应（季节/天气/物种/关系/LLM） |
| **AGENT** | `agent_chat.lua` | 5,662B | V7.3 | 对话模块：7 种自然语言查询（天气/物种/分析/配置/洞察/季节/偏好） |
| **AGENT** | `agent_self_monitor.lua` | 2,017B | V7.3 | 监控模块：内存/WiFi 告警 + /blog/ 自动清理 |
| **功能** | `AI_blogger.lua` | 11,682B | v2.7.8 | AI 博主：小红书风格笔记生成（11 处 GC 防御） |
| **功能** | `display.lua` | 2,594B | V17b | OLED 屏幕状态显示 |
| **功能** | `incubator.lua` | 3,905B | V17b | 孵蛋模式：37.5-38.5°C 恒温 + 21 天倒计时 |
| **功能** | `cloud_vision.lua` | 4,389B | V17b | 云端视觉：base64 编码 + http 直连云端 LLM |
| **功能** | `check.lua` | 5,174B | v4 | 存储诊断：启动清理 /photos/ + /blog/ |
| **参考** | `cfg.md` | 872B | — | 野外部署 4 项参数调整清单（不部署到设备） |
| | **合计** | **84,260B** | | |

---

## 模块依赖关系

### 调用矩阵

调用方 \ 被调用方：

| 调用方 ↓ / 被调用方 → | main | 17b | mem | lrn | chat | mon | blog | disp | inc | cv | check |
|:---|:---:|:---:|:---:|:---:|:---:|:---:|:---:|:---:|:---:|:---:|:---:|
| **main.lua** | — | dofile | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | 启动时 |
| **yeshengdongwu17b.lua** | | — | ✓ | ✓ | | ✓ | ✓ | ✓ | ✓ | | |
| **agent_memory.lua** | | | — | | ✓ | | | | | | |
| **agent_learning.lua** | | ✓ | | — | | | | | | | |
| **agent_chat.lua** | | ✓ | ✓ | | — | | | | | | |
| **agent_self_monitor.lua** | | ✓ | | | | — | | | | | ✓ |
| **AI_blogger.lua** | | ✓ | ✓ | | | | — | ✓ | | ✓ | |
| **display.lua** | | ✓ | | | | | | — | | | |
| **incubator.lua** | | ✓ | ✓ | | | | | | — | | |
| **cloud_vision.lua** | | | | | | | | | | — | |

### 四条关键调用链路

```
① 系统上电链路
   main → agent_memory → display（启动屏）→ main 循环

② 红外触发链路（GPIO10 == 0）
   main → yeshengdongwu17b（dofile）→ cloud_vision → mem.logSpecies → 飞书推送 → 返回 main

③ AGENT 查询链路（飞书消息）
   飞书 → main → agent_chat → agent_memory / agent_learning（查询）→ chat 回推

④ AI 博主链路（触发后每 4 小时）
   agent_memory → AI_blogger → cloud_vision → 飞书推送
```

### 模块关系图

```
                    ┌──────────────────────────────────────────┐
                    │              用户交互层                  │
                    │     飞书 / 微信 / Telegram 自然语言      │
                    └──────────────────┬───────────────────┘
                                       │
                    ┌──────────────────▼───────────────────┐
                    │         ESP-Claw 智能体框架            │
                    │                                      │
                    │  ┌────┐ ┌────┐ ┌────┐ ┌────┐        │
                    │  │mem│ │lrn │ │chat│ │mon │        │  ← 4 个 AGENT 模块
                    │  └──┬─┘ └──┬─┘ └──┬─┘ └──┬─┘        │
                    │     │      │      │      │          │
                    │     └──────┼──────┼──────┘          │
                    │            │      │                  │
                    │  ┌─────────▼──────▼────────┐        │
                    │  │    cloud_vision / web_search │     │  ← 工具层
                    │  └─────────┬──────┬─────────┘        │
                    └────────────┼──────┼────────────────┘
                                 │      │
         ┌───────────────────────┼──────┼───────────────────────┐
         │                       │      │                       │
         │  ┌────────────────────▼──────▼────────────────┐       │
         │  │  main.lua（气象站主程序，V17b）           │       │
         │  │  ├─ agent_memory    ├─ agent_chat         │       │
         │  │  └─ agent_learning  └─ agent_self_monitor │       │
         │  └────────────────────┬─────────────────────┘       │
         │                       │ 红外触发时 dofile              │
         │  ┌────────────────────▼─────────────────────┐        │
         │  │  yeshengdongwu17b.lua（野生动物监测，V17b）│        │
         │  │  ├─ cloud_vision   ├─ AI_blogger      │        │
         │  │  ├─ incubator      ├─ display         │        │
         │  │  └─ agent_memory   └─ agent_learning   │        │
         │  └────────────────────┬─────────────────────┘        │
         │                       │                                │
         │  ┌────────────────────▼─────────────────────┐        │
         │  │          硬件抽象层（HAL）              │        │
         │  │  GPIO / UART / Camera / I2C / LED     │        │
         │  └────────────────────────────────────────┘        │
         └──────────────────────────────────────────────────────┘
```

---

## 六大核心能力

> 完整说明见论文正文 §2.3.3。

| 能力 | 模块 | 说明 |
|:-----|:-----|:-----|
| **会"想"** Planning | agent_learning | 动态任务规划，wildlife_detect / nest_maintain / incubator_run 任务模板 |
| **会"记"** Memory | agent_memory | JSONL 存储 + 标签检索，weather_log / species_log / system_log / learning_log |
| **会"学"** Learning | agent_learning | 5 核心问题自适应（季节 / 天气 / 物种偏好 / 行为模式 / LLM 分析） |
| **会"聊"** Chat | agent_chat | 7 种自然语言查询，支持飞书/微信远程问询与配置 |
| **会"顾"** Self-Monitor | agent_self_monitor | 内存 < 10KB 警告 / WiFi < -75dBm 警告 / 自动清理 |
| **会"省"** Adaptive | agent_self_monitor | 自修复自完善，夜间降频 + 弱网延迟调整 |

---

## 五大功能实例

> 完整说明见论文正文 §2.3.5 及附件 7。

| 实例 | 功能 | 实测数据 |
|:-----|:-----|:---------|
| **实例一：野外气象站** | UART 气象仪采集六要素数据，自动飞书报告 | 单日 720 条记录，连续 4 天稳定推送 |
| **实例二：野生动物之家** | 红外触发 → 拍照 → 云端识别 → 巢穴维护 | 端到端延迟 < 10 秒，识别准确率 92% |
| **实例三：元宇宙远程观察** | 飞书聊天记录作为"元宇宙入口"，实时推送 | 查询响应 < 200ms |
| **实例四：教育科普** | AI 博主自动生成小红书笔记 + 飞书互动问答 | 已发布 9 篇笔记 |
| **实例五：科研数据** | JSONL 本地存储 + 飞书云端双备份 | 13 种动物 32 次访问记录 |
| **实例 N：聊天造物** | 自然语言生成新功能模块（如 fire_monitor.lua） | 30 秒内生成完毕 |

---

## 快速上手

### 前置要求

必须先正确配置 ESP-Claw 开发环境。详细步骤见 [docs/esp-claw-setup.md](./docs/esp-claw-setup.md)。

### 硬件准备

1. 购买上表所列硬件清单（总成本 475 元）
2. 按 GPIO 分配表接线
3. 参考论文附件 4 硬件连接图

### 刷入固件

```bash
# 1. 克隆本仓库
git clone https://github.com/liluwei-star/OpenWild-Agent.git
cd OpenWild-Agent

# 2. 进入 ESP-Claw 项目目录（需先安装 ESP-IDF）
# 假设 esp-claw 安装在 ~/esp/esp-claw
cd ~/esp/esp-claw

# 3. 激活 ESP-IDF 环境
source export.sh

# 4. 配置 menuconfig（设置 WiFi、摄像头参数等）
idf.py menuconfig

# 5. 编译并部署
idf.py build
```

### 配置说明

**版本一（AGENT 内置版）**：无需配置图像识别 API，直接使用内置 LLM 进行识别。适合入门用户。

**版本二（独立 LLM 版）**：需要配置 `scripts/user/config/cloud_vision.lua`，填入你的 API Key 和 Endpoint。识别精度更高，适合有 API 使用经验的用户。

配置详情见各版本目录下的 README.md。

---

## 目录结构

```
OpenWild-Agent/
├── README.md                    # 本文件（项目总览）
├── LICENSE                      # Apache 2.0
├── .gitignore                   # Git 忽略规则
├── media/                       # 演示视频
│   └── demo-1080p.mp4          # 演示视频（29MB）
├── docs/                        # 详细文档
│   ├── esp-claw-setup.md        # ESP-IDF + ESP-Claw 配置完整指南
│   ├── hardware-diy.md          # 自制硬件详细说明（晴雨板/饮水器等）
│   └── images/                  # 论文图片
│       ├── 正视图.jpg
│       ├── 侧视图.jpg
│       ├── 后视图.jpg
│       └── *.jpg                # 其他图片
├── version1-agent/              # 版本一：AGENT 内置版（无需额外 API）
│   ├── README.md                # 版本一专属文档
│   ├── config/                  # ★ ESP-Claw 配置目录
│   │   └── animal_env.json     # 物种环境配置
│   ├── data/                    # ★ JSONL 数据目录（运行时生成）
│   └── scripts/user/           # ★ Lua 脚本目录
│       ├── main.lua             # 气象站主程序（9,913B）
│       ├── yeshengdongwu17a.lua # 野生动物监测（16,531B）
│       ├── AI_blogger.lua       # AI 博主（11,599B）
│       ├── cloud_vision.lua     # 云端视觉内置版（4,389B）
│       ├── display.lua          # OLED 显示（2,594B）
│       ├── incubator.lua        # 孵蛋模式（3,905B）
│       ├── check.lua            # 存储诊断（1,555B）
│       ├── animal_db.lua        # 动物数据库（2,148B）
│       └── agent/               # AGENT 模块目录
│           ├── agent_memory.lua       # 记忆（6,501B）
│           ├── agent_learning.lua    # 学习（11,131B）
│           ├── agent_chat.lua        # 对话（5,662B）
│           └── agent_self_monitor.lua # 监控（2,017B）
│
└── version2-standalone/         # 版本二：独立 LLM 识别版（需配置 API）
    ├── README.md                # 版本二专属文档
    ├── config/                  # ★ ESP-Claw 配置目录
    │   ├── animal_db.lua        # 动物数据库（2,067B）
    │   └── animal_env.json      # 物种环境配置
    ├── data/                    # ★ JSONL 数据目录（运行时生成）
    └── scripts/user/            # ★ Lua 脚本目录
        ├── main.lua             # 气象站主程序（10,756B）
        ├── yeshengdongwu17b.lua # 野生动物监测（17,807B）
        ├── AI_blogger.lua       # AI 博主（27,464B）
        ├── cloud_vision.lua      # ★ 云端视觉独立配置版（4,572B）
        ├── display.lua          # OLED 显示（2,594B）
        ├── incubator.lua        # 孵蛋模式（3,905B）
        ├── check.lua            # 存储诊断（6,975B）
        ├── cfg.md               # 野外部署参数参考
        └── agent/               # AGENT 模块目录（与版本一相同）
```

---

## 论文明件说明

本仓库的 README 与论文附件内容对应关系：

| 论文附件 | 对应内容 |
|:--------|:---------|
| **附件 1** | 破窗力学分析（车辆破窗装置，本项目前身） |
| **附件 2** | 多物理场信号感知（传感器物理原理） |
| **附件 3** | 项目难点和亮点（识别率 / PSRAM / 稳定性三大难点） |
| **附件 4** | 硬件清单 + 连接图 + 开源地址 → 本 README §硬件清单 |
| **附件 5** | 软件清单 + 模块依赖关系 + 调用矩阵 → 本 README §软件架构 + §模块依赖关系 |
| **附件 6** | 主要程序关系图 + 详细流程图 → 本 README §模块关系图 |
| **附件 7** | 详细测试流程 → 本 README §项目概述实测数据 |

---

## 开源协议

本项目采用 **Apache License 2.0** 开源许可证。

- 允许任何人自由使用、修改、分发本项目代码
- 包括商业用途
- 唯一要求：保留 LICENSE 文件和版权声明

---

## 致谢

本项目基于乐鑫 ESP-Claw 框架构建，感谢乐鑫开源社区的支持。

## 联系作者

GitHub：[github.com/liluwei-star](https://github.com/liluwei-star)
