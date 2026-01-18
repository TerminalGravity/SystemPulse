import SwiftUI

struct LicenseView: View {
    @ObservedObject var licenseManager: LicenseManager
    @State private var email = ""
    @State private var licenseKey = ""
    @State private var errorMessage = ""
    @State private var isActivating = false

    var body: some View {
        VStack(spacing: 16) {
            // Header
            VStack(spacing: 8) {
                Image(systemName: "chart.bar.fill")
                    .font(.system(size: 40))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.green, .cyan],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )

                Text("System Pulse")
                    .font(.system(size: 20, weight: .bold, design: .rounded))

                Text("Enter your license to unlock")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }
            .padding(.top, 8)

            Divider()

            // Input fields
            VStack(alignment: .leading, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Email")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.secondary)
                    TextField("you@example.com", text: $email)
                        .textFieldStyle(.roundedBorder)
                        .font(.system(size: 13))
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("License Key")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.secondary)
                    TextField("XXXX-XXXX-XXXX-XXXX", text: $licenseKey)
                        .textFieldStyle(.roundedBorder)
                        .font(.system(size: 13, design: .monospaced))
                }
            }

            if !errorMessage.isEmpty {
                Text(errorMessage)
                    .font(.system(size: 11))
                    .foregroundColor(.red)
            }

            // Buttons
            VStack(spacing: 8) {
                Button(action: activate) {
                    if isActivating {
                        ProgressView()
                            .scaleEffect(0.7)
                            .frame(maxWidth: .infinity)
                    } else {
                        Text("Activate License")
                            .frame(maxWidth: .infinity)
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(email.isEmpty || licenseKey.isEmpty || isActivating)

                Button(action: openPurchasePage) {
                    Text("Buy License - $1.99")
                        .font(.system(size: 12))
                }
                .buttonStyle(.link)
            }

            Divider()

            // Footer
            Button(action: {
                NSApplication.shared.terminate(nil)
            }) {
                HStack(spacing: 4) {
                    Image(systemName: "power")
                        .font(.system(size: 10))
                    Text("Quit")
                        .font(.system(size: 11))
                }
                .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
        }
        .padding(20)
        .frame(width: 280)
        .background(Color(NSColor.windowBackgroundColor))
    }

    private func activate() {
        errorMessage = ""
        isActivating = true

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            if licenseManager.activateLicense(key: licenseKey, email: email) {
                // Success - view will automatically switch
            } else {
                errorMessage = "Invalid license key. Please check and try again."
            }
            isActivating = false
        }
    }

    private func openPurchasePage() {
        if let url = URL(string: "https://systempulse.app") {
            NSWorkspace.shared.open(url)
        }
    }
}
