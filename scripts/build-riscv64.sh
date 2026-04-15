#!/usr/bin/env bash
set -euo pipefail

TARGET="${TARGET:-riscv64gc-unknown-linux-gnu}"

export PKG_CONFIG_ALLOW_CROSS=1
export RUST_FONTCONFIG_DLOPEN=1

exec cargo build --release --target "${TARGET}" "$@"
