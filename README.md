# OpenWild Agent

**Low-Cost Wild Agent Platform — Open-Source Wildlife AI Monitoring Solution Based on ESP32-S3 + ESP-Claw**

[![ESP-IDF](https://img.shields.io/badge/ESP--IDF-5.3+-green.svg)](https://github.com/espressif/esp-idf)
[![License](https://img.shields.io/badge/License-Apache--2.0-blue.svg)](./LICENSE)
[![Platform](https://img.shields.io/badge/Platform-ESP32--S3-orange.svg)](https://github.com/espressif/esp-idf)

> GitHub: [github.com/liluwei-star/OpenWild-Agent](https://github.com/liluwei-star/OpenWild-Agent)

## Table of Contents

- [Project Overview](#project-overview)
- [Hardware List](#hardware-list)
- [Software Architecture](#software-architecture)
- [Module Dependencies](#module-dependencies)
- [Six Core Capabilities](#six-core-capabilities)
- [Five Functional Instances](#five-functional-instances)
- [Quick Start](#quick-start)
- [Directory Structure](#directory-structure)
- [Paper Appendix Reference](#paper-appendix-reference)
- [License](#license)
- [Contact](#contact)

---

## Project Overview

OpenWild Agent implements a full AI Agent architecture on ESP32-S3 using the Espressif ESP-Claw framework. A single ESP32-S3 board coordinates 12 Lua modules within 84KB of program space, achieving a closed loop of "perceive → decide → act → remember → learn" to support 5+N concurrent functional instances.

### Project Positioning

- **Not a single monitoring device, but a "smart agent operating system" for outdoor deployment**
- Achieves professional-grade outdoor intelligence at consumer hardware cost (~$65 / ¥475), compared to >$700 / ¥5000+ for equivalent commercial equipment
- Fully open-source code and documentation to promote ecosystem co-building

### Technical Specifications

| Metric | Value |
|:-------|:------|
| Main Chip | ESP32-S3 (240MHz / 512KB RAM / 4MB PSRAM) |
| Total Code Size | 84,260 bytes (12 Lua modules) |
| Image Recognition Accuracy | 92% (10 test animal species) |
| End-to-End Recognition Latency | < 10s (photo + cloud LLM + Feishu push) |
| Platform Stability | 5 consecutive days crash-free |
| Weather Data Collection | Up to 720 records/day |
| AI Recognition Success Rate | 100% (cloud vision solution) |
| Continuous Trigger Stability | 10 consecutive triggers, no crash |
| Hardware Cost | ¥475 (USB power version) |

---

## Hardware List

> Full details in Paper Appendix 4.

| Component | Model | Unit Price | Qty | Notes |
|:----------|:------|----------:|:----:|:------|
| Main Board | ESP32-S3-DevKitC | ¥35 | 1 | Core controller |
| IR Beam Sensor | Slot-type photoelectric | ¥5 | 1 | Door trigger |
| Radar Sensor | HLK-LD112 | ¥3 | 1 | In-nest animal detection |
| Temp/Humidity Sensor | DHT11 | ¥5 | 1 | Environment monitoring |
| Heating Film | 5V 1.5A | ¥18 | 1 | Temperature regulation |
| Fan | 5V 200mA | ¥10 | 1 | Temperature regulation |
| Ultrasonic Humidifier | 5V 500mA | ¥8 | 1 | Humidity regulation |
| LED | WS2812B | ¥4 | 1 | Status indicator |
| USB Camera | UVC protocol | ¥15 | 1 | Animal photography |
| OLED Screen | 2-inch SPI | ¥12 | 1 | Local status display |
| Weather Station | DFRobot EDU0157 | ¥300 | 1 | Six-element weather data |
| Misc | Transistors/resistors | ¥20 | 1 set | Support circuits |
| 18650 Li-ion ×2 | 3.7V 6800mAh parallel | ¥40 | 2 | Field power supply |
| **Total** | | **¥475** | | |

> Field version adds solar power system (two 5V panels + protection circuit), total ~¥550, capable of long-term unattended operation.

### Wiring Guide

ESP32-S3 GPIO Assignment (full):

| GPIO | Function | Component |
|:----:|:---------|:---------|
| GPIO5 | Radar signal input | HLK-LD112 Doppler radar |
| GPIO6 | OLED SCL | I2C clock |
| GPIO7 | OLED SDA | I2C data |
| GPIO9 | DHT11 data | Temp/humidity sensor |
| GPIO10 | IR trigger input | Slot-type IR beam sensor |
| GPIO13 | Fan control | PWM speed control |
| GPIO14 | Heating film control | PWM speed control |
| GPIO17 | Weather station TX | UART transmit |
| GPIO18 | Weather station RX | UART receive |
| GPIO21 | Humidifier control | On/off control |

![GPIO Pinout](../docs/images/OpenWild-Agent-图6-GPIO分配表.png)

---

## Software Architecture

> Full details in Paper Appendices 5 and 6.

### 12 Lua Modules Overview

| Category | Module | Size | Version | Key Role |
|:---------|:-------|-----:|:-------:|:---------|
| **Main** | `main.lua` | 9,913B | V17b | Weather station main + IR trigger scheduling + AGENT module loading |
| **Main** | `yeshengdongwu17a/b.lua` | 16,862B | V17b | Animal recognition + PSRAM fix + cloud vision |
| **AGENT** | `agent_memory.lua` | 8,457B | V7.7 | Memory: 2-day weather retention + species records never cleared |
| **AGENT** | `agent_learning.lua` | 12,733B | V7.5 | Learning: 5 core question adaptation (season/weather/species/relationship/LLM) |
| **AGENT** | `agent_chat.lua` | 5,662B | V7.3 | Chat: 7 natural language query types |
| **AGENT** | `agent_self_monitor.lua` | 2,017B | V7.3 | Monitor: memory/WiFi alerts + /blog/ auto-cleanup |
| **Feature** | `AI_blogger.lua` | 11,682B | v2.7.8 | AI blogger: Xiaohongshu-style post generation (11 GC defenses) |
| **Feature** | `display.lua` | 2,594B | V17b | OLED status display |
| **Feature** | `incubator.lua` | 3,905B | V17b | Incubator mode: 37.5–38.5°C constant + 21-day countdown |
| **Feature** | `cloud_vision.lua` | 4,389B | V17b | Cloud vision: base64 encode + HTTP direct to cloud LLM |
| **Feature** | `check.lua` | 5,174B | v4 | Storage diagnostics: startup cleanup /photos/ + /blog/ |
| **Ref** | `cfg.md` | 872B | — | Field deployment 4-parameter adjustment checklist (not deployed to device) |
| | **Total** | **84,260B** | | |

---

## Module Dependencies

### Call Matrix

Caller \ Callee:

| Caller ↓ / Callee → | main | 17b | mem | lrn | chat | mon | blog | disp | inc | cv | check |
|:---|:---:|:---:|:---:|:---:|:---:|:---:|:---:|:---:|:---:|:---:|:---:|
| **main.lua** | — | dofile | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | startup |
| **yeshengdongwu17b.lua** | | — | ✓ | ✓ | | ✓ | ✓ | ✓ | ✓ | | |
| **agent_memory.lua** | | | — | | ✓ | | | | | | |
| **agent_learning.lua** | | ✓ | | — | | | | | | | |
| **agent_chat.lua** | | ✓ | ✓ | | — | | | | | | |
| **agent_self_monitor.lua** | | ✓ | | | | — | | | | | ✓ |
| **AI_blogger.lua** | | ✓ | ✓ | | | | — | ✓ | | ✓ | |
| **display.lua** | | ✓ | | | | | | — | | | |
| **incubator.lua** | | ✓ | ✓ | | | | | | — | | |
| **cloud_vision.lua** | | | | | | | | | | — | |

### Four Key Call Chains

```
① System Boot Chain
   main → agent_memory → display (splash) → main loop

② IR Trigger Chain (GPIO10 == 0)
   main → yeshengdongwu17b (dofile) → cloud_vision → mem.logSpecies → Feishu push → return to main

③ AGENT Query Chain (Feishu message)
   Feishu → main → agent_chat → agent_memory / agent_learning (query) → chat push

④ AI Blogger Chain (every 4 hours post-trigger)
   agent_memory → AI_blogger → cloud_vision → Feishu push
```

### Module Relationship Diagram

```
                    ┌──────────────────────────────────────────┐
                    │           User Interaction Layer          │
                    │     Feishu / WeChat / Telegram NLP        │
                    └──────────────────┬───────────────────┘
                                       │
                    ┌──────────────────▼───────────────────┐
                    │         ESP-Claw Agent Framework       │
                    │                                        │
                    │  ┌────┐ ┌────┐ ┌────┐ ┌────┐        │
                    │  │mem│ │lrn │ │chat│ │mon │        │  ← 4 AGENT modules
                    │  └──┬─┘ └──┬─┘ └──┬─┘ └──┬─┘        │
                    │     │      │      │      │          │
                    │     └──────┼──────┼──────┘          │
                    │            │      │                  │
                    │  ┌─────────▼──────▼────────┐        │
                    │  │   cloud_vision / web_search  │     │  ← Tool layer
                    │  └─────────┬──────┬─────────┘        │
                    └────────────┼──────┼────────────────┘
                                 │      │
         ┌───────────────────────┼──────┼───────────────────────┐
         │                       │      │                       │
         │  ┌────────────────────▼──────▼────────────────┐       │
         │  │  main.lua (Weather Station Main, V17b)    │       │
         │  │  ├─ agent_memory    ├─ agent_chat         │       │
         │  │  └─ agent_learning  └─ agent_self_monitor │       │
         │  └────────────────────┬─────────────────────┘       │
         │                       │ IR trigger: dofile              │
         │  ┌────────────────────▼─────────────────────┐        │
         │  │  yeshengdongwu17b.lua (Wildlife Monitor, V17b)│     │
         │  │  ├─ cloud_vision   ├─ AI_blogger      │        │
         │  │  ├─ incubator      ├─ display         │        │
         │  │  └─ agent_memory   └─ agent_learning │        │
         │  └────────────────────┬─────────────────────┘       │
         │                       │                                │
         │  ┌────────────────────▼─────────────────────┐        │
         │  │          Hardware Abstraction Layer (HAL)        │        │
         │  │  GPIO / UART / Camera / I2C / LED     │        │
         │  └────────────────────────────────────────┘        │
         └──────────────────────────────────────────────────────┘
```

---

## Six Core Capabilities

> Full description in Paper §2.3.3.

| Capability | Module | Description |
|:-----------|:-------|:-----------|
| **Planning** | agent_learning | Dynamic task planning, wildlife_detect / nest_maintain / incubator_run task templates |
| **Memory** | agent_memory | JSONL storage + tag retrieval, weather_log / species_log / system_log / learning_log |
| **Learning** | agent_learning | 5 core question adaptation (season / weather / species preference / behavior pattern / LLM analysis) |
| **Chat** | agent_chat | 7 natural language query types, remote inquiry and config via Feishu/WeChat |
| **Self-Monitor** | agent_self_monitor | Memory < 10KB warning / WiFi < -75dBm warning / auto cleanup |
| **Adaptive** | agent_self_monitor | Self-healing, night-time downclocking + weak-network delay adjustment |

---

## Five Functional Instances

> Full description in Paper §2.3.5 and Appendix 7.

| Instance | Function | Test Data |
|:---------|:---------|:---------|
| **Instance 1: Field Weather Station** | UART weather station collects six-element data, auto Feishu report | 720 records/day, 4 consecutive days stable push |
| **Instance 2: Wildlife Home** | IR trigger → photo → cloud recognition → nest maintenance | End-to-end < 10s, 92% accuracy |
| **Instance 3: Metaverse Remote Observation** | Feishu chat history as "metaverse entry", real-time push | Query response < 200ms |
| **Instance 4: Education & Science** | AI blogger auto-generates Xiaohongshu posts + Feishu Q&A | 9 posts published |
| **Instance 5: Research Data** | JSONL local storage + Feishu cloud dual backup | 13 species, 32 visit records |
| **Instance N: Chat-to-Create** | Natural language generates new feature modules (e.g. fire_monitor.lua) | Generated in 30 seconds |

---

## Quick Start

### Prerequisites

ESP-Claw development environment must be set up first. See [docs/esp-claw-setup.md](./docs/esp-claw-setup.md) for detailed steps.

### Hardware Setup

1. Purchase components from the hardware list above (total ~¥475)
2. Wire according to the GPIO pinout table
3. Refer to Paper Appendix 4 for wiring diagrams

### Build & Deploy

```bash
# 1. Clone this repository
git clone https://github.com/liluwei-star/OpenWild-Agent.git
cd OpenWild-Agent

# 2. Enter ESP-Claw project directory (requires ESP-IDF installed)
# Assuming esp-claw is installed at ~/esp/esp-claw
cd ~/esp/esp-claw

# 3. Activate ESP-IDF environment
source export.sh

# 4. Configure menuconfig (set WiFi, camera parameters, etc.)
idf.py menuconfig

# 5. Build
idf.py build
```

### Configuration

**Version 1 (AGENT Built-in):** No image recognition API required. Uses built-in LLM for recognition. Suitable for beginners.

**Version 2 (Standalone LLM):** Requires configuring `scripts/user/config/cloud_vision.lua` with your API key and endpoint. Higher recognition accuracy. Suitable for users with API experience.

See the version-specific README.md for configuration details.

---

## Directory Structure

```
OpenWild-Agent/
├── README.md                    # This file (project overview)
├── LICENSE                      # Apache 2.0
├── .gitignore                   # Git ignore rules
├── media/                       # Demo video
│   └── demo-1080p.mp4          # Demo video (29MB)
├── docs/                        # Detailed documentation
│   ├── esp-claw-setup.md        # ESP-IDF + ESP-Claw setup guide
│   ├── hardware-diy.md          # DIY hardware guide (rain shields/drinkers/etc.)
│   └── images/                 # Paper images
│       ├── 正视图.jpg
│       ├── 侧视图.jpg
│       ├── 后视图.jpg
│       └── *.jpg                # Other images
├── version1-agent/              # Version 1: AGENT built-in (no extra API needed)
│   ├── README.md                # Version 1 specific docs
│   ├── config/                  # ★ ESP-Claw config directory
│   │   └── animal_env.json     # Species environment config
│   ├── data/                    # ★ JSONL data directory (runtime-generated)
│   └── scripts/user/           # ★ Lua scripts directory
│       ├── main.lua             # Weather station main (9,913B)
│       ├── yeshengdongwu17a.lua # Wildlife monitor (16,531B)
│       ├── AI_blogger.lua       # AI blogger (11,599B)
│       ├── cloud_vision.lua     # Cloud vision built-in (4,389B)
│       ├── display.lua          # OLED display (2,594B)
│       ├── incubator.lua        # Incubator mode (3,905B)
│       ├── check.lua            # Storage diagnostics (1,555B)
│       ├── animal_db.lua        # Animal database (2,148B)
│       └── agent/               # AGENT module directory
│           ├── agent_memory.lua       # Memory (6,501B)
│           ├── agent_learning.lua    # Learning (11,131B)
│           ├── agent_chat.lua        # Chat (5,662B)
│           └── agent_self_monitor.lua # Monitor (2,017B)
│
└── version2-standalone/         # Version 2: Standalone LLM (API required)
    ├── README.md                # Version 2 specific docs
    ├── config/                  # ★ ESP-Claw config directory
    │   ├── animal_db.lua        # Animal database (2,067B)
    │   └── animal_env.json      # Species environment config
    ├── data/                    # ★ JSONL data directory (runtime-generated)
    └── scripts/user/            # ★ Lua scripts directory
        ├── main.lua             # Weather station main (10,756B)
        ├── yeshengdongwu17b.lua # Wildlife monitor (17,807B)
        ├── AI_blogger.lua       # AI blogger (27,464B)
        ├── cloud_vision.lua      # ★ Cloud vision standalone config (4,572B)
        ├── display.lua          # OLED display (2,594B)
        ├── incubator.lua        # Incubator mode (3,905B)
        ├── check.lua            # Storage diagnostics (6,975B)
        ├── cfg.md               # Field deployment parameter reference
        └── agent/               # AGENT module directory (same as version 1)
```

---

## Paper Appendix Reference

This repository's README maps to the following paper appendices:

| Appendix | Content | Maps To |
|:---------|:--------|:--------|
| **Appendix 1** | Vehicle window-break mechanical analysis (predecessor project) | N/A |
| **Appendix 2** | Multi-physics signal sensing (sensor physics) | N/A |
| **Appendix 3** | Project challenges and highlights (recognition rate / PSRAM / stability) | This README |
| **Appendix 4** | Hardware list + wiring diagrams + open-source addresses | This README §Hardware List |
| **Appendix 5** | Software list + module dependencies + call matrix | This README §Software Architecture + §Module Dependencies |
| **Appendix 6** | Main program relationship diagram + detailed flowcharts | This README §Module Relationship Diagram |
| **Appendix 7** | Detailed test procedures | This README §Project Overview Test Data |

---

## License

This project is licensed under **Apache License 2.0**.

- Free to use, modify, and distribute for any purpose, including commercial use
-唯一要求：保留 LICENSE 文件和版权声明

---

## Acknowledgments

This project is built on the Espressif ESP-Claw framework. Thanks to the Espressif open-source community.

## Contact

GitHub: [github.com/liluwei-star](https://github.com/liluwei-star)
