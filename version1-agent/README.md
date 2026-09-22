# OpenWild Agent — 版本一（AGENT 内置版）

**无需配置任何 API Key，接入 WiFi 即可直接运行。适合零基础入门。**

---

## 本版本与版本二的区别

| 对比项 | 版本一（内置版） | 版本二（独立 LLM 版） |
|:-------|:----------------|:----------------------|
| **图像识别** | 内置 LLM，无需配置 | 需要单独配置 `cloud_vision.lua` |
| **API 费用** | 零成本 | 需要自备 API 费用 |
| **配置难度** | 零配置 | 需要配置 API Key |
| **适合人群** | 初学者、入门用户 | 有 API 使用经验的用户 |
| **摄像头** | USB UVC 摄像头 | OV2640 或 USB 摄像头 |

---

## 硬件要求

| 组件 | 型号 | 数量 | 说明 |
|:-----|:-----|:----:|:-----|
| 主控板 | ESP32-S3-DevKitC | 1 | 核心主控 |
| USB 摄像头 | 支持 UVC 协议 | 1 | 对准巢穴内部拍摄 |
| DHT11 | 温湿度传感器 | 1 | GPIO9 |
| 红外对射传感器 | 槽型光电 | 1 | GPIO10，动物门口触发 |
| HLK-LD112 雷达 | 多普勒雷达 | 1 | GPIO5，巢穴内动物检测 |
| 加热片 | 5V 1A | 1 | GPIO14，温度调控 |
| 风扇 | 5V 200mA | 1 | GPIO13，温度调控 |
| 雾化器 | 5V 500mA | 1 | GPIO21，湿度调控 |
| OLED 屏幕 | 2 寸 SPI | 1 | I2C 接口 |
| DFRobot EDU0157 | 云雀气象仪 | 1 | GPIO17/18，UART 通信 |
| 18650 锂电池 ×2 | 3.7V 6800mAh | 2 节 | 并联供电 |
| 晴雨板 + 自制支架 | 亚克力板 | 1 | 定制，详见 docs/hardware-diy.md |
| 应急饮水器 | 鸟/宠物饮水器 | 1 | 详见 docs/hardware-diy.md |

---

## GPIO 引脚分配

| GPIO | 功能 | 备注 |
|:-----|:-----|:-----|
| GPIO5 | HLK-LD112 雷达信号 | 多普勒雷达检测巢穴内动物 |
| GPIO6 | OLED SCL | I2C 时钟 |
| GPIO7 | OLED SDA | I2C 数据 |
| GPIO9 | DHT11 数据 | 温湿度传感器 |
| GPIO10 | 红外对射传感器 | 动物门口触发，低电平有效 |
| GPIO13 | 风扇控制 | PWM 调速 |
| GPIO14 | 加热片控制 | PWM 调速 |
| GPIO17 | 气象仪 TX | UART 发送 |
| GPIO18 | 气象仪 RX | UART 接收 |
| GPIO21 | 雾化器控制 | 开关控制 |

![GPIO 分配表](../docs/images/OpenWild-Agent-图6-GPIO分配表.png)

---

## 目录结构

```
version1-agent/
├── README.md                # 本文件
├── config/                  # ★ ESP-Claw 配置目录（部署到设备 /fatfs/config/）
│   └── animal_env.json     # 物种环境配置（运行时由 yeshengdongwu17a 写入）
├── data/                   # ★ JSONL 数据目录（部署到设备 /fatfs/data/）
│   ├── weather_log.jsonl    # 气象数据日志
│   ├── species_log.jsonl    # 物种访问日志
│   ├── system_log.jsonl    # 系统状态日志
│   └── learning_log.jsonl   # AGENT 学习日志
└── scripts/user/           # ★ Lua 脚本目录（部署到设备 /fatfs/scripts/user/）
    ├── main.lua            # 气象站主程序（9,913B）
    ├── yeshengdongwu17a.lua # 野生动物监测主程序（16,531B）
    ├── AI_blogger.lua      # AI 博主（11,599B）
    ├── display.lua         # OLED 显示（2,594B）
    ├── incubator.lua       # 孵蛋模式（3,905B）
    ├── check.lua           # 存储诊断（1,555B）
    ├── cloud_vision.lua    # 云端视觉（内置版本，无 API 费用，4,389B）
    ├── animal_db.lua       # 动物数据库（2,148B）
    └── agent/              # ★ AGENT 模块目录
        ├── agent_memory.lua        # 记忆模块（6,501B）
        ├── agent_learning.lua      # 学习模块（11,131B）
        ├── agent_chat.lua          # 对话模块（5,662B）
        └── agent_self_monitor.lua  # 监控模块（2,017B）
```

> **说明**：config/ 和 data/ 是 ESP-Claw 的根级目录，通过 `idf.py openocd` 或 `espowershell` 工具复制到设备的 `/fatfs/config/` 和 `/fatfs/data/`。

---

## 软件模块清单（版本一，共 11 个模块）

| 类别 | 模块 | 文件大小 | 版本 | 功能描述 |
|:-----|:-----|--------:|:----:|:---------|
| 主控 | `main.lua` | 9,913B | V17b | 气象站主程序，系统状态机 |
| 主控 | `yeshengdongwu17a.lua` | 16,531B | V17b | 野生动物监测主程序，PSRAM 修复版 |
| AGENT | `agent_memory.lua` | 6,501B | V7.7 | 记忆模块：气象数据 2 天保留 + 物种记录不清理 |
| AGENT | `agent_learning.lua` | 11,131B | V7.5 | 学习模块：5 核心问题自适应 |
| AGENT | `agent_chat.lua` | 5,662B | V7.3 | 对话模块：7 种自然语言查询 |
| AGENT | `agent_self_monitor.lua` | 2,017B | V7.3 | 监控模块：内存/WiFi 告警 |
| 功能 | `AI_blogger.lua` | 11,599B | v2.7.8 | AI 博主：小红书风格笔记生成 |
| 功能 | `display.lua` | 2,594B | V17b | OLED 屏幕状态显示 |
| 功能 | `incubator.lua` | 3,905B | V17b | 孵蛋模式：37.5-38.5°C 恒温 |
| 功能 | `cloud_vision.lua` | 4,389B | V17b | 云端视觉（内置版，零 API 费用） |
| 功能 | `check.lua` | 1,555B | v4 | 存储诊断：启动清理 /photos/ + /blog/ |

---

## 模块依赖关系

### 调用矩阵（✓ 表示调用）

| 调用方 ↓ / 被调用方 → | main | 17a | mem | lrn | chat | mon | blog | disp | inc | cv | check |
|:---|:---:|:---:|:---:|:---:|:---:|:---:|:---:|:---:|:---:|:---:|:---:|
| **main.lua** | — | dofile | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | 启动时 |
| **yeshengdongwu17a.lua** | | — | ✓ | ✓ | | ✓ | ✓ | ✓ | ✓ | 内置 | ✓ |
| **agent_memory.lua** | | | — | | ✓ | | | | | | |
| **agent_learning.lua** | | ✓ | | — | | | | | | | |
| **agent_chat.lua** | | ✓ | ✓ | | — | | | | | | |
| **agent_self_monitor.lua** | | ✓ | | | | — | | | | | ✓ |
| **AI_blogger.lua** | | ✓ | ✓ | | | | — | ✓ | | ✓ | |

### 四条关键调用链路

```
① 系统上电链路
   main → agent_memory → display（启动屏）→ main 循环

② 红外触发链路（GPIO10 == 0）
   main → yeshengdongwu17a（dofile）→ 视觉识别 → mem.logSpecies → 飞书推送 → 返回 main

③ AGENT 查询链路（飞书消息）
   飞书 → main → agent_chat → agent_memory / agent_learning（查询）→ chat 回推

④ AI 博主链路（触发后每 4 小时）
   agent_memory → AI_blogger → 飞书推送
```

---

## 飞书配置说明

版本一使用飞书消息推送，需要在 ESP-IDF menuconfig 中配置以下参数：

```
Component config → Feishu Message
├── FEISHU_APP_ID          # 飞书应用 App ID
├── FEISHU_APP_SECRET      # 飞书应用 App Secret
├── FEISHU_BOT_NAME        # 机器人名称（可选）
└── FEISHU_ALLOW_USER_IDS   # 允许查询的用户 ID，多个用逗号分隔
```

**创建飞书机器人的步骤：**

1. 打开 [飞书开放平台](https://open.feishu.cn/app)，创建企业自建应用
2. 在「凭证与基础信息」中获取 `App ID` 和 `App Secret`
3. 在「应用功能」→「机器人」中开启机器人能力
4. 在「权限管理」中添加以下权限：
   - `im:message:send_as_bot`（发送消息）
5. 发布应用后，将 `App ID` 和 `App Secret` 填入 menuconfig
6. 在目标群组中添加机器人，即可接收推送

> 本文件中飞书用户 ID 已替换为占位符 `ou_XXXXXXXXXXXXXXXXXXXXXXXX`，请替换为实际 ID。

---

## 数据存储说明

运行时生成的数据文件（位于 `/fatfs/data/`）：

| 文件 | 内容 | 保留策略 |
|:-----|:-----|:---------|
| `weather_log.jsonl` | 气象数据（温度/湿度/风速/气压等） | 按日期保留 2 天 |
| `species_log.jsonl` | 物种访问记录（时间/物种/环境） | 不自动清理（科研价值） |
| `system_log.jsonl` | 系统状态（内存/WiFi/运行时间） | 每小时记录 1 次 |
| `learning_log.jsonl` | AGENT 学习结果（阈值调整/分析） | 每日记录 |

---

## PSRAM 碎片化问题与解决方案

版本一基于 `yeshengdongwu17a.lua`，包含完整的 PSRAM 碎片化解决方案（17 处 GC + 4 阶段防御），确保连续触发 10 次无崩溃。

**问题现象：** 连续触发红外 3-5 次后，`camera.open()` 返回 false，拍照彻底失败。

**根因：** 连续触发下 PSRAM 碎片化严重：DHT 位采样、雷达/GPIO 检查、飞书 JSON 解析、知识库遍历等 Lua 分配把 PSRAM 切碎，导致 DMA 缓冲区分配失败。

**解决方案：**
```lua
-- 1. closeCameraHard()：多次关闭 + 800ms 等待 + 2 次 collectgarbage
-- 2. cap() 4 阶段防御：关闭 → 重试 → 丢帧 → 拍照
-- 3. 17 处 collectgarbage 嵌入（主程序 6 处 + AI 博主 11 处）
-- 4. cleanupBeforeReturn()：退出前强制清理
```

---

## 常见问题

**Q：红外触发后没有反应？**
A：检查 GPIO10 是否正确连接红外对射传感器，确保触发时为低电平。

**Q：摄像头无法打开？**
A：本版本使用 USB UVC 摄像头，确保摄像头插入 USB 口后在 `menuconfig` 中正确选择 Camera Type 为 USB UVC。

**Q：飞书收不到消息？**
A：在 `menuconfig` 中确认 App ID、App Secret 配置正确，且飞书机器人已加入目标群组。

**Q：气象数据采集异常？**
A：检查 GPIO17/18 的 UART 接线，确保气象仪 EDU0157 波特率配置为 115200。

---

## 自制硬件说明

晴雨板、雨水收集器、雾化导流槽、应急饮水器的自制方法详见 `docs/hardware-diy.md`。

---

## 开源协议

Apache License 2.0 — 详见项目根目录 `LICENSE`。
