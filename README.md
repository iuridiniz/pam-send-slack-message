# pam-send-slack-message

pam-send-slack-message is a program that publishes messages on slack when the linux server is accessed through ssh.

## Installation

Go to [releases page](https://github.com/iuridiniz/pam-send-slack-message/releases) and download last release.

```bash
wget https://github.com/iuridiniz/pam-send-slack-message/releases/download/v0.1.0/pam-send-slack-message.$(uname -m).musl.upx
sudo mkdir -p /usr/local/bin/
sudo cp pam-send-slack-message.$(uname -m).musl.upx /usr/local/bin/pam-send-slack-message
chmod +x /usr/local/bin/pam-send-slack-message
```

In order to work, you need a `SLACK-TOKEN` with `channel.write` permission and a `SLACK-CHANNEL-ID`. Follow instructions [here](https://api.slack.com/messaging/sending), if you are lost.
```
# configure pam/sshd
echo "session optional pam_exec.so /usr/local/bin/pam-send-slack-message SLACK-CHANNEL-ID SLACK-TOKEN" | sudo tee /etc/pam.d/sshd 

# assure token cannot be viewed by any ordinary user 
sudo chmod o-r /etc/pam.d/sshd
```


## Usage

After configuration, just log via ssh.

### pam/sshd configuration

This program need to be called by pam at session phase, you must change `/etc/pam.d/sshd` to have this line:

```
session optional pam_exec.so /path/to/pam-send-slack-message SLACK-CHANNEL-ID SLACK-TOKEN
```

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
