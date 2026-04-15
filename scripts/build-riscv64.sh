#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/riscv64-env.sh
source "${SCRIPT_DIR}/riscv64-env.sh"

TARGET="${TARGET:-riscv64gc-unknown-linux-gnu}"
AUTO_BUILD_DEPS="${AUTO_BUILD_DEPS:-1}"

missing_pc=()
for pc in libudev libinput xkbcommon; do
  if ! "${PKG_CONFIG}" --exists "${pc}" >/dev/null 2>&1; then
    missing_pc+=("${pc}.pc")
  fi
done

if (( ${#missing_pc[@]} > 0 )); then
  if [[ "${AUTO_BUILD_DEPS}" == "1" ]]; then
    echo "Missing target pkg-config files: ${missing_pc[*]}"
    echo "Attempting source build for riscv64 static deps..."
    "${SCRIPT_DIR}/build-riscv64-deps.sh"
  else
    echo "Missing target pkg-config files: ${missing_pc[*]}" >&2
    echo "Run: ./scripts/build-riscv64-deps.sh" >&2
    exit 1
  fi
fi

exec cargo build --release --target "${TARGET}" "$@"
