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

构建命令：

```bash
PKG_CONFIG_ALLOW_CROSS=1 RUST_FONTCONFIG_DLOPEN=1 cargo build --release --target riscv64gc-unknown-linux-gnu
```

或使用仓库脚本（自动设置交叉编译环境变量）：

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
- 为了避免宿主机缺少 `riscv64` 版 `libudev/libinput` 开发包导致交叉编译失败，项目通过 [vendor/i-slint-backend-linuxkms-1.15.1](/home/mq-b/project/rust/riscv64-test/vendor/i-slint-backend-linuxkms-1.15.1) 打了本地补丁，移除了构建期输入栈依赖。
- 上述补丁会让 `riscv64` 构建先保证“可编译可显示”；若你需要键盘/触摸输入，再恢复官方 backend 并配置目标系统的 `libudev/libinput` 交叉依赖。
- 访问 `/dev/fb0`、`/dev/input*`、`/dev/tty*` 通常需要 root 权限或对应设备权限。
- 如果你的系统有 DRM/KMS，去掉 `SLINT_BACKEND_LINUXFB=1` 也可尝试让 Slint 自动选择显示路径。
