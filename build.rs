fn main() {
    slint_build::compile("ui/app-window.slint").expect("failed to compile Slint UI");

    let target = std::env::var("TARGET").unwrap_or_default();
    if !target.contains("riscv64") {
        return;
    }

    let deps_prefix = std::env::var("R64_DEPS_PREFIX").unwrap_or_else(|_| {
        let manifest_dir = std::env::var("CARGO_MANIFEST_DIR").unwrap_or_else(|_| ".".into());
        format!("{manifest_dir}/.local/riscv64")
    });

    println!("cargo:rustc-link-search=native={deps_prefix}/lib");
    // libinput static archive depends on these libs; enforce link order near final link args.
    println!("cargo:rustc-link-arg=-Wl,-Bstatic");
    println!("cargo:rustc-link-arg=-Wl,--start-group");
    println!("cargo:rustc-link-arg=-linput");
    println!("cargo:rustc-link-arg=-levdev");
    println!("cargo:rustc-link-arg=-lmtdev");
    println!("cargo:rustc-link-arg=-ludev");
    println!("cargo:rustc-link-arg=-Wl,--end-group");
    println!("cargo:rustc-link-arg=-Wl,-Bdynamic");
}
