//
//  DreamflowBuilder.swift
//  Codexify
//
//  Modular prompt builder for Dreamflow reflection
//

import Foundation

/// Builds prompts for Dreamflow inference
class DreamflowBuilder {

    private let config: DreamflowConfig

    init(config: DreamflowConfig) {
        self.config = config
    }

    // MARK: - Prompt Building

    /// Build all prompts from context
    func buildPrompts(from context: DreamflowContext, config: DreamflowConfig) -> Prompts {
        var prompts = Prompts()

        // Build summary prompt
        if config.includeFields.summary {
            prompts.summary = buildSummaryPrompt(from: context)
        }

        // Build mood sketch prompt
        if config.includeFields.moodSketch {
            prompts.moodSketch = buildMoodSketchPrompt(from: context)
        }

        // Build foresight prompt
        if config.includeFields.foresight {
            prompts.foresight = buildForesightPrompt(from: context)
        }

        // Build anchors prompt
        if config.includeFields.anchors {
            prompts.anchors = buildAnchorsPrompt(from: context)
        }

        // Combined prompt (if needed for single inference)
        prompts.combined = buildCombinedPrompt(from: context, config: config)

        return prompts
    }

    // MARK: - Individual Prompt Builders

    private func buildSummaryPrompt(from context: DreamflowContext) -> String {
        var prompt = """
        # Daily Summary Reflection

        Date: \(formatDate(context.dateRange.start))

        ## Context

        """

        // Add thread history
        if !context.threadHistory.isEmpty {
            prompt += "\n### Conversations\n"
            for message in context.threadHistory.suffix(10) {
                prompt += "- [\(message.role.rawValue)]: \(message.content)\n"
            }
        }

        // Add memory fragments
        if !context.memoryFragments.isEmpty {
            prompt += "\n### Memory Fragments\n"
            for fragment in context.memoryFragments.prefix(5) {
                prompt += "- \(fragment.content)\n"
            }
        }

        // Add sensor summary
        prompt += "\n### Daily Activity\n"
        prompt += "Locations: \(context.sensorSummary.locations.joined(separator: ", "))\n"
        prompt += "Activities: \(context.sensorSummary.activities.joined(separator: ", "))\n"

        if let steps = context.sensorSummary.totalSteps {
            prompt += "Steps: \(steps)\n"
        }

        if let hr = context.sensorSummary.avgHeartRate {
            prompt += "Avg Heart Rate: \(Int(hr)) bpm\n"
        }

        prompt += """

        ## Task

        Create a concise daily summary (2-3 paragraphs) that captures:
        1. Key themes or topics from conversations
        2. Notable activities or locations
        3. Overall productivity and well-being indicators

        Write in first person, as if the user is reflecting on their day.
        """

        return prompt
    }

    private func buildMoodSketchPrompt(from context: DreamflowContext) -> String {
        var prompt = """
        # Mood Sketch

        Based on the following data from \(formatDate(context.dateRange.start)):

        """

        // Conversational tone indicators
        if !context.threadHistory.isEmpty {
            prompt += "\n## Communication Patterns\n"
            let recentMessages = context.threadHistory.suffix(5)
            for message in recentMessages {
                prompt += "- \(message.content.prefix(100))\n"
            }
        }

        // Activity and physical state
        prompt += "\n## Physical Activity\n"
        prompt += "Activities: \(context.sensorSummary.activities.joined(separator: ", "))\n"

        if let hr = context.sensorSummary.avgHeartRate {
            let hrState = hr > 85 ? "elevated" : hr > 60 ? "normal" : "low"
            prompt += "Heart rate: \(Int(hr)) bpm (\(hrState))\n"
        }

        prompt += """

        ## Task

        Sketch the user's likely mood for this day in 2-3 sentences.
        Consider:
        - Conversation tone (anxious, excited, calm, frustrated)
        - Activity level (energized, sluggish, balanced)
        - Overall engagement

        Use evocative language but remain grounded in the data.
        Example: "A day of steady focus with undercurrents of curiosity..."
        """

        return prompt
    }

    private func buildForesightPrompt(from context: DreamflowContext) -> String {
        var prompt = """
        # Predictive Foresight

        Historical Context from \(formatDate(context.dateRange.start)):

        """

        // Recent patterns
        prompt += "\n## Observed Patterns\n"

        if !context.threadHistory.isEmpty {
            let topics = extractTopics(from: context.threadHistory)
            prompt += "Discussion topics: \(topics.joined(separator: ", "))\n"
        }

        prompt += "Daily activities: \(context.sensorSummary.activities.joined(separator: ", "))\n"

        if let steps = context.sensorSummary.totalSteps {
            let activity = steps > 10000 ? "high" : steps > 5000 ? "moderate" : "low"
            prompt += "Activity level: \(activity) (\(steps) steps)\n"
        }

        prompt += """

        ## Task

        Based on the patterns above, generate 2-3 predictive insights:

        1. **If this trend continues...** (what outcomes are likely)
        2. **Potential risks or opportunities**
        3. **Recommended adjustments** (if any)

        Be specific but not prescriptive. Frame as gentle observations.
        Example: "If the focus on [topic] continues, you may find yourself drawn to..."
        """

        return prompt
    }

    private func buildAnchorsPrompt(from context: DreamflowContext) -> String {
        var prompt = """
        # Semantic Anchors

        Extract recurring themes from \(formatDate(context.dateRange.start)):

        """

        // Combine all text sources
        var textSources: [String] = []

        for message in context.threadHistory {
            textSources.append(message.content)
        }

        for fragment in context.memoryFragments {
            textSources.append(fragment.content)
        }

        let combinedText = textSources.joined(separator: " ")

        prompt += "\n## Source Material\n"
        prompt += combinedText.prefix(1000) + "...\n"

        prompt += """

        ## Task

        Identify 3-5 **semantic anchors** - recurring themes, concepts, or patterns.

        These should be:
        - Abstract enough to connect disparate ideas
        - Specific enough to be meaningful
        - Actionable or insightful

        Format as a bulleted list:
        - Anchor 1
        - Anchor 2
        - Anchor 3

        Examples:
        - "Balancing productivity with well-being"
        - "Exploring new technical frameworks"
        - "Strengthening social connections"
        """

        return prompt
    }

    private func buildCombinedPrompt(from context: DreamflowContext, config: DreamflowConfig) -> String {
        // For models that work better with a single prompt
        var sections: [String] = []

        if config.includeFields.summary {
            sections.append(buildSummaryPrompt(from: context))
        }

        if config.includeFields.moodSketch {
            sections.append(buildMoodSketchPrompt(from: context))
        }

        if config.includeFields.foresight {
            sections.append(buildForesightPrompt(from: context))
        }

        if config.includeFields.anchors {
            sections.append(buildAnchorsPrompt(from: context))
        }

        return sections.joined(separator: "\n\n---\n\n")
    }

    // MARK: - Helper Methods

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }

    private func extractTopics(from messages: [ThreadMessage]) -> [String] {
        // Simple topic extraction (could be enhanced with NLP)
        let stopWords = Set(["the", "a", "an", "and", "or", "but", "in", "on", "at", "to", "for", "of", "with", "is", "are", "was", "were"])

        var wordFrequency: [String: Int] = [:]

        for message in messages {
            let words = message.content
                .lowercased()
                .components(separatedBy: .punctuationCharacters)
                .joined()
                .components(separatedBy: .whitespaces)
                .filter { !stopWords.contains($0) && $0.count > 3 }

            for word in words {
                wordFrequency[word, default: 0] += 1
            }
        }

        return wordFrequency
            .sorted { $0.value > $1.value }
            .prefix(5)
            .map { $0.key }
    }

    // MARK: - Prompts Structure

    struct Prompts {
        var summary: String = ""
        var moodSketch: String?
        var foresight: String?
        var anchors: String?
        var combined: String = ""
    }
}

// MARK: - Connector Hooks (Phase-Aware)

/// Protocol for future connector integrations
protocol DreamflowConnectorProtocol {
    /// Hook called before Dreamflow execution
    func beforeDreamflow(context: DreamflowContext) async throws

    /// Hook called after Dreamflow execution
    func afterDreamflow(log: DreamflowLog) async throws

    /// Provide additional context for Dreamflow
    func provideContext(for date: Date) async throws -> [String: Any]
}

// TODO: Implement connectors for:
// - Email summary (fetch unread count, important threads)
// - Calendar events (upcoming meetings, deadlines)
// - Social media (mentions, DMs)
// - Device events (app usage, screen time)
// - Health trends (sleep quality, exercise patterns)

/// Example Email Connector (stub)
class EmailConnector: DreamflowConnectorProtocol {
    func beforeDreamflow(context: DreamflowContext) async throws {
        print("📧 [EmailConnector] Preparing email summary...")
        // TODO: Fetch unread emails, important threads
    }

    func afterDreamflow(log: DreamflowLog) async throws {
        print("📧 [EmailConnector] Dreamflow complete")
        // TODO: Could trigger email digest generation
    }

    func provideContext(for date: Date) async throws -> [String: Any] {
        // TODO: Return email stats
        return [
            "unreadCount": 5,
            "importantThreads": ["Project update", "Meeting request"]
        ]
    }
}

/// Example Calendar Connector (stub)
class CalendarConnector: DreamflowConnectorProtocol {
    func beforeDreamflow(context: DreamflowContext) async throws {
        print("📅 [CalendarConnector] Loading calendar events...")
        // TODO: Fetch calendar events
    }

    func afterDreamflow(log: DreamflowLog) async throws {
        print("📅 [CalendarConnector] Dreamflow complete")
    }

    func provideContext(for date: Date) async throws -> [String: Any] {
        // TODO: Return calendar info
        return [
            "upcomingEvents": 3,
            "nextMeeting": "Team standup at 10am"
        ]
    }
}
