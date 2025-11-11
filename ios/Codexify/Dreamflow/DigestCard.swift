//
//  DigestCard.swift
//  Codexify
//
//  Created by Codexify:Scout
//  Phase Two: Dreamflow Runtime - Interactive Compact Digest Card
//
//  A compact, interactive variant of DigestView for widgets and quick summaries
//

import SwiftUI

#if canImport(UIKit)
import UIKit
#endif

// MARK: - Digest Card

/// Compact, interactive digest card for widgets and notifications
struct DigestCard: View {

    // MARK: - Properties

    let digest: MorningDigest
    let maxInsightsCollapsed: Int
    let onOpenFullView: ((MorningDigest) -> Void)?

    @State private var isExpanded: Bool = false
    @Namespace private var animation

    // MARK: - Initialization

    /// Initialize DigestCard
    /// - Parameters:
    ///   - digest: The MorningDigest to display
    ///   - maxInsightsCollapsed: Max insights to show when collapsed (default: 1)
    ///   - onOpenFullView: Optional handler for opening full view
    init(
        digest: MorningDigest,
        maxInsightsCollapsed: Int = 1,
        onOpenFullView: ((MorningDigest) -> Void)? = nil
    ) {
        self.digest = digest
        self.maxInsightsCollapsed = maxInsightsCollapsed
        self.onOpenFullView = onOpenFullView
    }

    // MARK: - Body

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header section (always visible)
            headerSection

            // Expandable content
            if isExpanded {
                expandedContent
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(Spacing.md)
        .background(ColorTokens.surface)
        .cornerRadius(CornerRadius.md)
        .shadow(
            color: Shadows.sm.color,
            radius: Shadows.sm.radius,
            x: Shadows.sm.x,
            y: Shadows.sm.y
        )
        .overlay(
            RoundedRectangle(cornerRadius: CornerRadius.md)
                .stroke(ColorTokens.brandPrimary.opacity(0.2), lineWidth: 1)
        )
        .onTapGesture {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                isExpanded.toggle()
                performHaptic(.medium)
            }
        }
        .contextMenu {
            contextMenuContent
        }
    }

    // MARK: - Header Section

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            // Headline + mood icon
            HStack(alignment: .top, spacing: Spacing.sm) {
                // Mood/emoji indicator
                Text(moodEmoji)
                    .font(.system(size: FontSize.xl))
                    .matchedGeometryEffect(id: "emoji", in: animation)

                VStack(alignment: .leading, spacing: Spacing.xs) {
                    // Headline
                    Text(digest.headline)
                        .font(TextStyle.bodyEmphasis)
                        .foregroundColor(ColorTokens.brandPrimary)
                        .lineLimit(isExpanded ? nil : 2)
                        .matchedGeometryEffect(id: "headline", in: animation)

                    // Date
                    Text(formatRelativeDate(digest.date))
                        .font(TextStyle.caption)
                        .foregroundColor(ColorTokens.textTertiary)
                }

                Spacer()

                // Expand/collapse indicator
                Image(systemName: isExpanded ? "chevron.up.circle.fill" : "chevron.down.circle")
                    .font(.system(size: FontSize.md))
                    .foregroundColor(ColorTokens.brandPrimary.opacity(0.6))
                    .rotationEffect(.degrees(isExpanded ? 180 : 0))
                    .animation(.spring(response: 0.3), value: isExpanded)
            }

            // Collapsed insights preview
            if !isExpanded && !digest.keyInsights.isEmpty {
                insightsPreview
            }
        }
    }

    // MARK: - Insights Preview (Collapsed)

    private var insightsPreview: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            ForEach(Array(digest.keyInsights.prefix(maxInsightsCollapsed).enumerated()), id: \.offset) { _, insight in
                HStack(alignment: .top, spacing: Spacing.xs) {
                    Circle()
                        .fill(ColorTokens.brandPrimary)
                        .frame(width: 4, height: 4)
                        .padding(.top, 5)

                    Text(insight)
                        .font(TextStyle.caption)
                        .foregroundColor(ColorTokens.textSecondary)
                        .lineLimit(2)
                }
            }
        }
        .padding(.top, Spacing.xs)
    }

    // MARK: - Expanded Content

    private var expandedContent: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            Divider()
                .padding(.vertical, Spacing.xs)

            // All insights
            if !digest.keyInsights.isEmpty {
                insightsSection
            }

            // Mood trend
            if let mood = digest.moodTrend {
                moodSection(mood: mood)
            }

            // Action items
            if !digest.actionableItems.isEmpty {
                actionItemsSection
            }

            // Weekly patterns
            if let patterns = digest.weeklyPatterns, !patterns.isEmpty {
                patternsSection(patterns: patterns)
            }

            // Footer
            footerSection
        }
    }

    // MARK: - Insights Section (Expanded)

    private var insightsSection: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            sectionLabel(icon: "lightbulb.fill", title: "Insights", color: ColorTokens.brandPrimary)

            ForEach(Array(digest.keyInsights.enumerated()), id: \.offset) { index, insight in
                HStack(alignment: .top, spacing: Spacing.xs) {
                    Circle()
                        .fill(ColorTokens.brandPrimary)
                        .frame(width: 5, height: 5)
                        .padding(.top, 5)

                    Text(insight)
                        .font(TextStyle.caption)
                        .foregroundColor(ColorTokens.textSecondary)
                }
                .transition(.opacity.combined(with: .move(edge: .leading)))
                .animation(.spring(response: 0.3).delay(Double(index) * 0.03), value: isExpanded)
            }
        }
    }

    // MARK: - Mood Section

    private func moodSection(mood: String) -> some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            sectionLabel(icon: "heart.fill", title: "Mood", color: ColorTokens.brandSecondary)

            HStack(spacing: Spacing.xs) {
                Circle()
                    .fill(moodColor(for: mood))
                    .frame(width: 8, height: 8)

                Text(mood)
                    .font(TextStyle.caption)
                    .foregroundColor(ColorTokens.textSecondary)
                    .italic()
                    .lineLimit(2)
            }
        }
    }

    // MARK: - Action Items Section

    private var actionItemsSection: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            sectionLabel(icon: "checkmark.circle.fill", title: "Actions", color: ColorTokens.success)

            ForEach(Array(digest.actionableItems.enumerated()), id: \.offset) { index, item in
                HStack(alignment: .top, spacing: Spacing.xs) {
                    Text("✓")
                        .font(.system(size: FontSize.sm))
                        .foregroundColor(ColorTokens.success)

                    Text(item)
                        .font(TextStyle.caption)
                        .foregroundColor(ColorTokens.textSecondary)
                        .lineLimit(3)
                }
                .transition(.opacity.combined(with: .move(edge: .leading)))
                .animation(.spring(response: 0.3).delay(Double(index) * 0.03), value: isExpanded)
            }
        }
    }

    // MARK: - Patterns Section

    private func patternsSection(patterns: [String]) -> some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            sectionLabel(icon: "waveform.path.ecg", title: "Patterns", color: ColorTokens.warning)

            ForEach(Array(patterns.enumerated()), id: \.offset) { index, pattern in
                HStack(alignment: .top, spacing: Spacing.xs) {
                    Text("⚡")
                        .font(.system(size: FontSize.sm))

                    Text(pattern)
                        .font(TextStyle.caption)
                        .foregroundColor(ColorTokens.textTertiary)
                        .lineLimit(2)
                }
                .transition(.opacity)
                .animation(.spring(response: 0.3).delay(Double(index) * 0.03), value: isExpanded)
            }
        }
    }

    // MARK: - Footer Section

    private var footerSection: some View {
        HStack(spacing: Spacing.xs) {
            Image(systemName: "moon.stars.fill")
                .font(.system(size: FontSize.xs))
                .foregroundColor(ColorTokens.textTertiary)

            Text("\(digest.generatedFrom.count) reflection\(digest.generatedFrom.count == 1 ? "" : "s")")
                .font(TextStyle.caption)
                .foregroundColor(ColorTokens.textTertiary)

            Spacer()
        }
        .padding(.top, Spacing.xs)
    }

    // MARK: - Section Label

    private func sectionLabel(icon: String, title: String, color: Color) -> some View {
        HStack(spacing: Spacing.xs) {
            Image(systemName: icon)
                .font(.system(size: FontSize.sm))
                .foregroundColor(color)

            Text(title)
                .font(TextStyle.caption)
                .foregroundColor(ColorTokens.textPrimary)
                .fontWeight(.semibold)
        }
    }

    // MARK: - Context Menu

    private var contextMenuContent: some View {
        Group {
            Button(action: {
                shareDigest(digest)
            }) {
                Label("Share Digest", systemImage: "square.and.arrow.up")
            }

            Button(action: {
                copyToClipboard(digest.asPlainText())
            }) {
                Label("Copy Summary", systemImage: "doc.on.doc")
            }

            Divider()

            Button(action: {
                openFullView(digest)
            }) {
                Label("View Full", systemImage: "arrow.up.left.and.arrow.down.right")
            }
        }
    }

    // MARK: - Helper Methods

    private var moodEmoji: String {
        if let mood = digest.moodTrend {
            let moodLower = mood.lowercased()

            if moodLower.contains("positive") || moodLower.contains("up") || moodLower.contains("happy") {
                return "😊"
            } else if moodLower.contains("negative") || moodLower.contains("down") || moodLower.contains("sad") {
                return "😔"
            } else if moodLower.contains("calm") || moodLower.contains("peaceful") {
                return "😌"
            } else if moodLower.contains("energized") || moodLower.contains("excited") {
                return "⚡"
            } else if moodLower.contains("balanced") || moodLower.contains("stable") {
                return "⚖️"
            }
        }

        return "☀️" // Default morning emoji
    }

    private func moodColor(for mood: String) -> Color {
        let moodLower = mood.lowercased()

        if moodLower.contains("positive") || moodLower.contains("up") || moodLower.contains("improving") {
            return ColorTokens.success
        } else if moodLower.contains("negative") || moodLower.contains("down") || moodLower.contains("declining") {
            return ColorTokens.error
        } else if moodLower.contains("balanced") || moodLower.contains("stable") || moodLower.contains("steady") {
            return ColorTokens.brandSecondary
        } else {
            return ColorTokens.textSecondary
        }
    }

    private func formatRelativeDate(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }

    private func performHaptic(_ style: UIImpactFeedbackGenerator.FeedbackStyle) {
        #if canImport(UIKit)
        let generator = UIImpactFeedbackGenerator(style: style)
        generator.impactOccurred()
        #endif
    }

    // MARK: - Action Handlers

    private func shareDigest(_ digest: MorningDigest) {
        performHaptic(.light)

        #if canImport(UIKit)
        let activityVC = UIActivityViewController(
            activityItems: [digest.asPlainText()],
            applicationActivities: nil
        )

        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let rootVC = windowScene.windows.first?.rootViewController {
            rootVC.present(activityVC, animated: true)
        }
        #endif

        print("📤 [DigestCard] Shared digest: \(digest.headline)")
    }

    private func copyToClipboard(_ text: String) {
        performHaptic(.light)

        #if canImport(UIKit)
        UIPasteboard.general.string = text
        #endif

        print("📋 [DigestCard] Copied to clipboard")
    }

    private func openFullView(_ digest: MorningDigest) {
        performHaptic(.medium)

        if let handler = onOpenFullView {
            handler(digest)
        } else {
            print("🔍 [DigestCard] Open full view: \(digest.headline)")
            // Default behavior: no-op (caller should provide handler)
        }
    }
}

// MARK: - Widget Variant

/// Ultra-compact variant optimized for widgets
struct DigestCardWidget: View {
    let digest: MorningDigest

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            // Emoji + headline
            HStack(spacing: Spacing.xs) {
                Text(moodEmoji)
                    .font(.system(size: FontSize.md))

                Text(digest.headline)
                    .font(TextStyle.caption)
                    .foregroundColor(ColorTokens.textPrimary)
                    .fontWeight(.semibold)
                    .lineLimit(2)
            }

            // First insight
            if let firstInsight = digest.keyInsights.first {
                HStack(alignment: .top, spacing: 4) {
                    Circle()
                        .fill(ColorTokens.brandPrimary)
                        .frame(width: 3, height: 3)
                        .padding(.top, 4)

                    Text(firstInsight)
                        .font(.system(size: FontSize.xs))
                        .foregroundColor(ColorTokens.textSecondary)
                        .lineLimit(2)
                }
            }

            Spacer()

            // Footer
            HStack {
                Text("\(digest.generatedFrom.count) reflections")
                    .font(.system(size: FontSize.xs))
                    .foregroundColor(ColorTokens.textTertiary)

                Spacer()

                Text(formatRelativeDate(digest.date))
                    .font(.system(size: FontSize.xs))
                    .foregroundColor(ColorTokens.textTertiary)
            }
        }
        .padding(Spacing.sm)
        .background(ColorTokens.surface)
        .cornerRadius(CornerRadius.sm)
    }

    private var moodEmoji: String {
        if let mood = digest.moodTrend {
            let moodLower = mood.lowercased()

            if moodLower.contains("positive") || moodLower.contains("up") {
                return "😊"
            } else if moodLower.contains("negative") || moodLower.contains("down") {
                return "😔"
            } else if moodLower.contains("calm") {
                return "😌"
            } else if moodLower.contains("energized") {
                return "⚡"
            }
        }

        return "☀️"
    }

    private func formatRelativeDate(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

// MARK: - Grid Layout Example

/// Example grid layout showing multiple digest cards
struct DigestCardGrid: View {
    let digests: [MorningDigest]

    var body: some View {
        ScrollView {
            LazyVGrid(
                columns: [
                    GridItem(.flexible(), spacing: Spacing.md),
                    GridItem(.flexible(), spacing: Spacing.md)
                ],
                spacing: Spacing.md
            ) {
                ForEach(digests) { digest in
                    DigestCard(digest: digest) { selectedDigest in
                        print("📖 [Grid] Opening full view for: \(selectedDigest.headline)")
                    }
                }
            }
            .padding(Spacing.md)
        }
        .background(ColorTokens.background)
    }
}

// MARK: - Previews

#if DEBUG
struct DigestCard_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            // Collapsed state - Light mode
            DigestCard(digest: sampleDigest)
                .padding()
                .background(ColorTokens.background)
                .preferredColorScheme(.light)
                .previewDisplayName("Collapsed - Light")
                .previewLayout(.sizeThatFits)

            // Collapsed state - Dark mode
            DigestCard(digest: sampleDigest)
                .padding()
                .background(ColorTokens.background)
                .preferredColorScheme(.dark)
                .previewDisplayName("Collapsed - Dark")
                .previewLayout(.sizeThatFits)

            // Expanded state
            DigestCard(digest: sampleDigest)
                .padding()
                .background(ColorTokens.background)
                .preferredColorScheme(.light)
                .previewDisplayName("Expanded")
                .previewLayout(.sizeThatFits)
                .onAppear {
                    // Simulate expanded state in preview
                }

            // Widget variant
            DigestCardWidget(digest: sampleDigest)
                .frame(width: 169, height: 169)
                .background(ColorTokens.background)
                .preferredColorScheme(.light)
                .previewDisplayName("Widget (169x169)")

            // Grid layout
            DigestCardGrid(digests: [sampleDigest, sampleDigest2, sampleDigest3])
                .preferredColorScheme(.light)
                .previewDisplayName("Grid Layout")

            // Minimal data
            DigestCard(digest: minimalDigest)
                .padding()
                .background(ColorTokens.background)
                .preferredColorScheme(.light)
                .previewDisplayName("Minimal Data")
                .previewLayout(.sizeThatFits)
        }
    }

    static var sampleDigest: MorningDigest {
        MorningDigest(
            date: Date(),
            headline: "A productive week of deep work",
            keyInsights: [
                "Focused heavily on Swift development",
                "Maintained consistent reflection patterns",
                "Balanced technical and creative work"
            ],
            moodTrend: "trending positive and stable",
            actionableItems: [
                "Continue SwiftUI exploration",
                "Schedule deep work sessions"
            ],
            weeklyPatterns: [
                "Productivity peaks mid-week",
                "Morning routine established"
            ],
            generatedFrom: Array(repeating: UUID(), count: 7)
        )
    }

    static var sampleDigest2: MorningDigest {
        MorningDigest(
            date: Date().addingTimeInterval(-86400),
            headline: "Energized and creative flow",
            keyInsights: [
                "High energy throughout the day",
                "Creative breakthroughs in design"
            ],
            moodTrend: "energized and excited",
            actionableItems: [
                "Capture design ideas in Figma"
            ],
            weeklyPatterns: nil,
            generatedFrom: Array(repeating: UUID(), count: 3)
        )
    }

    static var sampleDigest3: MorningDigest {
        MorningDigest(
            date: Date().addingTimeInterval(-172800),
            headline: "Calm and balanced day",
            keyInsights: [
                "Peaceful morning meditation",
                "Steady progress on projects"
            ],
            moodTrend: "calm and balanced",
            actionableItems: [
                "Continue mindfulness practice"
            ],
            weeklyPatterns: nil,
            generatedFrom: Array(repeating: UUID(), count: 5)
        )
    }

    static var minimalDigest: MorningDigest {
        MorningDigest(
            date: Date(),
            headline: "Quiet day",
            keyInsights: [
                "No tracked activity"
            ],
            moodTrend: nil,
            actionableItems: [],
            weeklyPatterns: nil,
            generatedFrom: []
        )
    }
}
#endif
