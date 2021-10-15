use ellipse::Ellipse;
use log::{error, info, warn};
use simple_logger::SimpleLogger;

mod settings;
use settings::Settings;

enum PamType {
    OpenSession,
    CloseSession,
}

#[derive(Default, Debug)]
struct SshAuthInfo {
    pub method: String,
    pub key: String,
    pub kind: String,
}

impl std::fmt::Display for SshAuthInfo {
    fn fmt(&self, f: &mut std::fmt::Formatter) -> std::fmt::Result {
        let msg = format!(
            "{} {} {}",
            self.method,
            self.kind,
            self.key.as_str().truncate_ellipse(40)
        );
        write!(f, "{}", msg.trim())
    }
}

fn get_pam_type() -> String {
    std::env::var("PAM_TYPE").expect("Cannot read environment variable `PAM_TYPE`")
}

fn get_user() -> String {
    std::env::var("PAM_USER").expect("Cannot read environment variable `PAM_USER`")
}

fn get_ssh_auth_info() -> SshAuthInfo {
    let mut info = SshAuthInfo::default();
    let ssh_auth_info_0 = std::env::var("SSH_AUTH_INFO_0");
    if ssh_auth_info_0.is_err() {
        return info;
    }
    let ssh_auth_info_0 = ssh_auth_info_0.unwrap();
    let parts = ssh_auth_info_0.split(' ').collect::<Vec<_>>();
    if parts.len() >= 3 {
        info.key = parts[2].trim().to_string();
    }
    if parts.len() >= 2 {
        info.kind = parts[1].trim().to_string();
    }
    if !parts.is_empty() {
        info.method = parts[0].trim().to_string();
    }
    info
}

fn get_hostname() -> String {
    gethostname::gethostname()
        .into_string()
        .expect("Cannot get hostname")
}

fn get_remote_ip() -> String {
    std::env::var("PAM_RHOST").expect("Cannot read environment variable `PAM_RHOST`")
}

fn send_slack_msg(
    channel_id: String,
    token: String,
    msg: String,
) -> std::result::Result<reqwest::blocking::Response, reqwest::Error> {
    let client = reqwest::blocking::Client::new();
    client
        .post("https://slack.com/api/chat.postMessage")
        .timeout(std::time::Duration::from_secs(3))
        .header("Content-Type", "application/json")
        .header("Authorization", format!("Bearer {}", token))
        .body(format!(
            r#"{{
                "channel": "{}",
                "text": "{}"
            }}"#,
            channel_id, msg
        ))
        .send()
}

fn handle_pam(settings: Settings, pam_type: PamType) {
    let channel_id = settings.slack_channel_id.clone();
    let token = settings.slack_token.clone();
    let tz: Result<chrono_tz::Tz, _> = settings.timezone.parse();
    let when;
    if tz.is_ok() {
        when = chrono::Utc::now().with_timezone(&tz.unwrap()).to_rfc2822();
    } else {
        warn!("invalid timezone `{}`, using utc", settings.timezone);
        when = chrono::Utc::now().to_rfc2822();
    }

    let user = get_user();
    let addr = get_remote_ip();
    let hostname = get_hostname();
    let auth_info = get_ssh_auth_info();

    let mut msg;
    match pam_type {
        PamType::OpenSession => {
            msg = settings.open_session_message.clone();
        }
        PamType::CloseSession => {
            msg = settings.close_session_message.clone();
        }
    }
    // Replace placeholders
    msg = msg.replace("{addr}", &addr);
    msg = msg.replace("{hostname}", &hostname);
    msg = msg.replace("{user}", &user);
    msg = msg.replace("{auth_info}", auth_info.to_string().as_str());
    msg = msg.replace("{when}", &when);

    let res = send_slack_msg(channel_id, token, msg);
    if res.is_err() {
        error!("Cannot send slack message");
        return;
    }
    let body = res.unwrap().text().unwrap();
    info!("API response:\n==mark==\n{}\n==mark==", body);
}

fn main() {
    SimpleLogger::new().init().unwrap();

    let config_file = format!("/etc/{}", env!("CARGO_PKG_NAME"));
    let settings = Settings::new(config_file.as_str());
    // dbg!(&settings);

    if settings.is_err() {
        eprintln!("Cannot read settings: {:?}", settings.err());
        std::process::exit(1);
    }

    let pam_type = get_pam_type();

    if pam_type == "open_session" {
        handle_pam(settings.unwrap(), PamType::OpenSession);
    } else if pam_type == "close_session" {
        handle_pam(settings.unwrap(), PamType::CloseSession);
    } else {
        eprintln!("Unknown environment `PAM_TYPE`={:?}", pam_type);
    }
}
