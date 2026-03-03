import Testing
@testable import AtelierKit

@Suite("CLIEngine argument building")
struct CLIEngineTests {

    @Suite("Fresh session")
    struct FreshSession {
        @Test("Never includes --continue or --resume")
        func neverIncludesContinueOrResume() {
            let args = CLIEngine.buildArguments(
                message: "hello", modelAlias: "opus", sessionId: nil
            )
            #expect(!args.contains("--continue"))
            #expect(!args.contains("--resume"))
        }

        @Test("Includes required flags")
        func includesRequiredFlags() {
            let args = CLIEngine.buildArguments(
                message: "hello", modelAlias: "opus", sessionId: nil
            )
            #expect(args.contains("-p"))
            #expect(args.contains("--output-format"))
            #expect(args.contains("stream-json"))
            #expect(args.contains("--model"))
            #expect(args.contains("opus"))
            #expect(args.contains("--include-partial-messages"))
        }

        @Test("Does not include --max-turns")
        func maxTurnsNotPresent() {
            let args = CLIEngine.buildArguments(
                message: "hello", modelAlias: "opus", sessionId: nil
            )
            #expect(!args.contains("--max-turns"))
        }
    }

    @Test("Resume session passes session ID and --resume flag")
    func resumeSessionPassesSessionId() {
        let args = CLIEngine.buildArguments(
            message: "follow up", modelAlias: "sonnet", sessionId: "abc-123"
        )
        #expect(args.contains("--resume"))
        #expect(args.contains("abc-123"))
        #expect(!args.contains("--continue"))
    }

    @Test("Message is passed as positional argument after end-of-options marker")
    func messageIsPassedAfterEndOfOptions() throws {
        let msg = "What is 2+2?"
        let args = CLIEngine.buildArguments(
            message: msg, modelAlias: "haiku", sessionId: nil
        )
        let ddIdx = try #require(args.firstIndex(of: "--"), "-- marker missing")
        #expect(args[ddIdx + 1] == msg)
        #expect(args.last == msg)
    }

    @Test("Dash-prefixed message is not misinterpreted as a flag")
    func dashPrefixedMessageSafe() throws {
        let args = CLIEngine.buildArguments(
            message: "-7", modelAlias: "haiku", sessionId: nil
        )
        let ddIdx = try #require(args.firstIndex(of: "--"), "-- marker missing")
        #expect(args[ddIdx + 1] == "-7")
    }

    @Test("Model alias is passed verbatim after --model flag")
    func modelAliasIsPassedVerbatim() throws {
        let args = CLIEngine.buildArguments(
            message: "hi", modelAlias: "haiku", sessionId: nil
        )
        let mIdx = try #require(args.firstIndex(of: "--model"), "--model flag missing")
        #expect(args[mIdx + 1] == "haiku")
    }

    @Suite("Append system prompt")
    struct AppendSystemPrompt {
        @Test("Non-empty value adds --append-system-prompt flag")
        func appendSystemPromptAddsFlag() throws {
            let args = CLIEngine.buildArguments(
                message: "hi", modelAlias: "opus", sessionId: nil,
                appendSystemPrompt: "Extra context here"
            )
            let idx = try #require(
                args.firstIndex(of: "--append-system-prompt"),
                "--append-system-prompt flag missing"
            )
            #expect(args[idx + 1] == "Extra context here")
        }

        @Test(
            "Nil or empty value omits --append-system-prompt flag",
            arguments: [nil, ""] as [String?]
        )
        func omitsFlagForNilOrEmpty(value: String?) {
            let args = CLIEngine.buildArguments(
                message: "hi", modelAlias: "opus", sessionId: nil,
                appendSystemPrompt: value
            )
            #expect(!args.contains("--append-system-prompt"))
        }
    }
}
