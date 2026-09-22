# ESP-Claw 配置指南

OpenWild Agent 基于乐鑫 ESP-Claw 框架构建。在使用本项目前，必须先正确配置 ESP-Claw 环境。

## 什么是 ESP-Claw

ESP-Claw（地址：https://github.com/espressif/esp-claw）是乐鑫官方开源的 AI Agent 开发框架，封装了 LLM 对话、工具调用、Agent 循环等能力。本项目在此基础上扩展了野外智能体的专用模块（气象监测、图像采集、智能决策等）。

## 环境准备

### 硬件要求

- **开发板**：ESP32-S3（推荐 ESP32-S3-N16R2 或更好，RAM ≥ 2MB）
- **电脑**：Windows 10/11、macOS 或 Linux
- **存储卡**：MicroSD 卡（容量 8GB+，用于存储图片和日志）

### 软件依赖

| 软件 | 版本 | 说明 |
|------|------|------|
| Python | ≥ 3.10 | 脚本运行和包管理 |
| ESP-IDF | 5.3+ | 乐鑫官方 SDK |
| VS Code | 最新版 | 代码编辑（推荐） |
| git | 最新版 | 版本控制 |

> **注意**：ESP-IDF 5.3 包含 ESP-Claw 所需的全部依赖。安装一次即可同时支持标准 ESP32 开发和高阶 Agent 开发。

---

## 安装步骤（Windows）

### 第一步：安装 ESP-IDF 离线包（一键安装，推荐）

乐鑫提供全量离线安装包，包含了 ESP-IDF 5.3、交叉编译器、Python 环境等所有依赖，**无需单独安装 Python 或 CMake**。

1. 打开 https://dl.espressif.com/dl/esp-idf/
2. 下载 `esp-idf-setup-x.x.exe`（版本号以页面最新为准）
3. 运行安装程序，安装路径建议选择 `C:\Espressif`
4. 安装程序会提示选择"完整安装"，确保勾选：
   - ESP-IDF 5.3+
   - Python
   - 串口驱动
5. 等待安装完成（约 15～30 分钟）

> **如果之前安装过 ESP-IDF**，建议先卸载旧版再安装新版，以避免路径冲突。

### 第二步：验证安装

安装完成后，打开"ESP-IDF 5.3 CMD"（开始菜单 → Espressif 文件夹），输入：

```bash
idf.py --version
```

如果显示类似 `v5.3.1` 的版本号，说明安装成功。

### 第三步：克隆 ESP-Claw 官方仓库

在合适的位置新建工作目录，打开"ESP-IDF 5.3 CMD"，执行：

```bash
cd %USERPROFILE%
git clone https://github.com/espressif/esp-claw.git esp-claw
cd esp-claw
git submodule update --init --recursive
```

> ** submodule 说明**：ESP-Claw 依赖多个子模块（HTTP 客户端、JSON 解析等），首次 clone 必须执行 `git submodule update`，否则编译会报头文件缺失错误。

### 第四步：创建你的第一个 Agent 项目

```bash
cd esp-claw
idf.py create-project my-agent
cd my-agent
idf.py set-target esp32s3
idf.py menuconfig
```

在 `menuconfig` 中配置（路径因版本可能略有不同）：

```
Component config → ESP AI Agent
  → Enable ESP AI Agent [Y]
  → Enable LLM (Large Language Model) support [Y]
  → Select LLM provider → OpenAI / MiniMax / 自定义

ESP AI Agent Configuration
  → WiFi SSID → 你的WiFi名称
  → WiFi Password → 你的WiFi密码
```

保存并退出 `menuconfig`。

### 第五步：运行官方示例

ESP-Claw 自带一个完整的对话示例，验证环境是否正常：

```bash
cd esp-claw/examples/getting_started
idf.py build
idf.py -p COM3 flash monitor
```

用串口监视器（115200 波特率）查看输出，看到"Agent started"即代表环境正常。

> **串口编号**：Windows 上可在"设备管理器 → 端口（COM 和 LPT）"查看 ESP 开发板对应的 COM 编号。

---

## ESP-Claw 目录结构（快速扫盲）

```
esp-claw/
├── examples/               # 官方示例（重点参考）
│   ├── getting_started/    # 入门的最小可运行项目
│   └── tools/              # 工具注册示例
├── components/
│   ├── esp-agent/          # Agent 核心（循环、消息调度）
│   ├── llm/                # LLM 适配层（OpenAI/MiniMax/自定义）
│   ├── tools/              # 内置工具集（文件系统/网络/硬件）
│   └── ui/                 # 屏幕交互
├── docs/                   # 官方文档
└── README.md
```

**本项目（OpenWild Agent）的目录结构参照 esp-claw 的 `examples/` 组织方式。**

---

## 常见问题

### Q1：idf.py 命令提示"command not found"

在"开始菜单"中打开的是"ESP-IDF CMD"（绿色图标），不是普通 CMD 窗口。确保使用的是乐鑫提供的专用终端。

### Q2：idf.py menuconfig 界面乱码

这是 Windows 编码问题，不影响实际配置。可直接编辑 `sdkconfig` 文件（与 `CMakeLists.txt` 同目录），搜索对应选项并修改值：

```bash
# 示例：设置WiFi
CONFIG_ESP_WIFI_SSID="MyWiFi"
CONFIG_ESP_WIFI_PASSWORD="MyPassword"
```

### Q3：编译报错"undefined reference to `esp_agent_init`"

执行 `git submodule update --init --recursive` 重新下载子模块，然后 clean 并重新编译：

```bash
idf.py fullclean
idf.py build
```

### Q4：flash 失败（MAC 地址错误等）

按住开发板的"BOOT"按钮不放，再按一下"RESET"（EN）按钮，然后重新 flash：

```bash
idf.py -p COM3 -b 921600 flash
```

### Q5：WiFi 连不上

- 确认 SSID 和密码正确（区分大小写）
- 确认路由器是 2.4GHz 频段（ESP32-S3 不支持 5GHz）
- 确认没有企业级 WPA 认证（需用 Portal 认证的校园网无法直接使用）

### Q6：SD 卡初始化失败

- 格式化 SD 卡为 FAT32 格式
- 检查 SD 卡座焊接是否良好
- 在 `menuconfig` 中确认 SPI 速率设置为 `1MHz` 试运行，正常后再提高

---

## 下一步

环境配置完成后，回到项目 README，按版本选择对应文档：
- **版本一（AGENT）**：内置 LLM 识别，无需额外配置图像识别 API
- **版本二（独立LLM）**：需要配置 `cloud_vision.lua` 中的图像识别端点

参见项目根目录的 `VERSION1_README.md` 或 `VERSION2_README.md`。
