import Testing
import Foundation
@testable import AtelierKit

@Test @MainActor func appendUserMessage() {
    let session = Session()
    session.appendUserMessage("Hello")
    #expect(session.items.count == 1)
    if case .userMessage(let msg) = session.items[0].content {
        #expect(msg.text == "Hello")
    } else {
        Issue.record("Expected userMessage")
    }
}

@Test @MainActor func beginAndStreamAssistant() {
    let session = Session()
    session.beginAssistantMessage()
    #expect(session.isStreaming)
    #expect(session.activeAssistantText == "")

    session.applyDelta("Hello")
    session.applyDelta(" world")
    #expect(session.activeAssistantText == "Hello world")
}

@Test @MainActor func completeAssistantMessage() {
    let session = Session()
    session.beginAssistantMessage()
    session.applyDelta("Done")
    session.completeAssistantMessage(usage: TokenUsage(inputTokens: 10, outputTokens: 5))

    #expect(!session.isStreaming)
    #expect(session.activeAssistantText == "")
    #expect(session.items.count == 1)

    if case .assistantMessage(let msg) = session.items[0].content {
        #expect(msg.text == "Done")
        #expect(msg.isComplete)
        #expect(msg.usage.inputTokens == 10)
        #expect(msg.usage.outputTokens == 5)
    } else {
        Issue.record("Expected assistantMessage")
    }
}

@Test @MainActor func handleErrorAppendsSystemEvent() {
    let session = Session()
    session.beginAssistantMessage()
    session.applyDelta("partial")
    session.handleError(.cliError("Rate limited"))

    #expect(!session.isStreaming)
    #expect(session.activeAssistantText == "")
    // assistant item + error system event
    #expect(session.items.count == 2)
    if case .system(let evt) = session.items[1].content {
        #expect(evt.kind == .error)
        #expect(evt.message == "Rate limited")
    } else {
        Issue.record("Expected system error event")
    }
}

@Test @MainActor func multiTurnConversation() {
    let session = Session()

    session.appendUserMessage("Hi")
    session.beginAssistantMessage()
    session.applyDelta("Hey!")
    session.completeAssistantMessage(usage: TokenUsage(inputTokens: 5, outputTokens: 3))

    session.appendUserMessage("How are you?")
    session.beginAssistantMessage()
    session.applyDelta("Great!")
    session.completeAssistantMessage(usage: TokenUsage(inputTokens: 12, outputTokens: 4))

    #expect(session.items.count == 4)
    #expect(!session.isStreaming)
}
