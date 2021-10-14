use ellipse::Ellipse;
use log::{error, info};
use simple_logger::SimpleLogger;

use chrono_tz::America::Fortaleza;

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
            self.key.as_str().truncate_ellipse(20)
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

fn open_session(channel_id: String, token: String) {
    let user = get_user();
    let addr = get_remote_ip();
    let host = get_hostname();
    let auth_info = get_ssh_auth_info();
    let when = chrono::Local::now().with_timezone(&Fortaleza).to_rfc2822();

    // https://api.slack.com/reference/surfaces/formatting
    // TODO: use a external template
    let msg = format!(
        "<!here> 🕵️ ▶️▶️▶️ IP `{}` logged in `{}` as `{}` using `{}` at `{}`",
        addr, host, user, auth_info, when
    );

    info!("{}", msg);
    let res = send_slack_msg(channel_id, token, msg);
    if res.is_err() {
        error!("Cannot send slack message");
        return;
    }
    let body = res.unwrap().text().unwrap();
    info!("API response:\n==mark==\n{}\n==mark==", body);
}

fn close_session(channel_id: String, token: String) {
    let user = get_user();
    let addr = get_remote_ip();
    let host = get_hostname();
    let auth_info = get_ssh_auth_info();
    let when = chrono::Local::now().with_timezone(&Fortaleza).to_rfc2822();

    // https://api.slack.com/reference/surfaces/formatting
    // TODO: use a external template
    let msg = format!(
        "<!here> 🕵️ 🛑🛑🛑 IP `{}` logout from `{}` (is was `{}` using `{}`) at `{}`",
        addr, host, user, auth_info, when
    );
    info!("{}", msg);
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

    let args: Vec<String> = std::env::args().collect();
    if args.len() < 3 {
        eprintln!("Usage: {} <channel_id> <token>", args[0]);
        return;
    }

    let channel_id = args[1].clone();
    let token = args[2].clone();

    let pam_type = get_pam_type();

    if pam_type == "open_session" {
        open_session(channel_id, token);
    } else if pam_type == "close_session" {
        close_session(channel_id, token);
    } else {
        eprintln!("Unknown environment `PAM_TYPE`={:?}", pam_type);
    }
}
