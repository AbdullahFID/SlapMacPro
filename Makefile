BINARY_NAME = SlapMacPro
INSTALL_DIR = $(HOME)/Desktop/slapmac/bin
LAUNCH_AGENT = $(HOME)/Library/LaunchAgents/com.slapmacpro.plist

.PHONY: build run clean install uninstall enable disable

build:
	swift build -c release

run: build
	.build/release/SlapMacClone

debug:
	swift build
	.build/debug/SlapMacClone

clean:
	swift package clean
	rm -rf .build

install: build
	@mkdir -p $(INSTALL_DIR)
	@cp .build/release/SlapMacClone $(INSTALL_DIR)/$(BINARY_NAME)
	@echo '<?xml version="1.0" encoding="UTF-8"?>' > $(LAUNCH_AGENT)
	@echo '<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">' >> $(LAUNCH_AGENT)
	@echo '<plist version="1.0"><dict>' >> $(LAUNCH_AGENT)
	@echo '  <key>Label</key><string>com.slapmacpro</string>' >> $(LAUNCH_AGENT)
	@echo '  <key>ProgramArguments</key><array><string>$(INSTALL_DIR)/$(BINARY_NAME)</string></array>' >> $(LAUNCH_AGENT)
	@echo '  <key>RunAtLoad</key><true/>' >> $(LAUNCH_AGENT)
	@echo '  <key>KeepAlive</key><false/>' >> $(LAUNCH_AGENT)
	@echo '  <key>StandardErrorPath</key><string>/tmp/slapmacpro.log</string>' >> $(LAUNCH_AGENT)
	@echo '</dict></plist>' >> $(LAUNCH_AGENT)
	@launchctl load $(LAUNCH_AGENT) 2>/dev/null || true
	@echo "Installed and launched. Starts automatically at login."
	@echo "Logs: tail -f /tmp/slapmacpro.log"

uninstall:
	@launchctl unload $(LAUNCH_AGENT) 2>/dev/null || true
	@rm -f $(LAUNCH_AGENT)
	@rm -f $(INSTALL_DIR)/$(BINARY_NAME)
	@pkill -f $(BINARY_NAME) 2>/dev/null || true
	@echo "Uninstalled."

enable:
	@launchctl load -w $(LAUNCH_AGENT)
	@echo "Enabled launch at login."

disable:
	@launchctl unload -w $(LAUNCH_AGENT)
	@echo "Disabled launch at login."
