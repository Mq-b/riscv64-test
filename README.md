# RISCV64-TEST

测试 rust 使用 riscv64 工具链。

## 构建

```bash
cargo build --release --target riscv64gc-unknown-linux-gnu
```

## 测试

```bash
➜  debug git:(master) ✗ qemu-riscv64 ./riscv64-test
Hello, world!
```
