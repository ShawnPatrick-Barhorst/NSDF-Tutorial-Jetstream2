#!/usr/bin/env bash
set -euo pipefail

ENV_NAME="NSDF-Tutorial"
KERNEL_NAME="nsdf-tutorial"
KERNEL_DISPLAY='Python (NSDF-Tutorial)'

# Use script location as base so relative paths work
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# Ensure conda is available (Jetstream module)
if command -v module >/dev/null 2>&1; then
  module purge || true
  module load miniforge
fi

if ! command -v conda >/dev/null 2>&1; then
  echo "ERROR: conda not found. Did you 'module load miniforge'?" >&2
  exit 1
fi

# Make conda activate work in scripts
source "$(conda info --base)/etc/profile.d/conda.sh"

echo "[1/7] Create env from environment.yml"
# If it already exists, remove it to match your exact steps
if conda env list | awk '{print $1}' | grep -qx "$ENV_NAME"; then
  conda env remove -n "$ENV_NAME" -y
fi
conda env create -f environment.yml

echo "[2/7] Activate env: $ENV_NAME"
conda activate "$ENV_NAME"
hash -r

echo "[3/7] Verify activation (hard fail if wrong)"
python - <<PY
import os, sys
env = os.environ.get("CONDA_DEFAULT_ENV")
prefix = os.environ.get("CONDA_PREFIX")
print("CONDA_DEFAULT_ENV:", env)
print("CONDA_PREFIX:", prefix)
print("sys.executable:", sys.executable)
if env != "$ENV_NAME":
    raise SystemExit(f"ERROR: expected CONDA_DEFAULT_ENV=$ENV_NAME but got {env}")
PY

echo "[4/7] Install GEOtiled/geotiled editable"
GEOTILED_DIR="$SCRIPT_DIR/GEOtiled/geotiled"
if [[ ! -d "$GEOTILED_DIR" ]]; then
  echo "ERROR: GEOtiled/geotiled dir not found: $GEOTILED_DIR" >&2
  exit 1
fi
python -m pip install -e "$GEOTILED_DIR"

echo "[5/7] Run setup_openvisuspy.sh"
SETUP_SCRIPT="$SCRIPT_DIR/setup_openvisuspy.sh"
if [[ ! -f "$SETUP_SCRIPT" ]]; then
  echo "ERROR: setup script not found: $SETUP_SCRIPT" >&2
  exit 1
fi
chmod +x "$SETUP_SCRIPT"
"$SETUP_SCRIPT"

echo "[6/7] Install openvisuspy editable (from Materials/openvisuspy)"
OPENVISUSPY_DIR="$SCRIPT_DIR/openvisuspy"
if [[ ! -d "$OPENVISUSPY_DIR" ]]; then
  echo "ERROR: openvisuspy dir not found after setup: $OPENVISUSPY_DIR" >&2
  echo "If setup clones elsewhere, update OPENVISUSPY_DIR in this script." >&2
  exit 1
fi
python -m pip install -e "$OPENVISUSPY_DIR"

echo "[7/7] Install ipykernel + register kernel"
python -m pip install -U ipykernel
python -m ipykernel install --user --name "$KERNEL_NAME" --display-name "$KERNEL_DISPLAY"

echo "DONE"
echo "Run 'jupyter kernelspec list' to confirm kernel registration."
