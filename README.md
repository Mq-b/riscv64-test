# RISCV64 Slint Demo

`Rust + Slint` 全屏双按钮示例，面向嵌入式 Linux。

## 代码说明

- `ui/app-window.slint` 定义全屏界面，包含两个大按钮（`Button A`、`Button B`）。
- `src/main.rs` 只做事件绑定和程序启动逻辑。
- `build.rs` 负责在编译时把 `.slint` 文件编译进 Rust 代码。
- 点击按钮会更新顶部状态文字，并在标准输出打印点击日志。
- 运行时使用 `linuxkms + software renderer`，并通过 `SLINT_BACKEND_LINUXFB=1` 强制走 `/dev/fb0`。

## 交叉编译（静态链接，riscv64）

项目已在 `.cargo/config.toml` 里配置：

- 目标：`riscv64gc-unknown-linux-gnu`
- 链接器：`riscv64-linux-gnu-gcc`
- `rustflags`：`-C target-feature=+crt-static`

主机至少需要可用的交叉工具链：`riscv64-linux-gnu-gcc/g++`、`pkg-config`、`ninja`。  
其余构建工具（如 `meson/m4/gperf/bison`）在缺失时会由脚本自动下载源码构建到本地工具目录。

先构建 `riscv64` 目标静态依赖（源码下载并交叉编译到本地目录）：

```bash
./scripts/build-riscv64-deps.sh
```

再编译应用（脚本会 `source` 环境变量；如果缺依赖会自动触发上一步）：

```bash
./scripts/build-riscv64.sh
```

产物路径：

```bash
target/riscv64gc-unknown-linux-gnu/release/riscv64-test
```

## 本机预览（x86_64）

为了在开发机先看 UI，项目对非 `riscv64` 目标启用了 `winit-wayland + software renderer`。

构建命令：

```bash
RUST_FONTCONFIG_DLOPEN=1 cargo build --release --target x86_64-unknown-linux-gnu
```

运行命令：

```bash
RUST_FONTCONFIG_DLOPEN=1 cargo run --release --target x86_64-unknown-linux-gnu
```

产物路径：

```bash
target/x86_64-unknown-linux-gnu/release/riscv64-test
```

## 目标机运行（fb0）

在目标机纯控制台环境（无 X11/Wayland）运行：

```bash
SLINT_BACKEND=linuxkms-software \
SLINT_BACKEND_LINUXFB=1 \
./riscv64-test
```

## 备注

- `Cargo.toml` 已按目标架构分流依赖：`riscv64` 使用 `linuxkms`，其他架构使用 `winit-wayland`。
- 已恢复官方 `linuxkms` 输入链路（`libudev + libinput + xkbcommon`），可用于键盘/触摸输入。
- `scripts/build-riscv64-deps.sh` 会下载并交叉编译这些依赖为静态库，默认安装到 `.local/riscv64`。
- 第一次运行会在 `.deps/riscv64` 下缓存源码和主机工具（`m4/gperf/bison/meson`），后续会复用。
- 公共交叉环境由 `scripts/riscv64-env.sh` 提供，构建脚本会自动 `source`，你也可以手动加载：

  ```bash
  source scripts/riscv64-env.sh
  ```

- 访问 `/dev/fb0`、`/dev/input*`、`/dev/tty*` 通常需要 root 权限或对应设备权限。
- 如果你的系统有 DRM/KMS，去掉 `SLINT_BACKEND_LINUXFB=1` 也可尝试让 Slint 自动选择显示路径。
