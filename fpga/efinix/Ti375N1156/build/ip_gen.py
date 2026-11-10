# SPDX-FileCopyrightText: Copyright (c) 2013-2026 Efinix Inc. All rights reserved.
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

import os
import sys
from pathlib import Path

"""Generate and register the local CSI-2 RX IP."""
ipm_home = os.environ["EFXIPM_HOME"]
ipm_bin = f"{ipm_home}/bin"
if ipm_bin not in sys.path:
    sys.path.append(ipm_bin)

from ipm_api_service.design import IPMDesignAPI
from ipm_api_service.projectxml import ProjectXML

device_name = "Ti375N1156"
project_name = "N1156_HSB"
family_name = "Titanium"
is_verbose = True
output_dir = Path(__file__).resolve().parent.parent / "Ti375N1156_HSB"
project_file = output_dir / f"{project_name}.xml"
csirx_module_name = "efx_csi2_rx_top_rx"
mac_module_name = "mac10gbe"

if not project_file.is_file():
    raise FileNotFoundError(
        f"Project file not found: {project_file}. Run build_interface.py first."
    )

ipm_design = IPMDesignAPI(
    device_name=device_name,
    family_name=family_name,
    project_path=output_dir,
    is_verbose=is_verbose,
)
projectxml = ProjectXML(project_xml_path=project_file, is_verbose=is_verbose)

## Efinix CSI-RX IP
ipm_design.create_ip(
    module_name=csirx_module_name,
    vendor="efinixinc.com",
    library="mipi",
    name="efx_csi2_rx_top",
)

csirx_config = {
    "tINIT_NS": "400000",
    "NUM_DATA_LANE": "2",
    "ASYNC_STAGE": "2",
    "CLOCK_FREQ_MHZ": "100",
    "PIXEL_FIFO_DEPTH": "8192",
    "AREGISTER": "8",
    "Pack_40": "1",
    "Pack_48": "1",
    "Pack_56": "1",
    "Pack_64": "1",
    "FRAME_MODE": "\"GENERIC\"",
    "ENABLE_VCX": "0",
    "MIPI_CSI2_RX_DEBUG": "1'b0",
    "MIPI_CSI2_RX_PIXEL_SIDEBAND": "1'b0",
}

ipm_design.config_ip(module_name=csirx_module_name, configs=csirx_config)

## Efinix MAC 10GB Ethernet IP
ipm_design.create_ip(
    module_name=mac_module_name,
    vendor="efinixinc.com",
    library="ethernet",
    name="efx_mac10gbe",
)

mac_config = {
    "CUT_THRU_STORE_FWD": "1'b1",
    "INTER_PACKET_GAP": "4'd12",
    "MTU_FRAME_LENGTH": "15'd4096",
    "MAC_SOURCE_ADDRESS": "48'd0",
    "ENABLE_BROADCAST_FILTER": "1'b0",
    "REG_WIDTH": "6'd32",
    "TXFIFO_DEPTH": "512",
    "AXIS_DATA_WIDTH": "64",
    "DETECT_LINK_FAULT": "1'b1",
    "OPTIMIZE_TIMING": "1'b1",
    "TX_PKT_CNT_DW": "4'd3",
    "PORT_SOURCE_ADDRESS": "1'b0",
}

ipm_design.config_ip(module_name=mac_module_name, configs=mac_config)

for module_name in (csirx_module_name, mac_module_name):
    success, _, _ = ipm_design.validate_ip(module_name=module_name)
    if not success:
        raise RuntimeError(f"IP validation failed: {module_name}")

    ipm_design.generate_ip(module_name=module_name)
    if not projectxml.is_ip_exists(module_name):
        projectxml.add_ip(module_name)

projectxml.save()