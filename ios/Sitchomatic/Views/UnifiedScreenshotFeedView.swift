import SwiftUI
import UIKit

struct UnifiedScreenshotFeedView: View {
    @State private var manager = UnifiedScreenshotManager.shared
    @State private var selectedScreenshot: CapturedScreenshot?
    @State private var filterOption: ScreenshotFilterOption = .all
    @State private var showStats: Bool = false
    @State private var showClearConfirm: Bool = false
    @State private var showFullImage: Bool = false
    @State private var viewMode: ViewMode = .all
    @State private var showFlipbook: Bool = false
    @State private var flipbookStartIndex: Int = 0
    @State private var showCorrectionSheet: Bool = false
    @State private var correctionScreenshot: CapturedScreenshot?
    @State private var selectedAlbum: ScreenshotAlbum?

    enum ViewMode: String, CaseIterable {
        case all = "All"
        case albums = "Albums"
    }

    enum ScreenshotFilterOption: String, CaseIterable, Identifiable, Sendable {
        case all = "All"
        case crucial = "Crucial"
        case success = "Success"
        case permDisabled = "Perm"
        case tempDisabled = "Temp"
        case incorrect = "Incorrect"
        case unknown = "Unknown"
        case overridden = "Override"
        var id: String { rawValue }

        var color: Color {
            switch self {
            case .all: .primary
            case .crucial: .yellow
            case .success: .green
            case .permDisabled: .red
            case .tempDisabled: .orange
            case .incorrect: .secondary
            case .unknown: .gray
            case .overridden: .purple
            }
        }

        var icon: String {
            switch self {
            case .all: "photo.stack"
            case .crucial: "exclamationmark.triangle.fill"
            case .success: "checkmark.circle.fill"
            case .permDisabled: "lock.slash.fill"
            case .tempDisabled: "clock.badge.exclamationmark"
            case .incorrect: "xmark.circle.fill"
            case .unknown: "questionmark.circle"
            case .overridden: "pencil.circle.fill"
            }
        }
    }

    private var filteredScreenshots: [CapturedScreenshot] {
        switch filterOption {
        case .all: manager.screenshots
        case .crucial: manager.crucialScreenshots()
        case .success: manager.screenshots.filter { $0.detectedOutcome == .success || $0.userOverride == .success }
        case .permDisabled: manager.screenshots.filter { $0.detectedOutcome == .permDisabled || $0.userOverride == .permDisabled }
        case .tempDisabled: manager.screenshots.filter { $0.detectedOutcome == .tempDisabled || $0.userOverride == .tempDisabled }
        case .incorrect: manager.screenshots.filter { $0.detectedOutcome == .incorrectPassword || $0.detectedOutcome == .noAccount || $0.userOverride == .noAcc }
        case .unknown: manager.screenshots.filter { $0.detectedOutcome == .unknown && $0.userOverride == .none }
        case .overridden: manager.screenshots.filter { $0.hasUserOverride }
        }
    }

    private func countFor(_ option: ScreenshotFilterOption) -> Int {
        switch option {
        case .all: manager.screenshots.count
        case .crucial: manager.crucialScreenshots().count
        case .success: manager.screenshots.filter { $0.detectedOutcome == .success || $0.userOverride == .success }.count
        case .permDisabled: manager.screenshots.filter { $0.detectedOutcome == .permDisabled || $0.userOverride == .permDisabled }.count
        case .tempDisabled: manager.screenshots.filter { $0.detectedOutcome == .tempDisabled || $0.userOverride == .tempDisabled }.count
        case .incorrect: manager.screenshots.filter { $0.detectedOutcome == .incorrectPassword || $0.detectedOutcome == .noAccount || $0.userOverride == .noAcc }.count
        case .unknown: manager.screenshots.filter { $0.detectedOutcome == .unknown && $0.userOverride == .none }.count
        case .overridden: manager.screenshots.filter { $0.hasUserOverride }.count
        }
    }

    // MARK: - Album Grouping

    private var albums: [ScreenshotAlbum] {
        let grouped = Dictionary(grouping: filteredScreenshots) { $0.albumKey }
        return grouped.map { key, screenshots in
            let sorted = screenshots.sorted { $0.timestamp > $1.timestamp }
            return ScreenshotAlbum(
                id: key,
                cardDisplayNumber: sorted.first?.cardDisplayNumber ?? key,
                cardId: sorted.first?.cardId ?? "",
                screenshots: sorted,
                title: sorted.first?.albumTitle ?? key,
                latestTimestamp: sorted.first?.timestamp ?? Date()
            )
        }.sorted { $0.latestTimestamp > $1.latestTimestamp }
    }

    var body: some View {
        VStack(spacing: 0) {
            if !manager.screenshots.isEmpty {
                viewModeAndFilterBar
            }

            if showStats {
                analysisStatsCard
            }

            ScrollView {
                LazyVStack(spacing: 10) {
                    if manager.screenshots.isEmpty {
                        emptyState
                    } else if filteredScreenshots.isEmpty {
                        noMatchesState
                    } else if viewMode == .albums {
                        ForEach(albums) { album in
                            Button { selectedAlbum = album } label: {
                                AlbumCardView(album: album)
                            }
                            .buttonStyle(.plain)
                        }
                    } else {
                        ForEach(Array(filteredScreenshots.enumerated()), id: \.element.id) { index, screenshot in
                            Button {
                                selectedScreenshot = screenshot
                            } label: {
                                ScreenshotTile(screenshot: screenshot)
                            }
                            .buttonStyle(.plain)
                            .contextMenu {
                                Button {
                                    flipbookStartIndex = index
                                    showFlipbook = true
                                } label: {
                                    Label("Open Flipbook", systemImage: "book.pages")
                                }
                                Button {
                                    correctionScreenshot = screenshot
                                    showCorrectionSheet = true
                                } label: {
                                    Label("Override Result", systemImage: "pencil.circle")
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal)
                .padding(.vertical, 12)
                .padding(.bottom, 24)
            }
        }
        .background(Color(.systemGroupedBackground))
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button { withAnimation(.snappy) { showStats.toggle() } } label: {
                        Label(showStats ? "Hide AI Stats" : "Show AI Stats", systemImage: "cpu")
                    }
                    if !manager.screenshots.isEmpty {
                        Button(role: .destructive) { showClearConfirm = true } label: {
                            Label("Clear All Screenshots", systemImage: "trash")
                        }
                    }
                } label: {
                    Image(systemName: "camera.viewfinder")
                        .symbolEffect(.pulse, isActive: !manager.screenshots.isEmpty)
                }
            }
        }
        .sheet(item: $selectedScreenshot) { screenshot in
            ScreenshotDetailSheet(screenshot: screenshot, showFullImage: $showFullImage)
        }
        .sheet(item: $selectedAlbum) { album in
            NavigationStack {
                AlbumDetailSheet(album: album, manager: manager)
            }
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showCorrectionSheet) {
            if let screenshot = correctionScreenshot {
                NavigationStack {
                    ScreenshotCorrectionSheet(screenshot: screenshot, manager: manager)
                }
                .presentationDetents([.medium])
                .presentationDragIndicator(.visible)
            }
        }
        .fullScreenCover(isPresented: $showFlipbook) {
            ScreenshotFlipbookView(screenshots: filteredScreenshots, startIndex: flipbookStartIndex)
        }
        .alert("Clear All Screenshots?", isPresented: $showClearConfirm) {
            Button("Clear All", role: .destructive) { manager.clearAll() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will remove all \(manager.screenshots.count) screenshot(s). This cannot be undone.")
        }
    }

    private var viewModeAndFilterBar: some View {
        VStack(spacing: 4) {
            // View mode toggle (Albums / All)
            HStack(spacing: 8) {
                ForEach(ViewMode.allCases, id: \.rawValue) { mode in
                    let isSelected = viewMode == mode
                    Button {
                        withAnimation(.spring(duration: 0.25)) { viewMode = mode }
                    } label: {
                        Text(mode.rawValue)
                            .font(.system(size: 11, weight: .bold, design: .monospaced))
                            .foregroundStyle(isSelected ? .white : .secondary)
                            .padding(.horizontal, 12).padding(.vertical, 4)
                            .background(isSelected ? Color.accentColor.opacity(0.75) : Color(.tertiarySystemGroupedBackground))
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
                Spacer()
            }
            .padding(.horizontal, 16).padding(.top, 6)

            // Filter bar
            ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(ScreenshotFilterOption.allCases) { option in
                    let count = countFor(option)
                    let isSelected = filterOption == option
                    Button {
                        withAnimation(.spring(duration: 0.25)) { filterOption = option }
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: option.icon)
                                .font(.system(size: 9, weight: .bold))
                            Text(option.rawValue)
                                .font(.system(size: 10, weight: .bold, design: .monospaced))
                            if count > 0 {
                                Text("\(count)")
                                    .font(.system(size: 8, weight: .heavy, design: .monospaced))
                                    .padding(.horizontal, 4).padding(.vertical, 1)
                                    .background(isSelected ? .white.opacity(0.2) : .primary.opacity(0.08))
                                    .clipShape(Capsule())
                            }
                        }
                        .foregroundStyle(isSelected ? .white : .secondary)
                        .padding(.horizontal, 9).padding(.vertical, 5)
                        .background(isSelected ? option.color.opacity(0.75) : Color(.tertiarySystemGroupedBackground))
                        .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16).padding(.vertical, 8)
        }
        .sensoryFeedback(.selection, trigger: filterOption)
        }
    }

    private var analysisStatsCard: some View {
        let stats = manager.analysisStats
        return VStack(spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "cpu")
                    .font(.subheadline)
                    .foregroundStyle(.indigo)
                Text("Vision AI Analysis")
                    .font(.caption.bold())
                Spacer()
                Button { withAnimation(.snappy) { showStats = false } } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.caption).foregroundStyle(.tertiary)
                }
            }

            HStack(spacing: 6) {
                AIStatPill(value: "\(stats.totalCaptured)", label: "Captured", color: .blue)
                AIStatPill(value: "\(stats.totalAnalyzed)", label: "Analyzed", color: .indigo)
                AIStatPill(value: "\(stats.duplicatesSkipped)", label: "Deduped", color: .purple)
                AIStatPill(value: "\(stats.crucialDetections)", label: "Crucial", color: .yellow)
                AIStatPill(value: "\(stats.smartCrops)", label: "Cropped", color: .green)
            }

            if !stats.outcomeBreakdown.isEmpty {
                HStack(spacing: 4) {
                    ForEach(stats.outcomeBreakdown.sorted(by: { $0.value > $1.value }), id: \.key) { key, value in
                        HStack(spacing: 2) {
                            Circle()
                                .fill(outcomeColor(key))
                                .frame(width: 5, height: 5)
                            Text("\(key):\(value)")
                                .font(.system(size: 8, weight: .medium, design: .monospaced))
                                .foregroundStyle(.secondary)
                        }
                    }
                    Spacer()
                }
            }
        }
        .padding(12)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(.rect(cornerRadius: 12))
        .padding(.horizontal)
        .padding(.top, 4)
    }

    private func outcomeColor(_ key: String) -> Color {
        switch key {
        case "success": .green
        case "permDisabled": .red
        case "tempDisabled": .orange
        case "incorrectPassword": .secondary
        case "smsVerification": .purple
        case "errorBanner": .red
        default: .gray
        }
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "camera.viewfinder")
                .font(.system(size: 48))
                .foregroundStyle(.secondary.opacity(0.4))
                .symbolEffect(.pulse.byLayer, options: .repeating)
            Text("No Screenshots Yet")
                .font(.title3.bold())
            Text("Screenshots are captured automatically\nduring login testing with AI Vision analysis.\nCrucial response text is detected and cropped.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
    }

    private var noMatchesState: some View {
        VStack(spacing: 12) {
            Image(systemName: filterOption.icon)
                .font(.system(size: 36))
                .foregroundStyle(filterOption.color.opacity(0.4))
            Text("No \(filterOption.rawValue) Screenshots")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
    }
}

struct ScreenshotTile: View {
    let screenshot: UnifiedScreenshot

    var body: some View {
        VStack(spacing: 0) {
            Color(.secondarySystemBackground)
                .frame(height: 160)
                .overlay {
                    Image(uiImage: screenshot.displayImage)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .allowsHitTesting(false)
                }
                .clipShape(.rect(cornerRadii: .init(topLeading: 12, topTrailing: 12)))
                .overlay(alignment: .topLeading) {
                    HStack(spacing: 4) {
                        Image(systemName: screenshot.site == "joe" ? "suit.spade.fill" : "flame.fill")
                            .font(.system(size: 8, weight: .bold))
                            .foregroundStyle(screenshot.site == "joe" ? .green : .orange)
                        Text(screenshot.site.uppercased())
                            .font(.system(size: 8, weight: .heavy, design: .monospaced))
                            .foregroundStyle(.white)
                    }
                    .padding(.horizontal, 7).padding(.vertical, 3)
                    .background(.black.opacity(0.65))
                    .clipShape(Capsule())
                    .padding(8)
                }
                .overlay(alignment: .topTrailing) {
                    outcomeBadge.padding(8)
                }
                .overlay(alignment: .bottomLeading) {
                    HStack(spacing: 5) {
                        Image(systemName: screenshot.step.icon)
                            .font(.system(size: 8))
                        Text(screenshot.step.displayName)
                            .font(.system(size: 8, weight: .bold, design: .monospaced))
                        if screenshot.hasCrop {
                            Image(systemName: "crop")
                                .font(.system(size: 7, weight: .bold))
                                .foregroundStyle(.green)
                        }
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 7).padding(.vertical, 3)
                    .background(.black.opacity(0.6))
                    .clipShape(Capsule())
                    .padding(8)
                }

            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(screenshot.credentialEmail)
                        .font(.system(.caption, design: .monospaced, weight: .semibold))
                        .lineLimit(1)
                    Spacer()
                    Text(screenshot.formattedTime)
                        .font(.system(.caption2, design: .monospaced))
                        .foregroundStyle(.tertiary)
                }

                HStack(spacing: 8) {
                    if screenshot.attemptNumber > 0 {
                        HStack(spacing: 2) {
                            Image(systemName: "number").font(.system(size: 8))
                            Text("\(screenshot.attemptNumber)")
                                .font(.system(size: 9, weight: .bold, design: .monospaced))
                        }
                        .foregroundStyle(.secondary)
                    }

                    if screenshot.isCrucial {
                        HStack(spacing: 2) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.system(size: 8))
                            Text("CRUCIAL")
                                .font(.system(size: 8, weight: .heavy, design: .monospaced))
                        }
                        .foregroundStyle(.yellow)
                    }

                    if screenshot.visionConfidence > 0 {
                        HStack(spacing: 2) {
                            Image(systemName: "cpu").font(.system(size: 8))
                            Text("\(Int(screenshot.visionConfidence * 100))%")
                                .font(.system(size: 9, weight: .bold, design: .monospaced))
                        }
                        .foregroundStyle(.indigo)
                    }

                    if screenshot.analysisTimeMs > 0 {
                        Text("\(screenshot.analysisTimeMs)ms")
                            .font(.system(size: 8, weight: .medium, design: .monospaced))
                            .foregroundStyle(.quaternary)
                    }

                    Spacer()
                }

                if !screenshot.crucialKeywords.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 4) {
                            ForEach(screenshot.crucialKeywords, id: \.self) { keyword in
                                Text(keyword)
                                    .font(.system(size: 8, weight: .bold, design: .monospaced))
                                    .foregroundStyle(.white)
                                    .padding(.horizontal, 6).padding(.vertical, 2)
                                    .background(screenshot.outcomeColor.opacity(0.75))
                                    .clipShape(Capsule())
                            }
                        }
                    }
                }
            }
            .padding(10)
        }
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(.rect(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(screenshot.isCrucial ? screenshot.outcomeColor.opacity(0.4) : .clear, lineWidth: 1.5)
        )
    }

    private var outcomeBadge: some View {
        Text(screenshot.outcomeLabel)
            .font(.system(size: 8, weight: .heavy, design: .monospaced))
            .foregroundStyle(.white)
            .padding(.horizontal, 7).padding(.vertical, 3)
            .background(screenshot.outcomeColor.opacity(0.85))
            .clipShape(Capsule())
    }
}

struct ScreenshotDetailSheet: View {
    let screenshot: UnifiedScreenshot
    @Binding var showFullImage: Bool
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    imageSection
                    metadataCard
                    if !screenshot.crucialKeywords.isEmpty {
                        crucialKeywordsCard
                    }
                    if !screenshot.allDetectedText.isEmpty {
                        ocrTextCard
                    }
                }
                .padding()
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Screenshot Detail")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .presentationContentInteraction(.scrolls)
    }

    private var imageSection: some View {
        VStack(spacing: 8) {
            if screenshot.hasCrop {
                Picker("View", selection: $showFullImage) {
                    Text("AI Crop").tag(false)
                    Text("Full Page").tag(true)
                }
                .pickerStyle(.segmented)
            }

            let displayImage = showFullImage ? screenshot.fullImage : screenshot.displayImage
            Image(uiImage: displayImage)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .clipShape(.rect(cornerRadius: 10))
                .shadow(color: .black.opacity(0.25), radius: 10, y: 4)
        }
    }

    private var metadataCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: screenshot.site == "joe" ? "suit.spade.fill" : "flame.fill")
                    .foregroundStyle(screenshot.site == "joe" ? .green : .orange)
                Text(screenshot.site == "joe" ? "JoePoint" : "Ignition Lite")
                    .font(.headline)
                Spacer()
                Text(screenshot.outcomeLabel)
                    .font(.system(.caption2, design: .monospaced, weight: .heavy))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 8).padding(.vertical, 3)
                    .background(screenshot.outcomeColor)
                    .clipShape(Capsule())
            }

            VStack(spacing: 6) {
                metadataRow(icon: "person.fill", label: "Email", value: screenshot.credentialEmail)
                metadataRow(icon: "number", label: "Attempt", value: "\(screenshot.attemptNumber)")
                metadataRow(icon: screenshot.step.icon, label: "Step", value: screenshot.step.displayName)
                metadataRow(icon: "clock", label: "Time", value: screenshot.formattedTime)
                if screenshot.visionConfidence > 0 {
                    metadataRow(icon: "cpu", label: "AI Confidence", value: "\(Int(screenshot.visionConfidence * 100))%")
                }
                if screenshot.analysisTimeMs > 0 {
                    metadataRow(icon: "gauge.with.needle", label: "Analysis Time", value: "\(screenshot.analysisTimeMs)ms")
                }
                if screenshot.hasCrop {
                    metadataRow(icon: "crop", label: "Smart Crop", value: "Active — cropped to response text")
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(.rect(cornerRadius: 12))
    }

    private func metadataRow(icon: String, label: String, value: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 10))
                .foregroundStyle(.secondary)
                .frame(width: 16)
            Text(label)
                .font(.system(.caption, design: .monospaced, weight: .semibold))
                .foregroundStyle(.secondary)
                .frame(width: 90, alignment: .leading)
            Text(value)
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(.primary)
                .lineLimit(1)
            Spacer()
        }
    }

    private var crucialKeywordsCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.yellow)
                Text("Crucial Keywords Detected")
                    .font(.caption.bold())
                Spacer()
            }

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 100))], spacing: 6) {
                ForEach(screenshot.crucialKeywords, id: \.self) { keyword in
                    Text(keyword)
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 8).padding(.vertical, 4)
                        .frame(maxWidth: .infinity)
                        .background(screenshot.outcomeColor.opacity(0.7))
                        .clipShape(.rect(cornerRadius: 6))
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(.rect(cornerRadius: 12))
    }

    private var ocrTextCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "text.magnifyingglass")
                    .foregroundStyle(.indigo)
                Text("Full OCR Text")
                    .font(.caption.bold())
                Spacer()
                Button {
                    UIPasteboard.general.string = screenshot.allDetectedText
                } label: {
                    Image(systemName: "doc.on.doc")
                        .font(.caption)
                        .foregroundStyle(.blue)
                }
            }

            Text(screenshot.allDetectedText)
                .font(.system(size: 10, design: .monospaced))
                .foregroundStyle(.secondary)
                .lineLimit(20)
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(.rect(cornerRadius: 12))
    }
}

struct AIStatPill: View {
    let value: String
    let label: String
    let color: Color

    var body: some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.system(.caption, design: .monospaced, weight: .bold))
                .foregroundStyle(color)
            Text(label)
                .font(.system(size: 7, weight: .medium))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 6)
        .background(color.opacity(0.08))
        .clipShape(.rect(cornerRadius: 6))
    }
}

// MARK: - Album Model

struct ScreenshotAlbum: Identifiable {
    let id: String
    let cardDisplayNumber: String
    let cardId: String
    let screenshots: [CapturedScreenshot]
    let title: String
    let latestTimestamp: Date

    var successCount: Int { screenshots.filter { $0.effectiveResult == .success }.count }
    var noAccCount: Int { screenshots.filter { $0.effectiveResult == .noAcc }.count }
    var unsureCount: Int { screenshots.filter { $0.effectiveResult == .unsure }.count }
    var overallResult: UserResultOverride {
        if successCount > 0 { return .success }
        if noAccCount > 0 { return .noAcc }
        if unsureCount > 0 { return .unsure }
        return screenshots.first?.effectiveResult ?? .none
    }
}

// MARK: - Album Card View

struct AlbumCardView: View {
    let album: ScreenshotAlbum

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(album.title)
                    .font(.system(.subheadline, design: .monospaced, weight: .bold))
                    .lineLimit(1)
                Spacer()
                Text("\(album.screenshots.count)")
                    .font(.system(.caption2, design: .monospaced, weight: .heavy))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 6).padding(.vertical, 2)
                    .background(album.overallResult.color.opacity(0.75))
                    .clipShape(Capsule())
            }

            if let first = album.screenshots.first {
                Color(.secondarySystemBackground)
                    .frame(height: 100)
                    .overlay {
                        Image(uiImage: first.displayImage)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .allowsHitTesting(false)
                    }
                    .clipShape(.rect(cornerRadius: 8))
            }

            HStack(spacing: 8) {
                if album.successCount > 0 {
                    Label("\(album.successCount)", systemImage: "checkmark.circle.fill")
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundStyle(.green)
                }
                if album.noAccCount > 0 {
                    Label("\(album.noAccCount)", systemImage: "xmark.circle.fill")
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundStyle(.red)
                }
                Spacer()
                Text(album.latestTimestamp, style: .time)
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(12)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(.rect(cornerRadius: 12))
    }
}

// MARK: - Album Detail Sheet

struct AlbumDetailSheet: View {
    let album: ScreenshotAlbum
    let manager: UnifiedScreenshotManager
    @Environment(\.dismiss) private var dismiss
    @State private var showFlipbook: Bool = false

    var body: some View {
        List {
            Section {
                HStack {
                    Text(album.title).font(.headline)
                    Spacer()
                    Text("\(album.screenshots.count) screenshots")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }

            Section("Screenshots") {
                ForEach(album.screenshots) { screenshot in
                    HStack(spacing: 10) {
                        Color.clear
                            .frame(width: 50, height: 36)
                            .overlay {
                                Image(uiImage: screenshot.displayImage)
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                                    .allowsHitTesting(false)
                            }
                            .clipShape(.rect(cornerRadius: 4))

                        VStack(alignment: .leading, spacing: 2) {
                            Text(screenshot.stepName.replacingOccurrences(of: "_", with: " ").uppercased())
                                .font(.system(size: 10, weight: .bold, design: .monospaced))
                            Text(screenshot.formattedTime)
                                .font(.system(size: 9, design: .monospaced))
                                .foregroundStyle(.tertiary)
                        }
                        Spacer()
                        Text(screenshot.effectiveResult.displayLabel)
                            .font(.system(size: 9, weight: .bold, design: .monospaced))
                            .foregroundStyle(screenshot.effectiveResult.color)
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle(album.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Done") { dismiss() }
            }
            ToolbarItem(placement: .topBarLeading) {
                Button {
                    showFlipbook = true
                } label: {
                    Image(systemName: "book.pages")
                }
            }
        }
        .fullScreenCover(isPresented: $showFlipbook) {
            ScreenshotFlipbookView(screenshots: album.screenshots, startIndex: 0)
        }
    }
}

// MARK: - Correction Sheet

struct ScreenshotCorrectionSheet: View {
    let screenshot: CapturedScreenshot
    let manager: UnifiedScreenshotManager
    @Environment(\.dismiss) private var dismiss
    @State private var editingNote: String = ""

    var body: some View {
        List {
            Section("Current Result") {
                HStack {
                    Label(screenshot.outcomeLabel, systemImage: screenshot.effectiveResult.icon)
                        .foregroundStyle(screenshot.outcomeColor)
                    Spacer()
                    if screenshot.hasUserOverride {
                        Text("User Override")
                            .font(.caption2)
                            .foregroundStyle(.purple)
                    }
                }
            }

            Section("Override Result") {
                ForEach(UserResultOverride.overrideable, id: \.rawValue) { override_ in
                    Button {
                        manager.correctResult(for: screenshot, override: override_)
                        dismiss()
                    } label: {
                        Label(override_.displayLabel, systemImage: override_.icon)
                            .foregroundStyle(override_.color)
                    }
                }
            }

            if screenshot.hasUserOverride {
                Section {
                    Button(role: .destructive) {
                        manager.resetScreenshotOverride(screenshot)
                        dismiss()
                    } label: {
                        Label("Reset to Auto", systemImage: "arrow.uturn.backward")
                    }
                }
            }

            Section("Note") {
                TextField("Add a note...", text: $editingNote, axis: .vertical)
                    .lineLimit(3)
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Override Result")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Done") {
                    screenshot.userNote = editingNote
                    dismiss()
                }
            }
        }
        .onAppear { editingNote = screenshot.userNote }
    }
}
