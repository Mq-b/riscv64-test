#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
# shellcheck source=scripts/riscv64-env.sh
source "${SCRIPT_DIR}/riscv64-env.sh"

JOBS="${JOBS:-$(nproc)}"
DEPS_ROOT="${R64_DEPS_ROOT:-${REPO_ROOT}/.deps/riscv64}"
SRC_ROOT="${DEPS_ROOT}/src"
BUILD_ROOT="${DEPS_ROOT}/build"
DL_ROOT="${DEPS_ROOT}/downloads"
CROSS_FILE="${BUILD_ROOT}/meson-cross.txt"

EUDEV_VERSION="${EUDEV_VERSION:-3.2.14}"
LIBEVDEV_VERSION="${LIBEVDEV_VERSION:-1.13.4}"
MTDEV_VERSION="${MTDEV_VERSION:-1.1.6}"
XKBCOMMON_VERSION="${XKBCOMMON_VERSION:-1.7.0}"
LIBINPUT_VERSION="${LIBINPUT_VERSION:-1.19.0}"
MESON_VERSION="${MESON_VERSION:-1.5.1}"
AUTOTOOLS_HOST="${AUTOTOOLS_HOST:-riscv64-unknown-linux-gnu}"
BISON_VERSION="${BISON_VERSION:-3.8.2}"

mkdir -p "${SRC_ROOT}" "${BUILD_ROOT}" "${DL_ROOT}" "${R64_DEPS_PREFIX}"
TOOLS_ROOT="${DEPS_ROOT}/tools"
mkdir -p "${TOOLS_ROOT}"
HOST_TOOLS_PREFIX="${DEPS_ROOT}/host-tools"
mkdir -p "${HOST_TOOLS_PREFIX}/bin"
export PATH="${HOST_TOOLS_PREFIX}/bin:${PATH}"

need_cmd() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "Missing host tool: $1" >&2
    exit 1
  fi
}

for tool in curl tar make ninja pkg-config python3; do
  need_cmd "${tool}"
done

build_host_m4() {
  if command -v m4 >/dev/null 2>&1; then
    return
  fi

  local version="1.4.19"
  local name="m4-${version}"
  local archive="${DL_ROOT}/${name}.tar.xz"
  local src_dir="${TOOLS_ROOT}/${name}"

  download_any "${archive}" \
    "https://sources.buildroot.net/m4/${name}.tar.xz" \
    "https://ftp.gnu.org/gnu/m4/${name}.tar.xz"
  extract "${archive}" "${src_dir}"

  echo "[host-tool] build m4 ${version}"
  pushd "${src_dir}" >/dev/null
  CC="${HOST_CC:-gcc}" CXX="${HOST_CXX:-g++}" AR="${HOST_AR:-ar}" RANLIB="${HOST_RANLIB:-ranlib}" \
    ./configure --prefix="${HOST_TOOLS_PREFIX}"
  CC="${HOST_CC:-gcc}" CXX="${HOST_CXX:-g++}" AR="${HOST_AR:-ar}" RANLIB="${HOST_RANLIB:-ranlib}" \
    make -j"${JOBS}"
  make install
  popd >/dev/null
}

build_host_gperf() {
  if command -v gperf >/dev/null 2>&1; then
    return
  fi

  build_host_m4

  local version="3.1"
  local name="gperf-${version}"
  local archive="${DL_ROOT}/${name}.tar.gz"
  local src_dir="${TOOLS_ROOT}/${name}"

  download_any "${archive}" \
    "https://sources.buildroot.net/gperf/${name}.tar.gz" \
    "https://ftp.gnu.org/gnu/gperf/${name}.tar.gz"
  extract "${archive}" "${src_dir}"

  echo "[host-tool] build gperf ${version}"
  pushd "${src_dir}" >/dev/null
  CC="${HOST_CC:-gcc}" CXX="${HOST_CXX:-g++}" AR="${HOST_AR:-ar}" RANLIB="${HOST_RANLIB:-ranlib}" \
    ./configure --prefix="${HOST_TOOLS_PREFIX}"
  CC="${HOST_CC:-gcc}" CXX="${HOST_CXX:-g++}" AR="${HOST_AR:-ar}" RANLIB="${HOST_RANLIB:-ranlib}" \
    make -j"${JOBS}"
  make install
  popd >/dev/null
}

build_host_bison() {
  if command -v bison >/dev/null 2>&1; then
    return
  fi

  build_host_m4

  local name="bison-${BISON_VERSION}"
  local archive="${DL_ROOT}/${name}.tar.xz"
  local src_dir="${TOOLS_ROOT}/${name}"

  download_any "${archive}" \
    "https://sources.buildroot.net/bison/${name}.tar.xz" \
    "https://ftp.gnu.org/gnu/bison/${name}.tar.xz"
  extract "${archive}" "${src_dir}"

  echo "[host-tool] build bison ${BISON_VERSION}"
  pushd "${src_dir}" >/dev/null
  CC="${HOST_CC:-gcc}" CXX="${HOST_CXX:-g++}" AR="${HOST_AR:-ar}" RANLIB="${HOST_RANLIB:-ranlib}" \
    ./configure --prefix="${HOST_TOOLS_PREFIX}"
  CC="${HOST_CC:-gcc}" CXX="${HOST_CXX:-g++}" AR="${HOST_AR:-ar}" RANLIB="${HOST_RANLIB:-ranlib}" \
    make -j"${JOBS}"
  make install
  popd >/dev/null
}

MESON_BIN=""
ensure_meson() {
  if [[ -n "${MESON_BIN}" ]]; then
    return
  fi

  if command -v meson >/dev/null 2>&1; then
    MESON_BIN="$(command -v meson)"
    return
  fi

  local name="meson-${MESON_VERSION}"
  local archive="${DL_ROOT}/${name}.tar.gz"
  local src_dir="${TOOLS_ROOT}/${name}"

  download_any "${archive}" \
    "https://files.pythonhosted.org/packages/source/m/meson/meson-${MESON_VERSION}.tar.gz" \
    "https://sources.buildroot.net/meson/meson-${MESON_VERSION}.tar.gz" \
    "https://github.com/mesonbuild/meson/archive/refs/tags/${MESON_VERSION}.tar.gz"
  extract "${archive}" "${src_dir}"

  MESON_BIN="python3 ${src_dir}/meson.py"
}

meson_run() {
  ensure_meson
  # shellcheck disable=SC2086
  ${MESON_BIN} "$@"
}

download_any() {
  local out="$1"
  shift
  if [[ -f "${out}" ]]; then
    return
  fi
  local url
  for url in "$@"; do
    echo "[download] ${url}"
    if curl -L --retry 3 --fail --output "${out}" "${url}"; then
      return
    fi
  done
  echo "Failed to download archive: ${out}" >&2
  exit 1
}

extract() {
  local archive="$1"
  local dest_dir="$2"
  local strip_levels="${3:-1}"

  rm -rf "${dest_dir}"
  mkdir -p "${dest_dir}"

  case "${archive}" in
    *.tar.gz|*.tgz) tar -xzf "${archive}" --strip-components="${strip_levels}" -C "${dest_dir}" ;;
    *.tar.xz) tar -xJf "${archive}" --strip-components="${strip_levels}" -C "${dest_dir}" ;;
    *.tar.bz2) tar -xjf "${archive}" --strip-components="${strip_levels}" -C "${dest_dir}" ;;
    *)
      echo "Unsupported archive format: ${archive}" >&2
      exit 1
      ;;
  esac
}

patch_libinput_for_static() {
  local file="$1"
  python3 - "$file" <<'PY'
from pathlib import Path
import sys

path = Path(sys.argv[1])
lines = path.read_text().splitlines()
out = []
in_lib_block = False

for line in lines:
    if not in_lib_block and "lib_libinput = shared_library('input'" in line:
        out.append(line.replace("shared_library", "static_library", 1))
        in_lib_block = True
        continue

    if in_lib_block:
        stripped = line.lstrip()
        if stripped.startswith("version :") or stripped.startswith("link_args :") or stripped.startswith("link_depends :"):
            continue
        out.append(line)
        if stripped == ")":
            in_lib_block = False
        continue

    out.append(line)

path.write_text("\n".join(out) + "\n")
PY
}

write_meson_cross_file() {
  cat > "${CROSS_FILE}" <<MESON
[binaries]
c = '${CC}'
cpp = '${CXX}'
ar = '${AR}'
strip = '${STRIP}'
pkgconfig = '${PKG_CONFIG}'

[host_machine]
system = 'linux'
cpu_family = 'riscv64'
cpu = 'riscv64'
endian = 'little'

[properties]
needs_exe_wrapper = true

[built-in options]
c_args = ['--sysroot=${R64_SYSROOT}', '-I${R64_DEPS_PREFIX}/include']
cpp_args = ['--sysroot=${R64_SYSROOT}', '-I${R64_DEPS_PREFIX}/include']
c_link_args = ['--sysroot=${R64_SYSROOT}', '-L${R64_DEPS_PREFIX}/lib']
cpp_link_args = ['--sysroot=${R64_SYSROOT}', '-L${R64_DEPS_PREFIX}/lib']
MESON
}

pc_exists() {
  "${PKG_CONFIG}" --exists "$1"
}

build_eudev() {
  if pc_exists libudev; then
    echo "[skip] libudev already available"
    return
  fi

  build_host_gperf

  local name="eudev-${EUDEV_VERSION}"
  local archive="${DL_ROOT}/${name}.tar.gz"
  local src_dir="${SRC_ROOT}/eudev"

  download_any "${archive}" \
    "https://sources.buildroot.net/eudev/eudev-${EUDEV_VERSION}.tar.gz" \
    "https://github.com/eudev-project/eudev/archive/refs/tags/v${EUDEV_VERSION}.tar.gz"
  extract "${archive}" "${src_dir}"

  pushd "${src_dir}" >/dev/null
  if [[ ! -x ./configure ]]; then
    if command -v autoreconf >/dev/null 2>&1; then
      autoreconf -fiv
    else
      echo "eudev configure script is missing and autoreconf is not installed." >&2
      echo "Install autoconf/automake/libtool or switch EUDEV source to a release tarball." >&2
      exit 1
    fi
  fi

  echo "[build] eudev ${EUDEV_VERSION}"
  if ! ./configure \
      --host="${AUTOTOOLS_HOST}" \
      --prefix="${R64_DEPS_PREFIX}" \
      --enable-static \
      --disable-shared \
      --disable-hwdb \
      --disable-manpages \
      --disable-introspection; then
    ./configure \
      --host="${AUTOTOOLS_HOST}" \
      --prefix="${R64_DEPS_PREFIX}" \
      --enable-static \
      --disable-shared
  fi
  make -j"${JOBS}"
  make install
  popd >/dev/null
}

meson_setup_or_reconfigure() {
  local src_dir="$1"
  local build_dir="$2"
  shift 2

  if [[ -d "${build_dir}" ]]; then
    meson_run setup --reconfigure "${build_dir}" "${src_dir}" "$@"
  else
    meson_run setup "${build_dir}" "${src_dir}" "$@"
  fi
}

build_libevdev() {
  if pc_exists libevdev; then
    echo "[skip] libevdev already available"
    return
  fi

  local name="libevdev-${LIBEVDEV_VERSION}"
  local archive="${DL_ROOT}/${name}.tar.xz"
  local src_dir="${SRC_ROOT}/libevdev"
  local build_dir="${BUILD_ROOT}/libevdev"

  download_any "${archive}" \
    "https://sources.buildroot.net/libevdev/${name}.tar.xz" \
    "https://www.freedesktop.org/software/libevdev/${name}.tar.xz"
  extract "${archive}" "${src_dir}"

  echo "[build] libevdev ${LIBEVDEV_VERSION}"
  if ! meson_setup_or_reconfigure "${src_dir}" "${build_dir}" \
      --cross-file "${CROSS_FILE}" \
      --prefix "${R64_DEPS_PREFIX}" \
      --libdir lib \
      --buildtype release \
      --default-library static \
      -Dtests=disabled \
      -Ddocumentation=disabled; then
    meson_setup_or_reconfigure "${src_dir}" "${build_dir}" \
      --cross-file "${CROSS_FILE}" \
      --prefix "${R64_DEPS_PREFIX}" \
      --libdir lib \
      --buildtype release \
      --default-library static
  fi

  meson_run compile -C "${build_dir}" -j "${JOBS}"
  meson_run install -C "${build_dir}"
}

build_mtdev() {
  if pc_exists mtdev; then
    echo "[skip] mtdev already available"
    return
  fi

  local name="mtdev-${MTDEV_VERSION}"
  local archive="${DL_ROOT}/${name}.tar.bz2"
  local src_dir="${SRC_ROOT}/mtdev"

  download_any "${archive}" \
    "https://sources.buildroot.net/mtdev/${name}.tar.bz2" \
    "https://bitmath.org/code/mtdev/${name}.tar.bz2"
  extract "${archive}" "${src_dir}"

  if [[ -f /usr/share/misc/config.sub ]]; then
    cp /usr/share/misc/config.sub "${src_dir}/config-aux/config.sub"
  fi
  if [[ -f /usr/share/misc/config.guess ]]; then
    cp /usr/share/misc/config.guess "${src_dir}/config-aux/config.guess"
  fi

  echo "[build] mtdev ${MTDEV_VERSION}"
  pushd "${src_dir}" >/dev/null
  ./configure \
    --host="${AUTOTOOLS_HOST}" \
    --prefix="${R64_DEPS_PREFIX}" \
    --enable-static \
    --disable-shared
  make -j"${JOBS}"
  make install
  popd >/dev/null
}

build_xkbcommon() {
  if pc_exists xkbcommon; then
    echo "[skip] xkbcommon already available"
    return
  fi

  build_host_bison

  local name="libxkbcommon-${XKBCOMMON_VERSION}"
  local archive="${DL_ROOT}/${name}.tar.xz"
  local src_dir="${SRC_ROOT}/xkbcommon"
  local build_dir="${BUILD_ROOT}/xkbcommon"

  download_any "${archive}" \
    "https://sources.buildroot.net/libxkbcommon/${name}.tar.xz" \
    "https://xkbcommon.org/download/${name}.tar.xz"
  extract "${archive}" "${src_dir}"

  echo "[build] xkbcommon ${XKBCOMMON_VERSION}"
  if ! meson_setup_or_reconfigure "${src_dir}" "${build_dir}" \
      --cross-file "${CROSS_FILE}" \
      --prefix "${R64_DEPS_PREFIX}" \
      --libdir lib \
      --buildtype release \
      --default-library static \
      -Denable-x11=false \
      -Denable-wayland=false \
      -Denable-docs=false \
      -Denable-tools=false \
      -Denable-xkbregistry=false \
      -Denable-bash-completion=false; then
    meson_setup_or_reconfigure "${src_dir}" "${build_dir}" \
      --cross-file "${CROSS_FILE}" \
      --prefix "${R64_DEPS_PREFIX}" \
      --libdir lib \
      --buildtype release \
      --default-library static \
      -Denable-x11=false \
      -Denable-wayland=false
  fi

  meson_run compile -C "${build_dir}" -j "${JOBS}"
  meson_run install -C "${build_dir}"
}

build_libinput() {
  if pc_exists libinput; then
    echo "[skip] libinput already available"
    return
  fi

  local name="libinput-${LIBINPUT_VERSION}"
  local archive="${DL_ROOT}/${name}.tar.xz"
  local src_dir="${SRC_ROOT}/libinput"
  local build_dir="${BUILD_ROOT}/libinput"

  download_any "${archive}" \
    "https://sources.buildroot.net/libinput/${name}.tar.xz" \
    "https://www.freedesktop.org/software/libinput/${name}.tar.xz"
  extract "${archive}" "${src_dir}"
  patch_libinput_for_static "${src_dir}/meson.build"
  rm -rf "${build_dir}"

  echo "[build] libinput ${LIBINPUT_VERSION}"
  if ! meson_setup_or_reconfigure "${src_dir}" "${build_dir}" \
      --cross-file "${CROSS_FILE}" \
      --prefix "${R64_DEPS_PREFIX}" \
      --libdir lib \
      --buildtype release \
      --default-library static \
      -Ddocumentation=false \
      -Dtests=false \
      -Ddebug-gui=false \
      -Dlibwacom=false; then
    meson_setup_or_reconfigure "${src_dir}" "${build_dir}" \
      --cross-file "${CROSS_FILE}" \
      --prefix "${R64_DEPS_PREFIX}" \
      --libdir lib \
      --buildtype release \
      --default-library static
  fi

  meson_run compile -C "${build_dir}" -j "${JOBS}"
  meson_run install -C "${build_dir}"
}

check_final() {
  local missing=()
  for pc in libudev libevdev mtdev libinput xkbcommon; do
    if ! pc_exists "${pc}"; then
      missing+=("${pc}.pc")
    fi
  done

  if (( ${#missing[@]} > 0 )); then
    echo "Missing target pkg-config files after build: ${missing[*]}" >&2
    exit 1
  fi
}

write_meson_cross_file
build_eudev
build_libevdev
build_mtdev
build_xkbcommon
build_libinput
check_final

echo "riscv64 static deps ready in: ${R64_DEPS_PREFIX}"
