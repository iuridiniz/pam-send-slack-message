use config::{Config, ConfigError, File, FileFormat};
use serde::Deserialize;
use std::env;

#[derive(Debug, Deserialize)]
pub struct Settings {
    pub slack_token: String,
    pub slack_channel_id: String,
    pub open_session_message: String,
    pub close_session_message: String,
    pub timezone: String,
}

impl Settings {
    pub fn new(system_config_file: &str) -> Result<Self, ConfigError> {
        let mut s = Config::default();

        // Start off by merging in the "default" configuration file
        s.merge(File::from_str(
            include_str!("settings.default.toml").into(),
            FileFormat::Toml,
        ))?;

        // Add some settings from environment variables
        match env::var("SLACK_TOKEN") {
            Ok(token) => {
                s.set("slack_token", token)?;
            }
            Err(_) => {}
        };

        match env::var("SLACK_TOKEN") {
            Ok(token) => {
                s.set("slack_token", token)?;
            }
            Err(_) => {}
        };

        match env::var("SLACK_CHANNEL_ID") {
            Ok(channel_id) => {
                s.set("slack_channel_id", channel_id)?;
            }
            Err(_) => {}
        };

        // Add in system configuration file
        s.merge(File::new(system_config_file, FileFormat::Toml).required(false))?;

        // You can deserialize (and thus freeze) the entire configuration as
        s.try_into()
    }
}
