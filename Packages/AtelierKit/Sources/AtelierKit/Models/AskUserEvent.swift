import Foundation

public struct AskUserEvent: Sendable, Codable, Identifiable {
    /// Index used when the user typed a custom response instead of picking a predefined option.
    public static let customTextIndex = -1

    public enum Status: String, Sendable, Codable {
        case pending
        case answered
    }

    public struct Option: Sendable, Codable {
        public let label: String
        public let description: String?

        public init(label: String, description: String? = nil) {
            self.label = label
            self.description = description
        }
    }

    public let id: String
    public var question: String
    public var options: [Option]
    public var selectedIndex: Int?
    public var customText: String?
    public var status: Status
    public var answeredAt: Date?

    public init(
        id: String,
        question: String,
        options: [Option],
        selectedIndex: Int? = nil,
        customText: String? = nil,
        status: Status = .pending,
        answeredAt: Date? = nil
    ) {
        self.id = id
        self.question = question
        self.options = options
        self.selectedIndex = selectedIndex
        self.customText = customText
        self.status = status
        self.answeredAt = answeredAt
    }

    /// The label of the selected option, or the custom text if "Other" was chosen.
    public var selectedLabel: String? {
        if let customText { return customText }
        guard let index = selectedIndex, options.indices.contains(index) else { return nil }
        return options[index].label
    }
}
