# OpenWild Agent — 版本二（独立 LLM 识别版）

**需要单独配置图像识别 API，识别精度更高，适合有 API 使用经验的用户。**

---

## 本版本与版本一的区别

| 对比项 | 版本二（独立 LLM 版） | 版本一（内置版） |
|:-------|:----------------------|:----------------|
| **图像识别** | 专用视觉 LLM API（GPT-4o Vision / Claude / Qwen-VL 等） | 内置 LLM，无需额外配置 |
| **识别模型** | 可自定义（可选择最强模型） | 内置模型，不可更换 |
| **API 费用** | 需要自备 API 费用 | 零成本 |
| **配置难度** | 需要配置 `cloud_vision.lua` | 零配置 |
| **适合人群** | 有 API 使用经验的用户 | 初学者 |

---

## 硬件要求

| 组件 | 型号 | 数量 | 说明 |
|:-----|:-----|:----:|:-----|
| 主控板 | ESP32-S3-DevKitC | 1 | 核心主控 |
| 摄像头 | OV2640 或 USB UVC | 1 | 对准巢穴内部拍摄 |
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
version2-standalone/
├── README.md                # 本文件
├── config/                  # ★ ESP-Claw 配置目录（部署到设备 /fatfs/config/）
│   ├── animal_db.lua       # 动物数据库（2,067B）
│   └── animal_env.json     # 物种环境配置（运行时由 yeshengdongwu17b 写入）
├── data/                   # ★ JSONL 数据目录（部署到设备 /fatfs/data/）
│   ├── weather_log.jsonl    # 气象数据日志
│   ├── species_log.jsonl    # 物种访问日志
│   ├── system_log.jsonl    # 系统状态日志
│   └── learning_log.jsonl   # AGENT 学习日志
└── scripts/user/          # ★ Lua 脚本目录（部署到设备 /fatfs/scripts/user/）
    ├── main.lua           # 气象站主程序（10,756B）
    ├── yeshengdongwu17b.lua # ★ 野生动物监测主程序（17,807B，含云端视觉）
    ├── AI_blogger.lua     # AI 博主（27,464B）
    ├── cloud_vision.lua   # ★ 云端视觉封装（需配置 API，4,572B）
    ├── display.lua        # OLED 显示（2,594B）
    ├── incubator.lua      # 孵蛋模式（3,905B）
    ├── check.lua          # 存储诊断（6,975B）
    ├── cfg.md             # 野外部署参数参考（不部署到设备）
    └── agent/            # ★ AGENT 模块目录
        ├── agent_memory.lua       # 记忆模块（6,501B）
        ├── agent_learning.lua     # 学习模块（11,131B）
        ├── agent_chat.lua        # 对话模块（5,662B）
        └── agent_self_monitor.lua # 监控模块（2,017B）
```

> **说明**：config/ 和 data/ 是 ESP-Claw 的根级目录，通过 `idf.py openocd` 或 `espowershell` 工具复制到设备的 `/fatfs/config/` 和 `/fatfs/data/`。

---

## 软件模块清单（版本二，共 12 个模块）

| 类别 | 模块 | 文件大小 | 版本 | 功能描述 |
|:-----|:-----|--------:|:----:|:---------|
| 主控 | `main.lua` | 10,756B | V17b | 气象站主程序，系统状态机 |
| 主控 | `yeshengdongwu17b.lua` | 17,807B | V17b | 野生动物监测主程序，含云端视觉集成 |
| AGENT | `agent_memory.lua` | 6,501B | V7.7 | 记忆模块：气象数据 2 天保留 + 物种记录不清理 |
| AGENT | `agent_learning.lua` | 11,131B | V7.5 | 学习模块：5 核心问题自适应 |
| AGENT | `agent_chat.lua` | 5,662B | V7.3 | 对话模块：7 种自然语言查询 |
| AGENT | `agent_self_monitor.lua` | 2,017B | V7.3 | 监控模块：内存/WiFi 告警 |
| 功能 | `AI_blogger.lua` | 27,464B | v2.7.8 | AI 博主：小红书风格笔记生成 |
| 功能 | `display.lua` | 2,594B | V17b | OLED 屏幕状态显示 |
| 功能 | `incubator.lua` | 3,905B | V17b | 孵蛋模式：37.5-38.5°C 恒温 |
| 功能 | `cloud_vision.lua` | 4,572B | V17b | 云端视觉（独立配置版，需填入 API Key） |
| 功能 | `check.lua` | 6,975B | v4 | 存储诊断：启动清理 /photos/ + /blog/ |
| 参考 | `cfg.md` | 920B | — | 野外部署 4 项参数调整清单（不部署到设备） |

---

## 模块依赖关系

### 调用矩阵（✓ 表示调用）

| 调用方 ↓ / 被调用方 → | main | 17b | mem | lrn | chat | mon | blog | disp | inc | cv | check |
|:---|:---:|:---:|:---:|:---:|:---:|:---:|:---:|:---:|:---:|:---:|:---:|
| **main.lua** | — | dofile | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | 启动时 |
| **yeshengdongwu17b.lua** | | — | ✓ | ✓ | | ✓ | ✓ | ✓ | ✓ | dofile | |
| **agent_memory.lua** | | | — | | ✓ | | | | | | |
| **agent_learning.lua** | | ✓ | | — | | | | | | | |
| **agent_chat.lua** | | ✓ | ✓ | | — | | | | | | |
| **agent_self_monitor.lua** | | ✓ | | | | — | | | | | ✓ |
| **AI_blogger.lua** | | ✓ | ✓ | | | | — | ✓ | | ✓ | |
| **cloud_vision.lua** | | dofile | | | | | | | | — | |

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

---

## 云端视觉配置（cloud_vision.lua）

版本二的核心区别在于 `cloud_vision.lua` 是独立配置文件，需要填入 API Key 和 endpoint。

**支持的视觉 LLM API：**

| 提供商 | 模型 | endpoint 示例 |
|:-------|:-----|:--------------|
| OpenAI | GPT-4o Vision | `https://api.openai.com/v1/chat/completions` |
| Claude (Anthropic) | Claude 3.5 Sonnet | `https://api.anthropic.com/v1/messages` |
| 阿里云 | Qwen-VL2 | `https://dashscope.aliyuncs.com/compatible-mode/v1/chat/completions` |
| 硅基流动 | Llama-3.2-Vision | `https://api.siliconflow.cn/v1/chat/completions` |
| 自建 | 任意兼容 OpenAI 格式 | 填入你的服务器地址 |

**配置方法：**

打开 `scripts/user/cloud_vision.lua`，找到以下段落并填入真实值：

```lua
-- ============================================================
-- API 配置（必须填写，否则无法使用云端视觉）
-- ============================================================
local CFG = {
    provider   = "openai",      -- 可选：openai / claude / qwen / siliconflow / custom
    api_key    = "sk-xxx...xxx", -- ★ 替换为你的 API Key
    model      = "gpt-4o",      -- 或 "claude-3-5-sonnet-20241014" 等
    endpoint   = nil,            -- 通常自动推断，可手动填入
    max_tokens = 512,
    timeout_ms = 30000,
}
```

> **安全提示**：API Key 是敏感信息。提交到 GitHub 前，请确保 `cloud_vision.lua` 中的 Key 已替换为占位符。本仓库默认包含占位符 `sk-xxx...xxx`，请自行替换。

---

## 飞书配置说明

版本二使用飞书消息推送，需要在 ESP-IDF menuconfig 中配置以下参数：

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

版本二基于 `yeshengdongwu17b.lua`，包含完整的 PSRAM 碎片化解决方案（17 处 GC + 4 阶段防御），确保连续触发 10 次无崩溃。

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

**Q：cloud_vision.lua 配置后仍然无法识别？**
A：检查 API Key 是否正确，endpoint 是否可访问。建议先用 curl 测试 API 是否正常工作。

**Q：识别延迟太长？**
A：云端视觉延迟取决于 API 提供商速度。可以在 `cloud_vision.lua` 中更换更快的模型。

**Q：连续触发后 camera.open 失败？**
A：这是 PSRAM 碎片化问题，V17b 版本已通过 17 处 GC + 4 阶段防御彻底解决。如仍有问题，检查是否使用了正确版本。

**Q：飞书收不到消息？**
A：在 `menuconfig` 中确认 App ID、App Secret 配置正确，且飞书机器人已加入目标群组。

---

## 自制硬件说明

晴雨板、雨水收集器、雾化导流槽、应急饮水器的自制方法详见 `docs/hardware-diy.md`。

---

## 开源协议

Apache License 2.0 — 详见项目根目录 `LICENSE`。
