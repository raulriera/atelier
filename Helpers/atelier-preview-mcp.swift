#!/usr/bin/env swift
//
// atelier-preview-mcp — MCP server for PDF operations
// using PDFKit (no JXA needed).
//
// Speaks JSON-RPC 2.0 over stdio. The Claude CLI launches this as a child
// process and discovers the tools via `tools/list`.
//

import Foundation
import Quartz

// MARK: - JSON-RPC types

struct JSONRPCRequest: Codable {
    let jsonrpc: String
    let id: AnyCodableValue?
    let method: String
    let params: AnyCodableValue?
}

struct JSONRPCResponse: Codable {
    let jsonrpc: String
    let id: AnyCodableValue?
    let result: AnyCodableValue?
    let error: JSONRPCError?
}

struct JSONRPCError: Codable {
    let code: Int
    let message: String
}

/// A type-erased Codable value for JSON-RPC params/results.
enum AnyCodableValue: Codable {
    case string(String)
    case int(Int)
    case double(Double)
    case bool(Bool)
    case dict([String: AnyCodableValue])
    case array([AnyCodableValue])
    case null

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() {
            self = .null
        } else if let v = try? container.decode(Bool.self) {
            self = .bool(v)
        } else if let v = try? container.decode(Int.self) {
            self = .int(v)
        } else if let v = try? container.decode(Double.self) {
            self = .double(v)
        } else if let v = try? container.decode(String.self) {
            self = .string(v)
        } else if let v = try? container.decode([String: AnyCodableValue].self) {
            self = .dict(v)
        } else if let v = try? container.decode([AnyCodableValue].self) {
            self = .array(v)
        } else {
            self = .null
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .string(let v): try container.encode(v)
        case .int(let v): try container.encode(v)
        case .double(let v): try container.encode(v)
        case .bool(let v): try container.encode(v)
        case .dict(let v): try container.encode(v)
        case .array(let v): try container.encode(v)
        case .null: try container.encodeNil()
        }
    }

    var stringValue: String? {
        if case .string(let v) = self { return v }
        return nil
    }

    var intValue: Int? {
        if case .int(let v) = self { return v }
        return nil
    }

    var boolValue: Bool? {
        if case .bool(let v) = self { return v }
        return nil
    }

    var dictValue: [String: AnyCodableValue]? {
        if case .dict(let v) = self { return v }
        return nil
    }

    var arrayValue: [AnyCodableValue]? {
        if case .array(let v) = self { return v }
        return nil
    }
}

// MARK: - Path Resolution

/// Resolves a user-provided path against the working directory.
/// Absolute paths are returned as-is; relative paths are resolved
/// against `ATELIER_WORKING_DIRECTORY`.
func resolvePath(_ path: String) -> String {
    if path.hasPrefix("/") || path.hasPrefix("~") {
        return (path as NSString).expandingTildeInPath
    }
    let cwd = ProcessInfo.processInfo.environment["ATELIER_WORKING_DIRECTORY"]
        ?? FileManager.default.currentDirectoryPath
    return (cwd as NSString).appendingPathComponent(path)
}

// MARK: - Tool Definitions

struct ToolDefinition {
    let name: String
    let description: String
    let inputSchema: AnyCodableValue
}

func allTools() -> [ToolDefinition] {
    [
        // Read group
        ToolDefinition(
            name: "pdf_info",
            description: "Get information about a PDF file: page count, page size, title, author, and other metadata.",
            inputSchema: .dict([
                "type": .string("object"),
                "properties": .dict([
                    "path": .dict([
                        "type": .string("string"),
                        "description": .string("Path to the PDF file")
                    ])
                ]),
                "required": .array([.string("path")])
            ])
        ),
        ToolDefinition(
            name: "pdf_extract_text",
            description: "Extract text content from a PDF. Can extract from specific pages or the entire document.",
            inputSchema: .dict([
                "type": .string("object"),
                "properties": .dict([
                    "path": .dict([
                        "type": .string("string"),
                        "description": .string("Path to the PDF file")
                    ]),
                    "pages": .dict([
                        "type": .string("string"),
                        "description": .string("Page range to extract (e.g. \"1-5\", \"3\", \"1,3,5-7\"). Extracts all pages if omitted.")
                    ]),
                    "maxLength": .dict([
                        "type": .string("integer"),
                        "description": .string("Maximum characters to return. Defaults to 50000.")
                    ])
                ]),
                "required": .array([.string("path")])
            ])
        ),

        // Transform group
        ToolDefinition(
            name: "pdf_merge",
            description: "Merge multiple PDF files into a single PDF.",
            inputSchema: .dict([
                "type": .string("object"),
                "properties": .dict([
                    "inputs": .dict([
                        "type": .string("array"),
                        "items": .dict(["type": .string("string")]),
                        "description": .string("Array of paths to PDF files to merge, in order")
                    ]),
                    "outputPath": .dict([
                        "type": .string("string"),
                        "description": .string("Path for the merged output PDF. Defaults to 'merged.pdf' in the working directory.")
                    ])
                ]),
                "required": .array([.string("inputs")])
            ])
        ),
        ToolDefinition(
            name: "pdf_split",
            description: "Extract specific pages from a PDF into a new PDF file.",
            inputSchema: .dict([
                "type": .string("object"),
                "properties": .dict([
                    "path": .dict([
                        "type": .string("string"),
                        "description": .string("Path to the source PDF file")
                    ]),
                    "pages": .dict([
                        "type": .string("string"),
                        "description": .string("Page range to extract (e.g. \"1-5\", \"3\", \"1,3,5-7\")")
                    ]),
                    "outputPath": .dict([
                        "type": .string("string"),
                        "description": .string("Path for the output PDF. Defaults to '<source>-pages.pdf'.")
                    ])
                ]),
                "required": .array([.string("path"), .string("pages")])
            ])
        ),
    ]
}

// MARK: - Page Range Parsing

/// Parses a page range string like "1-5", "3", "1,3,5-7" into an array of
/// zero-based page indices. Returns nil on invalid input.
func parsePageRange(_ range: String, pageCount: Int) -> [Int]? {
    var indices: [Int] = []
    let parts = range.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
    for part in parts {
        if part.contains("-") {
            let bounds = part.split(separator: "-").map { $0.trimmingCharacters(in: .whitespaces) }
            guard bounds.count == 2,
                  let start = Int(bounds[0]),
                  let end = Int(bounds[1]),
                  start >= 1, end >= start, end <= pageCount else {
                return nil
            }
            for i in start...end { indices.append(i - 1) }
        } else {
            guard let page = Int(part), page >= 1, page <= pageCount else {
                return nil
            }
            indices.append(page - 1)
        }
    }
    return indices.isEmpty ? nil : indices
}

// MARK: - Tool Handlers

func handleToolCall(name: String, args: [String: AnyCodableValue]) -> (String, Bool) {
    switch name {
    case "pdf_info":
        guard let path = args["path"]?.stringValue else {
            return ("Missing required parameter: path", true)
        }
        let resolved = resolvePath(path)
        guard let doc = PDFDocument(url: URL(fileURLWithPath: resolved)) else {
            return ("Could not open PDF: \(path)", true)
        }
        var lines: [String] = []
        lines.append("File: \(resolved)")
        lines.append("Pages: \(doc.pageCount)")
        if let page = doc.page(at: 0) {
            let bounds = page.bounds(for: .mediaBox)
            lines.append("Page size: \(Int(bounds.width)) x \(Int(bounds.height)) points")
        }
        if let attrs = doc.documentAttributes {
            if let title = attrs[PDFDocumentAttribute.titleAttribute] as? String, !title.isEmpty {
                lines.append("Title: \(title)")
            }
            if let author = attrs[PDFDocumentAttribute.authorAttribute] as? String, !author.isEmpty {
                lines.append("Author: \(author)")
            }
            if let subject = attrs[PDFDocumentAttribute.subjectAttribute] as? String, !subject.isEmpty {
                lines.append("Subject: \(subject)")
            }
            if let creator = attrs[PDFDocumentAttribute.creatorAttribute] as? String, !creator.isEmpty {
                lines.append("Creator: \(creator)")
            }
        }
        lines.append("Encrypted: \(doc.isEncrypted)")
        return (lines.joined(separator: "\n"), false)

    case "pdf_extract_text":
        guard let path = args["path"]?.stringValue else {
            return ("Missing required parameter: path", true)
        }
        let resolved = resolvePath(path)
        let maxLength = args["maxLength"]?.intValue ?? 50000
        guard let doc = PDFDocument(url: URL(fileURLWithPath: resolved)) else {
            return ("Could not open PDF: \(path)", true)
        }

        let pageIndices: [Int]
        if let pagesStr = args["pages"]?.stringValue {
            guard let parsed = parsePageRange(pagesStr, pageCount: doc.pageCount) else {
                return ("Invalid page range: \(pagesStr). Document has \(doc.pageCount) pages.", true)
            }
            pageIndices = parsed
        } else {
            pageIndices = Array(0..<doc.pageCount)
        }

        var text = ""
        for idx in pageIndices {
            guard let page = doc.page(at: idx) else { continue }
            if let pageText = page.string {
                text += "--- Page \(idx + 1) ---\n"
                text += pageText
                text += "\n\n"
            }
            if text.count >= maxLength {
                text = String(text.prefix(maxLength))
                text += "\n\n[Truncated at \(maxLength) characters]"
                break
            }
        }
        return (text.isEmpty ? "No text found in the specified pages." : text, false)

    case "pdf_merge":
        guard let inputsArray = args["inputs"]?.arrayValue else {
            return ("Missing required parameter: inputs (array of PDF paths)", true)
        }
        let paths = inputsArray.compactMap(\.stringValue)
        guard paths.count >= 2 else {
            return ("At least 2 PDF files are required for merging.", true)
        }

        let outputPath: String
        if let out = args["outputPath"]?.stringValue {
            outputPath = resolvePath(out)
        } else {
            outputPath = resolvePath("merged.pdf")
        }

        let merged = PDFDocument()
        var totalPages = 0
        for path in paths {
            let resolved = resolvePath(path)
            guard let doc = PDFDocument(url: URL(fileURLWithPath: resolved)) else {
                return ("Could not open PDF: \(path)", true)
            }
            for i in 0..<doc.pageCount {
                guard let page = doc.page(at: i) else { continue }
                merged.insert(page, at: totalPages)
                totalPages += 1
            }
        }

        guard merged.write(toFile: outputPath) else {
            return ("Failed to write merged PDF to: \(outputPath)", true)
        }
        return ("Merged \(paths.count) PDFs (\(totalPages) pages) into: \(outputPath)", false)

    case "pdf_split":
        guard let path = args["path"]?.stringValue,
              let pagesStr = args["pages"]?.stringValue else {
            return ("Missing required parameters: path, pages", true)
        }
        let resolved = resolvePath(path)
        guard let doc = PDFDocument(url: URL(fileURLWithPath: resolved)) else {
            return ("Could not open PDF: \(path)", true)
        }
        guard let pageIndices = parsePageRange(pagesStr, pageCount: doc.pageCount) else {
            return ("Invalid page range: \(pagesStr). Document has \(doc.pageCount) pages.", true)
        }

        let outputPath: String
        if let out = args["outputPath"]?.stringValue {
            outputPath = resolvePath(out)
        } else {
            let base = (resolved as NSString).deletingPathExtension
            outputPath = "\(base)-pages.pdf"
        }

        let result = PDFDocument()
        for (i, idx) in pageIndices.enumerated() {
            guard let page = doc.page(at: idx) else { continue }
            result.insert(page, at: i)
        }

        guard result.write(toFile: outputPath) else {
            return ("Failed to write split PDF to: \(outputPath)", true)
        }
        return ("Extracted \(pageIndices.count) pages from \(path) into: \(outputPath)", false)

    default:
        return ("Unknown tool: \(name)", true)
    }
}

// MARK: - MCP request handling

func respond(id: AnyCodableValue?, result: AnyCodableValue) {
    let response = JSONRPCResponse(jsonrpc: "2.0", id: id, result: result, error: nil)
    guard let data = try? JSONEncoder().encode(response) else { return }
    var output = data
    output.append(contentsOf: "\n".utf8)
    FileHandle.standardOutput.write(output)
}

func respondError(id: AnyCodableValue?, code: Int, message: String) {
    let response = JSONRPCResponse(
        jsonrpc: "2.0", id: id, result: nil,
        error: JSONRPCError(code: code, message: message)
    )
    guard let data = try? JSONEncoder().encode(response) else { return }
    var output = data
    output.append(contentsOf: "\n".utf8)
    FileHandle.standardOutput.write(output)
}

func handleInitialize(id: AnyCodableValue?) {
    respond(id: id, result: .dict([
        "protocolVersion": .string("2024-11-05"),
        "capabilities": .dict([
            "tools": .dict([:])
        ]),
        "serverInfo": .dict([
            "name": .string("atelier-preview"),
            "version": .string("1.0.0")
        ])
    ]))
}

func handleToolsList(id: AnyCodableValue?) {
    let tools = allTools().map { tool -> AnyCodableValue in
        .dict([
            "name": .string(tool.name),
            "description": .string(tool.description),
            "inputSchema": tool.inputSchema
        ])
    }
    respond(id: id, result: .dict([
        "tools": .array(tools)
    ]))
}

func handleToolsCall(id: AnyCodableValue?, params: AnyCodableValue?) {
    guard let dict = params?.dictValue,
          let toolName = dict["name"]?.stringValue else {
        respondError(id: id, code: -32602, message: "Invalid parameters: missing tool name")
        return
    }

    let args = dict["arguments"]?.dictValue ?? [:]

    FileHandle.standardError.write(Data("preview: calling \(toolName)\n".utf8))

    let (output, isError) = handleToolCall(name: toolName, args: args)

    FileHandle.standardError.write(Data("preview: \(toolName) -> \(isError ? "error" : "ok")\n".utf8))

    if isError {
        respond(id: id, result: .dict([
            "content": .array([
                .dict([
                    "type": .string("text"),
                    "text": .string(output)
                ])
            ]),
            "isError": .bool(true)
        ]))
    } else {
        respond(id: id, result: .dict([
            "content": .array([
                .dict([
                    "type": .string("text"),
                    "text": .string(output)
                ])
            ])
        ]))
    }
}

// MARK: - Main loop

while let line = readLine(strippingNewline: true) {
    guard let data = line.data(using: .utf8),
          let request = try? JSONDecoder().decode(JSONRPCRequest.self, from: data) else {
        continue
    }

    switch request.method {
    case "initialize":
        handleInitialize(id: request.id)

    case "notifications/initialized":
        break

    case "tools/list":
        handleToolsList(id: request.id)

    case "tools/call":
        handleToolsCall(id: request.id, params: request.params)

    default:
        respondError(id: request.id, code: -32601, message: "Method not found: \(request.method)")
    }
}
