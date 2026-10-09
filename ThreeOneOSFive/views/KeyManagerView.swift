import SwiftUI
import UniformTypeIdentifiers

// MARK: - Admin Panel Tabs
private enum AdminTab: String, CaseIterable {
    case keys    = "🔑 Key"
    case patches = "⚡ Patch"
    case log     = "📋 Log"
}

// MARK: - KeyManagerView
struct KeyManagerView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var licenseManager: LicenseManager

    @State private var activeTab: AdminTab = .keys

    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.pageBackground.ignoresSafeArea()

                VStack(spacing: 0) {
                    // Tab bar
                    HStack(spacing: 0) {
                        ForEach(AdminTab.allCases, id: \.rawValue) { tab in
                            Button {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                    activeTab = tab
                                }
                            } label: {
                                Text(tab.rawValue)
                                    .font(.system(size: 12, weight: .bold, design: .rounded))
                                    .foregroundStyle(activeTab == tab ? AppTheme.accent : .white.opacity(0.45))
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 12)
                                    .background(
                                        activeTab == tab
                                            ? AppTheme.accent.opacity(0.14)
                                            : Color.clear,
                                        in: RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(6)
                    .background(Color.black.opacity(0.42), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)

                    // Content
                    Group {
                        switch activeTab {
                        case .keys:    KeyListTab()
                        case .patches: PatchManagerTab()
                        case .log:     KeyLogTab()
                        }
                    }
                    .environmentObject(licenseManager)
                }
            }
            .navigationTitle("Admin Panel")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Đóng") { dismiss() }
                        .fontWeight(.semibold)
                        .foregroundStyle(AppTheme.accent)
                }
            }
        }
        .tint(AppTheme.accent)
        .preferredColorScheme(.dark)
    }
}

// MARK: ─── TAB 1: Key List ───────────────────────────────────────
private struct KeyListTab: View {
    @EnvironmentObject private var licenseManager: LicenseManager
    @State private var showCreate = false
    @State private var copiedKey: String?
    @State private var confirmDeleteId: UUID?

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            Group {
                if licenseManager.memberKeys.isEmpty {
                    emptyState
                } else {
                    keyList
                }
            }

            // FAB — tạo key mới
            Button { showCreate = true } label: {
                HStack(spacing: 8) {
                    Image(systemName: "plus")
                        .font(.system(size: 16, weight: .black))
                    Text("Tạo Key")
                        .font(.system(size: 13, weight: .black, design: .rounded))
                }
                .foregroundStyle(.black)
                .padding(.horizontal, 18)
                .padding(.vertical, 14)
                .background(AppTheme.accent, in: Capsule())
                .shadow(color: AppTheme.accent.opacity(0.45), radius: 12)
            }
            .buttonStyle(.plain)
            .padding(.trailing, 20)
            .padding(.bottom, 24)
        }
        .sheet(isPresented: $showCreate) {
            CreateKeySheet()
                .environmentObject(licenseManager)
        }
        .confirmationDialog("Xóa key này?", isPresented: Binding(
            get: { confirmDeleteId != nil },
            set: { if !$0 { confirmDeleteId = nil } }
        ), titleVisibility: .visible) {
            Button("Xóa Key", role: .destructive) {
                if let id = confirmDeleteId { licenseManager.deleteMemberKey(id: id) }
                confirmDeleteId = nil
            }
            Button("Hủy", role: .cancel) { confirmDeleteId = nil }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 14) {
            Spacer()
            Image(systemName: "key.slash").font(.system(size: 44, weight: .light)).foregroundStyle(.white.opacity(0.2))
            Text("Chưa có key nào\nNhấn nút để tạo key mới")
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundStyle(.white.opacity(0.35))
                .multilineTextAlignment(.center)
            Spacer()
        }
    }

    private var keyList: some View {
        List(licenseManager.memberKeys) { entry in
            KeyRow(entry: entry, copiedKey: $copiedKey, onDelete: { confirmDeleteId = entry.id })
                .listRowBackground(Color.black.opacity(0.38))
                .listRowSeparatorTint(AppTheme.accent.opacity(0.12))
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
    }
}

// MARK: - Single Key Row
private struct KeyRow: View {
    let entry: MemberKeyEntry
    @Binding var copiedKey: String?
    let onDelete: () -> Void

    private let df: DateFormatter = {
        let f = DateFormatter(); f.dateStyle = .short; f.timeStyle = .short; return f
    }()

    private var statusColor: Color {
        if entry.isExpired { return .red }
        if entry.isUsed    { return .green }
        return .orange
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header row
            HStack(spacing: 8) {
                Circle().fill(statusColor).frame(width: 8, height: 8).shadow(color: statusColor, radius: 4)

                VStack(alignment: .leading, spacing: 2) {
                    Text(entry.note.isEmpty ? "Không có ghi chú" : entry.note)
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)

                    Text(entry.statusLabel + (entry.usedByDevice.map { " · \($0)" } ?? ""))
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundStyle(statusColor)
                }
                Spacer()

                // Copy
                Button {
                    UIPasteboard.general.string = entry.key
                    copiedKey = entry.key
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                        if copiedKey == entry.key { copiedKey = nil }
                    }
                } label: {
                    Image(systemName: copiedKey == entry.key ? "checkmark" : "doc.on.doc")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(copiedKey == entry.key ? .green : AppTheme.accent)
                        .frame(width: 34, height: 34)
                        .background(Color.black.opacity(0.38), in: Circle())
                }
                .buttonStyle(.plain)

                // Delete
                Button(role: .destructive, action: onDelete) {
                    Image(systemName: "trash")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.red.opacity(0.85))
                        .frame(width: 34, height: 34)
                        .background(Color.red.opacity(0.10), in: Circle())
                }
                .buttonStyle(.plain)
            }

            // Key code
            HStack(spacing: 8) {
                Text(entry.key)
                    .font(.system(size: 13, weight: .bold, design: .monospaced))
                    .foregroundStyle(AppTheme.accent)
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text("Tạo: \(df.string(from: entry.createdAt))")
                        .font(.system(size: 9, weight: .medium, design: .rounded))
                        .foregroundStyle(.white.opacity(0.3))
                    if let exp = entry.expiresAt {
                        Text("Hết hạn: \(df.string(from: exp))")
                            .font(.system(size: 9, weight: .bold, design: .rounded))
                            .foregroundStyle(entry.isExpired ? .red : .orange.opacity(0.85))
                    } else {
                        Text("Không giới hạn")
                            .font(.system(size: 9, weight: .medium, design: .rounded))
                            .foregroundStyle(.white.opacity(0.3))
                    }
                }
            }
        }
        .padding(.vertical, 10)
    }
}

// MARK: - Create Key Sheet
private struct CreateKeySheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var licenseManager: LicenseManager

    @State private var note         = ""
    @State private var hasExpiry    = false
    @State private var expiresAt    = Calendar.current.date(byAdding: .day, value: 30, to: Date()) ?? Date()

    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.pageBackground.ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 24) {
                        // Icon
                        Image(systemName: "key.badge.plus")
                            .font(.system(size: 56, weight: .light))
                            .foregroundStyle(AppTheme.accent)
                            .padding(.top, 20)

                        Text("Tạo Key Mới")
                            .font(.system(size: 20, weight: .black, design: .rounded))
                            .foregroundStyle(.white)

                        // Note field
                        VStack(alignment: .leading, spacing: 8) {
                            fieldLabel("GHI CHÚ / TÊN THÀNH VIÊN", icon: "person.fill")
                            TextField("VD: Nguyễn Văn A, tháng 10…", text: $note)
                                .styledInput()
                        }

                        // Expiry toggle
                        VStack(alignment: .leading, spacing: 12) {
                            fieldLabel("THỜI HẠN KEY", icon: "clock.fill")

                            Toggle(isOn: $hasExpiry.animation()) {
                                HStack(spacing: 8) {
                                    Image(systemName: hasExpiry ? "calendar.badge.clock" : "infinity")
                                        .foregroundStyle(hasExpiry ? AppTheme.accent : .white.opacity(0.45))
                                    Text(hasExpiry ? "Có thời hạn" : "Không giới hạn")
                                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                                        .foregroundStyle(.white)
                                }
                            }
                            .tint(AppTheme.accent)
                            .padding(14)
                            .background(Color.black.opacity(0.42), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(AppTheme.accent.opacity(0.28), lineWidth: 1))

                            if hasExpiry {
                                // Date picker — Wheels style (ngày giờ chi tiết)
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("Chọn ngày giờ hết hạn:")
                                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                                        .foregroundStyle(.white.opacity(0.6))
                                        .padding(.leading, 4)

                                    DatePicker(
                                        "Hết hạn",
                                        selection: $expiresAt,
                                        in: Date()...,
                                        displayedComponents: [.date, .hourAndMinute]
                                    )
                                    .datePickerStyle(.wheel)
                                    .labelsHidden()
                                    .frame(maxWidth: .infinity)
                                    .background(Color.black.opacity(0.38), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                                    .colorScheme(.dark)
                                    .transition(.opacity.combined(with: .move(edge: .top)))

                                    // Summary label
                                    HStack(spacing: 6) {
                                        Image(systemName: "calendar.badge.exclamationmark")
                                            .font(.system(size: 11))
                                            .foregroundStyle(.orange)
                                        Text("Hết hạn: \(expiresAt, format: .dateTime.day().month(.wide).year().hour().minute())")
                                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                                            .foregroundStyle(.orange)
                                    }
                                    .padding(.leading, 4)
                                }
                            }
                        }

                        // Format hint
                        HStack(spacing: 8) {
                            Image(systemName: "info.circle").foregroundStyle(.white.opacity(0.3))
                            Text("Key tạo tự động: OG-XXXX-XXXX-XXXX-XXXX")
                                .font(.system(size: 12, weight: .medium, design: .rounded))
                                .foregroundStyle(.white.opacity(0.35))
                        }
                        .padding(.horizontal, 4)
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 30)
                }
            }
            .navigationTitle("Tạo Key")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Hủy") { dismiss() }.foregroundStyle(.secondary)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Tạo") {
                        let entry = licenseManager.createMemberKey(
                            note: note.trimmingCharacters(in: .whitespaces),
                            expiresAt: hasExpiry ? expiresAt : nil
                        )
                        UIPasteboard.general.string = entry.key
                        dismiss()
                    }
                    .fontWeight(.black)
                    .foregroundStyle(AppTheme.accent)
                }
            }
        }
        .preferredColorScheme(.dark)
    }
}

// MARK: ─── TAB 2: Patch Manager ──────────────────────────────────
private struct PatchManagerTab: View {
    @EnvironmentObject private var licenseManager: LicenseManager
    @State private var showAddPatch    = false
    @State private var confirmDeleteId: UUID?
    @State private var editEntry: CustomPatchEntry?

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            Group {
                if licenseManager.customPatches.isEmpty {
                    patchEmptyState
                } else {
                    patchList
                }
            }

            Button { showAddPatch = true } label: {
                HStack(spacing: 8) {
                    Image(systemName: "plus").font(.system(size: 16, weight: .black))
                    Text("Thêm Patch")
                        .font(.system(size: 13, weight: .black, design: .rounded))
                }
                .foregroundStyle(.black)
                .padding(.horizontal, 18)
                .padding(.vertical, 14)
                .background(AppTheme.secondaryAccent, in: Capsule())
                .shadow(color: AppTheme.secondaryAccent.opacity(0.45), radius: 12)
            }
            .buttonStyle(.plain)
            .padding(.trailing, 20)
            .padding(.bottom, 24)
        }
        .sheet(isPresented: $showAddPatch) {
            AddPatchSheet()
                .environmentObject(licenseManager)
        }
        .sheet(item: $editEntry) { entry in
            EditPatchSheet(entry: entry)
                .environmentObject(licenseManager)
        }
        .confirmationDialog("Xóa patch này?", isPresented: Binding(
            get: { confirmDeleteId != nil },
            set: { if !$0 { confirmDeleteId = nil } }
        ), titleVisibility: .visible) {
            Button("Xóa Patch", role: .destructive) {
                if let id = confirmDeleteId { licenseManager.deleteCustomPatch(id: id) }
                confirmDeleteId = nil
            }
            Button("Hủy", role: .cancel) { confirmDeleteId = nil }
        }
    }

    private var patchEmptyState: some View {
        VStack(spacing: 14) {
            Spacer()
            Image(systemName: "bolt.slash.circle").font(.system(size: 44, weight: .light)).foregroundStyle(.white.opacity(0.2))
            Text("Chưa có patch thủ công\nNhấn nút để thêm patch mới")
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundStyle(.white.opacity(0.35))
                .multilineTextAlignment(.center)
            Spacer()
        }
    }

    private var patchList: some View {
        List(licenseManager.customPatches) { entry in
            CustomPatchRow(entry: entry,
                           onEdit: { editEntry = entry },
                           onDelete: { confirmDeleteId = entry.id })
                .listRowBackground(Color.black.opacity(0.38))
                .listRowSeparatorTint(AppTheme.secondaryAccent.opacity(0.12))
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
    }
}

// MARK: - Custom Patch Row
private struct CustomPatchRow: View {
    let entry: CustomPatchEntry
    let onEdit: () -> Void
    let onDelete: () -> Void

    private let df: DateFormatter = {
        let f = DateFormatter(); f.dateStyle = .short; f.timeStyle = .none; return f
    }()

    var body: some View {
        HStack(spacing: 12) {
            // Icon
            ZStack {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(AppTheme.secondaryAccent.opacity(0.15))
                    .frame(width: 44, height: 44)
                Image(systemName: "bolt.fill")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(AppTheme.secondaryAccent)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(entry.displayName)
                    .font(.system(size: 14, weight: .black, design: .rounded))
                    .foregroundStyle(.white)
                Text(entry.targetGame)
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundStyle(AppTheme.secondaryAccent)
                Text(entry.filename)
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.3))
                    .lineLimit(1)
            }

            Spacer()

            VStack(spacing: 6) {
                // Edit
                Button(action: onEdit) {
                    Image(systemName: "pencil")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(AppTheme.accent)
                        .frame(width: 32, height: 32)
                        .background(AppTheme.accent.opacity(0.12), in: Circle())
                }
                .buttonStyle(.plain)

                // Delete
                Button(role: .destructive, action: onDelete) {
                    Image(systemName: "trash")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.red.opacity(0.85))
                        .frame(width: 32, height: 32)
                        .background(Color.red.opacity(0.10), in: Circle())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, 8)
    }
}

// MARK: - Add Patch Sheet
private struct AddPatchSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var licenseManager: LicenseManager

    @State private var displayName  = ""
    @State private var targetGame   = "FREE FIRE • NORMAL"
    @State private var pickedFileData: Data?
    @State private var pickedFilename = ""
    @State private var showFilePicker = false
    @State private var errorMessage: String?

    private let gameOptions = [
        "FREE FIRE • NORMAL",
        "FREE FIRE • MAX",
        "PUBG MOBILE",
        "COD MOBILE",
        "Mobile Legends",
        "Khác"
    ]

    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.pageBackground.ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 24) {
                        Image(systemName: "bolt.badge.plus")
                            .font(.system(size: 52, weight: .light))
                            .foregroundStyle(AppTheme.secondaryAccent)
                            .padding(.top, 20)

                        Text("Thêm Patch Thủ Công")
                            .font(.system(size: 18, weight: .black, design: .rounded))
                            .foregroundStyle(.white)

                        // Tên patch
                        VStack(alignment: .leading, spacing: 8) {
                            fieldLabel("TÊN PATCH", icon: "textformat")
                            TextField("VD: Aim Đầu Pro, Aim Body Max…", text: $displayName)
                                .styledInput()
                        }

                        // Game
                        VStack(alignment: .leading, spacing: 8) {
                            fieldLabel("GAME MỤC TIÊU", icon: "gamecontroller.fill")
                            Menu {
                                ForEach(gameOptions, id: \.self) { opt in
                                    Button(opt) { targetGame = opt }
                                }
                            } label: {
                                HStack {
                                    Text(targetGame)
                                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                                        .foregroundStyle(.white)
                                    Spacer()
                                    Image(systemName: "chevron.up.chevron.down")
                                        .font(.system(size: 12))
                                        .foregroundStyle(AppTheme.secondaryAccent)
                                }
                                .padding(14)
                                .background(Color.black.opacity(0.42), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                                .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(AppTheme.secondaryAccent.opacity(0.38), lineWidth: 1))
                            }
                        }

                        // Upload file
                        VStack(alignment: .leading, spacing: 8) {
                            fieldLabel("FILE PATCH (.3105 / .OGIOS)", icon: "arrow.up.doc.fill")

                            Button { showFilePicker = true } label: {
                                HStack(spacing: 12) {
                                    Image(systemName: pickedFileData == nil ? "icloud.and.arrow.up" : "checkmark.circle.fill")
                                        .font(.system(size: 22, weight: .semibold))
                                        .foregroundStyle(pickedFileData == nil ? AppTheme.secondaryAccent : .green)

                                    VStack(alignment: .leading, spacing: 3) {
                                        Text(pickedFileData == nil ? "Chọn file patch từ Files app" : "File đã chọn")
                                            .font(.system(size: 13, weight: .bold, design: .rounded))
                                            .foregroundStyle(pickedFileData == nil ? AppTheme.secondaryAccent : .green)
                                        if !pickedFilename.isEmpty {
                                            Text(pickedFilename)
                                                .font(.system(size: 11, weight: .medium, design: .monospaced))
                                                .foregroundStyle(.white.opacity(0.55))
                                                .lineLimit(1)
                                        }
                                    }
                                    Spacer()
                                }
                                .padding(16)
                                .background(Color.black.opacity(0.42), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                                        .stroke(pickedFileData == nil ? AppTheme.secondaryAccent.opacity(0.38) : Color.green.opacity(0.5), lineWidth: 1)
                                )
                            }
                            .buttonStyle(.plain)
                        }

                        // Error
                        if let err = errorMessage {
                            HStack(spacing: 8) {
                                Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.red)
                                Text(err).font(.system(size: 12, weight: .medium, design: .rounded)).foregroundStyle(.red)
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 30)
                }
            }
            .navigationTitle("Thêm Patch")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Hủy") { dismiss() }.foregroundStyle(.secondary)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Lưu") { doSave() }
                        .fontWeight(.black)
                        .foregroundStyle(canSave ? AppTheme.secondaryAccent : .gray)
                        .disabled(!canSave)
                }
            }
            .fileImporter(
                isPresented: $showFilePicker,
                allowedContentTypes: [
                    UTType(filenameExtension: "3105") ?? .data,
                    UTType(filenameExtension: "OGIOS") ?? .data,
                    .data
                ],
                allowsMultipleSelection: false
            ) { result in
                handleFileImport(result)
            }
        }
        .preferredColorScheme(.dark)
    }

    private var canSave: Bool {
        !displayName.trimmingCharacters(in: .whitespaces).isEmpty && pickedFileData != nil
    }

    private func handleFileImport(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }
            let accessing = url.startAccessingSecurityScopedResource()
            defer { if accessing { url.stopAccessingSecurityScopedResource() } }
            do {
                pickedFileData    = try Data(contentsOf: url)
                pickedFilename    = url.lastPathComponent
                errorMessage      = nil
            } catch {
                errorMessage = "Không đọc được file: \(error.localizedDescription)"
            }
        case .failure(let error):
            errorMessage = error.localizedDescription
        }
    }

    private func doSave() {
        guard let data = pickedFileData else { return }
        let name = displayName.trimmingCharacters(in: .whitespaces)
        do {
            try licenseManager.addCustomPatch(
                displayName: name,
                targetGame: targetGame,
                fileData: data,
                originalFilename: pickedFilename
            )
            dismiss()
        } catch {
            errorMessage = "Lỗi lưu file: \(error.localizedDescription)"
        }
    }
}

// MARK: - Edit Patch Sheet
private struct EditPatchSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var licenseManager: LicenseManager
    let entry: CustomPatchEntry

    @State private var displayName: String
    @State private var targetGame: String

    init(entry: CustomPatchEntry) {
        self.entry      = entry
        _displayName    = State(initialValue: entry.displayName)
        _targetGame     = State(initialValue: entry.targetGame)
    }

    private let gameOptions = [
        "FREE FIRE • NORMAL", "FREE FIRE • MAX",
        "PUBG MOBILE", "COD MOBILE", "Mobile Legends", "Khác"
    ]

    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.pageBackground.ignoresSafeArea()
                VStack(spacing: 20) {
                    Image(systemName: "pencil.and.outline")
                        .font(.system(size: 44, weight: .light))
                        .foregroundStyle(AppTheme.accent)
                        .padding(.top, 20)

                    VStack(alignment: .leading, spacing: 8) {
                        fieldLabel("TÊN PATCH", icon: "textformat")
                        TextField("Tên patch…", text: $displayName).styledInput()
                    }
                    .padding(.horizontal, 20)

                    VStack(alignment: .leading, spacing: 8) {
                        fieldLabel("GAME MỤC TIÊU", icon: "gamecontroller.fill")
                        Menu {
                            ForEach(gameOptions, id: \.self) { opt in Button(opt) { targetGame = opt } }
                        } label: {
                            HStack {
                                Text(targetGame).font(.system(size: 14, weight: .semibold, design: .rounded)).foregroundStyle(.white)
                                Spacer()
                                Image(systemName: "chevron.up.chevron.down").font(.system(size: 12)).foregroundStyle(AppTheme.accent)
                            }
                            .padding(14)
                            .background(Color.black.opacity(0.42), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(AppTheme.accent.opacity(0.38), lineWidth: 1))
                        }
                    }
                    .padding(.horizontal, 20)

                    Spacer()
                }
            }
            .navigationTitle("Sửa Patch")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Hủy") { dismiss() }.foregroundStyle(.secondary)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Lưu") {
                        licenseManager.updateCustomPatch(
                            id: entry.id,
                            displayName: displayName.trimmingCharacters(in: .whitespaces),
                            targetGame: targetGame
                        )
                        dismiss()
                    }
                    .fontWeight(.black)
                    .foregroundStyle(AppTheme.accent)
                    .disabled(displayName.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
        .preferredColorScheme(.dark)
    }
}

// MARK: ─── TAB 3: Key Log ─────────────────────────────────────────
private struct KeyLogTab: View {
    @EnvironmentObject private var licenseManager: LicenseManager
    @State private var showClearConfirm = false

    private let df: DateFormatter = {
        let f = DateFormatter(); f.dateStyle = .short; f.timeStyle = .short; return f
    }()

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            Group {
                if licenseManager.keyLog.isEmpty {
                    VStack(spacing: 14) {
                        Spacer()
                        Image(systemName: "doc.text.magnifyingglass").font(.system(size: 44, weight: .light)).foregroundStyle(.white.opacity(0.2))
                        Text("Log trống").font(.system(size: 13, weight: .medium, design: .rounded)).foregroundStyle(.white.opacity(0.35))
                        Spacer()
                    }
                } else {
                    List(licenseManager.keyLog) { entry in
                        LogRow(entry: entry)
                            .listRowBackground(Color.black.opacity(0.38))
                            .listRowSeparatorTint(AppTheme.accent.opacity(0.1))
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                }
            }

            if !licenseManager.keyLog.isEmpty {
                Button {
                    showClearConfirm = true
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "trash").font(.system(size: 14, weight: .black))
                        Text("Xóa Log").font(.system(size: 13, weight: .black, design: .rounded))
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 14)
                    .background(Color.red.opacity(0.75), in: Capsule())
                }
                .buttonStyle(.plain)
                .padding(.trailing, 20)
                .padding(.bottom, 24)
                .confirmationDialog("Xóa toàn bộ log?", isPresented: $showClearConfirm, titleVisibility: .visible) {
                    Button("Xóa Tất Cả", role: .destructive) { licenseManager.clearKeyLog() }
                    Button("Hủy", role: .cancel) {}
                }
            }
        }
    }
}

private struct LogRow: View {
    let entry: KeyLogEntry
    private let df: DateFormatter = {
        let f = DateFormatter(); f.dateStyle = .short; f.timeStyle = .short; return f
    }()

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: actionIcon)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(actionColor)
                .frame(width: 26)

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(entry.key)
                        .font(.system(size: 12, weight: .bold, design: .monospaced))
                        .foregroundStyle(entry.role == "admin" ? AppTheme.accent : .white)
                    if entry.role == "admin" {
                        Text("ADMIN")
                            .font(.system(size: 8, weight: .black, design: .rounded))
                            .padding(.horizontal, 5).padding(.vertical, 2)
                            .background(AppTheme.accent.opacity(0.2), in: Capsule())
                            .foregroundStyle(AppTheme.accent)
                    }
                }
                Text("\(entry.action.uppercased()) · \(entry.deviceName)")
                    .font(.system(size: 10, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.4))
            }
            Spacer()
            Text(df.string(from: entry.timestamp))
                .font(.system(size: 9, weight: .medium, design: .rounded))
                .foregroundStyle(.white.opacity(0.3))
                .multilineTextAlignment(.trailing)
        }
        .padding(.vertical, 7)
    }

    private var actionIcon: String {
        switch entry.action {
        case "activated":   return "checkmark.circle.fill"
        case "deactivated": return "xmark.circle"
        case "created":     return "plus.circle.fill"
        case "deleted":     return "trash.circle"
        default:            return "circle"
        }
    }

    private var actionColor: Color {
        switch entry.action {
        case "activated":   return .green
        case "deactivated": return .red
        case "created":     return AppTheme.accent
        case "deleted":     return .red
        default:            return .gray
        }
    }
}

// MARK: - Shared UI helpers
private func fieldLabel(_ title: String, icon: String) -> some View {
    Label(title, systemImage: icon)
        .font(.system(size: 10, weight: .bold, design: .rounded))
        .tracking(1.0)
        .foregroundStyle(AppTheme.accent)
}

extension View {
    fileprivate func styledInput() -> some View {
        self
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
            .font(.system(size: 14, weight: .semibold, design: .rounded))
            .foregroundStyle(.white)
            .padding(14)
            .background(Color.black.opacity(0.42), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(AppTheme.accent.opacity(0.35), lineWidth: 1)
            )
    }
}
