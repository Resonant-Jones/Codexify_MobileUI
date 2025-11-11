//
//  DigestView.swift
//  Codexify
//
//  Created by Codexify:Scout
//  Phase Two: Dreamflow Runtime - Morning Digest UI Component
//
//  A SwiftUI component for rendering MorningDigest as a dashboard card
//

import SwiftUI

#if canImport(UIKit)
import UIKit
#endif

// MARK: - Digest View

/// Production-ready SwiftUI component for displaying MorningDigest
struct DigestView: View {

    // MARK: - Properties

    let digest: MorningDigest
    let showFullContent: Bool
    let onTap: (() -> Void)?
    let onShare: (() -> Void)?

    @State private var isExpanded: Bool = false
    @State private var showShareSheet: Bool = false
    @Namespace private var animation

    // MARK: - Initialization

    /// Initialize DigestView
    /// - Parameters:
    ///   - digest: The MorningDigest to display
    ///   - showFullContent: Whether to show full content initially (default: true)
    ///   - onTap: Optional tap handler
    ///   - onShare: Optional share handler
    init(
        digest: MorningDigest,
        showFullContent: Bool = true,
        onTap: (() -> Void)? = nil,
        onShare: (() -> Void)? = nil
    ) {
        self.digest = digest
        self.showFullContent = showFullContent
        self.onTap = onTap
        self.onShare = onShare
    }

    // MARK: - Body

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            headerSection

            Divider()
                .padding(.horizontal, Spacing.lg)
                .padding(.vertical, Spacing.sm)

            // Content
            if showFullContent || isExpanded {
                contentSection
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
            } else {
                collapsedContentSection
                    .transition(.opacity)
            }
        }
        .background(ColorTokens.surface)
        .cornerRadius(CornerRadius.lg)
        .shadow(
            color: Shadows.md.color,
            radius: Shadows.md.radius,
            x: Shadows.md.x,
            y: Shadows.md.y
        )
        .onTapGesture {
            if !showFullContent {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    isExpanded.toggle()
                    performHaptic(.light)
                }
            }
            onTap?()
        }
        .contextMenu {
            contextMenuContent
        }
    }

    // MARK: - Header Section

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            // Emoji + Headline
            HStack(alignment: .top, spacing: Spacing.md) {
                Text("☀️")
                    .font(.system(size: FontSize.xxl))
                    .matchedGeometryEffect(id: "emoji", in: animation)

                VStack(alignment: .leading, spacing: Spacing.xs) {
                    Text(digest.headline)
                        .font(TextStyle.h3)
                        .foregroundColor(ColorTokens.textPrimary)
                        .lineLimit(showFullContent || isExpanded ? nil : 2)
                        .matchedGeometryEffect(id: "headline", in: animation)

                    Text(formatDate(digest.date))
                        .font(TextStyle.caption)
                        .foregroundColor(ColorTokens.textTertiary)
                }

                Spacer()

                // Share button
                Button(action: handleShare) {
                    Image(systemName: "square.and.arrow.up")
                        .font(.system(size: FontSize.md))
                        .foregroundColor(ColorTokens.textSecondary)
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .padding(Spacing.lg)
    }

    // MARK: - Content Section

    private var contentSection: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.lg) {
                // Key Insights
                if !digest.keyInsights.isEmpty {
                    insightsSection
                }

                // Mood Trend
                if let mood = digest.moodTrend {
                    moodSection(mood: mood)
                }

                // Action Items
                if !digest.actionableItems.isEmpty {
                    actionItemsSection
                }

                // Weekly Patterns
                if let patterns = digest.weeklyPatterns, !patterns.isEmpty {
                    patternsSection(patterns: patterns)
                }

                // Footer metadata
                footerSection
            }
            .padding(Spacing.lg)
        }
    }

    // MARK: - Collapsed Content Section

    private var collapsedContentSection: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            // Show first insight only
            if let firstInsight = digest.keyInsights.first {
                HStack(alignment: .top, spacing: Spacing.sm) {
                    Text("•")
                        .foregroundColor(ColorTokens.brandPrimary)
                        .font(TextStyle.body)
                    Text(firstInsight)
                        .font(TextStyle.body)
                        .foregroundColor(ColorTokens.textSecondary)
                        .lineLimit(2)
                }
            }

            // Expand indicator
            HStack {
                Spacer()
                Text("Tap to expand")
                    .font(TextStyle.caption)
                    .foregroundColor(ColorTokens.textTertiary)
                Image(systemName: "chevron.down")
                    .font(.system(size: FontSize.sm))
                    .foregroundColor(ColorTokens.textTertiary)
                Spacer()
            }
            .padding(.top, Spacing.xs)
        }
        .padding(Spacing.lg)
    }

    // MARK: - Insights Section

    private var insightsSection: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            sectionHeader(
                icon: "lightbulb.fill",
                title: "Key Insights",
                color: ColorTokens.brandPrimary
            )

            ForEach(Array(digest.keyInsights.enumerated()), id: \.offset) { index, insight in
                HStack(alignment: .top, spacing: Spacing.sm) {
                    Circle()
                        .fill(ColorTokens.brandPrimary)
                        .frame(width: 6, height: 6)
                        .padding(.top, 6)

                    Text(insight)
                        .font(TextStyle.body)
                        .foregroundColor(ColorTokens.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .transition(.opacity.combined(with: .move(edge: .leading)))
                .animation(.spring(response: 0.3, dampingFraction: 0.7).delay(Double(index) * 0.05), value: isExpanded)
            }
        }
    }

    // MARK: - Mood Section

    private func moodSection(mood: String) -> some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            sectionHeader(
                icon: "heart.fill",
                title: "Mood Trend",
                color: ColorTokens.brandSecondary
            )

            HStack(spacing: Spacing.md) {
                // Mood indicator
                Circle()
                    .fill(moodColor(for: mood))
                    .frame(width: 12, height: 12)

                Text(mood)
                    .font(TextStyle.body)
                    .foregroundColor(ColorTokens.textSecondary)
                    .italic()
            }
            .padding(.vertical, Spacing.xs)
            .padding(.horizontal, Spacing.md)
            .background(ColorTokens.surfaceHover.opacity(0.5))
            .cornerRadius(CornerRadius.md)
        }
    }

    // MARK: - Action Items Section

    private var actionItemsSection: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            sectionHeader(
                icon: "checkmark.circle.fill",
                title: "Action Items",
                color: ColorTokens.success
            )

            ForEach(Array(digest.actionableItems.enumerated()), id: \.offset) { index, item in
                HStack(alignment: .top, spacing: Spacing.sm) {
                    Image(systemName: "arrow.right.circle")
                        .font(.system(size: FontSize.md))
                        .foregroundColor(ColorTokens.success)

                    Text(item)
                        .font(TextStyle.body)
                        .foregroundColor(ColorTokens.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .transition(.opacity.combined(with: .move(edge: .leading)))
                .animation(.spring(response: 0.3, dampingFraction: 0.7).delay(Double(index) * 0.05), value: isExpanded)
            }
        }
    }

    // MARK: - Patterns Section

    private func patternsSection(patterns: [String]) -> some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            sectionHeader(
                icon: "waveform.path.ecg",
                title: "Weekly Patterns",
                color: ColorTokens.warning
            )

            ForEach(Array(patterns.enumerated()), id: \.offset) { index, pattern in
                HStack(alignment: .top, spacing: Spacing.sm) {
                    Text("⚡")
                        .font(.system(size: FontSize.md))

                    Text(pattern)
                        .font(TextStyle.caption)
                        .foregroundColor(ColorTokens.textTertiary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .transition(.opacity.combined(with: .move(edge: .leading)))
                .animation(.spring(response: 0.3, dampingFraction: 0.7).delay(Double(index) * 0.05), value: isExpanded)
            }
        }
    }

    // MARK: - Footer Section

    private var footerSection: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            Divider()

            HStack(spacing: Spacing.sm) {
                Image(systemName: "clock")
                    .font(.system(size: FontSize.sm))
                    .foregroundColor(ColorTokens.textTertiary)

                Text("Generated from \(digest.generatedFrom.count) reflection\(digest.generatedFrom.count == 1 ? "" : "s")")
                    .font(TextStyle.caption)
                    .foregroundColor(ColorTokens.textTertiary)

                Spacer()
            }
        }
    }

    // MARK: - Section Header

    private func sectionHeader(icon: String, title: String, color: Color) -> some View {
        HStack(spacing: Spacing.sm) {
            Image(systemName: icon)
                .font(.system(size: FontSize.md))
                .foregroundColor(color)

            Text(title)
                .font(TextStyle.bodyEmphasis)
                .foregroundColor(ColorTokens.textPrimary)
        }
        .padding(.bottom, Spacing.xs)
    }

    // MARK: - Context Menu

    private var contextMenuContent: some View {
        Group {
            Button(action: handleShare) {
                Label("Share Digest", systemImage: "square.and.arrow.up")
            }

            Button(action: handleCopy) {
                Label("Copy as Text", systemImage: "doc.on.doc")
            }

            Button(action: handleCopyMarkdown) {
                Label("Copy as Markdown", systemImage: "doc.text")
            }

            Divider()

            Button(action: {}) {
                Label("View Details", systemImage: "info.circle")
            }
        }
    }

    // MARK: - Helper Methods

    private func formatDate(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        return formatter.localizedString(for: date, relativeTo: Date())
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

    private func handleShare() {
        performHaptic(.medium)
        showShareSheet = true

        #if canImport(UIKit)
        // Present share sheet
        let activityVC = UIActivityViewController(
            activityItems: [digest.asPlainText()],
            applicationActivities: nil
        )

        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let rootVC = windowScene.windows.first?.rootViewController {
            rootVC.present(activityVC, animated: true)
        }
        #endif

        onShare?()
    }

    private func handleCopy() {
        performHaptic(.light)

        #if canImport(UIKit)
        UIPasteboard.general.string = digest.asPlainText()
        #endif

        print("📋 [DigestView] Copied digest as plain text")
    }

    private func handleCopyMarkdown() {
        performHaptic(.light)

        #if canImport(UIKit)
        UIPasteboard.general.string = digest.asMarkdown()
        #endif

        print("📋 [DigestView] Copied digest as markdown")
    }

    private func performHaptic(_ style: UIImpactFeedbackGenerator.FeedbackStyle) {
        #if canImport(UIKit)
        let generator = UIImpactFeedbackGenerator(style: style)
        generator.impactOccurred()
        #endif
    }
}

// MARK: - Compact Variant

/// Compact version of DigestView for widgets and small spaces
struct DigestViewCompact: View {
    let digest: MorningDigest

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            // Header
            HStack(spacing: Spacing.sm) {
                Text("☀️")
                    .font(.system(size: FontSize.lg))

                Text(digest.headline)
                    .font(TextStyle.bodyEmphasis)
                    .foregroundColor(ColorTokens.textPrimary)
                    .lineLimit(2)
            }

            // First insight
            if let firstInsight = digest.keyInsights.first {
                HStack(alignment: .top, spacing: Spacing.xs) {
                    Circle()
                        .fill(ColorTokens.brandPrimary)
                        .frame(width: 4, height: 4)
                        .padding(.top, 4)

                    Text(firstInsight)
                        .font(TextStyle.caption)
                        .foregroundColor(ColorTokens.textSecondary)
                        .lineLimit(2)
                }
            }

            // Mood if available
            if let mood = digest.moodTrend {
                HStack(spacing: Spacing.xs) {
                    Image(systemName: "heart.fill")
                        .font(.system(size: FontSize.sm))
                        .foregroundColor(ColorTokens.brandSecondary)

                    Text(mood)
                        .font(TextStyle.caption)
                        .foregroundColor(ColorTokens.textTertiary)
                        .lineLimit(1)
                }
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
    }
}

// MARK: - Dashboard Integration Example

/// Example dashboard view showing DigestView integration
struct DashboardView: View {
    @State private var digest: MorningDigest?
    @State private var isLoading: Bool = true

    var body: some View {
        ScrollView {
            VStack(spacing: Spacing.lg) {
                // Header
                HStack {
                    Text("Morning Digest")
                        .font(TextStyle.h2)
                        .foregroundColor(ColorTokens.textPrimary)

                    Spacer()

                    Button(action: refreshDigest) {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: FontSize.md))
                            .foregroundColor(ColorTokens.brandPrimary)
                    }
                }
                .padding(.horizontal, Spacing.lg)
                .padding(.top, Spacing.xl)

                // Digest content
                if isLoading {
                    ProgressView("Loading digest...")
                        .padding(.vertical, Spacing.xxl)
                } else if let digest = digest {
                    DigestView(
                        digest: digest,
                        onTap: {
                            print("📊 [Dashboard] Digest tapped")
                        },
                        onShare: {
                            print("📤 [Dashboard] Digest shared")
                        }
                    )
                    .padding(.horizontal, Spacing.lg)
                } else {
                    emptyStateView
                }

                Spacer()
            }
        }
        .background(ColorTokens.background)
        .onAppear {
            loadDigest()
        }
    }

    private var emptyStateView: some View {
        VStack(spacing: Spacing.md) {
            Image(systemName: "moon.zzz")
                .font(.system(size: 48))
                .foregroundColor(ColorTokens.textTertiary)

            Text("No digest available")
                .font(TextStyle.h3)
                .foregroundColor(ColorTokens.textPrimary)

            Text("Run Dreamflow tonight to generate insights")
                .font(TextStyle.body)
                .foregroundColor(ColorTokens.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, Spacing.xl)
        }
        .padding(.vertical, Spacing.xxl)
    }

    private func loadDigest() {
        // Simulate async loading
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            withAnimation {
                isLoading = false
                // digest = ... (load from storage)
            }
        }
    }

    private func refreshDigest() {
        withAnimation {
            isLoading = true
        }
        loadDigest()
    }
}

// MARK: - Previews

#if DEBUG
struct DigestView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            // Full view - Light mode
            DigestView(digest: sampleDigest)
                .padding()
                .background(ColorTokens.background)
                .preferredColorScheme(.light)
                .previewDisplayName("Full - Light Mode")

            // Full view - Dark mode
            DigestView(digest: sampleDigest)
                .padding()
                .background(ColorTokens.background)
                .preferredColorScheme(.dark)
                .previewDisplayName("Full - Dark Mode")

            // Compact view
            DigestViewCompact(digest: sampleDigest)
                .padding()
                .background(ColorTokens.background)
                .preferredColorScheme(.light)
                .previewDisplayName("Compact")

            // Collapsed view
            DigestView(digest: sampleDigest, showFullContent: false)
                .padding()
                .background(ColorTokens.background)
                .preferredColorScheme(.light)
                .previewDisplayName("Collapsed")

            // Dashboard integration
            DashboardView()
                .preferredColorScheme(.light)
                .previewDisplayName("Dashboard")

            // Empty state
            DigestView(digest: emptyDigest)
                .padding()
                .background(ColorTokens.background)
                .preferredColorScheme(.light)
                .previewDisplayName("Minimal Data")
        }
    }

    static var sampleDigest: MorningDigest {
        MorningDigest(
            date: Date(),
            headline: "A week of productivity and deep reflection",
            keyInsights: [
                "Focused heavily on Swift development and AI integration",
                "Maintained consistent daily reflection patterns across 7 days",
                "Balanced technical work with creative exploration",
                "Identified recurring themes around mindfulness and productivity"
            ],
            moodTrend: "trending positive and stable with growing confidence",
            actionableItems: [
                "Continue exploring SwiftUI design patterns and component architecture",
                "Schedule dedicated time for deep work sessions this week",
                "Review weekly goals and adjust priorities based on insights"
            ],
            weeklyPatterns: [
                "Productivity peaks mid-week (Wednesday-Thursday)",
                "Consistent morning routine established around 6:30 AM",
                "Evening reflection sessions lasting 15-20 minutes"
            ],
            generatedFrom: Array(repeating: UUID(), count: 7)
        )
    }

    static var emptyDigest: MorningDigest {
        MorningDigest(
            date: Date(),
            headline: "Quiet day, light dreams",
            keyInsights: [
                "No tracked activity for this period"
            ],
            moodTrend: nil,
            actionableItems: [
                "Enable Dreamflow for nightly reflections"
            ],
            weeklyPatterns: nil,
            generatedFrom: []
        )
    }
}
#endif
