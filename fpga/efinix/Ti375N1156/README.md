# Efinix build

## Prerequisite

1. Ti375N1156 Development Kit
2. Dual Raspberry Pi Camera Connector Daughter Card
3. Raspberry Pi Camera Module 2
4. QSFP+ to SFP+ AOC

### Computer specification

1. Windows / x64 Linux which is capable for running Efinity 2026.1
2. Jetson AGX Thor

## Build flow (Windows / x64 Linux)

Set up Environment Variables:

- Windows

  ```bat
  /path/to/efinity/bin/setup.bat
  ```

- x64 Linux

  ```bash
  source /path/to/efinity/bin/setup.sh
  ```

Generate Project and IP:

```bash
python3 build/full_flow.py
efinity # open Efinity IDE
```

In Efinity IDE, open `Ti375N1156_HSB/N1156_HSB.xml` and run Synthesis, Placement, Routing and Generate Bitstream.

Connect the computer to the board's FTDI port, program the board with "SPI Active using JTAG Bridge" mode.

## Wiring for demo

| From | To |
| --- | --- |
| Board P4 | Daughter Card J2 |
| Daughter Card FPC2 | Pi Camera V2 |
| Board J9 SFP+ | AGX Thor QSFP28 |

Target demos:

- `linux_imx219_face_detection.py` --- All CUDA device
- `fusa_coe_imx219_face_detection.py` --- AGX Thor Only

Follow [Host Setup](https://docs.nvidia.com/holoscan/sensor-bridge/getting-started/host-setup) to configure the host to run the demos.