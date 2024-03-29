.PHONY: all clean install fake-open-session fake-close-session cross _cross _upx release deb deb-x86_64 deb-i686 deb-arm64

BINARY=pam-send-slack-message
SETTINGS_FILE=src/settings.default.toml

DESTDIR ?= /
PAM_SSHD_CONFIG ?= /etc/pam.d/sshd
SLACK_CHANNEL_ID ?= slack_channel_id
SLACK_TOKEN ?= slack_token

CROSS_BINARIES=$(BINARY).x86_64.musl.upx $(BINARY).aarch64.musl.upx $(BINARY).i686.musl.upx

all: $(BINARY)
cross: $(CROSS_BINARIES)

$(BINARY): $(wildcard src/*) Cargo.toml
	cargo build
	cp target/debug/$(BINARY) $(BINARY)
	strip $(BINARY)
	du -hs target/debug/$(BINARY) $(BINARY)

# X86_64 musl
$(BINARY).x86_64.musl: $(wildcard src/*) Cargo.toml
	make _cross TARGET_BINARY=$@ TARGET_TRIPLE=x86_64-unknown-linux-musl
	x86_64-linux-gnu-strip $@
	du -hs $@

$(BINARY).x86_64.musl.upx: $(BINARY).x86_64.musl
	make _upx TARGET_BINARY=$@ SOURCE_BINARY=$<

# i686 musl
$(BINARY).i686.musl: $(wildcard src/*) Cargo.toml
	make _cross TARGET_BINARY=$@ TARGET_TRIPLE=i686-unknown-linux-musl
	i686-linux-gnu-strip $@
	du -hs $@

$(BINARY).i686.musl.upx: $(BINARY).i686.musl
	make _upx TARGET_BINARY=$@ SOURCE_BINARY=$<

# AARCH64 musl
$(BINARY).aarch64.musl: $(wildcard src/*) Cargo.toml
	make _cross TARGET_BINARY=$@ TARGET_TRIPLE=aarch64-unknown-linux-musl
	aarch64-linux-gnu-strip $@
	du -hs $@

$(BINARY).aarch64.musl.upx: $(BINARY).aarch64.musl
	make _upx TARGET_BINARY=$@ SOURCE_BINARY=$<

# requires docker
# see: https://github.com/rust-embedded/cross
_cross:
	# cargo install cross
	cross build --release --target $(TARGET_TRIPLE)
	cp target/$(TARGET_TRIPLE)/release/$(BINARY) $(TARGET_BINARY)
	du -hs target/$(TARGET_TRIPLE)/release/$(BINARY)

# needs upx
# see https://upx.github.io/
_upx:
	rm -f $(TARGET_BINARY)
	upx --best --lzma -o $(TARGET_BINARY) $(SOURCE_BINARY)
	du -hs $(SOURCE_BINARY) $(TARGET_BINARY)
	touch $(TARGET_BINARY)

# requires cargo-deb
# https://github.com/mmstick/cargo-deb#readme
deb: deb-x86_64

deb-x86_64: $(BINARY).x86_64.musl
	cargo deb -v -o ./ --target x86_64-unknown-linux-musl --no-build

deb-i686: $(BINARY).i686.musl
	cargo deb -v -o ./ --target i686-unknown-linux-musl --no-build

# requires `[target.aarch64-unknown-linux-musl] strip = { path = "aarch64-linux-gnu-strip" }` in .cargo/config
deb-arm64: $(BINARY).aarch64.musl
	cargo deb -v -o ./ --target aarch64-unknown-linux-musl --no-build


install: $(BINARY)
	mkdir --parents $(DESTDIR)/usr/local/bin/ $(DESTDIR)/etc/
	install --backup --mode=0755 --strip --preserve-timestamps $(BINARY) $(DESTDIR)/usr/local/bin/$(BINARY)
	install --backup --mode=0755 --preserve-timestamps $(SETTINGS_FILE) $(DESTDIR)/etc/$(BINARY).toml

	@echo "Editing $(PAM_SSHD_CONFIG) if needed"
	grep -qE '^session optional pam_exec.so.* $(DESTDIR)/usr/local/bin/$(BINARY)' $(PAM_SSHD_CONFIG) || \
		echo 'session optional pam_exec.so $(DESTDIR)/usr/local/bin/$(BINARY)' >> $(PAM_SSHD_CONFIG)


fake-open-session: $(BINARY)
	@/usr/bin/env \
		PAM_TYPE=open_session \
		PAM_TTY=ssh \
		PAM_USER=root \
		PAM_RHOST=10.130.211.1 \
		SSH_CONNECTION="10.130.211.1 44494 10.130.211.149 22" \
		PAM_SERVICE=sshd \
		SSH_AUTH_INFO_0="publickey ssh-rsa BBBBB3NzBC1yc2EBBBBBIwBBBQEBtJYwzqB6n8TuPcEM9XQ9sGORkqIsXk63mK5z6BPq4uf2khuiBP4yett/CX3BK/xytyhhJyGxzCP2Z19PTP/vN3ZTIUXBpBVsR7Ew46XZOBB6mlGMxR8y0gcesllY/6VUivTJM22eF2IWEQ/BKLPCQuM5sbL5+BIS8nzjntMO+Rr0yW6hfw9tzPEbfBvSGycuMoBlisJCgRMkhB3YOPh3eCLBP/clzQ8249Xmn0iUJtBbP016hXjc69RwYBIok2mEhqsgm67yh/HMkB0IiNHp+vPqUexJ7hB3uNcMrBv9B2ykxBKC2WRS040Or2O9OWOBRUw+PiNM7UOOBPkinzPzuw==" \
		./$(BINARY) $(SLACK_CHANNEL_ID) $(SLACK_TOKEN)

fake-close-session: $(BINARY)
	@/usr/bin/env \
		PAM_TYPE=close_session\
		PAM_TTY=ssh \
		PAM_USER=root \
		PAM_RHOST=10.130.211.1 \
		SSH_CONNECTION="10.130.211.1 44494 10.130.211.149 22" \
		PAM_SERVICE=sshd \
		SSH_AUTH_INFO_0="password" \
		./$(BINARY) $(SLACK_CHANNEL_ID) $(SLACK_TOKEN)

release: cross sha1sum.txt

sha1sum.txt: $(CROSS_BINARIES)
	rm -f sha1sum.txt
	sha1sum pam-send-slack-message.* | tee sha1sum.txt

clean:
	rm -f $(BINARY) $(BINARY).* $(BINARY)_*.deb
	cargo clean

