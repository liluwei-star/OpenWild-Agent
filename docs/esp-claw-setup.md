# ESP-Claw Setup Guide

OpenWild Agent is built on the Espressif ESP-Claw framework. ESP-Claw must be correctly set up before using this project.

## What is ESP-Claw

ESP-Claw (https://github.com/espressif/esp-claw) is Espressif's official open-source AI Agent development framework, encapsulating LLM dialogue, tool calling, and agent loop capabilities. This project extends ESP-Claw with specialized modules for outdoor agents (weather monitoring, image capture, intelligent decision-making, etc.).

## Environment Setup

### Hardware Requirements

- **Development Board**: ESP32-S3 (recommended ESP32-S3-N16R2 or better, RAM ≥ 2MB)
- **Computer**: Windows 10/11, macOS, or Linux
- **Storage Card**: MicroSD card (8GB+, for storing photos and logs)

### Software Dependencies

| Software | Version | Notes |
|:---------|:--------|:------|
| Python | ≥ 3.10 | Script execution and package management |
| ESP-IDF | 5.3+ | Espressif official SDK |
| VS Code | Latest | Code editing (recommended) |
| git | Latest | Version control |

> **Note**: ESP-IDF 5.3 includes all dependencies required by ESP-Claw. Installing once supports both standard ESP32 development and advanced Agent development.

---

## Installation Steps (Windows)

### Step 1: Install ESP-IDF Offline Package (One-Click, Recommended)

Espressif provides a full offline installer containing ESP-IDF 5.3, cross-compilers, Python environment, and all dependencies. **No need to install Python or CMake separately.**

1. Open https://dl.espressif.com/dl/esp-idf/
2. Download `esp-idf-setup-x.x.exe` (version number as per latest on page)
3. Run the installer. Recommended install path: `C:\Espressif`
4. The installer will prompt to select "Full Install". Ensure these are checked:
   - ESP-IDF 5.3+
   - Python
   - Serial drivers
5. Wait for installation to complete (~15–30 minutes)

> **If you had a previous ESP-IDF installation**, it is recommended to uninstall the old version first to avoid path conflicts.

### Step 2: Verify Installation

After installation, open "ESP-IDF 5.3 CMD" (Start Menu → Espressif folder) and run:

```bash
idf.py --version
```

If it shows a version like `v5.3.1`, installation succeeded.

### Step 3: Clone ESP-Claw Official Repository

Create a working directory in a suitable location. Open "ESP-IDF 5.3 CMD" and run:

```bash
cd %USERPROFILE%
git clone https://github.com/espressif/esp-claw.git esp-claw
cd esp-claw
git submodule update --init --recursive
```

> **About submodules**: ESP-Claw depends on multiple submodules (HTTP client, JSON parser, etc.). `git submodule update` must be run on first clone, otherwise compilation will fail with missing header errors.

### Step 4: Create Your First Agent Project

```bash
cd esp-claw
idf.py create-project my-agent
cd my-agent
idf.py set-target esp32s3
idf.py menuconfig
```

In `menuconfig`, configure (paths may vary slightly by version):

```
Component config → ESP AI Agent
  → Enable ESP AI Agent [Y]
  → Enable LLM (Large Language Model) support [Y]
  → Select LLM provider → OpenAI / MiniMax / custom

ESP AI Agent Configuration
  → WiFi SSID → your WiFi name
  → WiFi Password → your WiFi password
```

Save and exit `menuconfig`.

### Step 5: Run the Official Example

ESP-Claw includes a complete dialogue example to verify the environment:

```bash
cd esp-claw/examples/getting_started
idf.py build
idf.py -p COM3 flash monitor
```

Use the serial monitor (115200 baud) to view output. "Agent started" means the environment is working correctly.

> **COM port number**: On Windows, find the COM number in "Device Manager → Ports (COM & LPT)".

---

## ESP-Claw Directory Structure (Quick Guide)

```
esp-claw/
├── examples/               # Official examples (key references)
│   ├── getting_started/    # Minimal runnable project for beginners
│   └── tools/              # Tool registration example
├── components/
│   ├── esp-agent/          # Agent core (loop, message dispatch)
│   ├── llm/                # LLM adapter layer (OpenAI/MiniMax/custom)
│   ├── tools/              # Built-in toolset (file system/network/hardware)
│   └── ui/                 # Screen interaction
├── docs/                   # Official documentation
└── README.md
```

**OpenWild Agent's directory structure follows esp-claw's `examples/` organization.**

---

## Common Issues

### Q1: idf.py command "command not found"

Make sure you opened "ESP-IDF CMD" (green icon) from the Start Menu, not a regular CMD window. Use the Espressif-provided terminal.

### Q2: idf.py menuconfig shows garbled text

This is a Windows encoding issue. It does not affect actual configuration. You can directly edit the `sdkconfig` file (in the same directory as `CMakeLists.txt`), search for the option and change its value:

```bash
# Example: set WiFi
CONFIG_ESP_WIFI_SSID="MyWiFi"
CONFIG_ESP_WIFI_PASSWORD="MyPassword"
```

### Q3: Compilation error "undefined reference to `esp_agent_init`"

Run `git submodule update --init --recursive` to re-download submodules, then clean and rebuild:

```bash
idf.py fullclean
idf.py build
```

### Q4: Flash fails (MAC address error, etc.)

Hold the "BOOT" button on the development board, press "RESET" (EN) once, then reflash:

```bash
idf.py -p COM3 -b 921600 flash
```

### Q5: WiFi won't connect

- Confirm SSID and password are correct (case-sensitive)
- Confirm the router is 2.4GHz (ESP32-S3 does not support 5GHz)
- Confirm no enterprise WPA authentication (campus networks requiring portal authentication cannot be used directly)

### Q6: SD card initialization fails

- Format the SD card as FAT32
- Check SD card socket soldering quality
- In `menuconfig`, try setting SPI speed to `1MHz` first. If it works, increase later.

---

## Next Steps

After environment setup, return to the project README and choose your version:
- **Version 1 (AGENT)**: Built-in LLM recognition. No extra image recognition API config needed.
- **Version 2 (Standalone LLM)**: Requires configuring the image recognition endpoint in `cloud_vision.lua`.

See `version1-agent/README.md` or `version2-standalone/README.md` in the project root.
