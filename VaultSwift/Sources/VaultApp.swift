import SwiftUI
import AppKit

// MARK: - Data Models

struct VaultField: Codable, Identifiable, Hashable {
    var id = UUID()
    var label: String
    var value: String
    var isSecret: Bool

    init(label: String = "", value: String = "", isSecret: Bool = false) {
        self.id = UUID()
        self.label = label
        self.value = value
        self.isSecret = isSecret
    }
}

struct VaultEntry: Codable, Identifiable, Hashable {
    var id = UUID()
    var name: String
    var fields: [VaultField]

    init(name: String = "", fields: [VaultField] = [
        VaultField(label: "Email", isSecret: false),
        VaultField(label: "Password", isSecret: true)
    ]) {
        self.id = UUID()
        self.name = name
        self.fields = fields
    }
}

struct VaultFolder: Codable, Identifiable, Hashable {
    var id = UUID()
    var name: String
    var entries: [VaultEntry]

    init(name: String, entries: [VaultEntry] = []) {
        self.id = UUID()
        self.name = name
        self.entries = entries
    }
}

struct VaultData: Codable {
    var folders: [VaultFolder]

    init() {
        folders = [VaultFolder(name: "Generale")]
    }

    func allEntries() -> [(entry: VaultEntry, folderName: String)] {
        var result: [(VaultEntry, String)] = []
        for folder in folders {
            for entry in folder.entries {
                result.append((entry, folder.name))
            }
        }
        return result
    }

    func search(_ query: String) -> [(entry: VaultEntry, folderName: String)] {
        if query.isEmpty { return allEntries() }
        return allEntries().filter {
            $0.entry.name.localizedCaseInsensitiveContains(query)
        }
    }
}

// MARK: - Storage

class VaultStorage {
    static let shared = VaultStorage()
    private let fileURL: URL

    init() {
        let dir = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".local_vault")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        fileURL = dir.appendingPathComponent("vault.json")
    }

    func load() -> VaultData {
        guard let data = try? Data(contentsOf: fileURL),
              let vault = try? JSONDecoder().decode(VaultData.self, from: data) else {
            return VaultData()
        }
        return vault
    }

    func save(_ vault: VaultData) {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        guard let data = try? encoder.encode(vault) else { return }
        try? data.write(to: fileURL)
    }
}

// MARK: - ViewModel

class VaultViewModel: ObservableObject {
    @Published var data: VaultData
    @Published var selectedFolderID: UUID?
    @Published var selectedEntryID: UUID?
    @Published var searchText = ""

    private let storage = VaultStorage.shared

    init() {
        data = storage.load()
        selectedFolderID = data.folders.first?.id
    }

    func reload() {
        data = storage.load()
    }

    var selectedFolder: VaultFolder? {
        data.folders.first { $0.id == selectedFolderID }
    }

    var selectedEntry: VaultEntry? {
        selectedFolder?.entries.first { $0.id == selectedEntryID }
    }

    var filteredEntries: [VaultEntry] {
        guard let folder = selectedFolder else { return [] }
        if searchText.isEmpty { return folder.entries }
        return folder.entries.filter {
            $0.name.localizedCaseInsensitiveContains(searchText)
        }
    }

    func save() { storage.save(data) }

    func addFolder(name: String) {
        let folder = VaultFolder(name: name)
        data.folders.append(folder)
        selectedFolderID = folder.id
        selectedEntryID = nil
        save()
    }

    func renameFolder(id: UUID, name: String) {
        if let idx = data.folders.firstIndex(where: { $0.id == id }) {
            data.folders[idx].name = name
            save()
        }
    }

    func deleteFolder(id: UUID) {
        guard data.folders.count > 1 else { return }
        data.folders.removeAll { $0.id == id }
        selectedFolderID = data.folders.first?.id
        selectedEntryID = nil
        save()
    }

    func addEntry(_ entry: VaultEntry) {
        if let idx = data.folders.firstIndex(where: { $0.id == selectedFolderID }) {
            data.folders[idx].entries.append(entry)
            selectedEntryID = entry.id
            save()
        }
    }

    func updateEntry(_ entry: VaultEntry) {
        if let fi = data.folders.firstIndex(where: { $0.id == selectedFolderID }),
           let ei = data.folders[fi].entries.firstIndex(where: { $0.id == entry.id }) {
            data.folders[fi].entries[ei] = entry
            save()
        }
    }

    func deleteEntry(id: UUID) {
        if let fi = data.folders.firstIndex(where: { $0.id == selectedFolderID }) {
            data.folders[fi].entries.removeAll { $0.id == id }
            selectedEntryID = nil
            save()
        }
    }
}

// MARK: - Spotlight Panel

class SpotlightPanel {
    static let shared = SpotlightPanel()

    private var panel: NSPanel?
    private var hostingView: NSHostingView<SpotlightView>?

    func toggle() {
        if let panel = panel, panel.isVisible {
            hide()
        } else {
            show()
        }
    }

    func show() {
        let data = VaultStorage.shared.load()

        if panel == nil {
            let p = NSPanel(
                contentRect: NSRect(x: 0, y: 0, width: 620, height: 68),
                styleMask: [.nonactivatingPanel, .titled, .fullSizeContentView],
                backing: .buffered,
                defer: false
            )
            p.isFloatingPanel = true
            p.level = .floating
            p.titleVisibility = .hidden
            p.titlebarAppearsTransparent = true
            p.isMovableByWindowBackground = true
            p.backgroundColor = .clear
            p.isOpaque = false
            p.hasShadow = true
            p.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
            p.hidesOnDeactivate = true
            panel = p
        }

        let view = SpotlightView(data: data) { [weak self] in
            self?.hide()
        }
        let hosting = NSHostingView(rootView: view)
        hosting.frame = NSRect(x: 0, y: 0, width: 620, height: 68)
        panel?.contentView = hosting
        hostingView = hosting

        // Centra sullo schermo
        if let screen = NSScreen.main {
            let screenFrame = screen.visibleFrame
            let x = screenFrame.midX - 310
            let y = screenFrame.midY + 100
            panel?.setFrame(NSRect(x: x, y: y, width: 620, height: 68), display: true)
        }

        panel?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func hide() {
        panel?.orderOut(nil)
        NSApp.hide(nil)
    }

    func updatePanelHeight(_ height: CGFloat) {
        guard let panel = panel else { return }
        let frame = panel.frame
        let newHeight = max(68, height)
        let newY = frame.maxY - newHeight
        panel.setFrame(NSRect(x: frame.minX, y: newY, width: frame.width, height: newHeight), display: true)
        hostingView?.frame = NSRect(x: 0, y: 0, width: frame.width, height: newHeight)
    }
}

// MARK: - Spotlight View

struct SpotlightView: View {
    let data: VaultData
    let onDismiss: () -> Void

    @State private var query = ""
    @State private var selectedIndex = 0
    @State private var copiedFieldID: UUID?
    @State private var expandedEntryID: UUID?

    var results: [(entry: VaultEntry, folderName: String)] {
        data.search(query)
    }

    var body: some View {
        VStack(spacing: 0) {
            // Search bar
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 18, weight: .light))
                    .foregroundColor(.secondary)

                SpotlightTextField(
                    text: $query,
                    onEscape: onDismiss,
                    onArrowDown: { selectedIndex = min(selectedIndex + 1, results.count - 1) },
                    onArrowUp: { selectedIndex = max(selectedIndex - 1, 0) },
                    onReturn: {
                        if results.indices.contains(selectedIndex) {
                            let entry = results[selectedIndex].entry
                            if expandedEntryID == entry.id {
                                // Copia tutto
                                copyAll(entry)
                            } else {
                                expandedEntryID = entry.id
                            }
                        }
                    }
                )

                if !query.isEmpty {
                    Button {
                        query = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 14))
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                }

                Text("ESC")
                    .font(.system(size: 10, weight: .medium, design: .rounded))
                    .foregroundColor(.secondary.opacity(0.5))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(Color.secondary.opacity(0.1))
                    .cornerRadius(4)
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 14)

            // Results
            if !results.isEmpty {
                Divider()
                    .padding(.horizontal, 12)

                ScrollView {
                    VStack(spacing: 2) {
                        ForEach(Array(results.prefix(8).enumerated()), id: \.element.entry.id) { index, result in
                            SpotlightResultRow(
                                entry: result.entry,
                                folderName: result.folderName,
                                isSelected: index == selectedIndex,
                                isExpanded: expandedEntryID == result.entry.id,
                                copiedFieldID: copiedFieldID,
                                onSelect: {
                                    selectedIndex = index
                                    if expandedEntryID == result.entry.id {
                                        expandedEntryID = nil
                                    } else {
                                        expandedEntryID = result.entry.id
                                    }
                                },
                                onCopyField: { field in
                                    copyField(field)
                                },
                                onCopyAll: {
                                    copyAll(result.entry)
                                }
                            )
                        }
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 6)
                }
                .frame(maxHeight: 380)
            }
        }
        .background(
            VisualEffectView(material: .hudWindow, blendingMode: .behindWindow)
                .cornerRadius(14)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
        .cornerRadius(14)
        .onChange(of: query) { _ in
            selectedIndex = 0
            if query.isEmpty { expandedEntryID = nil }
        }
        .onChange(of: results.count) { count in
            let rowHeight: CGFloat = 44
            let expandedHeight: CGFloat = expandedEntryID != nil ? 140 : 0
            let totalHeight = 68 + (count > 0 ? CGFloat(min(count, 8)) * rowHeight + expandedHeight + 20 : 0)
            SpotlightPanel.shared.updatePanelHeight(totalHeight)
        }
        .onChange(of: expandedEntryID) { _ in
            let rowHeight: CGFloat = 44
            let count = results.count
            let expandedHeight: CGFloat = expandedEntryID != nil ? 140 : 0
            let totalHeight = 68 + (count > 0 ? CGFloat(min(count, 8)) * rowHeight + expandedHeight + 20 : 0)
            SpotlightPanel.shared.updatePanelHeight(totalHeight)
        }
    }

    private func copyField(_ field: VaultField) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(field.value, forType: .string)
        copiedFieldID = field.id
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            copiedFieldID = nil
        }
    }

    private func copyAll(_ entry: VaultEntry) {
        let text = entry.fields.map { "\($0.label): \($0.value)" }.joined(separator: "\n")
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    }
}

// MARK: - Spotlight Result Row

struct SpotlightResultRow: View {
    let entry: VaultEntry
    let folderName: String
    let isSelected: Bool
    let isExpanded: Bool
    let copiedFieldID: UUID?
    let onSelect: () -> Void
    let onCopyField: (VaultField) -> Void
    let onCopyAll: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            // Main row
            HStack {
                Image(systemName: "key.fill")
                    .font(.system(size: 12))
                    .foregroundColor(.purple.opacity(0.7))
                    .frame(width: 24)

                VStack(alignment: .leading, spacing: 1) {
                    Text(entry.name)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.primary)
                    Text(folderName)
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                }

                Spacer()

                Text("\(entry.fields.count) campi")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)

                Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                    .font(.system(size: 9))
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(isSelected ? Color.purple.opacity(0.15) : Color.clear)
            .cornerRadius(8)
            .contentShape(Rectangle())
            .onTapGesture { onSelect() }

            // Expanded fields
            if isExpanded {
                VStack(spacing: 4) {
                    ForEach(entry.fields) { field in
                        HStack {
                            Text(field.label)
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(.secondary)
                                .frame(width: 80, alignment: .leading)

                            if field.isSecret {
                                Text(String(repeating: "•", count: min(field.value.count, 16)))
                                    .font(.system(size: 12, design: .monospaced))
                                    .foregroundColor(.primary.opacity(0.6))
                            } else {
                                Text(field.value)
                                    .font(.system(size: 12, design: .monospaced))
                                    .foregroundColor(.primary.opacity(0.8))
                                    .lineLimit(1)
                            }

                            Spacer()

                            Button {
                                onCopyField(field)
                            } label: {
                                HStack(spacing: 2) {
                                    Image(systemName: copiedFieldID == field.id ? "checkmark" : "doc.on.doc")
                                        .font(.system(size: 9))
                                    Text(copiedFieldID == field.id ? "Copiato!" : "Copia")
                                        .font(.system(size: 10))
                                }
                                .foregroundColor(copiedFieldID == field.id ? .green : .purple)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.purple.opacity(0.1))
                                .cornerRadius(5)
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                    }

                    // Copy all button
                    Button {
                        onCopyAll()
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "doc.on.doc.fill")
                                .font(.system(size: 9))
                            Text("Copia tutto")
                                .font(.system(size: 10, weight: .medium))
                        }
                        .foregroundColor(.purple)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 5)
                        .background(Color.purple.opacity(0.08))
                        .cornerRadius(5)
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, 8)
                }
                .padding(.vertical, 6)
                .padding(.horizontal, 28)
            }
        }
    }
}

// MARK: - Spotlight TextField (handles keyboard events)

struct SpotlightTextField: NSViewRepresentable {
    @Binding var text: String
    let onEscape: () -> Void
    let onArrowDown: () -> Void
    let onArrowUp: () -> Void
    let onReturn: () -> Void

    func makeNSView(context: Context) -> NSTextField {
        let field = NSTextField()
        field.isBordered = false
        field.drawsBackground = false
        field.font = .systemFont(ofSize: 20, weight: .light)
        field.placeholderString = "Cerca credenziali..."
        field.focusRingType = .none
        field.textColor = .white
        field.delegate = context.coordinator
        field.cell?.lineBreakMode = .byTruncatingTail

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            field.window?.makeFirstResponder(field)
        }
        return field
    }

    func updateNSView(_ field: NSTextField, context: Context) {
        if field.stringValue != text {
            field.stringValue = text
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, NSTextFieldDelegate {
        let parent: SpotlightTextField

        init(_ parent: SpotlightTextField) {
            self.parent = parent
        }

        func controlTextDidChange(_ obj: Notification) {
            if let field = obj.object as? NSTextField {
                parent.text = field.stringValue
            }
        }

        func control(_ control: NSControl, textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
            if commandSelector == #selector(NSResponder.cancelOperation(_:)) {
                parent.onEscape()
                return true
            }
            if commandSelector == #selector(NSResponder.moveDown(_:)) {
                parent.onArrowDown()
                return true
            }
            if commandSelector == #selector(NSResponder.moveUp(_:)) {
                parent.onArrowUp()
                return true
            }
            if commandSelector == #selector(NSResponder.insertNewline(_:)) {
                parent.onReturn()
                return true
            }
            return false
        }
    }
}

// MARK: - Visual Effect View

struct VisualEffectView: NSViewRepresentable {
    let material: NSVisualEffectView.Material
    let blendingMode: NSVisualEffectView.BlendingMode

    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = blendingMode
        view.state = .active
        return view
    }

    func updateNSView(_ view: NSVisualEffectView, context: Context) {
        view.material = material
        view.blendingMode = blendingMode
    }
}

// MARK: - Folder Sidebar

struct FolderSidebar: View {
    @EnvironmentObject var vm: VaultViewModel
    @State private var newFolderName = ""
    @State private var showingNewFolder = false
    @State private var renamingFolderID: UUID?
    @State private var renameText = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("CARTELLE")
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.secondary)
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 8)

            List(selection: $vm.selectedFolderID) {
                ForEach(vm.data.folders) { folder in
                    if renamingFolderID == folder.id {
                        TextField("Nome", text: $renameText, onCommit: {
                            if !renameText.isEmpty {
                                vm.renameFolder(id: folder.id, name: renameText)
                            }
                            renamingFolderID = nil
                        })
                        .textFieldStyle(.plain)
                        .font(.system(size: 13))
                    } else {
                        HStack {
                            Image(systemName: "folder.fill")
                                .font(.system(size: 12))
                                .foregroundColor(.purple.opacity(0.8))
                            Text(folder.name)
                                .font(.system(size: 13))
                            Spacer()
                            Text("\(folder.entries.count)")
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                        }
                        .tag(folder.id)
                        .contextMenu {
                            Button("Rinomina") {
                                renameText = folder.name
                                renamingFolderID = folder.id
                            }
                            if vm.data.folders.count > 1 {
                                Button("Elimina", role: .destructive) {
                                    vm.deleteFolder(id: folder.id)
                                }
                            }
                        }
                    }
                }
            }
            .listStyle(.sidebar)
            .onChange(of: vm.selectedFolderID) { _ in
                vm.selectedEntryID = nil
            }

            Divider()

            if showingNewFolder {
                HStack {
                    TextField("Nome cartella", text: $newFolderName, onCommit: {
                        if !newFolderName.isEmpty {
                            vm.addFolder(name: newFolderName)
                            newFolderName = ""
                        }
                        showingNewFolder = false
                    })
                    .textFieldStyle(.roundedBorder)
                    .font(.system(size: 12))

                    Button {
                        showingNewFolder = false
                        newFolderName = ""
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 10))
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
            } else {
                Button {
                    showingNewFolder = true
                } label: {
                    HStack {
                        Image(systemName: "plus")
                            .font(.system(size: 11))
                        Text("Nuova cartella")
                            .font(.system(size: 12))
                    }
                    .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
            }
        }
    }
}

// MARK: - Entry List

struct EntryList: View {
    @EnvironmentObject var vm: VaultViewModel
    @State private var showingAddSheet = false

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                    .font(.system(size: 13))
                TextField("Cerca...", text: $vm.searchText)
                    .textFieldStyle(.plain)
                    .font(.system(size: 13))
                if !vm.searchText.isEmpty {
                    Button {
                        vm.searchText = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                            .font(.system(size: 12))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(10)
            .background(Color(.controlBackgroundColor).opacity(0.5))
            .cornerRadius(8)
            .padding(.horizontal, 12)
            .padding(.top, 12)
            .padding(.bottom, 8)

            List(selection: $vm.selectedEntryID) {
                ForEach(vm.filteredEntries) { entry in
                    VStack(alignment: .leading, spacing: 3) {
                        Text(entry.name)
                            .font(.system(size: 13, weight: .medium))
                        Text("\(entry.fields.count) campi")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 4)
                    .tag(entry.id)
                }
            }
            .listStyle(.sidebar)

            Divider()

            Button {
                showingAddSheet = true
            } label: {
                HStack {
                    Image(systemName: "plus")
                    Text("Nuovo")
                        .font(.system(size: 13, weight: .medium))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
            }
            .buttonStyle(.plain)
            .foregroundColor(.purple)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
        }
        .sheet(isPresented: $showingAddSheet) {
            AddEditSheet(entry: nil) { entry in
                vm.addEntry(entry)
            }
        }
    }
}

// MARK: - Detail View

struct DetailView: View {
    @EnvironmentObject var vm: VaultViewModel
    @State private var revealedFields: Set<UUID> = []
    @State private var copiedFieldID: UUID?
    @State private var copiedAll = false
    @State private var showingEditSheet = false

    var body: some View {
        Group {
            if let entry = vm.selectedEntry {
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        HStack(alignment: .center) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(entry.name)
                                    .font(.system(size: 24, weight: .bold))
                                Text(vm.selectedFolder?.name ?? "")
                                    .font(.system(size: 12))
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                            Button {
                                showingEditSheet = true
                            } label: {
                                Image(systemName: "pencil")
                                    .font(.system(size: 13))
                                    .foregroundColor(.secondary)
                                    .padding(8)
                                    .background(Color(.controlBackgroundColor))
                                    .cornerRadius(6)
                            }
                            .buttonStyle(.plain)

                            Button {
                                vm.deleteEntry(id: entry.id)
                            } label: {
                                Image(systemName: "trash")
                                    .font(.system(size: 13))
                                    .foregroundColor(.red.opacity(0.7))
                                    .padding(8)
                                    .background(Color(.controlBackgroundColor))
                                    .cornerRadius(6)
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.bottom, 20)

                        Button {
                            copyAll(entry: entry)
                        } label: {
                            HStack {
                                Image(systemName: copiedAll ? "checkmark" : "doc.on.doc")
                                    .font(.system(size: 12))
                                Text(copiedAll ? "Copiato!" : "Copia tutto")
                                    .font(.system(size: 13, weight: .medium))
                            }
                            .foregroundColor(copiedAll ? .green : .purple)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(Color(.controlBackgroundColor))
                            .cornerRadius(8)
                        }
                        .buttonStyle(.plain)
                        .padding(.bottom, 16)

                        ForEach(entry.fields) { field in
                            FieldCard(
                                field: field,
                                isRevealed: revealedFields.contains(field.id),
                                isCopied: copiedFieldID == field.id,
                                onToggleReveal: {
                                    if revealedFields.contains(field.id) {
                                        revealedFields.remove(field.id)
                                    } else {
                                        revealedFields.insert(field.id)
                                    }
                                },
                                onCopy: { copyField(field) }
                            )
                        }
                    }
                    .padding(24)
                }
                .sheet(isPresented: $showingEditSheet) {
                    AddEditSheet(entry: entry) { updated in
                        vm.updateEntry(updated)
                    }
                }
            } else {
                VStack {
                    Image(systemName: "key.fill")
                        .font(.system(size: 40))
                        .foregroundColor(.secondary.opacity(0.3))
                        .padding(.bottom, 8)
                    Text("Seleziona un elemento")
                        .font(.system(size: 15))
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }

    private func copyField(_ field: VaultField) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(field.value, forType: .string)
        copiedFieldID = field.id
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { copiedFieldID = nil }
    }

    private func copyAll(entry: VaultEntry) {
        let text = entry.fields.map { "\($0.label): \($0.value)" }.joined(separator: "\n")
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
        copiedAll = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { copiedAll = false }
    }
}

struct FieldCard: View {
    let field: VaultField
    let isRevealed: Bool
    let isCopied: Bool
    let onToggleReveal: () -> Void
    let onCopy: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(field.label.uppercased())
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.secondary)
                    .tracking(0.5)
                Spacer()
                if field.isSecret {
                    Button { onToggleReveal() } label: {
                        Image(systemName: isRevealed ? "eye.slash" : "eye")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                }
                Button { onCopy() } label: {
                    HStack(spacing: 3) {
                        Image(systemName: isCopied ? "checkmark" : "doc.on.doc")
                            .font(.system(size: 10))
                        Text(isCopied ? "Copiato!" : "Copia")
                            .font(.system(size: 11))
                    }
                    .foregroundColor(isCopied ? .green : .purple)
                }
                .buttonStyle(.plain)
            }
            if field.isSecret && !isRevealed {
                Text(String(repeating: "•", count: min(field.value.count, 24)))
                    .font(.system(size: 14, design: .monospaced))
                    .foregroundColor(.primary.opacity(0.8))
            } else {
                Text(field.value.isEmpty ? "—" : field.value)
                    .font(.system(size: 14, design: .monospaced))
                    .foregroundColor(.primary.opacity(0.8))
                    .textSelection(.enabled)
            }
        }
        .padding(14)
        .background(Color(.controlBackgroundColor))
        .cornerRadius(10)
        .padding(.bottom, 6)
    }
}

// MARK: - Add/Edit Sheet

struct AddEditSheet: View {
    @Environment(\.dismiss) var dismiss
    let existingEntry: VaultEntry?
    let onSave: (VaultEntry) -> Void

    @State private var name: String
    @State private var fields: [VaultField]

    init(entry: VaultEntry?, onSave: @escaping (VaultEntry) -> Void) {
        self.existingEntry = entry
        self.onSave = onSave
        _name = State(initialValue: entry?.name ?? "")
        _fields = State(initialValue: entry?.fields ?? [
            VaultField(label: "Email", isSecret: false),
            VaultField(label: "Password", isSecret: true)
        ])
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text(existingEntry != nil ? "Modifica" : "Nuovo elemento")
                    .font(.system(size: 16, weight: .semibold))
                Spacer()
                Button { dismiss() } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.secondary)
                        .padding(6)
                        .background(Color(.controlBackgroundColor))
                        .cornerRadius(12)
                }
                .buttonStyle(.plain)
            }
            .padding(20)

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("NOME")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(.secondary)
                        TextField("es. Supabase Personale", text: $name)
                            .textFieldStyle(.roundedBorder)
                            .font(.system(size: 14))
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("CAMPI")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(.secondary)

                        ForEach($fields) { $field in
                            HStack(spacing: 8) {
                                VStack(spacing: 6) {
                                    TextField("Nome campo", text: $field.label)
                                        .textFieldStyle(.roundedBorder)
                                        .font(.system(size: 12))
                                    HStack {
                                        if field.isSecret {
                                            SecureField("Valore", text: $field.value)
                                                .textFieldStyle(.roundedBorder)
                                                .font(.system(size: 13))
                                        } else {
                                            TextField("Valore", text: $field.value)
                                                .textFieldStyle(.roundedBorder)
                                                .font(.system(size: 13))
                                        }
                                        Toggle(isOn: $field.isSecret) {
                                            Image(systemName: field.isSecret ? "eye.slash" : "eye")
                                                .font(.system(size: 11))
                                        }
                                        .toggleStyle(.button)
                                        .help("Segreto")
                                    }
                                }
                                Button {
                                    fields.removeAll { $0.id == field.id }
                                } label: {
                                    Image(systemName: "xmark")
                                        .font(.system(size: 10))
                                        .foregroundColor(.secondary)
                                }
                                .buttonStyle(.plain)
                            }
                            .padding(10)
                            .background(Color(.controlBackgroundColor))
                            .cornerRadius(8)
                        }

                        Button {
                            fields.append(VaultField())
                        } label: {
                            HStack {
                                Image(systemName: "plus")
                                    .font(.system(size: 11))
                                Text("Aggiungi campo")
                                    .font(.system(size: 12))
                            }
                            .foregroundColor(.secondary)
                        }
                        .buttonStyle(.plain)
                        .padding(.top, 4)
                    }
                }
                .padding(20)
            }

            Divider()

            HStack {
                Button("Annulla") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Spacer()
                Button("Salva") {
                    var entry = existingEntry ?? VaultEntry()
                    entry.name = name
                    entry.fields = fields.filter { !$0.label.isEmpty }
                    onSave(entry)
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(name.isEmpty)
            }
            .padding(20)
        }
        .frame(width: 480, height: 520)
    }
}

// MARK: - Content View

struct ContentView: View {
    @EnvironmentObject var vm: VaultViewModel

    var body: some View {
        NavigationSplitView(columnVisibility: .constant(.all)) {
            FolderSidebar()
                .navigationSplitViewColumnWidth(min: 160, ideal: 180, max: 220)
        } content: {
            EntryList()
                .navigationSplitViewColumnWidth(min: 180, ideal: 220, max: 280)
        } detail: {
            DetailView()
        }
        .navigationSplitViewStyle(.balanced)
    }
}

// MARK: - App Delegate

class AppDelegate: NSObject, NSApplicationDelegate {
    private var mainWindow: NSWindow?

    func applicationDidFinishLaunching(_ notification: Notification) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.mainWindow = NSApp.windows.first { $0.isVisible }
            self.setupCGEventTapHotkey()
        }
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag {
            if let window = mainWindow {
                window.makeKeyAndOrderFront(nil)
                sender.activate(ignoringOtherApps: true)
            }
        }
        return true
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ application: NSApplication) -> Bool {
        return false
    }

    private func setupCGEventTapHotkey() {
        let callback: CGEventTapCallBack = { proxy, type, event, refcon in
            if type == .keyDown {
                let keycode = event.getIntegerValueField(.keyboardEventKeycode)
                let flags = event.flags
                if keycode == 35
                    && flags.contains(.maskCommand)
                    && flags.contains(.maskShift) {
                    DispatchQueue.main.async {
                        SpotlightPanel.shared.toggle()
                    }
                    return nil
                }
            }
            return Unmanaged.passRetained(event)
        }

        let refcon = Unmanaged.passUnretained(self).toOpaque()

        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: CGEventMask(1 << CGEventType.keyDown.rawValue),
            callback: callback,
            userInfo: refcon
        ) else {
            print("Impossibile creare event tap. Controlla i permessi di Accessibilita'.")
            return
        }

        let source = CFMachPortCreateRunLoopSource(nil, tap, 0)
        let thread = Thread {
            let loop = CFRunLoopGetCurrent()
            CFRunLoopAddSource(loop, source, .defaultMode)
            CGEvent.tapEnable(tap: tap, enable: true)
            CFRunLoopRun()
        }
        thread.qualityOfService = .userInteractive
        thread.start()
    }
}

// MARK: - App Entry Point

@main
struct VaultAppMain: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var delegate
    @StateObject private var vm = VaultViewModel()

    var body: some Scene {
        Window("Vault", id: "main") {
            ContentView()
                .environmentObject(vm)
                .frame(minWidth: 750, minHeight: 450)
                .preferredColorScheme(.dark)
        }
        .windowStyle(.titleBar)
        .windowToolbarStyle(.unified(showsTitle: false))
        .defaultSize(width: 900, height: 560)
    }
}
