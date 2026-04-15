#!/usr/bin/env bash

# Shared riscv64 cross environment for dependency builds and cargo builds.
# This file is intended to be sourced by other scripts.

if [[ -n "${R64_ENV_LOADED:-}" ]]; then
  return 0
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

TARGET="${TARGET:-riscv64gc-unknown-linux-gnu}"
GNU_TRIPLE="${GNU_TRIPLE:-riscv64-linux-gnu}"
R64_DEPS_PREFIX="${R64_DEPS_PREFIX:-${REPO_ROOT}/.local/riscv64}"
R64_SYSROOT="${R64_SYSROOT:-/}"

append_unique() {
  local var_name="$1"
  local value="$2"
  local current="${!var_name:-}"
  if [[ -z "${current}" ]]; then
    printf -v "${var_name}" '%s' "${value}"
    export "${var_name}"
    return
  fi
  if [[ ":${current}:" != *":${value}:"* ]]; then
    printf -v "${var_name}" '%s' "${current}:${value}"
    export "${var_name}"
  fi
}

append_flag() {
  local var_name="$1"
  local flag="$2"
  local current="${!var_name:-}"
  if [[ " ${current} " != *" ${flag} "* ]]; then
    printf -v "${var_name}" '%s' "${current} ${flag}"
    export "${var_name}"
  fi
}

export TARGET
export GNU_TRIPLE
export R64_DEPS_PREFIX
export R64_SYSROOT

export CC="${CC:-${GNU_TRIPLE}-gcc}"
export CXX="${CXX:-${GNU_TRIPLE}-g++}"
export AR="${AR:-${GNU_TRIPLE}-ar}"
export STRIP="${STRIP:-${GNU_TRIPLE}-strip}"
export RANLIB="${RANLIB:-${GNU_TRIPLE}-ranlib}"
export PKG_CONFIG="${PKG_CONFIG:-pkg-config}"

export PKG_CONFIG_ALLOW_CROSS=1
export PKG_CONFIG_ALL_STATIC=1
export PKG_CONFIG_SYSROOT_DIR="${PKG_CONFIG_SYSROOT_DIR:-${R64_SYSROOT}}"

append_unique PKG_CONFIG_LIBDIR "${R64_DEPS_PREFIX}/lib/pkgconfig"
append_unique PKG_CONFIG_LIBDIR "${R64_DEPS_PREFIX}/share/pkgconfig"
append_unique PKG_CONFIG_PATH "${R64_DEPS_PREFIX}/lib/pkgconfig"
append_unique PKG_CONFIG_PATH "${R64_DEPS_PREFIX}/share/pkgconfig"

append_unique LIBRARY_PATH "${R64_DEPS_PREFIX}/lib"
append_unique LD_LIBRARY_PATH "${R64_DEPS_PREFIX}/lib"
append_flag CFLAGS "--sysroot=${R64_SYSROOT}"
append_flag CFLAGS "-I${R64_DEPS_PREFIX}/include"
append_flag CPPFLAGS "--sysroot=${R64_SYSROOT}"
append_flag CPPFLAGS "-I${R64_DEPS_PREFIX}/include"
append_flag CXXFLAGS "--sysroot=${R64_SYSROOT}"
append_flag CXXFLAGS "-I${R64_DEPS_PREFIX}/include"
append_flag LDFLAGS "--sysroot=${R64_SYSROOT}"
append_flag LDFLAGS "-L${R64_DEPS_PREFIX}/lib"
if [[ " ${RUSTFLAGS:-} " != *" -L native=${R64_DEPS_PREFIX}/lib "* ]]; then
  export RUSTFLAGS="${RUSTFLAGS:-} -L native=${R64_DEPS_PREFIX}/lib"
fi

export RUST_FONTCONFIG_DLOPEN=1
export R64_ENV_LOADED=1
