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

#!/usr/bin/env python3
"""Regenerate Ti375N1156_HSB (interface + IP). Synth / P&R / program in the Efinity GUI.

Prerequisites:
  source <EFINITY_HOME>/bin/setup.sh
  Close the Efinity GUI before regenerating the project and IP.
"""

from __future__ import annotations

import os
import subprocess
import sys
from pathlib import Path

SCRIPT_DIR = Path(__file__).resolve().parent
PROJECT_DIR = SCRIPT_DIR.parent / "Ti375N1156_HSB"
PROJECT_XML = PROJECT_DIR / "N1156_HSB.xml"
BUILD_INTERFACE = SCRIPT_DIR / "build_interface.py"
IP_GEN = SCRIPT_DIR / "ip_gen.py"


def require_env() -> None:
    missing = [name for name in ("EFINITY_HOME", "EFXPT_HOME", "EFXIPM_HOME") if not os.environ.get(name)]
    if missing:
        raise SystemExit(
            "Missing environment variable(s): "
            + ", ".join(missing)
            + ". Source <EFINITY_HOME>/bin/setup.sh first."
        )


def run(cmd: list[str], *, cwd: Path) -> None:
    print(f"\n==> {' '.join(cmd)}  (cwd={cwd})")
    try:
        subprocess.run(cmd, cwd=cwd, check=True)
    except subprocess.CalledProcessError as exc:
        raise SystemExit(f"Command failed with exit code {exc.returncode}: {' '.join(cmd)}") from None


def main() -> None:
    require_env()
    run([sys.executable, str(BUILD_INTERFACE)], cwd=SCRIPT_DIR)
    run([sys.executable, str(IP_GEN)], cwd=SCRIPT_DIR)
    if not PROJECT_XML.is_file():
        raise SystemExit(f"Expected project file missing after build: {PROJECT_XML}")
    print(f"\nDone. Open {PROJECT_XML} in Efinity for synth / P&R / program.")


if __name__ == "__main__":
    main()
