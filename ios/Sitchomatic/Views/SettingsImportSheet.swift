import SwiftUI
import UIKit
import UniformTypeIdentifiers

struct SettingsImportSheet<VM: AnyObject>: View {
    let vm: VM
    @Environment(\.dismiss) private var dismiss
    @State private var importText: String = ""
    @State private var importResult: AppDataExportService.ImportResult?
    @State private var showFileImporter: Bool = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                HStack(spacing: 8) {
                    Button {
                        if let clip = UIPasteboard.general.string { importText = clip }
                    } label: {
                        Label("Paste", systemImage: "doc.on.clipboard").font(.caption)
                    }
                    .buttonStyle(.bordered).controlSize(.small)

                    Button { showFileImporter = true } label: {
                        Label("Load File", systemImage: "folder").font(.caption)
                    }
                    .buttonStyle(.bordered).controlSize(.small)

                    Spacer()

                    let byteCount = importText.utf8.count
                    if byteCount > 0 {
                        Text(byteCount > 1024 ? "\(byteCount / 1024)KB" : "\(byteCount)B")
                            .font(.system(.caption2, design: .monospaced))
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.horizontal)

                TextEditor(text: $importText)
                    .font(.system(.callout, design: .monospaced))
                    .scrollContentBackground(.hidden).padding(10)
                    .background(Color(.tertiarySystemGroupedBackground))
                    .clipShape(.rect(cornerRadius: 10)).frame(minHeight: 180)
                    .overlay(alignment: .topLeading) {
                        if importText.isEmpty {
                            Text("Paste exported JSON config here...")
                                .font(.system(.callout, design: .monospaced))
                                .foregroundStyle(.quaternary)
                                .padding(.horizontal, 14).padding(.vertical, 18)
                                .allowsHitTesting(false)
                        }
                    }
                    .padding(.horizontal)

                if let result = importResult {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(result.summary)
                            .font(.system(.caption, design: .monospaced, weight: .bold))
                            .foregroundStyle(.green)
                        if !result.errors.isEmpty {
                            ForEach(result.errors, id: \.self) { error in
                                Text(error)
                                    .font(.system(.caption2, design: .monospaced))
                                    .foregroundStyle(.red)
                            }
                        }
                    }
                    .padding(.horizontal)
                }

                Spacer()
            }
            .padding(.top)
            .navigationTitle("Import Settings").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Import") {
                        let result = AppDataExportService.shared.importJSON(importText)
                        importResult = result
                        if result.errors.isEmpty {
                            Task {
                                try? await Task.sleep(for: .seconds(2))
                                dismiss()
                            }
                        }
                    }
                    .disabled(importText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .fileImporter(isPresented: $showFileImporter, allowedContentTypes: [.json, .plainText], allowsMultipleSelection: false) { result in
                switch result {
                case .success(let urls):
                    guard let url = urls.first else { return }
                    guard url.startAccessingSecurityScopedResource() else { return }
                    defer { url.stopAccessingSecurityScopedResource() }
                    if let data = try? Data(contentsOf: url), let text = String(data: data, encoding: .utf8) {
                        importText = text
                    }
                case .failure: break
                }
            }
        }
        .presentationDetents([.medium, .large]).presentationDragIndicator(.visible)
        .presentationContentInteraction(.scrolls)
    }
}
