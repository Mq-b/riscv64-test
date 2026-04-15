slint::include_modules!();

fn main() -> Result<(), slint::PlatformError> {
    let ui = AppWindow::new()?;

    let weak_left = ui.as_weak();
    ui.on_left_clicked(move || {
        if let Some(ui) = weak_left.upgrade() {
            ui.set_status_text("Button A pressed".into());
        }
        println!("Button A pressed");
    });

    let weak_right = ui.as_weak();
    ui.on_right_clicked(move || {
        if let Some(ui) = weak_right.upgrade() {
            ui.set_status_text("Button B pressed".into());
        }
        println!("Button B pressed");
    });

    ui.run()
}
