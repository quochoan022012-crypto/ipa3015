import Combine
import Foundation
import Security
import UIKit

// MARK: - Key Role
enum KeyRole: Equatable {
    case admin
    case member
}

// MARK: - Activation Result
enum ActivationResult: Equatable {
    case success(role: KeyRole)
    case invalid
    case alreadyUsed
    case expired
    case notFound
}

// MARK: - Key Log Entry
struct KeyLogEntry: Codable, Identifiable {
    let id: UUID
    let key: String
    let role: String        // "admin" | "member"
    let action: String      // "activated" | "deactivated" | "created" | "deleted"
    let deviceName: String
    let timestamp: Date

    init(key: String, role: KeyRole, action: String) {
        self.id         = UUID()
        self.key        = key
        self.role       = role == .admin ? "admin" : "member"
        self.action     = action
        self.deviceName = UIDevice.current.name
        self.timestamp  = Date()
    }
}

// MARK: - Member Key Entry
struct MemberKeyEntry: Codable, Identifiable {
    var id: UUID
    var key: String
    var note: String            // tên thành viên / ghi chú
    var isUsed: Bool
    var usedByDevice: String?
    var usedAt: Date?
    var createdAt: Date
    var expiresAt: Date?        // nil = không hết hạn

    var isExpired: Bool {
        guard let exp = expiresAt else { return false }
        return Date() > exp
    }

    var statusLabel: String {
        if isExpired { return "Hết hạn" }
        if isUsed    { return "Đang dùng" }
        return "Chưa dùng"
    }

    init(key: String, note: String, expiresAt: Date? = nil) {
        self.id           = UUID()
        self.key          = key
        self.note         = note
        self.isUsed       = false
        self.usedByDevice = nil
        self.usedAt       = nil
        self.createdAt    = Date()
        self.expiresAt    = expiresAt
    }
}

// MARK: - Custom Patch Entry (admin-managed)
struct CustomPatchEntry: Codable, Identifiable {
    var id: UUID
    var displayName: String     // tên hiển thị (VD: "Aim Đầu Pro")
    var targetGame: String      // tên game (VD: "FREE FIRE • MAX")
    var filename: String        // tên file .3105 đã lưu trong Documents
    var createdAt: Date

    init(displayName: String, targetGame: String, filename: String) {
        self.id          = UUID()
        self.displayName = displayName
        self.targetGame  = targetGame
        self.filename    = filename
        self.createdAt   = Date()
    }

    /// URL thực tế của file patch trong Application Support
    var patchURL: URL? {
        guard let root = try? PatchProjectLibraryPath.customPatchesRoot() else { return nil }
        return root.appendingPathComponent(filename)
    }
}

/// Namespace nhỏ để tránh circular dep với PatchProjectLibrary
enum PatchProjectLibraryPath {
    static func customPatchesRoot() throws -> URL {
        let base = try FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        let root = base.appendingPathComponent("CustomPatches", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        return root
    }
}

// MARK: - LicenseManager
@MainActor
final class LicenseManager: ObservableObject {

    // ── Constants ────────────────────────────────────────────────
    private static let adminKey           = "QHOANIOS18"
    private static let memberKeysUD       = "ogios.memberKeys"
    private static let keyLogUD           = "ogios.keyLog"
    private static let customPatchesUD    = "ogios.customPatches"
    private static let activeKeychain     = "ogios.activeKey"
    private let service                   = "com.OGIOS.external-ios.activation"

    // ── Published ─────────────────────────────────────────────────
    @Published private(set) var isActive      = false
    @Published private(set) var isAdmin       = false
    @Published private(set) var isBusy        = false
    @Published private(set) var message: String?

    @Published private(set) var memberKeys:   [MemberKeyEntry]   = []
    @Published private(set) var keyLog:       [KeyLogEntry]      = []
    @Published private(set) var customPatches:[CustomPatchEntry]  = []

    // ── Init ──────────────────────────────────────────────────────
    init() {
        loadMemberKeys()
        loadKeyLog()
        loadCustomPatches()
        restoreSession()
    }

    // MARK: - Session restore

    private func restoreSession() {
        guard let saved = savedActiveKey(), !saved.isEmpty else { return }
        let r = resolveRole(of: saved)
        switch r {
        case .success(let role):
            isActive = true
            isAdmin  = (role == .admin)
        default:
            clearSavedKey()
        }
    }

    // MARK: - Lifecycle

    func beginLaunchSession() {
        restoreSession()
        if isActive {
            message = isAdmin ? "Admin đã đăng nhập" : "Đã kích hoạt — sẵn sàng sử dụng"
        } else {
            message = "Vui lòng nhập key để tiếp tục"
        }
    }

    // MARK: - Activation

    @discardableResult
    func activate(key: String, remember: Bool = true) -> ActivationResult {
        let trimmed = key.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return .invalid }

        let result = resolveRole(of: trimmed)

        switch result {
        case .success(let role):
            if role == .member { markMemberKeyUsed(trimmed) }
            if remember { saveActiveKey(trimmed) }
            isActive = true
            isAdmin  = (role == .admin)
            message  = role == .admin ? "✅ Admin đăng nhập thành công" : "✅ Kích hoạt thành công"
            appendLog(KeyLogEntry(key: trimmed, role: role, action: "activated"))
            log("license: '\(masked(trimmed))' activated role=\(role == .admin ? "admin" : "member")")

        case .expired:
            message = "⏰ Key đã hết hạn — liên hệ Admin để gia hạn"
            log("license: expired key '\(masked(trimmed))'")

        case .alreadyUsed:
            message = "⚠️ Key đã được dùng trên thiết bị khác"
            log("license: key '\(masked(trimmed))' already used by another device")

        case .invalid:
            message = "❌ Key không hợp lệ"
            log("license: invalid key '\(masked(trimmed))'")

        case .notFound:
            message = "❌ Key không tồn tại"
            log("license: key not found '\(masked(trimmed))'")
        }
        return result
    }

    func deactivate() {
        if let k = savedActiveKey() {
            let role: KeyRole = k.uppercased() == Self.adminKey ? .admin : .member
            appendLog(KeyLogEntry(key: k, role: role, action: "deactivated"))
            log("license: '\(masked(k))' deactivated")
        }
        clearSavedKey()
        isActive = false
        isAdmin  = false
        message  = "Đã đăng xuất"
    }

    // MARK: - Member Key Management

    func createMemberKey(note: String, expiresAt: Date?) -> MemberKeyEntry {
        let key   = generateKey()
        let entry = MemberKeyEntry(key: key, note: note, expiresAt: expiresAt)
        memberKeys.append(entry)
        saveMemberKeys()
        appendLog(KeyLogEntry(key: key, role: .admin, action: "created"))
        let expStr = expiresAt.map { DateFormatter.localizedString(from: $0, dateStyle: .short, timeStyle: .short) } ?? "Không giới hạn"
        log("license: admin created key '\(key)' note='\(note)' expires=\(expStr)")
        return entry
    }

    func deleteMemberKey(id: UUID) {
        guard let idx = memberKeys.firstIndex(where: { $0.id == id }) else { return }
        let k = memberKeys[idx]
        appendLog(KeyLogEntry(key: k.key, role: .admin, action: "deleted"))
        log("license: admin deleted key '\(k.key)'")
        memberKeys.remove(at: idx)
        saveMemberKeys()
    }

    func clearKeyLog() {
        keyLog = []
        UserDefaults.standard.removeObject(forKey: Self.keyLogUD)
        log("license: admin cleared key log")
    }

    // MARK: - Custom Patch Management

    func addCustomPatch(displayName: String, targetGame: String, fileData: Data, originalFilename: String) throws -> CustomPatchEntry {
        let root    = try PatchProjectLibraryPath.customPatchesRoot()
        // Tạo tên file unique
        let base    = sanitizeFilename(displayName)
        var dest    = root.appendingPathComponent("\(base).3105")
        var suffix  = 2
        while FileManager.default.fileExists(atPath: dest.path) {
            dest = root.appendingPathComponent("\(base)-\(suffix).3105")
            suffix += 1
        }
        try fileData.write(to: dest, options: [.atomic, .completeFileProtection])

        let entry = CustomPatchEntry(displayName: displayName, targetGame: targetGame, filename: dest.lastPathComponent)
        customPatches.append(entry)
        saveCustomPatches()
        log("license: admin added custom patch '\(displayName)' file=\(dest.lastPathComponent)")
        return entry
    }

    func deleteCustomPatch(id: UUID) {
        guard let idx = customPatches.firstIndex(where: { $0.id == id }) else { return }
        let patch = customPatches[idx]
        if let url = patch.patchURL {
            try? FileManager.default.removeItem(at: url)
        }
        log("license: admin deleted custom patch '\(patch.displayName)'")
        customPatches.remove(at: idx)
        saveCustomPatches()
    }

    func updateCustomPatch(id: UUID, displayName: String, targetGame: String) {
        guard let idx = customPatches.firstIndex(where: { $0.id == id }) else { return }
        customPatches[idx].displayName = displayName
        customPatches[idx].targetGame  = targetGame
        saveCustomPatches()
        log("license: admin updated custom patch id=\(id)")
    }

    // MARK: - Private helpers

    private func resolveRole(of key: String) -> ActivationResult {
        if key.uppercased() == Self.adminKey {
            return .success(role: .admin)
        }
        guard let idx = memberKeys.firstIndex(where: { $0.key == key }) else {
            return .notFound
        }
        let entry = memberKeys[idx]
        if entry.isExpired { return .expired }
        if entry.isUsed {
            if entry.usedByDevice == UIDevice.current.name {
                return .success(role: .member) // Thiết bị cũ → cho vào lại
            }
            return .alreadyUsed
        }
        return .success(role: .member)
    }

    private func markMemberKeyUsed(_ key: String) {
        guard let idx = memberKeys.firstIndex(where: { $0.key == key }) else { return }
        memberKeys[idx].isUsed       = true
        memberKeys[idx].usedByDevice = UIDevice.current.name
        memberKeys[idx].usedAt       = Date()
        saveMemberKeys()
    }

    private func generateKey() -> String {
        let chars = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"
        let parts = (0..<4).map { _ in String((0..<4).map { _ in chars.randomElement()! }) }
        return "OG-" + parts.joined(separator: "-")
    }

    private func masked(_ key: String) -> String {
        guard key.count > 4 else { return String(repeating: "*", count: key.count) }
        return String(key.prefix(3)) + String(repeating: "*", count: key.count - 3)
    }

    private func sanitizeFilename(_ name: String) -> String {
        let allowed = CharacterSet.alphanumerics.union(.init(charactersIn: "-_ "))
        let s = name.unicodeScalars.map { allowed.contains($0) ? Character(String($0)) : Character("-") }
        let r = String(s).trimmingCharacters(in: .whitespacesAndNewlines).prefix(60)
        return r.isEmpty ? "CustomPatch" : String(r)
    }

    // MARK: - Keychain

    private func savedActiveKey() -> String? {
        let q: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: Self.activeKeychain,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var r: CFTypeRef?
        guard SecItemCopyMatching(q as CFDictionary, &r) == errSecSuccess,
              let d = r as? Data else { return nil }
        return String(data: d, encoding: .utf8)
    }

    private func saveActiveKey(_ value: String) {
        let base: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: Self.activeKeychain
        ]
        SecItemDelete(base as CFDictionary)
        var item = base
        item[kSecValueData as String]      = Data(value.utf8)
        item[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        SecItemAdd(item as CFDictionary, nil)
    }

    private func clearSavedKey() {
        let q: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: Self.activeKeychain
        ]
        SecItemDelete(q as CFDictionary)
    }

    // MARK: - UserDefaults persistence

    private func loadMemberKeys() {
        guard let d = UserDefaults.standard.data(forKey: Self.memberKeysUD),
              let v = try? JSONDecoder().decode([MemberKeyEntry].self, from: d) else { return }
        memberKeys = v
    }

    private func saveMemberKeys() {
        if let d = try? JSONEncoder().encode(memberKeys) {
            UserDefaults.standard.set(d, forKey: Self.memberKeysUD)
        }
    }

    private func loadKeyLog() {
        guard let d = UserDefaults.standard.data(forKey: Self.keyLogUD),
              let v = try? JSONDecoder().decode([KeyLogEntry].self, from: d) else { return }
        keyLog = v
    }

    private func appendLog(_ entry: KeyLogEntry) {
        keyLog.insert(entry, at: 0)
        if keyLog.count > 500 { keyLog = Array(keyLog.prefix(500)) }
        if let d = try? JSONEncoder().encode(keyLog) {
            UserDefaults.standard.set(d, forKey: Self.keyLogUD)
        }
    }

    private func loadCustomPatches() {
        guard let d = UserDefaults.standard.data(forKey: Self.customPatchesUD),
              let v = try? JSONDecoder().decode([CustomPatchEntry].self, from: d) else { return }
        customPatches = v
    }

    private func saveCustomPatches() {
        if let d = try? JSONEncoder().encode(customPatches) {
            UserDefaults.standard.set(d, forKey: Self.customPatchesUD)
        }
    }

    // Legacy compat
    func refresh() { beginLaunchSession() }
    func rememberedKey() -> String? { savedActiveKey() }
}
