import SwiftUI
import UniformTypeIdentifiers

struct ImportSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var importText: String = ""
    @State private var importResult: AppDataExportService.ImportResult?
    @State private var showFileImporter: Bool = false
    @State private var isImporting: Bool = false

    var body: some View {
        List {
            Section {
                Button {
                    if let clip = UIPasteboard.general.string {
                        importText = clip
                    }
                } label: {
                    HStack {
                        Image(systemName: "doc.on.clipboard.fill")
                            .foregroundStyle(.blue)
                        Text("Paste from Clipboard")
                        Spacer()
                    }
                }

                Button {
                    showFileImporter = true
                } label: {
                    HStack {
                        Image(systemName: "folder.fill")
                            .foregroundStyle(.orange)
                        Text("Load from File")
                        Spacer()
                    }
                }
            } header: {
                Label("Input", systemImage: "square.and.arrow.down")
            }

            Section {
                TextEditor(text: $importText)
                    .font(.system(.caption, design: .monospaced))
                    .frame(minHeight: 200)
                    .overlay(alignment: .topLeading) {
                        if importText.isEmpty {
                            Text("Paste your exported JSON here...")
                                .font(.system(.caption, design: .monospaced))
                                .foregroundStyle(.quaternary)
                                .padding(.horizontal, 4)
                                .padding(.vertical, 8)
                                .allowsHitTesting(false)
                        }
                    }
            } header: {
                Label("JSON Content", systemImage: "doc.text")
            } footer: {
                if !importText.isEmpty {
                    let byteCount = importText.utf8.count
                    Text("\(byteCount > 1024 ? "\(byteCount / 1024)KB" : "\(byteCount)B") | Tap Import to restore settings")
                }
            }

            if let result = importResult {
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Image(systemName: result.errors.isEmpty ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                                .foregroundStyle(result.errors.isEmpty ? .green : .orange)
                            Text(result.summary)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(result.errors.isEmpty ? .green : .orange)
                        }

                        if !result.errors.isEmpty {
                            ForEach(result.errors, id: \.self) { error in
                                Text(error)
                                    .font(.caption2.monospacedDigit())
                                    .foregroundStyle(.red)
                            }
                        }
                    }
                } header: {
                    Label("Import Result", systemImage: "checkmark.seal")
                }
            }

            Section {
                Button {
                    isImporting = true
                    let result = AppDataExportService.shared.importJSON(importText)
                    importResult = result
                    isImporting = false

                    if result.errors.isEmpty {
                        Task {
                            try? await Task.sleep(for: .seconds(2.5))
                            dismiss()
                        }
                    }
                } label: {
                    HStack {
                        if isImporting {
                            ProgressView()
                                .controlSize(.small)
                        } else {
                            Image(systemName: "square.and.arrow.down.fill")
                        }
                        Text("Import Settings")
                            .font(.headline)
                        Spacer()
                    }
                    .foregroundStyle(importText.isEmpty || isImporting ? .secondary : .blue)
                }
                .disabled(importText.isEmpty || isImporting)
            }
        }
        .navigationTitle("Import Settings")
        .navigationBarTitleDisplayMode(.inline)
        .fileImporter(
            isPresented: $showFileImporter,
            allowedContentTypes: [.json, .plainText],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                guard let url = urls.first else { return }
                guard url.startAccessingSecurityScopedResource() else { return }
                defer { url.stopAccessingSecurityScopedResource() }
                if let data = try? Data(contentsOf: url),
                   let text = String(data: data, encoding: .utf8) {
                    importText = text
                }
            case .failure:
                break
            }
        }
    }
}
