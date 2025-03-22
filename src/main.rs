use std::process::Command;use std::path::Path;fn run_binwalk(file_path: &str, args: &[&str]) -> Result<(), String> {    println!("Running binwalk on {}", file_path);        let mut command = Command::new("binwalk");    command.arg(file_path);    for arg in args {        command.arg(arg);
    }
    
    let output = command.output().map_err(|e| format!("Failed to execute binwalk: {}", e))?;
    
    if output.status.success() {
        let stdout = String::from_utf8_lossy(&output.stdout);
        println!("Binwalk output:\n{}", stdout);
        Ok(())
    } else {
        let stderr = String::from_utf8_lossy(&output.stderr);