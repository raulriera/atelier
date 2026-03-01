import Testing
import Foundation
@testable import AtelierDesign

struct MarkdownRendererTests {
    @Test func plainParagraph() {
        let blocks = MarkdownRenderer.parse("Hello world")
        #expect(blocks.count == 1)
        if case .paragraph(let text) = blocks[0] {
            #expect(String(text.characters) == "Hello world")
        } else {
            Issue.record("Expected paragraph")
        }
    }

    @Test func fencedCodeBlock() {
        let source = """
        ```swift
        let x = 42
        ```
        """
        let blocks = MarkdownRenderer.parse(source)
        #expect(blocks.count == 1)
        if case .codeBlock(let language, let code) = blocks[0] {
            #expect(language == "swift")
            #expect(code == "let x = 42")
        } else {
            Issue.record("Expected codeBlock")
        }
    }

    @Test func codeBlockWithoutLanguage() {
        let source = """
        ```
        plain code
        ```
        """
        let blocks = MarkdownRenderer.parse(source)
        #expect(blocks.count == 1)
        if case .codeBlock(let language, let code) = blocks[0] {
            #expect(language == nil)
            #expect(code == "plain code")
        } else {
            Issue.record("Expected codeBlock")
        }
    }

    @Test func headingLevels() {
        let blocks = MarkdownRenderer.parse("# Title")
        #expect(blocks.count == 1)
        if case .heading(let level, let text) = blocks[0] {
            #expect(level == 1)
            #expect(String(text.characters) == "Title")
        } else {
            Issue.record("Expected heading")
        }

        let blocks2 = MarkdownRenderer.parse("### Subtitle")
        if case .heading(let level, _) = blocks2[0] {
            #expect(level == 3)
        }
    }

    @Test func boldInlineMarkup() {
        let blocks = MarkdownRenderer.parse("This is **bold** text")
        #expect(blocks.count == 1)
        if case .paragraph(let text) = blocks[0] {
            #expect(String(text.characters) == "This is bold text")
        } else {
            Issue.record("Expected paragraph with bold")
        }
    }

    @Test func unorderedList() {
        let source = """
        - Item one
        - Item two
        - Item three
        """
        let blocks = MarkdownRenderer.parse(source)
        #expect(blocks.count == 1)
        if case .list(let ordered, let items) = blocks[0] {
            #expect(!ordered)
            #expect(items.count == 3)
            #expect(String(items[0].characters) == "Item one")
        } else {
            Issue.record("Expected unordered list")
        }
    }

    @Test func emptyInput() {
        let blocks = MarkdownRenderer.parse("")
        #expect(blocks.isEmpty)
    }

    @Test func mixedContent() {
        let source = """
        # Header

        A paragraph.

        ```python
        print("hi")
        ```

        - bullet
        """
        let blocks = MarkdownRenderer.parse(source)
        #expect(blocks.count == 4)
        if case .heading = blocks[0] {} else { Issue.record("Expected heading") }
        if case .paragraph = blocks[1] {} else { Issue.record("Expected paragraph") }
        if case .codeBlock = blocks[2] {} else { Issue.record("Expected codeBlock") }
        if case .list = blocks[3] {} else { Issue.record("Expected list") }
    }

    @Test func blockQuote() {
        let blocks = MarkdownRenderer.parse("> A quote")
        #expect(blocks.count == 1)
        if case .blockQuote(let text) = blocks[0] {
            #expect(String(text.characters) == "A quote")
        } else {
            Issue.record("Expected blockQuote")
        }
    }

    @Test func thematicBreak() {
        let blocks = MarkdownRenderer.parse("---")
        #expect(blocks.count == 1)
        if case .thematicBreak = blocks[0] {} else {
            Issue.record("Expected thematicBreak")
        }
    }
}
