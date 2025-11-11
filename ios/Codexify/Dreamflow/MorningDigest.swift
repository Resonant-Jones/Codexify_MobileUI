//
//  MorningDigest.swift
//  Codexify
//
//  Created by Codexify:Scout
//  Phase Two: Dreamflow Runtime - Morning Digest Generation & Presentation
//
//  Aggregates DreamflowLog results into user-facing digests with semantic analysis
//

import Foundation
#if canImport(UIKit)
import UIKit
#endif
#if canImport(SwiftUI)
import SwiftUI
#endif

// MARK: - Morning Digest Generator

/// Generates morning digests from DreamflowLog aggregation
class MorningDigestGenerator {

    // MARK: - Properties

    private let modelRouter: ModelRouter?
    private let useLLMForSummarization: Bool

    // MARK: - Initialization

    /// Initialize the digest generator
    /// - Parameters:
    ///   - modelRouter: Optional ModelRouter for LLM-based summarization
    ///   - useLLMForSummarization: Whether to use LLM for summary generation (default: true)
    init(modelRouter: ModelRouter? = nil, useLLMForSummarization: Bool = true) {
        self.modelRouter = modelRouter
        self.useLLMForSummarization = useLLMForSummarization && modelRouter != nil

        print("☀️ [MorningDigestGenerator] Initialized (LLM: \(self.useLLMForSummarization))")
    }

    // MARK: - Public API

    /// Generate a morning digest from DreamflowLogs
    /// - Parameters:
    ///   - logs: Array of DreamflowLog entries (1-7 days typically)
    ///   - date: Date for the digest (default: now)
    /// - Returns: MorningDigest with aggregated insights
    /// - Throws: Error if generation fails
    func generateMorningDigest(
        from logs: [DreamflowLog],
        date: Date = Date()
    ) async throws -> MorningDigest {
        print("\n☀️ [MorningDigest] Generating digest from \(logs.count) logs...")

        // Handle empty case
        guard !logs.isEmpty else {
            return createFallbackDigest(for: date)
        }

        // Sort logs by date
        let sortedLogs = logs.sorted { $0.date < $1.date }

        // Generate components
        let headline: String
        let keyInsights: [String]
        let moodTrend: String?
        let actionableItems: [String]
        let weeklyPatterns: [String]?

        if useLLMForSummarization, let router = modelRouter {
            // Use LLM for sophisticated summarization
            let llmResults = try await generateWithLLM(logs: sortedLogs, router: router)
            headline = llmResults.headline
            keyInsights = llmResults.keyInsights
            moodTrend = llmResults.moodTrend
            actionableItems = llmResults.actionableItems
            weeklyPatterns = llmResults.weeklyPatterns
        } else {
            // Use rule-based generation
            headline = generateHeadline(from: sortedLogs)
            keyInsights = extractKeyInsights(from: sortedLogs)
            moodTrend = analyzeMoodTrend(from: sortedLogs)
            actionableItems = extractActionableItems(from: sortedLogs)
            weeklyPatterns = identifyWeeklyPatterns(from: sortedLogs)
        }

        let digest = MorningDigest(
            date: date,
            headline: headline,
            keyInsights: keyInsights,
            moodTrend: moodTrend,
            actionableItems: actionableItems,
            weeklyPatterns: weeklyPatterns,
            generatedFrom: sortedLogs.map { $0.id }
        )

        print("✅ [MorningDigest] Generated: \"\(headline)\"")
        return digest
    }

    // MARK: - LLM-Based Generation

    private func generateWithLLM(logs: [DreamflowLog], router: ModelRouter) async throws -> LLMDigestResults {
        // Aggregate all summaries
        let summaries = logs.map { log in
            """
            Date: \(formatDate(log.date))
            Summary: \(log.summary)
            \(log.moodSketch.map { "Mood: \($0)" } ?? "")
            \(log.foresight.map { "Foresight: \($0)" } ?? "")
            Anchors: \(log.anchors.joined(separator: ", "))
            """
        }.joined(separator: "\n\n---\n\n")

        let prompt = """
        Based on the following daily reflections from the past \(logs.count) days, create a morning digest:

        \(summaries)

        Generate a structured response with:

        1. **Headline** (1 compelling sentence summarizing the period)
        2. **Key Insights** (3-5 bullet points of notable patterns or themes)
        3. **Mood Trend** (1 sentence describing emotional trajectory)
        4. **Actionable Items** (2-3 concrete suggestions for today)
        5. **Weekly Patterns** (optional: recurring themes across days)

        Format as JSON:
        {
          "headline": "...",
          "keyInsights": ["...", "..."],
          "moodTrend": "...",
          "actionableItems": ["...", "..."],
          "weeklyPatterns": ["...", "..."]
        }

        Keep it concise, actionable, and encouraging.
        """

        print("🤖 [MorningDigest] Requesting LLM summarization...")
        let response = try await router.routeRequest(prompt)

        // Parse JSON response
        return try parseLLMResponse(response)
    }

    private func parseLLMResponse(_ response: String) throws -> LLMDigestResults {
        // Try to extract JSON from response
        guard let jsonData = extractJSON(from: response)?.data(using: .utf8) else {
            // Fallback: parse manually
            return LLMDigestResults(
                headline: extractHeadline(from: response) ?? "Daily Reflection Summary",
                keyInsights: extractBulletPoints(from: response, section: "Key Insights"),
                moodTrend: extractSection(from: response, section: "Mood Trend"),
                actionableItems: extractBulletPoints(from: response, section: "Actionable Items"),
                weeklyPatterns: extractBulletPoints(from: response, section: "Weekly Patterns")
            )
        }

        let decoder = JSONDecoder()
        do {
            let parsed = try decoder.decode(LLMDigestResults.self, from: jsonData)
            return parsed
        } catch {
            print("⚠️ [MorningDigest] JSON parsing failed, using fallback: \(error)")
            return LLMDigestResults(
                headline: "Daily Reflection Summary",
                keyInsights: ["Unable to parse insights"],
                moodTrend: nil,
                actionableItems: [],
                weeklyPatterns: nil
            )
        }
    }

    // MARK: - Rule-Based Generation

    private func generateHeadline(from logs: [DreamflowLog]) -> String {
        let days = logs.count
        let totalAnchors = logs.flatMap { $0.anchors }.count

        // Determine dominant theme
        let dominantAnchor = mostFrequentAnchor(from: logs)

        if days == 1 {
            if let anchor = dominantAnchor {
                return "A day focused on \(anchor.lowercased())"
            }
            return "A day of reflection and growth"
        } else {
            let timeframe = days == 7 ? "week" : "\(days) days"
            if let anchor = dominantAnchor {
                return "A \(timeframe) of \(anchor.lowercased()) and reflection"
            }
            return "Insights from the past \(timeframe)"
        }
    }

    private func extractKeyInsights(from logs: [DreamflowLog]) -> [String] {
        var insights: [String] = []

        // Insight 1: Activity summary
        let totalDays = logs.count
        insights.append("Reflected on \(totalDays) day\(totalDays == 1 ? "" : "s") of activity")

        // Insight 2: Dominant themes
        let topAnchors = topNAnchors(from: logs, count: 3)
        if !topAnchors.isEmpty {
            insights.append("Key themes: \(topAnchors.map { $0.anchor }.joined(separator: ", "))")
        }

        // Insight 3: Mood observation
        if let moodTrend = analyzeMoodTrend(from: logs) {
            insights.append("Mood: \(moodTrend)")
        }

        // Insight 4: Foresight patterns
        let foresightCount = logs.filter { $0.foresight != nil }.count
        if foresightCount > 0 {
            insights.append("Generated \(foresightCount) predictive insight\(foresightCount == 1 ? "" : "s")")
        }

        return insights
    }

    private func analyzeMoodTrend(from logs: [DreamflowLog]) -> String? {
        let moodSketches = logs.compactMap { $0.moodSketch }

        guard !moodSketches.isEmpty else {
            return nil
        }

        // Simple sentiment analysis based on keywords
        let positiveKeywords = ["calm", "focused", "energized", "positive", "productive", "happy", "content", "balanced"]
        let negativeKeywords = ["anxious", "stressed", "frustrated", "tired", "overwhelmed", "scattered", "low"]

        var positiveCount = 0
        var negativeCount = 0

        for sketch in moodSketches {
            let lowerSketch = sketch.lowercased()
            positiveCount += positiveKeywords.filter { lowerSketch.contains($0) }.count
            negativeCount += negativeKeywords.filter { lowerSketch.contains($0) }.count
        }

        if positiveCount > negativeCount * 1.5 {
            return "trending positive and stable"
        } else if negativeCount > positiveCount * 1.5 {
            return "showing signs of stress or fatigue"
        } else if positiveCount > 0 || negativeCount > 0 {
            return "mixed but generally balanced"
        } else {
            return "steady and neutral"
        }
    }

    private func extractActionableItems(from logs: [DreamflowLog]) -> [String] {
        var items: [String] = []

        // Extract from foresight
        for log in logs {
            if let foresight = log.foresight {
                // Look for recommendation patterns
                let lines = foresight.components(separatedBy: .newlines)
                for line in lines {
                    if line.lowercased().contains("consider") ||
                       line.lowercased().contains("recommend") ||
                       line.lowercased().contains("suggest") ||
                       line.lowercased().contains("try") {
                        items.append(line.trimmingCharacters(in: .whitespaces))
                    }
                }
            }
        }

        // Fallback: generic actionables
        if items.isEmpty {
            let dominantAnchor = mostFrequentAnchor(from: logs)
            if let anchor = dominantAnchor {
                items.append("Continue exploring themes around \(anchor.lowercased())")
            }
            items.append("Review yesterday's reflections for patterns")
        }

        return Array(items.prefix(3)) // Limit to 3
    }

    private func identifyWeeklyPatterns(from logs: [DreamflowLog]) -> [String]? {
        guard logs.count >= 3 else {
            return nil // Need at least 3 days for patterns
        }

        var patterns: [String] = []

        // Pattern 1: Recurring anchors
        let topAnchors = topNAnchors(from: logs, count: 2)
        if let first = topAnchors.first, first.count >= 3 {
            patterns.append("\(first.anchor) appeared in \(first.count) reflections")
        }

        // Pattern 2: Mood consistency
        let moodSketches = logs.compactMap { $0.moodSketch }
        if moodSketches.count >= logs.count / 2 {
            patterns.append("Consistent mood tracking across \(moodSketches.count) days")
        }

        // Pattern 3: Reflection depth
        let avgSummaryLength = logs.map { $0.summary.count }.reduce(0, +) / logs.count
        if avgSummaryLength > 200 {
            patterns.append("Detailed daily reflections (avg \(avgSummaryLength) chars)")
        }

        return patterns.isEmpty ? nil : patterns
    }

    private func createFallbackDigest(for date: Date) -> MorningDigest {
        return MorningDigest(
            date: date,
            headline: "Quiet day, light dreams",
            keyInsights: [
                "No tracked activity or reflections for this period",
                "Consider running Dreamflow to capture today's insights"
            ],
            moodTrend: nil,
            actionableItems: [
                "Enable Dreamflow for nightly reflections",
                "Review your day and note any interesting patterns"
            ],
            weeklyPatterns: nil,
            generatedFrom: []
        )
    }

    // MARK: - Semantic Analysis Utilities

    /// Find the most frequently occurring anchor across logs
    /// - Parameter logs: Array of DreamflowLog entries
    /// - Returns: Most frequent anchor string, or nil if none
    func mostFrequentAnchor(from logs: [DreamflowLog]) -> String? {
        let anchors = logs.flatMap { $0.anchors }
        guard !anchors.isEmpty else { return nil }

        var frequency: [String: Int] = [:]
        for anchor in anchors {
            frequency[anchor, default: 0] += 1
        }

        return frequency.max(by: { $0.value < $1.value })?.key
    }

    /// Get top N most frequent anchors
    /// - Parameters:
    ///   - logs: Array of DreamflowLog entries
    ///   - count: Number of top anchors to return
    /// - Returns: Array of (anchor, frequency) tuples
    func topNAnchors(from logs: [DreamflowLog], count: Int) -> [(anchor: String, count: Int)] {
        let anchors = logs.flatMap { $0.anchors }
        guard !anchors.isEmpty else { return [] }

        var frequency: [String: Int] = [:]
        for anchor in anchors {
            frequency[anchor, default: 0] += 1
        }

        return frequency
            .sorted { $0.value > $1.value }
            .prefix(count)
            .map { (anchor: $0.key, count: $0.value) }
    }

    /// Analyze if mood is trending upward based on temporal progression
    /// - Parameter logs: Array of DreamflowLog entries (must be sorted by date)
    /// - Returns: True if mood appears to be improving
    func isMoodTrendingUp(from logs: [DreamflowLog]) -> Bool {
        let moodSketches = logs.compactMap { $0.moodSketch }
        guard moodSketches.count >= 2 else { return false }

        let positiveKeywords = ["better", "improved", "positive", "energized", "calm", "focused", "productive"]
        let negativeKeywords = ["worse", "declined", "negative", "tired", "stressed", "anxious", "scattered"]

        // Compare first half vs second half
        let midpoint = moodSketches.count / 2
        let firstHalf = moodSketches[..<midpoint].joined(separator: " ").lowercased()
        let secondHalf = moodSketches[midpoint...].joined(separator: " ").lowercased()

        let firstHalfPositive = positiveKeywords.filter { firstHalf.contains($0) }.count
        let firstHalfNegative = negativeKeywords.filter { firstHalf.contains($0) }.count

        let secondHalfPositive = positiveKeywords.filter { secondHalf.contains($0) }.count
        let secondHalfNegative = negativeKeywords.filter { secondHalf.contains($0) }.count

        let firstScore = firstHalfPositive - firstHalfNegative
        let secondScore = secondHalfPositive - secondHalfNegative

        return secondScore > firstScore
    }

    /// Summarize patterns across multiple logs
    /// - Parameter logs: Array of DreamflowLog entries
    /// - Returns: Human-readable pattern summary
    func summarizePatterns(from logs: [DreamflowLog]) -> String {
        var summary = ""

        // Temporal summary
        if logs.count == 1 {
            summary += "Single day reflection. "
        } else {
            summary += "Reflecting on \(logs.count) days. "
        }

        // Anchor analysis
        let topAnchors = topNAnchors(from: logs, count: 3)
        if !topAnchors.isEmpty {
            let anchorList = topAnchors.map { "\($0.anchor) (\($0.count)×)" }.joined(separator: ", ")
            summary += "Key themes: \(anchorList). "
        }

        // Mood analysis
        if isMoodTrendingUp(from: logs) {
            summary += "Mood trending upward. "
        } else if let moodTrend = analyzeMoodTrend(from: logs) {
            summary += "Mood: \(moodTrend). "
        }

        // Reflection depth
        let logsWithForesight = logs.filter { $0.foresight != nil }.count
        if logsWithForesight > 0 {
            summary += "Generated foresight in \(logsWithForesight) reflection\(logsWithForesight == 1 ? "" : "s"). "
        }

        return summary.trimmingCharacters(in: .whitespaces)
    }

    // MARK: - Helper Methods

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }

    private func extractJSON(from text: String) -> String? {
        // Find JSON block in response
        guard let startRange = text.range(of: "{"),
              let endRange = text.range(of: "}", options: .backwards) else {
            return nil
        }

        return String(text[startRange.lowerBound...endRange.upperBound])
    }

    private func extractHeadline(from text: String) -> String? {
        let lines = text.components(separatedBy: .newlines)
        for line in lines {
            if line.lowercased().contains("headline") {
                // Extract text after colon or quote
                if let colonRange = line.range(of: ":") {
                    return line[colonRange.upperBound...].trimmingCharacters(in: .whitespacesAndNewlines)
                        .trimmingCharacters(in: CharacterSet(charactersIn: "\""))
                }
            }
        }
        return nil
    }

    private func extractSection(from text: String, section: String) -> String? {
        let lines = text.components(separatedBy: .newlines)
        for (index, line) in lines.enumerated() {
            if line.lowercased().contains(section.lowercased()) {
                if index + 1 < lines.count {
                    return lines[index + 1].trimmingCharacters(in: .whitespacesAndNewlines)
                        .trimmingCharacters(in: CharacterSet(charactersIn: "\""))
                }
            }
        }
        return nil
    }

    private func extractBulletPoints(from text: String, section: String) -> [String] {
        let lines = text.components(separatedBy: .newlines)
        var inSection = false
        var bullets: [String] = []

        for line in lines {
            if line.lowercased().contains(section.lowercased()) {
                inSection = true
                continue
            }

            if inSection {
                let trimmed = line.trimmingCharacters(in: .whitespaces)
                if trimmed.isEmpty {
                    inSection = false
                    continue
                }

                if trimmed.hasPrefix("-") || trimmed.hasPrefix("•") || trimmed.hasPrefix("*") {
                    let bullet = trimmed
                        .replacingOccurrences(of: "^[-•*]\\s*", with: "", options: .regularExpression)
                        .trimmingCharacters(in: CharacterSet(charactersIn: "\""))
                    if !bullet.isEmpty {
                        bullets.append(bullet)
                    }
                } else if trimmed.first?.isNumber == true {
                    let bullet = trimmed
                        .replacingOccurrences(of: "^\\d+\\.\\s*", with: "", options: .regularExpression)
                        .trimmingCharacters(in: CharacterSet(charactersIn: "\""))
                    if !bullet.isEmpty {
                        bullets.append(bullet)
                    }
                }
            }
        }

        return bullets
    }

    // MARK: - Helper Types

    private struct LLMDigestResults: Codable {
        let headline: String
        let keyInsights: [String]
        let moodTrend: String?
        let actionableItems: [String]
        let weeklyPatterns: [String]?
    }
}

// MARK: - Formatting Extensions

extension MorningDigest {

    /// Format digest as plain text for notifications or sharing
    /// - Returns: Plain text representation
    func asPlainText() -> String {
        var text = ""

        text += "☀️ \(headline)\n\n"

        if !keyInsights.isEmpty {
            text += "Key Insights:\n"
            for insight in keyInsights {
                text += "  • \(insight)\n"
            }
            text += "\n"
        }

        if let mood = moodTrend {
            text += "Mood: \(mood)\n\n"
        }

        if !actionableItems.isEmpty {
            text += "Action Items:\n"
            for item in actionableItems {
                text += "  → \(item)\n"
            }
            text += "\n"
        }

        if let patterns = weeklyPatterns, !patterns.isEmpty {
            text += "Patterns:\n"
            for pattern in patterns {
                text += "  ⚡ \(pattern)\n"
            }
        }

        return text
    }

    #if canImport(UIKit)
    /// Format digest as attributed string for rich text display
    /// - Returns: NSAttributedString with formatting
    func asAttributedText() -> NSAttributedString {
        let result = NSMutableAttributedString()

        // Headline
        let headlineAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 20, weight: .bold),
            .foregroundColor: UIColor.label
        ]
        result.append(NSAttributedString(string: "☀️ \(headline)\n\n", attributes: headlineAttributes))

        // Key Insights
        if !keyInsights.isEmpty {
            let sectionAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 16, weight: .semibold),
                .foregroundColor: UIColor.label
            ]
            result.append(NSAttributedString(string: "Key Insights\n", attributes: sectionAttributes))

            let bulletAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 14, weight: .regular),
                .foregroundColor: UIColor.secondaryLabel
            ]
            for insight in keyInsights {
                result.append(NSAttributedString(string: "  • \(insight)\n", attributes: bulletAttributes))
            }
            result.append(NSAttributedString(string: "\n"))
        }

        // Mood
        if let mood = moodTrend {
            let moodAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 14, weight: .regular),
                .foregroundColor: UIColor.systemBlue
            ]
            result.append(NSAttributedString(string: "Mood: \(mood)\n\n", attributes: moodAttributes))
        }

        // Action Items
        if !actionableItems.isEmpty {
            let sectionAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 16, weight: .semibold),
                .foregroundColor: UIColor.label
            ]
            result.append(NSAttributedString(string: "Action Items\n", attributes: sectionAttributes))

            let actionAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 14, weight: .medium),
                .foregroundColor: UIColor.systemGreen
            ]
            for item in actionableItems {
                result.append(NSAttributedString(string: "  → \(item)\n", attributes: actionAttributes))
            }
        }

        return result
    }
    #endif

    /// Format digest as markdown
    /// - Returns: Markdown-formatted string
    func asMarkdown() -> String {
        var markdown = ""

        markdown += "# ☀️ \(headline)\n\n"

        if !keyInsights.isEmpty {
            markdown += "## Key Insights\n\n"
            for insight in keyInsights {
                markdown += "- \(insight)\n"
            }
            markdown += "\n"
        }

        if let mood = moodTrend {
            markdown += "**Mood:** \(mood)\n\n"
        }

        if !actionableItems.isEmpty {
            markdown += "## Action Items\n\n"
            for item in actionableItems {
                markdown += "→ \(item)\n"
            }
            markdown += "\n"
        }

        if let patterns = weeklyPatterns, !patterns.isEmpty {
            markdown += "## Patterns\n\n"
            for pattern in patterns {
                markdown += "⚡ \(pattern)\n"
            }
        }

        return markdown
    }

    /// Get a short summary suitable for widget or notification
    /// - Returns: Concise summary string
    func asShortSummary() -> String {
        var summary = headline

        if let mood = moodTrend {
            summary += " • \(mood)"
        }

        if let firstInsight = keyInsights.first {
            summary += " • \(firstInsight)"
        }

        return summary
    }
}

#if canImport(SwiftUI)
// MARK: - SwiftUI Integration

/// SwiftUI view for displaying a MorningDigest
struct DigestView: View {
    let digest: MorningDigest

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.lg) {
                // Headline
                Text("☀️ \(digest.headline)")
                    .font(TextStyle.h2)
                    .foregroundColor(ColorTokens.textPrimary)
                    .padding(.bottom, Spacing.sm)

                // Key Insights
                if !digest.keyInsights.isEmpty {
                    VStack(alignment: .leading, spacing: Spacing.sm) {
                        Text("Key Insights")
                            .font(TextStyle.bodyEmphasis)
                            .foregroundColor(ColorTokens.textPrimary)

                        ForEach(digest.keyInsights, id: \.self) { insight in
                            HStack(alignment: .top, spacing: Spacing.sm) {
                                Text("•")
                                    .foregroundColor(ColorTokens.brandPrimary)
                                Text(insight)
                                    .font(TextStyle.body)
                                    .foregroundColor(ColorTokens.textSecondary)
                            }
                        }
                    }
                    .padding(.bottom, Spacing.md)
                }

                // Mood Trend
                if let mood = digest.moodTrend {
                    HStack(spacing: Spacing.sm) {
                        Text("Mood:")
                            .font(TextStyle.bodyEmphasis)
                            .foregroundColor(ColorTokens.textPrimary)
                        Text(mood)
                            .font(TextStyle.body)
                            .foregroundColor(ColorTokens.brandSecondary)
                    }
                    .padding(.bottom, Spacing.md)
                }

                // Action Items
                if !digest.actionableItems.isEmpty {
                    VStack(alignment: .leading, spacing: Spacing.sm) {
                        Text("Action Items")
                            .font(TextStyle.bodyEmphasis)
                            .foregroundColor(ColorTokens.textPrimary)

                        ForEach(digest.actionableItems, id: \.self) { item in
                            HStack(alignment: .top, spacing: Spacing.sm) {
                                Text("→")
                                    .foregroundColor(ColorTokens.success)
                                Text(item)
                                    .font(TextStyle.body)
                                    .foregroundColor(ColorTokens.textSecondary)
                            }
                        }
                    }
                    .padding(.bottom, Spacing.md)
                }

                // Weekly Patterns
                if let patterns = digest.weeklyPatterns, !patterns.isEmpty {
                    VStack(alignment: .leading, spacing: Spacing.sm) {
                        Text("Patterns")
                            .font(TextStyle.bodyEmphasis)
                            .foregroundColor(ColorTokens.textPrimary)

                        ForEach(patterns, id: \.self) { pattern in
                            HStack(alignment: .top, spacing: Spacing.sm) {
                                Text("⚡")
                                Text(pattern)
                                    .font(TextStyle.caption)
                                    .foregroundColor(ColorTokens.textTertiary)
                            }
                        }
                    }
                }

                Spacer()
            }
            .padding(Spacing.lg)
        }
        .background(ColorTokens.background)
    }
}

// MARK: - Preview

#if DEBUG
struct DigestView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            DigestView(digest: sampleDigest)
                .preferredColorScheme(.light)
                .previewDisplayName("Light Mode")

            DigestView(digest: sampleDigest)
                .preferredColorScheme(.dark)
                .previewDisplayName("Dark Mode")
        }
    }

    static var sampleDigest: MorningDigest {
        MorningDigest(
            date: Date(),
            headline: "A week of productivity and reflection",
            keyInsights: [
                "Focused heavily on Swift development and AI integration",
                "Maintained consistent daily reflection patterns",
                "Balanced technical work with creative exploration"
            ],
            moodTrend: "steady and positive with growing confidence",
            actionableItems: [
                "Continue exploring SwiftUI design patterns",
                "Schedule time for deep work sessions",
                "Review weekly goals and adjust priorities"
            ],
            weeklyPatterns: [
                "Productivity peaks mid-week",
                "Consistent morning routine established"
            ],
            generatedFrom: []
        )
    }
}
#endif

#endif
