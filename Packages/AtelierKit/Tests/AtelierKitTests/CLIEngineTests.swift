import Testing
@testable import AtelierKit

struct CLIEngineTests {
    @Test func freshSessionNeverIncludesContinue() {
        let args = CLIEngine.buildArguments(
            message: "hello", modelAlias: "opus", sessionId: nil
        )
        #expect(!args.contains("--continue"))
        #expect(!args.contains("--resume"))
    }

    @Test func freshSessionIncludesRequiredFlags() {
        let args = CLIEngine.buildArguments(
            message: "hello", modelAlias: "opus", sessionId: nil
        )
        #expect(args.contains("-p"))
        #expect(args.contains("--output-format"))
        #expect(args.contains("stream-json"))
        #expect(args.contains("--model"))
        #expect(args.contains("opus"))
        #expect(args.contains("--max-turns"))
        #expect(args.contains("1"))
        #expect(args.contains("--include-partial-messages"))
    }

    @Test func resumeSessionPassesSessionId() {
        let args = CLIEngine.buildArguments(
            message: "follow up", modelAlias: "sonnet", sessionId: "abc-123"
        )
        #expect(args.contains("--resume"))
        #expect(args.contains("abc-123"))
        #expect(!args.contains("--continue"))
    }

    @Test func messageIsPassedVerbatim() {
        let msg = "What is 2+2?"
        let args = CLIEngine.buildArguments(
            message: msg, modelAlias: "haiku", sessionId: nil
        )
        guard let pIdx = args.firstIndex(of: "-p") else {
            Issue.record("-p flag missing")
            return
        }
        #expect(args[pIdx + 1] == msg)
    }

    @Test func modelAliasIsPassedVerbatim() {
        let args = CLIEngine.buildArguments(
            message: "hi", modelAlias: "haiku", sessionId: nil
        )
        guard let mIdx = args.firstIndex(of: "--model") else {
            Issue.record("--model flag missing")
            return
        }
        #expect(args[mIdx + 1] == "haiku")
    }
}
