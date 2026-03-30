#!/bin/bash
set -e

INSTALL_DIR="$HOME/Desktop/slapmac/bin"
AUDIO_DIR="$HOME/Desktop/slapmac/audio"
LAUNCH_AGENT="$HOME/Library/LaunchAgents/com.slapmacpro.plist"
BINARY="$INSTALL_DIR/SlapMacPro"

echo "Installing SlapMacPro..."

# Copy binary
mkdir -p "$INSTALL_DIR"
cp "$(dirname "$0")/SlapMacPro" "$BINARY"
chmod +x "$BINARY"
codesign --force --sign - "$BINARY" 2>/dev/null || true

# Create audio dir
mkdir -p "$AUDIO_DIR"

# Create LaunchAgent
cat > "$LAUNCH_AGENT" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>Label</key><string>com.slapmacpro</string>
  <key>ProgramArguments</key><array><string>$BINARY</string></array>
  <key>RunAtLoad</key><true/>
  <key>KeepAlive</key><false/>
  <key>StandardErrorPath</key><string>/tmp/slapmacpro.log</string>
</dict></plist>
EOF

# Load and launch
launchctl load "$LAUNCH_AGENT" 2>/dev/null || true

echo ""
echo "SlapMacPro installed!"
echo "  Binary: $BINARY"
echo "  Launches at login: Yes"
echo "  Logs: tail -f /tmp/slapmacpro.log"
echo ""
echo "Drop your sound files (.mp3/.wav) into: $AUDIO_DIR"
echo "See README.md for file naming conventions."
echo ""
echo "To uninstall: launchctl unload $LAUNCH_AGENT && rm -rf $INSTALL_DIR $LAUNCH_AGENT"
