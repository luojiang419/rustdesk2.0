# 11-ping延迟测速修复完成

## 已完成内容
- 读取最新接力基线：`进度快照/10-中继延迟修复版强制编译完成.md`。
- 新建阶段备份：`backup/6-ping延迟测速修复阶段/`。
- 修复服务器延迟仍显示 `0ms` 的问题：
  - 后端测速优先使用系统 `ping` 输出中的延迟数值。
  - 支持解析 `time=14ms`、`时间=15ms`、`time=0.42 ms`、`time<1ms` 等格式。
  - `ping` 不可用或失败时，继续使用原 TCP connect 作为在线回退。
  - TCP 回退成功但耗时小于 1ms 时，最小显示为 `1ms`，避免再次出现 `0ms`。
- 已重新编译 Windows Release 测试版。
- 已清理本轮测试/检查产生的临时缓存：
  - `G:\data\app\rustdesk\target\debug`

## 当前修改到哪个模块
- 当前模块：服务器配置卡片延迟测速后端。
- 当前状态：已完成，可直接运行 Windows Release 产物测试刷新按钮。

## 具体修改的代码前后对比

### 1. `src/server_profiles.rs`
修改前：
```rust
async fn test_endpoint_latency(server: &str, default_port: i32) -> (i64, String) {
    if server.is_empty() {
        return (-1, String::new());
    }
    let start = Instant::now();
    match connect_tcp(check_port(server, default_port), CONNECT_TIMEOUT).await {
        Ok(_) => (start.elapsed().as_millis() as i64, String::new()),
        Err(err) => (-1, err.to_string()),
    }
}
```

修改后：
```rust
async fn test_endpoint_latency(server: &str, default_port: i32) -> (i64, String) {
    if server.is_empty() {
        return (-1, String::new());
    }
    if let Some(host) = ping_host_for_endpoint(server) {
        if let Ok(latency_ms) = ping_latency_ms(host).await {
            return (latency_ms, String::new());
        }
    }
    let start = Instant::now();
    match connect_tcp(check_port(server, default_port), CONNECT_TIMEOUT).await {
        Ok(_) => (elapsed_millis_at_least_one(start), String::new()),
        Err(err) => (-1, err.to_string()),
    }
}
```

新增：
```rust
async fn ping_latency_ms(host: String) -> Result<i64, String> {
    let output = tokio::task::spawn_blocking(move || ping_command(&host).output())
        .await
        .map_err(|err| err.to_string())?
        .map_err(|err| err.to_string())?;
    let mut text = String::from_utf8_lossy(&output.stdout).to_string();
    if !output.stderr.is_empty() {
        text.push('\n');
        text.push_str(&String::from_utf8_lossy(&output.stderr));
    }
    if let Some(latency_ms) = parse_ping_latency_ms(&text) {
        return Ok(latency_ms);
    }
    Err(if output.status.success() {
        "Unable to parse ping latency".to_owned()
    } else {
        format!("Ping failed: {}", output.status)
    })
}
```

新增测试：
```rust
#[test]
fn extracts_ping_host_from_endpoint() {
    assert_eq!(
        ping_host_for_endpoint("example.com:21117").as_deref(),
        Some("example.com")
    );
    assert_eq!(
        ping_host_for_endpoint("[2001:db8::1]:21117").as_deref(),
        Some("2001:db8::1")
    );
}

#[test]
fn parses_ping_latency_outputs() {
    assert_eq!(
        parse_ping_latency_ms("Reply from 8.8.8.8: bytes=32 time=14ms TTL=117"),
        Some(14)
    );
    assert_eq!(
        parse_ping_latency_ms("来自 8.8.8.8 的回复: 字节=32 时间=15ms TTL=117"),
        Some(15)
    );
    assert_eq!(
        parse_ping_latency_ms("64 bytes from 8.8.8.8: icmp_seq=1 ttl=117 time=0.42 ms"),
        Some(1)
    );
}
```

## 已验证结果
- `rustfmt --edition 2021 src\server_profiles.rs`：通过。
- `cargo test --lib server_profiles --no-default-features`：通过，5 个测试通过。
- `cargo check --features flutter`：通过。
- `cargo build --features flutter --release`：通过。
- `D:\flutter\bin\flutter.bat build windows --release`：通过。
- 构建输出中仍有既有 warning：
  - Rust 侧 unused / deprecated warning。
  - Flutter 侧 `file_picker` default plugin 声明 warning。
  - 本轮未处理这些无关 warning。

## 构建产物
- 测试入口：
  - `G:\data\app\rustdesk\flutter\build\windows\x64\runner\Release\rustdesk2.0.exe`
- 关键后端 DLL：
  - `G:\data\app\rustdesk\flutter\build\windows\x64\runner\Release\librustdesk.dll`
  - 大小：30550016
  - 时间：2026-06-30 13:40:47

## 待办清单（未完成）
- 运行 `rustdesk2.0.exe`。
- 打开 `ID/Relay Server` 设置卡片。
- 点击刷新按钮，确认 `Relay Server` 行显示 ping 延迟值，不再显示 `0ms`。
- 如果某些服务器禁 ping，应确认它仍会通过 TCP 回退显示在线延迟或离线状态。

## 下一步要做什么
1. 运行 `G:\data\app\rustdesk\flutter\build\windows\x64\runner\Release\rustdesk2.0.exe`。
2. 打开服务器设置页并点击刷新。
3. 观察 ID Server 和 Relay Server 延迟值是否变成真实 ping 值。
