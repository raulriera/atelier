import Foundation

/// Provides a randomized selection of suggestion prompts for the empty
/// conversation state.
///
/// Prompts are organized in two tiers:
/// - **Capability prompts** reference enabled capabilities (Calendar, Mail, etc.)
///   and describe multi-step workflows that use them.
/// - **General prompts** work without any capabilities — pure knowledge work.
///
/// The provider prioritizes capability prompts when capabilities are enabled,
/// filling remaining slots with general prompts. This ensures the suggestions
/// always showcase what Atelier can *actually do right now*.
public struct SuggestionProvider: Sendable {

    /// Returns a selection of suggestion prompts tailored to enabled capabilities.
    ///
    /// - Parameters:
    ///   - enabledCapabilityIDs: The set of currently enabled capability IDs.
    ///   - count: The number of suggestions to return.
    /// - Returns: An array of prompts — capability-aware first, general to fill.
    public static func suggestions(
        enabledCapabilityIDs: Set<String> = [],
        count: Int = 4
    ) -> [SuggestionPrompt] {
        // Collect capability prompts that match enabled capabilities
        var capabilityPool = capabilityPrompts.filter { prompt in
            prompt.requiredCapabilities.allSatisfy { enabledCapabilityIDs.contains($0) }
        }
        capabilityPool.shuffle()

        // Fill remaining slots with general prompts
        var generalPool = generalPrompts
        generalPool.shuffle()

        var result: [SuggestionPrompt] = []
        let capCount = min(capabilityPool.count, count)
        result.append(contentsOf: capabilityPool.prefix(capCount))
        let remaining = count - result.count
        if remaining > 0 {
            result.append(contentsOf: generalPool.prefix(remaining))
        }

        return Array(result.prefix(count))
    }

    // MARK: - Capability Prompts

    /// Prompts that leverage specific enabled capabilities.
    static let capabilityPrompts: [SuggestionPrompt] = [

        // Calendar
        SuggestionPrompt(
            iconSystemName: "calendar",
            title: "Optimize my week",
            subtitle: "Review calendar and find focus time",
            prompt: """
                Help me plan and optimize my week.

                First, review my calendar and show me a summary:
                - Total meetings and their combined duration
                - Busiest days vs lightest days
                - Where I have gaps of 2+ hours for focus time

                Before proposing changes, ask me about:
                - What I'm trying to accomplish this week
                - How much focus time I need and for what
                - Any deadlines or commitments not on my calendar
                - Which types of meetings I could decline or shorten

                Then show me your top 3-5 proposed changes with explanations. Start with the highest-impact changes first.
                """,
            requiredCapabilities: ["calendar"]
        ),

        // Mail
        SuggestionPrompt(
            iconSystemName: "envelope",
            title: "Process my inbox",
            subtitle: "Triage unread emails by priority",
            prompt: """
                Help me triage my inbox.

                First, scan my recent unread messages and categorize them:
                - Urgent: needs a response today
                - This week: important but not time-sensitive
                - FYI: informational, no action needed
                - Low priority: newsletters, notifications, can be archived

                For each urgent item, draft a brief response for my review. For "this week" items, suggest when I should handle them. Archive or flag the rest as appropriate.

                Before taking any action, show me the full categorized list and let me adjust priorities.
                """,
            requiredCapabilities: ["mail"]
        ),

        // Calendar + Mail
        SuggestionPrompt(
            iconSystemName: "sunrise",
            title: "Morning briefing",
            subtitle: "Today's meetings, emails, and priorities",
            prompt: """
                Give me a morning briefing for today.

                1. Check my calendar — what meetings do I have? Flag any that overlap or look like they could be shortened.
                2. Scan my unread emails — highlight anything urgent or from key contacts.
                3. Based on my schedule and inbox, suggest a prioritized plan for the day: what to tackle first, when to take meetings, and where my focus blocks are.

                Present it as a clean daily agenda I can reference throughout the day.
                """,
            requiredCapabilities: ["calendar", "mail"]
        ),

        // Reminders
        SuggestionPrompt(
            iconSystemName: "checklist",
            title: "Review my tasks",
            subtitle: "Organize and prioritize reminders",
            prompt: """
                Help me get my tasks under control.

                First, pull up all my reminders and show me:
                - Overdue items that need immediate attention
                - Items due this week
                - Items with no due date that might be stale

                Then help me prioritize: ask me which items I can defer, delegate, or delete. For the ones I'm keeping, suggest a realistic schedule based on my available time this week.
                """,
            requiredCapabilities: ["reminders"]
        ),

        // Calendar + Reminders
        SuggestionPrompt(
            iconSystemName: "clock.badge.checkmark",
            title: "Weekly review",
            subtitle: "Reflect on last week, plan the next",
            prompt: """
                Let's do a weekly review.

                First, pull up:
                - My calendar for the past week — what meetings did I attend?
                - My completed reminders — what did I finish?
                - My overdue or upcoming reminders — what's still pending?

                Then guide me through a reflection:
                - What went well this week?
                - What didn't go as planned?
                - What should I prioritize next week?

                Based on my answers, help me set up next week: create reminders for key tasks and suggest time blocks on my calendar for focused work.
                """,
            requiredCapabilities: ["calendar", "reminders"]
        ),

        // Notes
        SuggestionPrompt(
            iconSystemName: "note.text",
            title: "Meeting prep",
            subtitle: "Research context before a meeting",
            prompt: """
                Help me prepare for a meeting.

                I'll tell you who I'm meeting with and what it's about. Then:
                1. Search my notes for anything related to this person or topic
                2. Summarize what I already know and any open items from past conversations
                3. Suggest 3-5 talking points or questions I should raise
                4. Create a new note with the prep summary so I can reference it during the meeting

                Ask me for the meeting details to get started.
                """,
            requiredCapabilities: ["notes"]
        ),

        // iWork
        SuggestionPrompt(
            iconSystemName: "doc.richtext",
            title: "Build a presentation",
            subtitle: "Create a Keynote deck from scratch",
            prompt: """
                Help me build a presentation in Keynote.

                Before creating anything, ask me:
                - What's the topic and who's the audience?
                - What's the key message or call to action?
                - How long is the presentation (number of slides)?
                - Do I have specific data or points to include?

                Then create the deck with:
                - A compelling title slide
                - An agenda/overview slide
                - Content slides with clear headlines and supporting points
                - A summary slide with key takeaways

                Add speaker notes for each slide with talking points and timing guidance.
                """,
            requiredCapabilities: ["iwork"]
        ),

        // Mail + Notes
        SuggestionPrompt(
            iconSystemName: "envelope.badge.person.crop",
            title: "Client follow-up",
            subtitle: "Draft emails from meeting notes",
            prompt: """
                Help me follow up after a client meeting.

                1. Search my notes for the most recent meeting notes
                2. Extract the key decisions, action items, and next steps
                3. Draft a follow-up email that summarizes what we discussed, confirms action items and owners, and proposes next steps with dates

                Show me the draft before sending. Ask me if anything needs adjusting — tone, details, or recipients.
                """,
            requiredCapabilities: ["mail", "notes"]
        ),

        // Finder
        SuggestionPrompt(
            iconSystemName: "folder",
            title: "Organize this project",
            subtitle: "Audit files and suggest structure",
            prompt: """
                Help me organize this project folder.

                1. List all files and show me a breakdown by type (documents, images, spreadsheets, etc.)
                2. Flag anything that looks outdated, duplicated, or misplaced
                3. Suggest a cleaner folder structure based on the content patterns you see
                4. Show me the proposed reorganization as a before/after tree

                Only move files after I approve the plan.
                """,
            requiredCapabilities: ["finder"]
        ),

        // Safari
        SuggestionPrompt(
            iconSystemName: "safari",
            title: "Research from open tabs",
            subtitle: "Synthesize what I've been reading",
            prompt: """
                Help me make sense of my open Safari tabs.

                1. List all my open tabs and group them by topic
                2. Read the content of the most relevant ones
                3. Synthesize the key information into a structured summary: main findings, conflicting viewpoints, and gaps in the research

                Then ask me what I'm trying to decide or write — and tailor the summary to be useful for that specific goal.
                """,
            requiredCapabilities: ["safari"]
        ),

        // Preview
        SuggestionPrompt(
            iconSystemName: "doc.text.magnifyingglass",
            title: "Analyze a PDF",
            subtitle: "Extract and summarize document content",
            prompt: """
                Find any PDF documents in this project and help me work with them.

                For each PDF:
                1. Extract the text content and give me a summary — what is it about?
                2. Pull out the key data: dates, numbers, names, action items
                3. Highlight anything that needs my attention or follow-up

                If it's a contract or agreement, flag important terms, deadlines, and obligations. If it's a report, summarize the findings and recommendations.
                """,
            requiredCapabilities: ["preview"]
        ),
    ]

    // MARK: - General Prompts

    /// Prompts that work without any capabilities — pure knowledge work.
    static let generalPrompts: [SuggestionPrompt] = [
        SuggestionPrompt(
            iconSystemName: "text.book.closed",
            title: "Summarize an article",
            subtitle: "Distill key points from a long read",
            prompt: """
                I'd like to paste an article and get a structured breakdown:
                - One-paragraph summary
                - 3-5 key takeaways
                - Main arguments and supporting evidence
                - Action items or implications for me
                - Questions the article raises but doesn't answer

                I'll paste the article next.
                """
        ),
        SuggestionPrompt(
            iconSystemName: "lightbulb",
            title: "Brainstorm ideas",
            subtitle: "Generate creative options for a challenge",
            prompt: """
                I need to brainstorm ideas for a challenge I'm facing.

                Before generating ideas, ask me:
                - What's the specific problem or opportunity?
                - What constraints should I work within (budget, time, resources)?
                - What have I already tried or considered?
                - Who is the audience or stakeholder?

                Then give me 10 ideas ranging from safe/proven to bold/unconventional. For each, include a one-line rationale and effort estimate (low/medium/high).
                """
        ),
        SuggestionPrompt(
            iconSystemName: "text.quote",
            title: "Refine my writing",
            subtitle: "Polish tone, clarity, and structure",
            prompt: """
                I have a draft I'd like to improve. I'll paste it next.

                Please review it for:
                - Clarity: are the ideas easy to follow?
                - Tone: is it appropriate for the audience?
                - Structure: does the flow make sense?
                - Conciseness: can anything be cut without losing meaning?

                Show me a revised version with tracked changes (strikethrough for removals, **bold** for additions). Then explain your top 3 most impactful edits.
                """
        ),
        SuggestionPrompt(
            iconSystemName: "magnifyingglass",
            title: "Research a topic",
            subtitle: "Deep dive with structured findings",
            prompt: """
                I need to research a topic thoroughly.

                I'll tell you the topic. Then please provide:
                1. Background and context — what's the history?
                2. Current state — where do things stand today?
                3. Key players or perspectives — who matters and why?
                4. Open questions — what's still debated or unclear?
                5. Implications — what does this mean for someone in my position?

                Cite specific sources where possible. Flag areas where information may be outdated or contested.
                """
        ),
        SuggestionPrompt(
            iconSystemName: "doc.text",
            title: "Draft a proposal",
            subtitle: "Structure a compelling case",
            prompt: """
                Help me draft a proposal or business case.

                Before writing, ask me:
                - What am I proposing and to whom?
                - What problem does this solve?
                - What's my budget and timeline?
                - Who are the decision-makers?

                Then structure it as:
                1. Executive summary (2-3 sentences)
                2. Problem statement with evidence
                3. Proposed solution with specifics
                4. Timeline and milestones
                5. Budget breakdown
                6. Risks and mitigations
                7. Next steps and ask
                """
        ),
        SuggestionPrompt(
            iconSystemName: "moon.stars",
            title: "Plan tomorrow",
            subtitle: "Set up for a productive day",
            prompt: """
                Help me plan tomorrow.

                I'll share what's on my plate — meetings, deadlines, and goals. Then:
                1. Suggest a time-blocked schedule with realistic buffers
                2. Identify my top 3 priorities (the ones that move the needle)
                3. Flag anything I should prepare for in advance
                4. Recommend what to defer if the day gets derailed

                Ask me about my energy patterns too — when am I sharpest for deep work vs. better for meetings?
                """
        ),
    ]
}
