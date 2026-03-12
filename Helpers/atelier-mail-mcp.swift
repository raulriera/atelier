//
// atelier-mail-mcp — MCP server that controls Mail.app
// via JXA (JavaScript for Automation) through osascript.
//
// Built on MCPHelperKit — compiled alongside MCPHelperKit sources
// via multi-file swiftc. All JSON-RPC, JXA, and MCP boilerplate
// lives in the shared library.
//

import Foundation

// MARK: - Tool Definitions

func allTools() -> [ToolDefinition] {
    [
        // Read group
        ToolDefinition(
            name: "mail_list_mailboxes",
            description: "List all mailboxes (folders) across all configured email accounts in Mail.",
            inputSchema: .dict([
                "type": .string("object"),
                "properties": .dict([:])
            ])
        ),
        ToolDefinition(
            name: "mail_search_messages",
            description: "Search for email messages matching a query. Searches subject, sender, and content. Returns up to 25 results by default.",
            inputSchema: .dict([
                "type": .string("object"),
                "properties": .dict([
                    "query": .dict([
                        "type": .string("string"),
                        "description": .string("Search query to match against message subject, sender, and content")
                    ]),
                    "mailbox": .dict([
                        "type": .string("string"),
                        "description": .string("Mailbox name to search in (e.g. \"INBOX\"). Searches all mailboxes if omitted.")
                    ]),
                    "account": .dict([
                        "type": .string("string"),
                        "description": .string("Account name to search in. Searches all accounts if omitted.")
                    ]),
                    "limit": .dict([
                        "type": .string("integer"),
                        "description": .string("Maximum number of results to return. Defaults to 25.")
                    ])
                ]),
                "required": .array([.string("query")])
            ])
        ),
        ToolDefinition(
            name: "mail_get_message",
            description: "Get the full content of an email message by its message ID. Returns sender, recipients, subject, date, and body.",
            inputSchema: .dict([
                "type": .string("object"),
                "properties": .dict([
                    "messageId": .dict([
                        "type": .string("string"),
                        "description": .string("The message ID to retrieve")
                    ])
                ]),
                "required": .array([.string("messageId")])
            ])
        ),

        // Manage group
        ToolDefinition(
            name: "mail_move_message",
            description: "Move an email message to a different mailbox.",
            inputSchema: .dict([
                "type": .string("object"),
                "properties": .dict([
                    "messageId": .dict([
                        "type": .string("string"),
                        "description": .string("The message ID to move")
                    ]),
                    "targetMailbox": .dict([
                        "type": .string("string"),
                        "description": .string("The destination mailbox name (e.g. \"Archive\", \"Trash\")")
                    ]),
                    "targetAccount": .dict([
                        "type": .string("string"),
                        "description": .string("The account containing the target mailbox. Uses the message's account if omitted.")
                    ])
                ]),
                "required": .array([.string("messageId"), .string("targetMailbox")])
            ])
        ),
        ToolDefinition(
            name: "mail_mark_read",
            description: "Mark an email message as read or unread.",
            inputSchema: .dict([
                "type": .string("object"),
                "properties": .dict([
                    "messageId": .dict([
                        "type": .string("string"),
                        "description": .string("The message ID to update")
                    ]),
                    "read": .dict([
                        "type": .string("boolean"),
                        "description": .string("Set to true to mark as read, false to mark as unread. Defaults to true.")
                    ])
                ]),
                "required": .array([.string("messageId")])
            ])
        ),
        ToolDefinition(
            name: "mail_flag_message",
            description: "Flag or unflag an email message.",
            inputSchema: .dict([
                "type": .string("object"),
                "properties": .dict([
                    "messageId": .dict([
                        "type": .string("string"),
                        "description": .string("The message ID to update")
                    ]),
                    "flagged": .dict([
                        "type": .string("boolean"),
                        "description": .string("Set to true to flag, false to unflag. Defaults to true.")
                    ])
                ]),
                "required": .array([.string("messageId")])
            ])
        ),
        ToolDefinition(
            name: "mail_delete_message",
            description: "Delete an email message (moves it to Trash).",
            inputSchema: .dict([
                "type": .string("object"),
                "properties": .dict([
                    "messageId": .dict([
                        "type": .string("string"),
                        "description": .string("The message ID to delete")
                    ])
                ]),
                "required": .array([.string("messageId")])
            ])
        ),

        // Send group
        ToolDefinition(
            name: "mail_create_draft",
            description: "Create a new email draft in Mail. The draft will be saved but not sent.",
            inputSchema: .dict([
                "type": .string("object"),
                "properties": .dict([
                    "to": .dict([
                        "type": .string("string"),
                        "description": .string("Recipient email address(es), comma-separated for multiple")
                    ]),
                    "subject": .dict([
                        "type": .string("string"),
                        "description": .string("Email subject line")
                    ]),
                    "body": .dict([
                        "type": .string("string"),
                        "description": .string("Email body text")
                    ]),
                    "cc": .dict([
                        "type": .string("string"),
                        "description": .string("CC recipient(s), comma-separated")
                    ]),
                    "bcc": .dict([
                        "type": .string("string"),
                        "description": .string("BCC recipient(s), comma-separated")
                    ]),
                    "account": .dict([
                        "type": .string("string"),
                        "description": .string("Account to send from. Uses the default account if omitted.")
                    ])
                ]),
                "required": .array([.string("to"), .string("subject"), .string("body")])
            ])
        ),
        ToolDefinition(
            name: "mail_send_message",
            description: "Create and immediately send an email message.",
            inputSchema: .dict([
                "type": .string("object"),
                "properties": .dict([
                    "to": .dict([
                        "type": .string("string"),
                        "description": .string("Recipient email address(es), comma-separated for multiple")
                    ]),
                    "subject": .dict([
                        "type": .string("string"),
                        "description": .string("Email subject line")
                    ]),
                    "body": .dict([
                        "type": .string("string"),
                        "description": .string("Email body text")
                    ]),
                    "cc": .dict([
                        "type": .string("string"),
                        "description": .string("CC recipient(s), comma-separated")
                    ]),
                    "bcc": .dict([
                        "type": .string("string"),
                        "description": .string("BCC recipient(s), comma-separated")
                    ]),
                    "account": .dict([
                        "type": .string("string"),
                        "description": .string("Account to send from. Uses the default account if omitted.")
                    ])
                ]),
                "required": .array([.string("to"), .string("subject"), .string("body")])
            ])
        ),
    ]
}

// MARK: - Tool Handlers

func handleToolCall(name: String, args: [String: AnyCodableValue]) -> (String, Bool) {
    switch name {
    case "mail_list_mailboxes":
        let script = """
        var app = Application("Mail");
        var results = [];
        var accounts = app.accounts();
        for (var a = 0; a < accounts.length; a++) {
            var acct = accounts[a];
            var mailboxes = acct.mailboxes();
            for (var m = 0; m < mailboxes.length; m++) {
                results.push(acct.name() + " / " + mailboxes[m].name());
            }
        }
        results.length > 0 ? results.join("\\n") : "No mailboxes found";
        """
        let result = executeJXA(script)
        if result.exitCode != 0 {
            return ("Error listing mailboxes: \(result.error)", true)
        }
        return (result.output, false)

    case "mail_search_messages":
        guard let query = args["query"]?.stringValue else {
            return ("Missing required parameter: query", true)
        }
        let limit = args["limit"]?.intValue ?? 25
        let safeQuery = jxaEscape(query)
        let mailboxFilter: String
        if let mailbox = args["mailbox"]?.stringValue {
            let accountFilter: String
            if let account = args["account"]?.stringValue {
                accountFilter = "app.accounts.byName(\"\(jxaEscape(account))\")"
            } else {
                accountFilter = "app.accounts[0]"
            }
            mailboxFilter = "\(accountFilter).mailboxes.byName(\"\(jxaEscape(mailbox))\")"
        } else {
            mailboxFilter = "null"
        }
        let script = """
        var app = Application("Mail");
        var query = "\(safeQuery)".toLowerCase();
        var limit = \(limit);
        var results = [];
        var mailbox = \(mailboxFilter);
        var messages;
        if (mailbox) {
            messages = mailbox.messages();
        } else {
            messages = app.inbox.messages();
        }
        var count = Math.min(messages.length, 200);
        for (var i = 0; i < count && results.length < limit; i++) {
            try {
                var msg = messages[i];
                var subject = msg.subject() || "";
                var sender = msg.sender() || "";
                if (subject.toLowerCase().indexOf(query) !== -1 || sender.toLowerCase().indexOf(query) !== -1) {
                    var date = msg.dateReceived();
                    var dateStr = date ? date.toISOString() : "unknown";
                    var read = msg.readStatus() ? "read" : "unread";
                    var flagged = msg.flaggedStatus() ? " [flagged]" : "";
                    results.push(msg.id() + " | " + dateStr + " | " + sender + " | " + subject + " (" + read + ")" + flagged);
                }
            } catch(e) { continue; }
        }
        results.length > 0 ? results.join("\\n") : "No messages found matching: " + query;
        """
        let result = executeJXA(script)
        if result.exitCode != 0 {
            return ("Error searching messages: \(result.error)", true)
        }
        return (result.output, false)

    case "mail_get_message":
        guard let messageId = args["messageId"]?.stringValue else {
            return ("Missing required parameter: messageId", true)
        }
        let safeId = jxaEscape(messageId)
        let script = """
        var app = Application("Mail");
        var msg = null;
        var accounts = app.accounts();
        outer:
        for (var a = 0; a < accounts.length; a++) {
            var mailboxes = accounts[a].mailboxes();
            for (var m = 0; m < mailboxes.length; m++) {
                var messages = mailboxes[m].messages();
                for (var i = 0; i < messages.length; i++) {
                    try {
                        if (String(messages[i].id()) === "\(safeId)") {
                            msg = messages[i];
                            break outer;
                        }
                    } catch(e) { continue; }
                }
            }
        }
        if (!msg) {
            "Message not found: \(safeId)";
        } else {
            var subject = msg.subject() || "(no subject)";
            var sender = msg.sender() || "(unknown)";
            var date = msg.dateReceived();
            var dateStr = date ? date.toISOString() : "unknown";
            var toRecips = msg.toRecipients();
            var toList = [];
            for (var t = 0; t < toRecips.length; t++) {
                toList.push(toRecips[t].address());
            }
            var ccRecips = msg.ccRecipients();
            var ccList = [];
            for (var c = 0; c < ccRecips.length; c++) {
                ccList.push(ccRecips[c].address());
            }
            var body = msg.content() || "(empty body)";
            if (body.length > \(maxContentLength)) {
                body = body.substring(0, \(maxContentLength)) + "\\n... (content truncated)";
            }
            "From: " + sender + "\\nTo: " + toList.join(", ") + (ccList.length > 0 ? "\\nCC: " + ccList.join(", ") : "") + "\\nDate: " + dateStr + "\\nSubject: " + subject + "\\n\\n" + body;
        }
        """
        let result = executeJXA(script)
        if result.exitCode != 0 {
            return ("Error getting message: \(result.error)", true)
        }
        return (result.output, false)

    case "mail_move_message":
        guard let messageId = args["messageId"]?.stringValue,
              let targetMailbox = args["targetMailbox"]?.stringValue else {
            return ("Missing required parameters: messageId, targetMailbox", true)
        }
        let safeId = jxaEscape(messageId)
        let safeTarget = jxaEscape(targetMailbox)
        let accountSelector: String
        if let account = args["targetAccount"]?.stringValue {
            accountSelector = "app.accounts.byName(\"\(jxaEscape(account))\")"
        } else {
            // Find the account that owns this message
            accountSelector = "msgAccount"
        }
        let script = """
        var app = Application("Mail");
        var msg = null;
        var msgAccount = null;
        var accounts = app.accounts();
        outer:
        for (var a = 0; a < accounts.length; a++) {
            var mailboxes = accounts[a].mailboxes();
            for (var m = 0; m < mailboxes.length; m++) {
                var messages = mailboxes[m].messages();
                for (var i = 0; i < messages.length; i++) {
                    try {
                        if (String(messages[i].id()) === "\(safeId)") {
                            msg = messages[i];
                            msgAccount = accounts[a];
                            break outer;
                        }
                    } catch(e) { continue; }
                }
            }
        }
        if (!msg) {
            "Message not found: \(safeId)";
        } else {
            var target = \(accountSelector).mailboxes.byName("\(safeTarget)");
            msg.mailbox = target;
            "Moved message to \(safeTarget)";
        }
        """
        let result = executeJXA(script)
        if result.exitCode != 0 {
            return ("Error moving message: \(result.error)", true)
        }
        return (result.output, false)

    case "mail_mark_read":
        guard let messageId = args["messageId"]?.stringValue else {
            return ("Missing required parameter: messageId", true)
        }
        let read = args["read"]?.boolValue ?? true
        let safeId = jxaEscape(messageId)
        let script = """
        var app = Application("Mail");
        var accounts = app.accounts();
        var found = false;
        outer:
        for (var a = 0; a < accounts.length; a++) {
            var mailboxes = accounts[a].mailboxes();
            for (var m = 0; m < mailboxes.length; m++) {
                var messages = mailboxes[m].messages();
                for (var i = 0; i < messages.length; i++) {
                    try {
                        if (String(messages[i].id()) === "\(safeId)") {
                            messages[i].readStatus = \(read);
                            found = true;
                            break outer;
                        }
                    } catch(e) { continue; }
                }
            }
        }
        found ? "Marked message as \(read ? "read" : "unread")" : "Message not found: \(safeId)";
        """
        let result = executeJXA(script)
        if result.exitCode != 0 {
            return ("Error marking message: \(result.error)", true)
        }
        return (result.output, false)

    case "mail_flag_message":
        guard let messageId = args["messageId"]?.stringValue else {
            return ("Missing required parameter: messageId", true)
        }
        let flagged = args["flagged"]?.boolValue ?? true
        let safeId = jxaEscape(messageId)
        let script = """
        var app = Application("Mail");
        var accounts = app.accounts();
        var found = false;
        outer:
        for (var a = 0; a < accounts.length; a++) {
            var mailboxes = accounts[a].mailboxes();
            for (var m = 0; m < mailboxes.length; m++) {
                var messages = mailboxes[m].messages();
                for (var i = 0; i < messages.length; i++) {
                    try {
                        if (String(messages[i].id()) === "\(safeId)") {
                            messages[i].flaggedStatus = \(flagged);
                            found = true;
                            break outer;
                        }
                    } catch(e) { continue; }
                }
            }
        }
        found ? "\(flagged ? "Flagged" : "Unflagged") message" : "Message not found: \(safeId)";
        """
        let result = executeJXA(script)
        if result.exitCode != 0 {
            return ("Error flagging message: \(result.error)", true)
        }
        return (result.output, false)

    case "mail_delete_message":
        guard let messageId = args["messageId"]?.stringValue else {
            return ("Missing required parameter: messageId", true)
        }
        let safeId = jxaEscape(messageId)
        let script = """
        var app = Application("Mail");
        var accounts = app.accounts();
        var found = false;
        outer:
        for (var a = 0; a < accounts.length; a++) {
            var mailboxes = accounts[a].mailboxes();
            for (var m = 0; m < mailboxes.length; m++) {
                var messages = mailboxes[m].messages();
                for (var i = 0; i < messages.length; i++) {
                    try {
                        if (String(messages[i].id()) === "\(safeId)") {
                            messages[i].delete();
                            found = true;
                            break outer;
                        }
                    } catch(e) { continue; }
                }
            }
        }
        found ? "Deleted message" : "Message not found: \(safeId)";
        """
        let result = executeJXA(script)
        if result.exitCode != 0 {
            return ("Error deleting message: \(result.error)", true)
        }
        return (result.output, false)

    case "mail_create_draft":
        guard let to = args["to"]?.stringValue,
              let subject = args["subject"]?.stringValue,
              let body = args["body"]?.stringValue else {
            return ("Missing required parameters: to, subject, body", true)
        }
        let cc = args["cc"]?.stringValue
        let bcc = args["bcc"]?.stringValue
        let script = buildComposeScript(to: to, subject: subject, body: body, cc: cc, bcc: bcc, send: false)
        let result = executeJXA(script)
        if result.exitCode != 0 {
            return ("Error creating draft: \(result.error)", true)
        }
        return (result.output, false)

    case "mail_send_message":
        guard let to = args["to"]?.stringValue,
              let subject = args["subject"]?.stringValue,
              let body = args["body"]?.stringValue else {
            return ("Missing required parameters: to, subject, body", true)
        }
        let cc = args["cc"]?.stringValue
        let bcc = args["bcc"]?.stringValue
        let script = buildComposeScript(to: to, subject: subject, body: body, cc: cc, bcc: bcc, send: true)
        let result = executeJXA(script)
        if result.exitCode != 0 {
            return ("Error sending message: \(result.error)", true)
        }
        return (result.output, false)

    default:
        return ("Unknown tool: \(name)", true)
    }
}

// MARK: - Compose Helper

/// Builds a JXA script for creating/sending an email.
func buildComposeScript(to: String, subject: String, body: String, cc: String?, bcc: String?, send: Bool) -> String {
    let safeTo = jxaEscape(to)
    let safeSubject = jxaEscape(subject)
    let safeBody = jxaEscape(body)

    var recipientLines = """
    var toAddresses = "\(safeTo)".split(",");
    for (var i = 0; i < toAddresses.length; i++) {
        var addr = toAddresses[i].trim();
        if (addr.length > 0) {
            var recip = app.ToRecipient({address: addr});
            msg.toRecipients.push(recip);
        }
    }
    """

    if let cc {
        let safeCc = jxaEscape(cc)
        recipientLines += """

        var ccAddresses = "\(safeCc)".split(",");
        for (var j = 0; j < ccAddresses.length; j++) {
            var ccAddr = ccAddresses[j].trim();
            if (ccAddr.length > 0) {
                var ccRecip = app.CcRecipient({address: ccAddr});
                msg.ccRecipients.push(ccRecip);
            }
        }
        """
    }

    if let bcc {
        let safeBcc = jxaEscape(bcc)
        recipientLines += """

        var bccAddresses = "\(safeBcc)".split(",");
        for (var k = 0; k < bccAddresses.length; k++) {
            var bccAddr = bccAddresses[k].trim();
            if (bccAddr.length > 0) {
                var bccRecip = app.BccRecipient({address: bccAddr});
                msg.bccRecipients.push(bccRecip);
            }
        }
        """
    }

    let sendLine = send
        ? "msg.send(); \"Sent message to \" + \"\(safeTo)\" + \" with subject: \" + \"\(safeSubject)\";"
        : "\"Draft created for \" + \"\(safeTo)\" + \" with subject: \" + \"\(safeSubject)\";"

    return """
    var app = Application("Mail");
    var msg = app.OutgoingMessage({
        subject: "\(safeSubject)",
        content: "\(safeBody)"
    });
    app.outgoingMessages.push(msg);
    \(recipientLines)
    \(sendLine)
    """
}

// MARK: - Entry Point

@main enum MailHelper { static func main() { MCPServer.run(name: "mail", tools: allTools(), handler: handleToolCall) } }
