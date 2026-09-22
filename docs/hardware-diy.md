# DIY Hardware Guide

This document describes the mechanical components that need to be built for the OpenWild Agent smart nest device: rain shield, rainwater collector, spray guide channel, and emergency drinker.

## Overall Layout

The device consists of nine modules mounted on a backplane (recommended: 60cm × 45cm × 1.5cm wood or aluminum plate):

| # | Name | Position | Notes |
|:--|:-----|:---------|:------|
| 1 | Weather station | Top-left of backplane | Monitors temp, humidity, pressure |
| 2 | USB camera | Left-center of backplane | USB interface, captures nest interior |
| 3 | Solar panel | Top-center of backplane | 12V/5W, with protection diode |
| 4 | Main controller | Center-right of backplane | ESP32-S3 core board, see version docs |
| 5 | Woven nest | Lower-center of backplane | ~25cm diameter, wicker craft, hung |
| 6 | Ultrasonic humidifier | Below-right of nest | Atomizer + small fan, USB powered |
| 7 | Emergency drinker | Bottom-right of backplane | Pet waterer modification, see this doc |
| 8 | Spray guide channel | Between humidifier and nest | Acrylic sheet DIY, see this doc |
| 9 | Rain shield | Top of backplane | Acrylic sheet DIY, see this doc |

> **Backplane mounting advice**: Use a pencil to draw component outlines and screw holes on the backplane first. Pre-drill holes with an electric drill. Then mount each component in order. The solar panel and weather station should be mounted highest to avoid being blocked by other components.

---

## 1. Rain Shield (Required)

The rain shield is the key external component, serving two functions:
- **Shade**: Prevents direct sunlight from overheating the nest interior
- **Rainwater diversion**: Guides rainwater to the collector, preventing water accumulation on equipment

### Materials

| Material | Spec | Qty | Notes |
|:---------|:-----|:----:|:------|
| Acrylic sheet | 3mm thick, slightly larger than nest (~30cm × 30cm) | 1 | Transparent or frosted |
| Acrylic sheet (diverter) | 2mm thick, 15cm × 5cm | 1 | For rainwater diversion channel |
| Hot glue or construction adhesive | Waterproof type | 1 tube | |
| M3 screws + nuts | 10mm length | 4 sets | Mount rain shield to backplane |

### Steps

**Step 1: Cut acrylic sheet**

Cut the 3mm acrylic sheet to the desired shape using a laser cutter or hand saw. Recommended size: about 5cm larger than the nest diameter (~30cm diameter circle or square). Drill four M3 screw holes at corners (3.2mm hole diameter to avoid cracking).

> **No laser cutter?** Search "acrylic sheet custom cut" on Taobao. Upload a CAD drawing or just tell the merchant the size and shape. About ¥5 per piece. Frosted transparent is recommended for both aesthetics and shading.

**Step 2: Make rainwater diversion channel**

Cut a 3cm-wide strip from the 2mm acrylic sheet, the same width as the rain shield. Glue this strip to the underside of the rain shield (the side facing the backplane) with hot glue, centered at the bottom edge. Angle it at about 15°–20° so rainwater flows toward the rainwater collector at the bottom-right of the backplane.

**Step 3: Mount the rain shield**

Hang the rain shield above the backplane using four corner posts (plastic or aluminum pillars, ~3cm spacing). The shield should not touch the backplane directly — leave air gap for ventilation. Pass M3 screws through the acrylic holes, then through the posts, and secure to the backplane.

### Verification

Simulate rainfall: spray water from above the rain shield with a spray bottle. Observe whether all rainwater flows along the diversion channel to the collector, with no significant dripping at the shield's lower edge.

---

## 2. Rainwater Collector (Optional, Recommended for Field Use)

Works with the rain shield's diversion channel to collect rainwater into a storage container for the humidifier. Enables unattended field water supply.

### Materials

| Material | Spec | Qty | Notes |
|:---------|:-----|:----:|:------|
| Plastic bottle (drinks) | 500ml–1.5L | 1 | Rainwater collection |
| PVC or silicone tube | 5mm inner diameter | ~30cm | Diversion tube |
| Hot glue | Waterproof type | 1 tube | |

### Steps

1. Cut off the bottle mouth to create an open container
2. Use a soldering iron to melt a small hole (~6mm diameter) near the bottom of the bottle side wall. Insert the silicone tube and seal with hot glue
3. Hang the bottle upside-down at the bottom-right of the backplane (next to the drinker). Place the drinker below the bottle mouth
4. Connect the rain shield diversion channel exit to the plastic bottle interior with a short tube
5. Water flow: rain shield → diversion tube → plastic bottle → bottle mouth drips → emergency drinker

> **Maintenance**: Inspect monthly in field conditions. Clear fallen leaves and mosquito eggs from the bottle. In freezing areas, drain water before winter to prevent cracking.

---

## 3. Ultrasonic Humidifier + Spray Guide Channel

The humidifier produces fine water mist via ultrasonic atomization. The spray guide channel directs mist evenly into the nest, simulating natural dew conditions — especially useful during incubation.

### Materials

| Material | Spec | Qty | Notes |
|:---------|:-----|:----:|:------|
| Ultrasonic atomizer disc | 5V/2.5MHz, adjustable mist output | 1 | ~¥3 on Taobao |
| Small quiet fan | 5V/0.2A, 5015 size | 1 | Blows mist toward guide channel |
| Acrylic sheet | 3mm, ~25cm × 8cm | 1 | Spray guide channel |
| USB power cable | 1 meter | 1 | Power (can connect to solar controller 5V output) |
| Hot glue / construction adhesive | Waterproof type | 1 tube | |
| Atomizer wicking棉芯 | ~8mm diameter | 1 | ~15cm |

### Steps

**Humidifier assembly**

1. Solder power wires to the atomizer disc (red positive, black negative). Apply waterproof treatment (seal solder joint with hot glue)
2. Pass the wicking棉芯 through the atomizer disc center hole. Put the other end of the wick into the emergency drinker
3. Glue the atomizer disc to the bottom of a small plastic housing (or 3D-printed case) with hot glue
4. Glue the small fan above the atomizer disc with hot glue, blowing toward the guide channel

**Spray guide channel**

1. Cut a long strip ~8cm wide and ~25cm long from 3mm acrylic sheet
2. Bend the strip slightly along its length (use a heat gun to warm acrylic before bending) to form a semi-circular concave channel
3. Drill 1cm diameter holes at both ends of the channel as mist inlet and outlet
4. Glue the guide channel to the backplane with hot glue. Inlet faces the humidifier fan outlet; outlet faces the woven nest opening
5. Mount the guide channel at a 5°–10° upward angle from horizontal so mist drifts naturally into the nest

**Power wiring**

```
Solar panel + → Solar controller (5V output) → USB cable → Humidifier
                                              ↓
Solar panel - → Solar controller GND → ESP32-S3 main (controlled by GPIO)
```

The ESP32-S3 controls humidifier power via an N-channel MOSFET (e.g. AO3400). The main controller outputs a high signal to turn the MOSFET on and start the humidifier. See the `humidifier.lua` software module.

### Verification

After powering on: the atomizer disc should quickly produce white water mist, and the fan should blow the mist along the guide channel into the nest. The nest interior should show visible mist within 5 minutes. Your hand near the nest opening should feel distinct moisture and coolness.

---

## 4. Emergency Drinker (Optional, Recommended for Field Use)

Provides reliable water for wildlife. Built from a modified pet waterer — simple structure, low cost, easy maintenance.

### Materials

| Material | Spec | Qty | Notes |
|:---------|:-----|:----:|:------|
| Pet waterer | ~1.5L capacity, with water basin | 1 | ~¥20 on Taobao |
| Silicone tube | 5mm inner diameter | ~20cm | Connect to atomizer wick |
| 502 glue | Quick-dry | 1 bottle | Seal connections |
| Float valve (optional) | Small turtle-watering type | 1 | Auto-refill, maintains water level |

### Steps

1. **Modify the basin**: Use a soldering iron to melt a 6mm diameter hole near the bottom of the pet waterer's basin side wall. Insert the silicone tube and seal with 502 glue, as the atomizer wick water supply port
2. **Position**: Mount the drinker at the bottom-right of the backplane, level with or slightly below the humidifier to ensure smooth wick water absorption
3. **Wick connection**: Put one end of the atomizer wick (棉芯) into the bottom of the drinker basin. Insert the other end into the atomizer disc hole on the humidifier. The wick uses capillary action to continuously supply water
4. **Auto-refill (optional)**: If a rainwater collector is installed, connect the collector bottle's outlet tube to the drinker basin as well. The float valve controls the maximum water level to prevent overflow

### Maintenance Schedule

| Item | Interval | Action |
|:-----|:---------|:------|
| Clean basin | Every 2 weeks | Empty, rinse with clean water |
| Replace wick | Every month | Cut discolored portion, add fresh wick |
| Check seals | First maintenance each month | Confirm tubes are secure, no leaks |

---

## 5. Woven Nest Installation

The woven nest is the actual animal habitat. Its position is the most critical.

### Nest Selection

- **Size**: 22–28cm diameter, 15–20cm depth, ~45° opening angle
- **Material**: Natural wicker or willow weave, good breathability
- **Where to buy**: Search "wicker bird house" or "wicker nest" on Taobao. ~¥15–30

### Mounting

1. Drill two holes ~8cm apart on the backplane (hole diameter slightly smaller than hanging wire)
2. Pass ~15cm of soft steel wire (or fishing line) through the nest hanging rings. Thread both ends through the backplane holes. Tighten on the back of the backplane and reinforce with hot glue
3. Adjust nest angle so the opening faces the camera direction (~30° downward angle) for clear interior capture
4. Line the nest bottom with clean coconut fiber or dry grass for comfort and insulation

### Camera Focus Adjustment

After mounting, power on the ESP32-S3 main controller. Open the screen or serial monitor to confirm the USB camera covers the nest interior clearly. If the image is blurry, loosen the camera mounting screws, adjust angle slightly, and re-tighten.

---

## 6. Solar Power System

### Materials

| Material | Spec | Qty | Notes |
|:---------|:-----|:----:|:------|
| Solar panel | 12V/5W, with diode | 1 | |
| Solar controller | 12V/5A, small | 1 | Over-charge/discharge protection |
| 18650 Li-ion battery | 3.7V/3000mAh | 2 | Parallel for 3.7V/6000mAh |
| DC-DC boost module | 3.7V → 5V/2A | 1 | Powers ESP32-S3 and peripherals |

### Wiring

```
Solar panel (+) → Solar controller (+) → [Battery pack] → DC-DC boost → 5V USB output
Solar panel (-) → Solar controller (-)              ↓
                                         Solar controller LOAD (+) → ESP32-S3 power
                                         Solar controller LOAD (-) → GND
```

### Solar Controller Settings

Configure in the solar controller menu:
- **Battery type**: Lithium-ion (Li-ion)
- **Over-charge protection voltage**: 4.2V
- **Over-discharge protection voltage**: 3.0V
- **Light-control lamp-on threshold**: Set as needed (not used in this project)

---

## 7. Assembly Sequence (Recommended)

Assemble in this order to avoid interference:

1. **Backplane preparation**: Cut backplane, drill all mounting holes
2. **Solar panel**: Mount at top-center of backplane
3. **Solar controller + battery + DC-DC module**: Mount at top-right of backplane (most convenient for wiring)
4. **Main controller (clear box)**: Mount at center-right of backplane
5. **Weather station**: Mount at top-left of backplane
6. **Woven nest**: Hang at lower-center of backplane
7. **USB camera**: Mount above nest, aimed at nest opening (route USB cable so it doesn't block the nest entrance)
8. **Ultrasonic humidifier**: Mount below-right of nest
9. **Spray guide channel**: Mount between humidifier and nest
10. **Emergency drinker**: Mount at bottom-right of backplane
11. **Rain shield**: Mount at top of backplane, hung via posts
12. **All wiring**: Connect per wiring diagram. Check positive/negative polarity
13. **Software deployment**: Connect computer, deploy scripts and config to device via ESP-Claw tools
14. **Function test**: Test each module individually
15. **Backplane enclosure**: Optionally cover the entire backplane with transparent waterproof film or acrylic sheet (prevents rainwater splashing)

---

## 8. Tool List

| Tool | Purpose |
|:-----|:--------|
| Electric drill (3mm/6mm drill bits) | Drill backplane mounting holes |
| Hot glue gun + glue sticks | Mounting and sealing |
| Screwdriver set (M2/M3 screws) | Secure components |
| Wire stripper | Handle power cables |
| Soldering iron (30W) | Solder wire connections |
| Silicone sealant | Waterproof sealing |
| Tape measure + pencil | Layout and marking |
| Multimeter | Check wiring polarity and shorts |
| Laptop (with ESP-IDF installed) | Deploy scripts and config to device |
| USB data cable | Connect ESP32-S3 |

---

## 9. Version Differences

| Item | Version 1 (AGENT) | Version 2 (Standalone LLM) |
|:-----|:------------------|:---------------------------|
| Main board | ESP32-S3 (HEZHOU Air8101) | ESP32-S3 N32R16 |
| Image recognition | Built-in LLM, no extra config needed | Requires `cloud_vision.lua` and LLM API |
| USB camera | Same | Same |
| DIY hardware | Same | Same |
