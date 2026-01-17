class Systempulse < Formula
  desc "Lightweight native macOS menubar app for real-time system monitoring"
  homepage "https://github.com/TerminalGravity/SystemPulse"
  url "https://github.com/TerminalGravity/SystemPulse/archive/refs/tags/v1.0.0.tar.gz"
  sha256 "19112f87b8249e3c0eefa843f31af4cbea48373918caa85b1f69d5247ab5ac7f"
  license "MIT"

  depends_on :macos
  depends_on xcode: ["14.0", :build]

  def install
    system "swift", "build", "-c", "release", "--disable-sandbox"

    # Create app bundle structure
    app_bundle = prefix/"SystemPulse.app/Contents"
    (app_bundle/"MacOS").mkpath
    (app_bundle/"MacOS").install ".build/release/SystemPulse"

    # Install Info.plist
    (app_bundle/"Info.plist").write <<~EOS
      <?xml version="1.0" encoding="UTF-8"?>
      <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
      <plist version="1.0">
      <dict>
        <key>CFBundleDevelopmentRegion</key>
        <string>en</string>
        <key>CFBundleExecutable</key>
        <string>SystemPulse</string>
        <key>CFBundleIdentifier</key>
        <string>com.jackfelke.SystemPulse</string>
        <key>CFBundleInfoDictionaryVersion</key>
        <string>6.0</string>
        <key>CFBundleName</key>
        <string>System Pulse</string>
        <key>CFBundlePackageType</key>
        <string>APPL</string>
        <key>CFBundleShortVersionString</key>
        <string>#{version}</string>
        <key>CFBundleVersion</key>
        <string>1</string>
        <key>LSMinimumSystemVersion</key>
        <string>13.0</string>
        <key>LSUIElement</key>
        <true/>
        <key>NSHighResolutionCapable</key>
        <true/>
        <key>NSPrincipalClass</key>
        <string>NSApplication</string>
      </dict>
      </plist>
    EOS
  end

  def caveats
    <<~EOS
      SystemPulse has been installed to:
        #{prefix}/SystemPulse.app

      To use, either:
        1. Copy to Applications: cp -r #{prefix}/SystemPulse.app /Applications/
        2. Or run directly: open #{prefix}/SystemPulse.app
    EOS
  end

  test do
    assert_predicate prefix/"SystemPulse.app/Contents/MacOS/SystemPulse", :exist?
  end
end
