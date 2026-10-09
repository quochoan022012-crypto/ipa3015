import SwiftUI

// MARK: - Màn hình nhập key khi mở app
struct LicenseActivationView: View {
    @ObservedObject var manager: LicenseManager

    @State private var keyInput    = ""
    @State private var rememberKey = true
    @State private var shakeOffset: CGFloat = 0
    @State private var resultBanner: String? = nil

    var body: some View {
        ZStack {
            AnimatedHyperBackdrop()
                .ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()
                logoSection
                Spacer().frame(height: 32)
                keyInputCard
                Spacer()
                footerNote
            }
            .padding(.horizontal, 24)
        }
        .preferredColorScheme(.dark)
    }

    // MARK: - Logo
    private var logoSection: some View {
        VStack(spacing: 10) {
            ZStack {
                Circle()
                    .fill(AppTheme.accent.opacity(0.14))
                    .frame(width: 88, height: 88)
                    .blur(radius: 16)
                Image(systemName: "lock.shield.fill")
                    .font(.system(size: 44, weight: .bold))
                    .foregroundStyle(AppTheme.accent)
            }
            Text("OGIOS")
                .font(.system(size: 28, weight: .black, design: .rounded))
                .tracking(4)
                .foregroundStyle(.white)
            Text("NHẬP KEY ĐỂ TIẾP TỤC")
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .tracking(2)
                .foregroundStyle(AppTheme.accent.opacity(0.8))
        }
    }

    // MARK: - Key input card
    private var keyInputCard: some View {
        VStack(spacing: 18) {
            // Input field
            VStack(alignment: .leading, spacing: 8) {
                Label("Access Key", systemImage: "key.fill")
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .tracking(1.2)
                    .foregroundStyle(AppTheme.accent)

                TextField("Nhập key của bạn…", text: $keyInput)
                    .textInputAutocapitalization(.characters)
                    .autocorrectionDisabled()
                    .font(.system(size: 15, weight: .semibold, design: .monospaced))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 14)
                    .background(Color.black.opacity(0.45), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(AppTheme.accent.opacity(0.42), lineWidth: 1)
                    )
                    .submitLabel(.done)
                    .onSubmit { doActivate() }
            }

            // Remember toggle
            Toggle(isOn: $rememberKey) {
                Label("Ghi nhớ key trên thiết bị này", systemImage: "icloud.and.arrow.down")
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.72))
            }
            .tint(AppTheme.accent)
            .padding(.horizontal, 4)

            // Status message
            if let msg = manager.message, !msg.isEmpty {
                HStack(spacing: 8) {
                    Image(systemName: msg.hasPrefix("✅") ? "checkmark.circle.fill" : "xmark.circle.fill")
                        .foregroundStyle(msg.hasPrefix("✅") ? .green : .red)
                    Text(msg)
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundStyle(msg.hasPrefix("✅") ? .green : .red)
                        .lineLimit(2)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(
                    (msg.hasPrefix("✅") ? Color.green : Color.red).opacity(0.10),
                    in: RoundedRectangle(cornerRadius: 10, style: .continuous)
                )
                .offset(x: shakeOffset)
            }

            // Activate button
            Button(action: doActivate) {
                HStack(spacing: 8) {
                    if manager.isBusy {
                        ProgressView().tint(.white)
                    } else {
                        Image(systemName: "checkmark.shield.fill")
                    }
                    Text(manager.isBusy ? "Đang kiểm tra…" : "Kích Hoạt")
                        .font(.system(size: 15, weight: .black, design: .rounded))
                }
                .frame(maxWidth: .infinity, minHeight: 52)
                .foregroundStyle(.white)
                .background(
                    keyInput.trimmingCharacters(in: .whitespaces).isEmpty
                        ? Color.gray.opacity(0.35)
                        : AppTheme.accent,
                    in: RoundedRectangle(cornerRadius: 16, style: .continuous)
                )
            }
            .buttonStyle(.plain)
            .disabled(keyInput.trimmingCharacters(in: .whitespaces).isEmpty || manager.isBusy)
        }
        .padding(20)
        .background(Color.black.opacity(0.48), in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(AppTheme.accent.opacity(0.28), lineWidth: 1)
        )
    }

    private var footerNote: some View {
        Text("Liên hệ Admin để nhận key • OGIOS")
            .font(.system(size: 10, weight: .medium, design: .rounded))
            .foregroundStyle(.white.opacity(0.35))
            .padding(.bottom, 20)
    }

    // MARK: - Action
    private func doActivate() {
        let trimmed = keyInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let result = manager.activate(key: trimmed, remember: rememberKey)
        if result != .success(role: .admin) && result != .success(role: .member) {
            triggerShake()
        }
    }

    private func triggerShake() {
        withAnimation(.spring(response: 0.08, dampingFraction: 0.3).repeatCount(4, autoreverses: true)) {
            shakeOffset = 10
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            shakeOffset = 0
        }
    }
}
