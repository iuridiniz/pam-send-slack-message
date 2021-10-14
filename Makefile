.PHONY: all clean install fake-open-session fake-close-session cross _cross _upx release

BINARY=pam-send-slack-message

DESTDIR ?= /usr/local/bin
PAM_SSHD_CONFIG ?= /etc/pam.d/sshd
SLACK_CHANNEL_ID ?= slack_channel_id
SLACK_TOKEN ?= slack_token


CROSS_BINARIES=$(BINARY).x86_64.musl.upx $(BINARY).aarch64.musl.upx $(BINARY).i686.musl.upx

all: $(BINARY)
cross: $(CROSS_BINARIES)

$(BINARY): $(wildcard src/*.rs) Cargo.toml
	cargo build
	cp target/debug/$(BINARY) $(BINARY)
	strip $(BINARY)
	du -hs target/debug/$(BINARY) $(BINARY)

# X86_64 musl
$(BINARY).x86_64.musl: $(wildcard src/*.rs) Cargo.toml
	make _cross TARGET_BINARY=$@ TARGET_TRIPLE=x86_64-unknown-linux-musl
	x86_64-linux-gnu-strip $@
	du -hs $@

$(BINARY).x86_64.musl.upx: $(BINARY).x86_64.musl
	make _upx TARGET_BINARY=$@ SOURCE_BINARY=$<

# i686 musl
$(BINARY).i686.musl: $(wildcard src/*.rs) Cargo.toml
	make _cross TARGET_BINARY=$@ TARGET_TRIPLE=i686-unknown-linux-musl
	i686-linux-gnu-strip $@
	du -hs $@

$(BINARY).i686.musl.upx: $(BINARY).i686.musl
	make _upx TARGET_BINARY=$@ SOURCE_BINARY=$<

# AARCH64 musl
$(BINARY).aarch64.musl: $(wildcard src/*.rs) Cargo.toml
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

# requires nightly, rust-src, rust-std
# $(BINARY).musl-optz: $(wildcard src/*.rs) Cargo.toml
# 	RUSTFLAGS="$(RUSTFLAGS) -L/usr/lib/x86_64-linux-musl/ -Copt-level=z -Cpanic=abort" cargo +nightly build -v -Z unstable-options -Z build-std=std,panic_abort -Z build-std-features=panic_immediate_abort --release --target x86_64-unknown-linux-musl
# 	cp target/x86_64-unknown-linux-musl/release/$(BINARY) $(BINARY).musl-optz
# 	strip $(BINARY).musl-optz

install: $(BINARY)
	install -b -m 0755 -p $(BINARY) $(DESTDIR)/$(BINARY)

	@echo "Editing $(PAM_SSHD_CONFIG) if needed"
	@grep -qE '^session optional pam_exec.so.* $(DESTDIR)/$(BINARY)' $(PAM_SSHD_CONFIG) || \
		echo 'session optional pam_exec.so $(DESTDIR)/$(BINARY) $(SLACK_CHANNEL_ID) $(SLACK_TOKEN)' >> $(PAM_SSHD_CONFIG)

	chmod o-r $(PAM_SSHD_CONFIG)

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
	rm -f $(BINARY) $(BINARY).*
	cargo clean

