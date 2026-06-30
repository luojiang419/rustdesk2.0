use hbb_common::{
    config::{Config, CONNECT_TIMEOUT, RELAY_PORT, RENDEZVOUS_PORT},
    futures::future::{join, join_all},
    socket_client::{check_port, connect_tcp},
    tokio,
};
use serde_derive::{Deserialize, Serialize};
use std::time::Instant;

pub const OPTION_SERVER_PROFILES: &str = "server-profiles";
pub const OPTION_AUTO_SERVER_SWITCH_THRESHOLD_MS: &str = "auto-server-switch-threshold-ms";
pub const DEFAULT_AUTO_SERVER_SWITCH_THRESHOLD_MS: u64 = 300;

#[derive(Debug, Clone, Default, Serialize, Deserialize, PartialEq, Eq)]
#[serde(rename_all = "camelCase")]
pub struct ServerProfile {
    pub id: String,
    pub name: String,
    pub id_server: String,
    pub relay_server: String,
    pub api_server: String,
    pub key: String,
    #[serde(default = "default_enabled")]
    pub enabled: bool,
}

#[derive(Debug, Clone, Default, Serialize, Deserialize, PartialEq, Eq)]
#[serde(rename_all = "camelCase")]
pub struct ServerProfileStatus {
    pub id: String,
    pub id_server: String,
    pub relay_server: String,
    pub latency_ms: i64,
    pub error: String,
    pub relay_latency_ms: i64,
    pub relay_error: String,
}

fn default_enabled() -> bool {
    true
}

fn trim_end_slash(input: &str) -> String {
    input.trim().trim_end_matches('/').to_owned()
}

pub fn normalize_server(input: &str) -> String {
    trim_end_slash(input)
}

fn normalize_key(input: &str) -> String {
    input.trim().to_owned()
}

fn profile_id_for(server: &str, index: usize) -> String {
    let mut id: String = server
        .chars()
        .map(|c| {
            if c.is_ascii_alphanumeric() {
                c.to_ascii_lowercase()
            } else {
                '-'
            }
        })
        .collect();
    while id.contains("--") {
        id = id.replace("--", "-");
    }
    let id = id.trim_matches('-');
    if id.is_empty() {
        format!("server-{}", index + 1)
    } else {
        format!("server-{}-{}", index + 1, id)
    }
}

fn sanitize_profiles(mut profiles: Vec<ServerProfile>) -> Vec<ServerProfile> {
    let mut out = Vec::new();
    for (idx, mut profile) in profiles.drain(..).enumerate() {
        profile.id_server = normalize_server(&profile.id_server);
        profile.relay_server = normalize_server(&profile.relay_server);
        profile.api_server = normalize_server(&profile.api_server);
        profile.key = normalize_key(&profile.key);
        profile.name = profile.name.trim().to_owned();
        if profile.id_server.is_empty() {
            continue;
        }
        if profile.name.is_empty() {
            profile.name = profile.id_server.clone();
        }
        if profile.id.trim().is_empty() {
            profile.id = profile_id_for(&profile.id_server, idx);
        } else {
            profile.id = profile.id.trim().to_owned();
        }
        if !out
            .iter()
            .any(|existing: &ServerProfile| existing.id_server == profile.id_server)
        {
            out.push(profile);
        }
    }
    out
}

fn decode_profiles(json: &str) -> Vec<ServerProfile> {
    if json.trim().is_empty() {
        return Vec::new();
    }
    serde_json::from_str::<Vec<ServerProfile>>(json)
        .map(sanitize_profiles)
        .unwrap_or_default()
}

fn encode_profiles(profiles: &[ServerProfile]) -> String {
    serde_json::to_string(profiles).unwrap_or_default()
}

fn legacy_profile_from_options() -> Option<ServerProfile> {
    let id_server = normalize_server(&Config::get_option("custom-rendezvous-server"));
    let relay_server = normalize_server(&Config::get_option("relay-server"));
    let api_server = normalize_server(&Config::get_option("api-server"));
    let key = normalize_key(&Config::get_option("key"));
    if id_server.is_empty() && relay_server.is_empty() && api_server.is_empty() && key.is_empty() {
        return None;
    }
    Some(ServerProfile {
        id: profile_id_for(&id_server, 0),
        name: if id_server.is_empty() {
            "Server 1".to_owned()
        } else {
            id_server.clone()
        },
        id_server,
        relay_server,
        api_server,
        key,
        enabled: true,
    })
}

fn sync_legacy_options(profiles: &[ServerProfile]) {
    let enabled: Vec<&ServerProfile> = profiles
        .iter()
        .filter(|profile| profile.enabled && !profile.id_server.is_empty())
        .collect();
    let servers = enabled
        .iter()
        .map(|profile| profile.id_server.clone())
        .collect::<Vec<_>>()
        .join(",");
    Config::set_option("rendezvous-servers".to_owned(), servers);
    if let Some(primary) = enabled.first() {
        Config::set_option(
            "custom-rendezvous-server".to_owned(),
            primary.id_server.clone(),
        );
        Config::set_option("relay-server".to_owned(), primary.relay_server.clone());
        Config::set_option("api-server".to_owned(), primary.api_server.clone());
        Config::set_option("key".to_owned(), primary.key.clone());
    }
}

pub fn get_profiles() -> Vec<ServerProfile> {
    let mut profiles = decode_profiles(&Config::get_option(OPTION_SERVER_PROFILES));
    if profiles.is_empty() {
        if let Some(profile) = legacy_profile_from_options() {
            profiles.push(profile);
        }
    }
    profiles
}

pub fn get_profiles_json() -> String {
    let profiles = get_profiles();
    if Config::get_option(OPTION_SERVER_PROFILES).trim().is_empty() && !profiles.is_empty() {
        save_profiles(profiles.clone());
    }
    encode_profiles(&profiles)
}

pub fn save_profiles(profiles: Vec<ServerProfile>) -> String {
    let profiles = sanitize_profiles(profiles);
    let json = encode_profiles(&profiles);
    Config::set_option(OPTION_SERVER_PROFILES.to_owned(), json.clone());
    sync_legacy_options(&profiles);
    ensure_default_threshold();
    json
}

pub fn save_profiles_json(json: &str) -> String {
    save_profiles(decode_profiles(json))
}

pub fn ensure_default_threshold() {
    if Config::get_option(OPTION_AUTO_SERVER_SWITCH_THRESHOLD_MS)
        .trim()
        .is_empty()
    {
        Config::set_option(
            OPTION_AUTO_SERVER_SWITCH_THRESHOLD_MS.to_owned(),
            DEFAULT_AUTO_SERVER_SWITCH_THRESHOLD_MS.to_string(),
        );
    }
}

pub fn auto_switch_threshold_ms() -> u64 {
    Config::get_option(OPTION_AUTO_SERVER_SWITCH_THRESHOLD_MS)
        .parse::<u64>()
        .unwrap_or(DEFAULT_AUTO_SERVER_SWITCH_THRESHOLD_MS)
}

pub fn enabled_profiles() -> Vec<ServerProfile> {
    get_profiles()
        .into_iter()
        .filter(|profile| profile.enabled && !profile.id_server.is_empty())
        .collect()
}

fn endpoint_matches(configured: &str, endpoint: &str, default_port: i32) -> bool {
    let configured = normalize_server(configured);
    let endpoint = normalize_server(endpoint);
    if configured.is_empty() || endpoint.is_empty() {
        return false;
    }
    configured == endpoint
        || check_port(configured, default_port) == check_port(endpoint, default_port)
}

pub fn key_for_server(server: &str) -> String {
    enabled_profiles()
        .into_iter()
        .find(|profile| {
            endpoint_matches(&profile.id_server, server, RENDEZVOUS_PORT)
                || endpoint_matches(&profile.relay_server, server, RELAY_PORT)
        })
        .map(|profile| profile.key)
        .unwrap_or_default()
}

pub fn relay_for_server(server: &str) -> String {
    enabled_profiles()
        .into_iter()
        .find(|profile| endpoint_matches(&profile.id_server, server, RENDEZVOUS_PORT))
        .map(|profile| profile.relay_server)
        .unwrap_or_default()
}

pub fn api_for_server(server: &str) -> String {
    enabled_profiles()
        .into_iter()
        .find(|profile| endpoint_matches(&profile.id_server, server, RENDEZVOUS_PORT))
        .map(|profile| profile.api_server)
        .unwrap_or_default()
}

pub fn import_profiles_from_doc(path: &str) -> String {
    let Ok(content) = std::fs::read_to_string(path) else {
        return get_profiles_json();
    };
    let mut profiles = Vec::new();
    let mut pending_server = String::new();
    for raw_line in content.lines() {
        let line = raw_line.trim();
        if line.is_empty() {
            continue;
        }
        let lower = line.to_ascii_lowercase();
        if lower.starts_with("key") || line.starts_with("key：") || line.starts_with("key:") {
            let key = line
                .split_once('：')
                .or_else(|| line.split_once(':'))
                .map(|(_, value)| value.trim())
                .unwrap_or_default();
            if !pending_server.is_empty() {
                let idx = profiles.len();
                profiles.push(ServerProfile {
                    id: profile_id_for(&pending_server, idx),
                    name: pending_server.clone(),
                    id_server: pending_server.clone(),
                    relay_server: pending_server.clone(),
                    api_server: String::new(),
                    key: key.to_owned(),
                    enabled: true,
                });
                pending_server.clear();
            }
        } else {
            pending_server = normalize_server(line);
        }
    }
    if profiles.is_empty() {
        get_profiles_json()
    } else {
        save_profiles(profiles)
    }
}

#[hbb_common::tokio::main(flavor = "current_thread")]
pub async fn test_profiles_latency_json(json: String) -> String {
    let profiles = sanitize_profiles(decode_profiles(&json));
    let futs = profiles.into_iter().map(|profile| async move {
        let id = profile.id;
        let id_server = profile.id_server;
        let relay_server = profile.relay_server;
        let ((latency_ms, error), (relay_latency_ms, relay_error)) = join(
            test_endpoint_latency(&id_server, RENDEZVOUS_PORT),
            test_endpoint_latency(&relay_server, RELAY_PORT),
        )
        .await;
        ServerProfileStatus {
            id,
            id_server,
            relay_server,
            latency_ms,
            error,
            relay_latency_ms,
            relay_error,
        }
    });
    serde_json::to_string(&join_all(futs).await).unwrap_or_default()
}

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

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn parse_doc_profiles() {
        let path = std::env::temp_dir().join("rustdesk-server-profiles-test.md");
        std::fs::write(
            &path,
            "115.231.35.105\nkey：abc=\n\n81.71.49.16\nkey:def=\n",
        )
        .unwrap();
        let content = std::fs::read_to_string(&path).unwrap();
        let mut profiles = Vec::new();
        let mut pending_server = String::new();
        for raw_line in content.lines() {
            let line = raw_line.trim();
            if line.is_empty() {
                continue;
            }
            let lower = line.to_ascii_lowercase();
            if lower.starts_with("key") || line.starts_with("key：") || line.starts_with("key:") {
                let key = line
                    .split_once('：')
                    .or_else(|| line.split_once(':'))
                    .map(|(_, value)| value.trim())
                    .unwrap_or_default();
                if !pending_server.is_empty() {
                    let idx = profiles.len();
                    profiles.push(ServerProfile {
                        id: profile_id_for(&pending_server, idx),
                        name: pending_server.clone(),
                        id_server: pending_server.clone(),
                        relay_server: pending_server.clone(),
                        api_server: String::new(),
                        key: key.to_owned(),
                        enabled: true,
                    });
                    pending_server.clear();
                }
            } else {
                pending_server = normalize_server(line);
            }
        }
        assert_eq!(profiles.len(), 2);
        assert_eq!(profiles[0].id_server, "115.231.35.105");
        assert_eq!(profiles[0].key, "abc=");
        assert_eq!(profiles[1].id_server, "81.71.49.16");
        assert_eq!(profiles[1].key, "def=");
    }

    #[test]
    fn sanitize_deduplicates_servers() {
        let profiles = sanitize_profiles(vec![
            ServerProfile {
                id_server: " example.com/ ".to_owned(),
                enabled: true,
                ..Default::default()
            },
            ServerProfile {
                id_server: "example.com".to_owned(),
                enabled: true,
                ..Default::default()
            },
        ]);
        assert_eq!(profiles.len(), 1);
        assert_eq!(profiles[0].id_server, "example.com");
    }

    #[test]
    fn status_serializes_relay_latency_fields() {
        let status = ServerProfileStatus {
            id: "server-a".to_owned(),
            id_server: "id.example.test".to_owned(),
            relay_server: "relay.example.test".to_owned(),
            latency_ms: 42,
            error: String::new(),
            relay_latency_ms: 51,
            relay_error: String::new(),
        };
        let value = serde_json::to_value(status).unwrap();
        assert_eq!(value["idServer"], "id.example.test");
        assert_eq!(value["relayServer"], "relay.example.test");
        assert_eq!(value["latencyMs"], 42);
        assert_eq!(value["relayLatencyMs"], 51);
    }
}
