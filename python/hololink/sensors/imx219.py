# SPDX-FileCopyrightText: Copyright (c) 2026 NVIDIA CORPORATION & AFFILIATES. All rights reserved.
# SPDX-License-Identifier: Apache-2.0
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
# http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

"""IMX219 camera driver for efinix examples.

Default mode: 1920x1080 RAW10.
"""

from __future__ import annotations

import enum
import logging
import time

import hololink as hololink_module

DRIVER_NAME = "IMX219"
CAM_I2C_ADDRESS = 0x10
EXPECTED_MODEL_ID = 0x0219

# Board control (from imx219_init.cpp)
HSB_CTRL1_ADDR = 0x00000008
CAM_EN_ENABLE = 0x00000000
I2C_CLOCK_COUNT_ADDR = 0x0300020C
I2C_CLOCK_COUNT_400_KHZ = 0x19

MODE_SELECT = 0x0100
IMG_ORIENTATION_A = 0x0172
CSI_LANE_MODE = 0x0114
DPHY_CTRL = 0x0128
EXCK_FREQ_1 = 0x012A
EXCK_FREQ_0 = 0x012B
FRM_LENGTH_A_1 = 0x0160
FRM_LENGTH_A_0 = 0x0161
LINE_LENGTH_A_1 = 0x0162
LINE_LENGTH_A_0 = 0x0163
X_ADD_STA_A_1 = 0x0164
X_ADD_STA_A_0 = 0x0165
X_ADD_END_A_1 = 0x0166
X_ADD_END_A_0 = 0x0167
Y_ADD_STA_A_1 = 0x0168
Y_ADD_STA_A_0 = 0x0169
Y_ADD_END_A_1 = 0x016A
Y_ADD_END_A_0 = 0x016B
x_output_size_A_1 = 0x016C
x_output_size_A_0 = 0x016D
y_output_size_A_1 = 0x016E
y_output_size_A_0 = 0x016F
X_ODD_INC_A = 0x0170
Y_ODD_INC_A = 0x0171
BINNING_MODE_H_A = 0x0174
BINNING_MODE_V_A = 0x0175
CSI_DATA_FORMAT_A_1 = 0x018C
CSI_DATA_FORMAT_A_0 = 0x018D
VTPXCK_DIV = 0x0301
VTSYCK_DIV = 0x0303
PREPLLCK_VT_DIV = 0x0304
PREPLLCK_OP_DIV = 0x0305
PLL_VT_MPY_1 = 0x0306
PLL_VT_MPY_0 = 0x0307
OPPXCK_DIV = 0x0309
OPSYCK_DIV = 0x030B
PLL_OP_MPY_1 = 0x030C
PLL_OP_MPY_0 = 0x030D
ANA_GAIN_GLOBAL_A = 0x0157
DIG_GAIN_GLOBAL_A_1 = 0x0158
DIG_GAIN_GLOBAL_A_0 = 0x0159
COARSE_INTEGRATION_TIME_A_1 = 0x015A
COARSE_INTEGRATION_TIME_A_0 = 0x015B


class Imx219_Mode(enum.IntEnum):
    MODE_1080P_RAW10 = 0


class Imx219Cam:
    """Hololink sensor object for IMX219 (LinuxReceiverOp / RoceReceiverOp / FusaCoeCaptureOp)."""

    def __init__(
        self,
        hololink_channel,
        i2c_bus=None,
        mode=Imx219_Mode.MODE_1080P_RAW10,
    ):
        self._hololink = hololink_channel.hololink()
        # Efinix bring-up used BL_I2C_BUS (0); allow override.
        if i2c_bus is None:
            i2c_bus = hololink_module.BL_I2C_BUS
        self._i2c = self._hololink.get_i2c(i2c_bus)
        self._mode = Imx219_Mode(mode)
        self._pixel_format = hololink_module.sensors.csi.PixelFormat.RAW_10
        self._width = 1920
        self._height = 1080
        self._running = False
        self.set_mode(self._mode)

    def set_mode(self, mode=Imx219_Mode.MODE_1080P_RAW10):
        try:
            resolved_mode = Imx219_Mode(mode)
        except ValueError as exc:
            raise ValueError(f"Unsupported IMX219 mode: {mode}") from exc
        if resolved_mode != Imx219_Mode.MODE_1080P_RAW10:
            raise ValueError(f"Unsupported IMX219 mode: {mode}")
        self._mode = resolved_mode
        self._width = 1920
        self._height = 1080
        self._pixel_format = hololink_module.sensors.csi.PixelFormat.RAW_10

    def get_register(self, register):
        write_bytes = bytearray(4)
        serializer = hololink_module.Serializer(write_bytes)
        serializer.append_uint16_be(register)
        reply = self._i2c.i2c_transaction(
            CAM_I2C_ADDRESS, write_bytes[: serializer.length()], 1
        )
        deserializer = hololink_module.Deserializer(reply)
        return deserializer.next_uint8()

    def set_register(self, register, value, timeout=None):
        write_bytes = bytearray(4)
        serializer = hololink_module.Serializer(write_bytes)
        serializer.append_uint16_be(register)
        serializer.append_uint8(value & 0xFF)
        self._i2c.i2c_transaction(
            CAM_I2C_ADDRESS,
            write_bytes[: serializer.length()],
            0,
            timeout=timeout,
        )

    def get_model_id(self):
        msb = self.get_register(0x0000)
        lsb = self.get_register(0x0001)
        return (msb << 8) | lsb

    def enable_camera_power(self):
        if not self._hololink.write_uint32(HSB_CTRL1_ADDR, CAM_EN_ENABLE):
            raise RuntimeError("failed to enable camera (write HSB_CTRL1)")
        time.sleep(0.05)

    def set_i2c_clock(self):
        # Hololink::I2c::set_i2c_clock() is not exposed by the Python binding.
        # Program the same I2C controller clock-count register directly.
        if not self._hololink.write_uint32(
            I2C_CLOCK_COUNT_ADDR, I2C_CLOCK_COUNT_400_KHZ
        ):
            raise RuntimeError("failed to configure I2C clock")

    def _access_comm_seq(self):
        self.set_register(0x30EB, 0x05)
        self.set_register(0x30EB, 0x0C)
        self.set_register(0x300A, 0xFF)
        self.set_register(0x300B, 0xFF)
        self.set_register(0x30EB, 0x05)
        self.set_register(0x30EB, 0x09)

    def _output_size(self, width, height):
        self.set_register(x_output_size_A_1, (width >> 8) & 0xFF)
        self.set_register(x_output_size_A_0, width & 0xFF)
        self.set_register(y_output_size_A_1, (height >> 8) & 0xFF)
        self.set_register(y_output_size_A_0, height & 0xFF)

    def _output_active_pixel(self, x_start, x_end, y_start, y_end):
        self.set_register(X_ADD_STA_A_1, (x_start >> 8) & 0xFF)
        self.set_register(X_ADD_STA_A_0, x_start & 0xFF)
        self.set_register(X_ADD_END_A_1, (x_end >> 8) & 0xFF)
        self.set_register(X_ADD_END_A_0, x_end & 0xFF)
        self.set_register(Y_ADD_STA_A_1, (y_start >> 8) & 0xFF)
        self.set_register(Y_ADD_STA_A_0, y_start & 0xFF)
        self.set_register(Y_ADD_END_A_1, (y_end >> 8) & 0xFF)
        self.set_register(Y_ADD_END_A_0, y_end & 0xFF)

    def _set_binning_mode(self, x_mode, y_mode):
        self.set_register(BINNING_MODE_H_A, min(x_mode, 3))
        self.set_register(BINNING_MODE_V_A, min(y_mode, 3))

    def gain_filter(self, analog_gain=0x50, digital_gain=0x200):
        self.set_register(ANA_GAIN_GLOBAL_A, analog_gain & 0xFF)
        self.set_register(DIG_GAIN_GLOBAL_A_1, (digital_gain >> 8) & 0x0F)
        self.set_register(DIG_GAIN_GLOBAL_A_0, digital_gain & 0xFF)

    def configure(self, mode=None):
        """Program 1080p RAW10; leave sensor in standby until start()."""
        if mode is not None:
            self.set_mode(mode)

        self.enable_camera_power()
        self.set_i2c_clock()

        model_id = self.get_model_id()
        logging.info("IMX219 MODEL_ID=0x%04X", model_id)
        if model_id != EXPECTED_MODEL_ID:
            raise RuntimeError(
                f"unexpected MODEL_ID 0x{model_id:04X} (expected 0x{EXPECTED_MODEL_ID:04X})"
            )

        # PiCam_init() — stream enable deferred to start()
        self.set_register(MODE_SELECT, 0x00)
        self._access_comm_seq()
        self.set_register(CSI_LANE_MODE, 0x01)
        self.set_register(DPHY_CTRL, 0x00)
        self.set_register(EXCK_FREQ_1, 0x18)
        self.set_register(EXCK_FREQ_0, 0x00)
        self.set_register(FRM_LENGTH_A_1, 0x04)
        self.set_register(FRM_LENGTH_A_0, 0x59)
        self.set_register(LINE_LENGTH_A_1, 0x0D)
        self.set_register(LINE_LENGTH_A_0, 0x78)

        # Standard IMX219 1080p30 readout window: crop the active array to
        # 1920x1080 before transmission. A full-height readout cannot sustain
        # the shorter 1763-line frame period configured below.
        self._output_active_pixel(680, 2599, 692, 1771)
        self._output_size(self._width, self._height)

        self.set_register(X_ODD_INC_A, 0x01)
        self.set_register(Y_ODD_INC_A, 0x01)
        self._set_binning_mode(0, 0)

        self.set_register(CSI_DATA_FORMAT_A_1, 0x0A)
        self.set_register(CSI_DATA_FORMAT_A_0, 0x0A)

        self.set_register(VTPXCK_DIV, 0x05)
        self.set_register(VTSYCK_DIV, 0x01)
        self.set_register(PREPLLCK_VT_DIV, 0x03)
        self.set_register(PREPLLCK_OP_DIV, 0x03)
        self.set_register(PLL_VT_MPY_1, 0x00)
        self.set_register(PLL_VT_MPY_0, 0x39)
        self.set_register(OPPXCK_DIV, 0x0A)
        self.set_register(OPSYCK_DIV, 0x01)
        self.set_register(PLL_OP_MPY_1, 0x00)
        self.set_register(PLL_OP_MPY_0, 0x72)
        self.set_register(OPPXCK_DIV, 0x0A)
        self.set_register(OPSYCK_DIV, 0x01)
        self.set_register(PLL_OP_MPY_1, 0x00)
        self.set_register(PLL_OP_MPY_0, 0x72)

        self.gain_filter(0x20, 0x100)
        self.set_register(LINE_LENGTH_A_1, 0x0D)
        self.set_register(LINE_LENGTH_A_0, 0x78)
        # 1080p cropped timing: 1763 lines at a 182.4 MHz pixel rate is ~30 fps.
        self.set_register(FRM_LENGTH_A_1, 0x06)
        self.set_register(FRM_LENGTH_A_0, 0xE3)
        # Keep well below the 1763-line frame length so daytime scenes aren't clipped white.
        self.set_register(COARSE_INTEGRATION_TIME_A_1, 0x04)
        self.set_register(COARSE_INTEGRATION_TIME_A_0, 0x00)
        self.set_register(IMG_ORIENTATION_A, 0x00)

        # Remain in standby; the receiver operator's device_start callback calls start().
        # Sensor RX data generator is absent when SIF_RX_DATA_GEN is disabled.
        self.set_register(MODE_SELECT, 0x00)
        time.sleep(0.1)

    def start(self):
        self.set_register(MODE_SELECT, 0x01)
        self._running = True

    def stop(self):
        self.set_register(MODE_SELECT, 0x00)
        time.sleep(0.1)
        self._running = False

    def configure_converter(self, converter):
        start_byte = converter.receiver_start_byte()
        transmitted_line_bytes = converter.transmitted_line_bytes(
            self._pixel_format, self._width
        )
        received_line_bytes = converter.received_line_bytes(transmitted_line_bytes)
        converter.configure(
            start_byte,
            received_line_bytes,
            self._width,
            self._height,
            self._pixel_format,
        )

    def pixel_format(self):
        return self._pixel_format

    def bayer_format(self):
        # Test alternate CFA interpretation for the current IMX219 stream.
        return hololink_module.sensors.csi.BayerFormat.RGGB

    def get_width(self):
        return self._width

    def get_height(self):
        return self._height

    def get_pixel_format(self):
        return int(self._pixel_format)

    def get_bayer_format(self):
        return self.bayer_format().name.lower()
