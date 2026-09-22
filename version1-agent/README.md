# OpenWild Agent — Version 1 (AGENT Built-in)

**No API Key configuration required. Just connect to WiFi and it runs directly. Perfect for beginners.**

---

## How This Version Differs from Version 2

| Item | Version 1 (Built-in) | Version 2 (Standalone LLM) |
|:-----|:--------------------|:---------------------------|
| **Image Recognition** | Built-in LLM, no config needed | Requires separate `cloud_vision.lua` configuration |
| **API Cost** | Zero cost | User pays for API usage |
| **Setup Difficulty** | Zero config | Requires API key |
| **Target Users** | Beginners, first-time users | Users with API experience |
| **Camera** | USB UVC camera | OV2640 or USB camera |

---

## Hardware Requirements

| Component | Model | Qty | Notes |
|:----------|:------|:----:|:------|
| Main Board | ESP32-S3-DevKitC | 1 | Core controller |
| USB Camera | UVC protocol support | 1 | Aimed at nest interior |
| DHT11 | Temp/humidity sensor | 1 | GPIO9 |
| IR Beam Sensor | Slot-type photoelectric | 1 | GPIO10, door trigger |
| HLK-LD112 Radar | Doppler radar | 1 | GPIO5, in-nest detection |
| Heating Film | 5V 1A | 1 | GPIO14, temperature control |
| Fan | 5V 200mA | 1 | GPIO13, temperature control |
| Humidifier | 5V 500mA | 1 | GPIO21, humidity control |
| OLED Screen | 2-inch SPI | 1 | I2C interface |
| DFRobot EDU0157 | Lark weather station | 1 | GPIO17/18, UART |
| 18650 Li-ion ×2 | 3.7V 6800mAh | 2 | Parallel power supply |
| Rain shield + custom bracket | Acrylic sheet | 1 | See docs/hardware-diy.md |
| Emergency drinker | Bird/pet waterer | 1 | See docs/hardware-diy.md |

---

## GPIO Pin Assignment

| GPIO | Function | Notes |
|:-----|:---------|:------|
| GPIO5 | HLK-LD112 radar signal | Doppler radar, in-nest animal detection |
| GPIO6 | OLED SCL | I2C clock |
| GPIO7 | OLED SDA | I2C data |
| GPIO9 | DHT11 data | Temp/humidity sensor |
| GPIO10 | IR beam sensor | Door trigger, active low |
| GPIO13 | Fan control | PWM speed control |
| GPIO14 | Heating film control | PWM speed control |
| GPIO17 | Weather station TX | UART transmit |
| GPIO18 | Weather station RX | UART receive |
| GPIO21 | Humidifier control | On/off switch |

![GPIO Pinout](../docs/images/OpenWild-Agent-图6-GPIO分配表.png)

---

## Directory Structure

```
version1-agent/
├── README.md                # This file
├── config/                  # ★ ESP-Claw config directory (deployed to /fatfs/config/)
│   └── animal_env.json     # Species environment config (written by yeshengdongwu17a at runtime)
├── data/                   # ★ JSONL data directory (deployed to /fatfs/data/)
│   ├── weather_log.jsonl    # Weather data log
│   ├── species_log.jsonl    # Species visit log
│   ├── system_log.jsonl    # System status log
│   └── learning_log.jsonl   # AGENT learning log
└── scripts/user/           # ★ Lua scripts directory (deployed to /fatfs/scripts/user/)
    ├── main.lua            # Weather station main (9,913B)
    ├── yeshengdongwu17a.lua # Wildlife monitor main (16,531B)
    ├── AI_blogger.lua      # AI blogger (11,599B)
    ├── display.lua         # OLED display (2,594B)
    ├── incubator.lua       # Incubator mode (3,905B)
    ├── check.lua           # Storage diagnostics (1,555B)
    ├── cloud_vision.lua    # Cloud vision (built-in, zero API cost, 4,389B)
    ├── animal_db.lua       # Animal database (2,148B)
    └── agent/              # ★ AGENT module directory
        ├── agent_memory.lua        # Memory module (6,501B)
        ├── agent_learning.lua      # Learning module (11,131B)
        ├── agent_chat.lua          # Chat module (5,662B)
        └── agent_self_monitor.lua  # Monitor module (2,017B)
```

> **Note**: config/ and data/ are ESP-Claw root directories. Deploy to device `/fatfs/config/` and `/fatfs/data/` via `idf.py openocd` or `espowershell`.

---

## Software Module List (Version 1, 11 modules total)

| Category | Module | File Size | Version | Description |
|:---------|:-------|---------:|:-------:|:-----------|
| Main | `main.lua` | 9,913B | V17b | Weather station main, system state machine |
| Main | `yeshengdongwu17a.lua` | 16,531B | V17b | Wildlife monitor main, PSRAM fix included |
| AGENT | `agent_memory.lua` | 6,501B | V7.7 | Memory: 2-day weather retention + species records never cleared |
| AGENT | `agent_learning.lua` | 11,131B | V7.5 | Learning: 5 core question adaptation |
| AGENT | `agent_chat.lua` | 5,662B | V7.3 | Chat: 7 natural language query types |
| AGENT | `agent_self_monitor.lua` | 2,017B | V7.3 | Monitor: memory/WiFi alerts |
| Feature | `AI_blogger.lua` | 11,599B | v2.7.8 | AI blogger: Xiaohongshu-style post generation |
| Feature | `display.lua` | 2,594B | V17b | OLED status display |
| Feature | `incubator.lua` | 3,905B | V17b | Incubator mode: 37.5–38.5°C constant |
| Feature | `cloud_vision.lua` | 4,389B | V17b | Cloud vision (built-in, zero API cost) |
| Feature | `check.lua` | 1,555B | v4 | Storage diagnostics: startup cleanup /photos/ + /blog/ |

---

## Module Dependencies

### Call Matrix (✓ = calls)

| Caller ↓ / Callee → | main | 17a | mem | lrn | chat | mon | blog | disp | inc | cv | check |
|:---|:---:|:---:|:---:|:---:|:---:|:---:|:---:|:---:|:---:|:---:|:---:|
| **main.lua** | — | dofile | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | startup |
| **yeshengdongwu17a.lua** | | — | ✓ | ✓ | | ✓ | ✓ | ✓ | ✓ | built-in | ✓ |
| **agent_memory.lua** | | | — | | ✓ | | | | | | |
| **agent_learning.lua** | | ✓ | | — | | | | | | | |
| **agent_chat.lua** | | ✓ | ✓ | | — | | | | | | |
| **agent_self_monitor.lua** | | ✓ | | | | — | | | | | ✓ |
| **AI_blogger.lua** | | ✓ | ✓ | | | | — | ✓ | | ✓ | |

### Four Key Call Chains

```
① System Boot Chain
   main → agent_memory → display (splash) → main loop

② IR Trigger Chain (GPIO10 == 0)
   main → yeshengdongwu17a (dofile) → vision recognition → mem.logSpecies → Feishu push → return to main

③ AGENT Query Chain (Feishu message)
   Feishu → main → agent_chat → agent_memory / agent_learning (query) → chat push

④ AI Blogger Chain (every 4 hours post-trigger)
   agent_memory → AI_blogger → Feishu push
```

---

## Feishu Configuration

Version 1 uses Feishu message push. Configure the following in ESP-IDF menuconfig:

```
Component config → Feishu Message
├── FEISHU_APP_ID          # Feishu app App ID
├── FEISHU_APP_SECRET      # Feishu app App Secret
├── FEISHU_BOT_NAME        # Bot name (optional)
└── FEISHU_ALLOW_USER_IDS   # Comma-separated allowed user IDs
```

**Steps to create a Feishu bot:**

1. Open [Feishu Open Platform](https://open.feishu.cn/app) and create an enterprise self-built app
2. Get `App ID` and `App Secret` from "Credentials & Basic Info"
3. Enable bot capability in "App Features → Bot"
4. In "Permissions Management", add: `im:message:send_as_bot` (send messages)
5. After publishing, fill `App ID` and `App Secret` into menuconfig
6. Add the bot to your target group to receive pushes

> Feishu user IDs in this file have been replaced with placeholder `ou_XXXXXXXXXXXXXXXXXXXXXXXX`. Replace with your actual IDs.

---

## Data Storage

Runtime-generated data files (at `/fatfs/data/`):

| File | Content | Retention Policy |
|:-----|:--------|:----------------|
| `weather_log.jsonl` | Weather data (temp/humidity/wind speed/pressure, etc.) | 2 days by date |
| `species_log.jsonl` | Species visit records (time/species/environment) | Never auto-cleared (research value) |
| `system_log.jsonl` | System status (memory/WiFi/uptime) | 1 record/hour |
| `learning_log.jsonl` | AGENT learning results (threshold adjustments/analysis) | 1 record/day |

---

## PSRAM Fragmentation: Problem and Solution

Version 1 is based on `yeshengdongwu17a.lua`, which includes a complete PSRAM fragmentation solution (17 GC insertions + 4-stage defense), ensuring 10 consecutive triggers without crash.

**Symptom:** After 3–5 consecutive IR triggers, `camera.open()` returns false and photography fails completely.

**Root Cause:** Under consecutive triggers, PSRAM becomes severely fragmented: DHT bit sampling, radar/GPIO checks, Feishu JSON parsing, knowledge base traversal — all these Lua allocations slice PSRAM into fragments, causing DMA buffer allocation failures.

**Solution:**
```lua
-- 1. closeCameraHard(): multiple closes + 800ms wait + 2× collectgarbage
-- 2. cap() 4-stage defense: close → retry → drop frame → capture
-- 3. 17 collectgarbage insertions (6 in main + 11 in AI blogger)
-- 4. cleanupBeforeReturn(): forced cleanup before exit
```

---

## FAQ

**Q: No response after IR trigger?**
A: Check GPIO10 is correctly wired to the IR beam sensor. Ensure it goes low when triggered.

**Q: Camera won't open?**
A: This version uses USB UVC camera. Ensure camera is plugged in and Camera Type is set to USB UVC in `menuconfig`.

**Q: No Feishu messages received?**
A: Confirm App ID and App Secret are correct in `menuconfig`, and the Feishu bot has been added to the target group.

**Q: Weather data collection abnormal?**
A: Check GPIO17/18 UART wiring. Ensure weather station EDU0157 baud rate is set to 115200.

---

## DIY Hardware

For DIY instructions on rain shields, rainwater collectors, spray guide channels, and emergency drinkers, see `docs/hardware-diy.md`.

---

## License

Apache License 2.0 — see project root `LICENSE`.
