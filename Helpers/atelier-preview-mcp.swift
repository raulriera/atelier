//
// atelier-preview-mcp — MCP server for PDF operations
// using PDFKit (no JXA needed).
//
// Compiled alongside MCPHelperKit sources via multi-file swiftc.
// Boilerplate (JSON-RPC, transport, main loop) lives in MCPHelperKit.
//

import Foundation
import Quartz

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

// MARK: - Entry Point

@main enum PreviewHelper { static func main() { MCPServer.run(name: "preview", tools: allTools(), handler: handleToolCall) } }
