# pam-send-slack-message

pam-send-slack-message is a program that publishes messages on slack when the linux server is accessed through ssh.

## Installation

Go to [releases page](https://github.com/iuridiniz/pam-send-slack-message/releases) and download last release. There are static binaries for Linux (ARM64, x86_64, x86) and a debian package for debian based systems (Ubuntu).

Here a example of how to install it using upx (compressed) binary:

```bash
wget https://github.com/iuridiniz/pam-send-slack-message/releases/download/v0.2.0/pam-send-slack-message.$(uname -m).musl.upx
sudo mkdir -p /usr/local/bin/
sudo cp pam-send-slack-message.$(uname -m).musl.upx /usr/local/bin/pam-send-slack-message
chmod +x /usr/local/bin/pam-send-slack-message
```

### Configuration
In order to work, you need a `SLACK-TOKEN` with `channel.write` permission and a `SLACK-CHANNEL-ID`. Follow instructions [here](https://api.slack.com/messaging/sending), if you are lost.

```bash
# configure pam/sshd
echo "session optional pam_exec.so /usr/local/bin/pam-send-slack-message | sudo tee -a /etc/pam.d/sshd 
```

create a file `/etc/pam-send-slack-message.toml` with the following content:

```ini
slack_token = "<SLACK-TOKEN>"
slack_channel_id = "<SLACK-CHANNEL-ID>"
# see https://api.slack.com/reference/surfaces/formatting
open_session_message = """🕵️ ▶️▶️▶️ IP `{addr}` logged in `{hostname}` as `{user}` using `{auth_info}` at `{when}`"""
close_session_message = """🕵️ 🛑🛑🛑 IP `{addr}` logout from `{hostname}` (is was `{user}` using `{auth_info}`) at `{when}`"""
# could be "America/Sao_Paulo" or "America/Los_Angeles" or "Europe/Oslo"
timezone = "UTC"
```

replace `<SLACK-TOKEN>` and `<SLACK-CHANNEL-ID>` with your own.

## Usage

After machine configuration, just log in the machine through ssh.

### pam/sshd configuration

This program need to be called by pam at session phase, you must edit `/etc/pam.d/sshd` to have this line:

```
session optional pam_exec.so /path/to/pam-send-slack-message
```

You can learn about pam configuration [here](http://www.linux-pam.org/Linux-PAM-html/sag-configuration-file.html).

### pam-send-slack-message configuration

A file located at `/etc/pam.d/pam-send-slack-message.conf` is used to configure this software.

The valid keys are:

* `slack_token`: your slack token (required)
* `slack_channel_id`: your slack channel id (required)
* `open_session_message`: the message to send when a user logs in (if not specified, the default message will be used)
* `close_session_message`: the message to send when a user logs out (if not specified, the default message will be used).
* `timezone`: the timezone to use (defaults to UTC)

You can view default values in [src/settings.default.toml](https://github.com/iuridiniz/pam-send-slack-message/blob/master/src/settings.default.toml)

## Hacking

### Manual compilation

Pre-requisites: All you need is a working cargo + rust compiler, make and gcc.

```bash
make clean
make all
```

### Testing

In order to test, you need a `SLACK-TOKEN `with `channel.write` permission and a `SLACK-CHANNEL-ID`.

Simulate a pam login using ssh:

```bash
make SLACK_CHANNEL_ID=slack_channel_id SLACK_TOKEN=slack_token fake-open-session
``` 

Simulate a pam logout using ssh:

```bash
make SLACK_CHANNEL_ID=slack_channel_id SLACK_TOKEN=slack_token fake-close-session
```

In order to avoid pass env vars all the time, I recommend use [`direnv`](https://direnv.net/), there's a sample `.envrc` in `envrc.sample`

```bash
cp envrc.sample .envrc
direnv allow .
```

### Enable logs when using inside pam

change `/etc/pam.d/sshd` to:

```
session optional pam_exec.so debug log=/tmp/file_to_log.txt /usr/local/bin/pam-send-slack-message SLACK-CHANNEL-ID SLACK-TOKEN
```

See `/tmp/pam-slack.log`, also see audit logs, in ubuntu they are located in `/var/log/auth.log`


## Contributing
Pull requests are welcome. For major changes, please open an issue first to discuss what you would like to change.

## License
[MIT](https://choosealicense.com/licenses/mit/)
