import Testing
import Foundation
import Markdown
@testable import AtelierDesign

struct InlineTextTests {
    private func inlines(from source: String) -> [any InlineMarkup] {
        let document = Document(parsing: source)
        for child in document.children {
            if let paragraph = child as? Paragraph {
                return paragraph.children.compactMap { $0 as? any InlineMarkup }
            }
        }
        return []
    }

    @Test func plainTextPassesThrough() {
        let result = InlineText.attributedString(from: inlines(from: "hello"))
        #expect(String(result.characters) == "hello")
    }

    @Test func boldProducesStrongEmphasis() {
        let result = InlineText.attributedString(from: inlines(from: "**bold**"))
        #expect(String(result.characters) == "bold")
        let runs = result.runs.map { $0 }
        #expect(runs.count == 1)
        #expect(runs[0].inlinePresentationIntent == .stronglyEmphasized)
    }

    @Test func inlineCodeProducesCodeIntent() {
        let result = InlineText.attributedString(from: inlines(from: "`code`"))
        #expect(String(result.characters) == "code")
        let runs = result.runs.map { $0 }
        #expect(runs[0].inlinePresentationIntent == .code)
    }

    @Test func linkProducesURLAttribute() {
        let result = InlineText.attributedString(from: inlines(from: "[link](https://example.com)"))
        #expect(String(result.characters) == "link")
        let runs = result.runs.map { $0 }
        #expect(runs[0].link == URL(string: "https://example.com"))
    }

    @Test func nestedMarkup() {
        let result = InlineText.attributedString(from: inlines(from: "**bold and *italic***"))
        let text = String(result.characters)
        #expect(text.contains("bold"))
        #expect(text.contains("italic"))
    }
}
