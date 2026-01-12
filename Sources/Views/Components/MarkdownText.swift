import Foundation
import SwiftUI

struct MarkdownText: View {
  private let font: Font
  private let textAlignment: TextAlignment
  private let layoutDirection: LayoutDirection
  private let lineSpacing: CGFloat
  private let blocks: [MarkdownBlock]

  init(
    text: String,
    font: Font = TypeScale.body,
    textAlignment: TextAlignment = .leading,
    layoutDirection: LayoutDirection = .leftToRight,
    lineSpacing: CGFloat = 2
  ) {
    self.font = font
    self.textAlignment = textAlignment
    self.layoutDirection = layoutDirection
    self.lineSpacing = lineSpacing
    self.blocks = MarkdownParser.parseBlocks(from: MarkdownPreprocessor.normalize(text))
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 0) {
      ForEach(Array(blocks.enumerated()), id: \.element.id) { index, block in
        blockView(for: block)
          .padding(.top, topPadding(for: index))
      }
    }
    // Ensure flush left alignment - no indentation
    .frame(maxWidth: .infinity, alignment: .leading)
    .textSelection(.enabled)
    .foregroundStyle(.primary)
    .environment(\.layoutDirection, layoutDirection)
  }

  @ViewBuilder
  private func blockView(for block: MarkdownBlock) -> some View {
    switch block.kind {
    case .heading(let level, let content):
      headingView(level: level, content: content)
    case .paragraph(let content):
      paragraphView(content)
    case .orderedList(let items):
      orderedListView(items: items)
    case .unorderedList(let items):
      unorderedListView(items: items)
    }
  }

  private func headingView(level: Int, content: String) -> some View {
    Text(makeAttributedText(from: content))
      .font(fontForHeading(level))
      .fontWeight(.semibold)
      .multilineTextAlignment(textAlignment)
      .lineSpacing(lineSpacing)
      // Always use leading alignment for container to ensure flush left
      .frame(maxWidth: .infinity, alignment: .leading)
  }

  private func paragraphView(_ content: String) -> some View {
    Text(makeAttributedText(from: content))
      .font(font)
      .multilineTextAlignment(textAlignment)
      .lineSpacing(lineSpacing)
      // Always use leading alignment for container to ensure flush left
      .frame(maxWidth: .infinity, alignment: .leading)
  }

  private func orderedListView(items: [MarkdownListItem]) -> some View {
    return VStack(alignment: .leading, spacing: listItemSpacing) {
      ForEach(items) { item in
        HStack(alignment: .firstTextBaseline, spacing: Space.xs) {
          if let number = item.number {
            Text("\(number).")
              .font(font)
              .fontWeight(.semibold)
              .monospacedDigit()
          }
          Text(makeAttributedText(from: item.content))
            .font(font)
            .multilineTextAlignment(textAlignment)
            .lineSpacing(lineSpacing)
        }
      }
    }
    // Always use leading alignment for container to ensure flush left
    .frame(maxWidth: .infinity, alignment: .leading)
  }

  private func unorderedListView(items: [MarkdownListItem]) -> some View {
    return VStack(alignment: .leading, spacing: listItemSpacing) {
      ForEach(items) { item in
        HStack(alignment: .firstTextBaseline, spacing: Space.xs) {
          Text("•")
            .font(font)
            .fontWeight(.semibold)
          Text(makeAttributedText(from: item.content))
            .font(font)
            .multilineTextAlignment(textAlignment)
            .lineSpacing(lineSpacing)
        }
      }
    }
    // Always use leading alignment for container to ensure flush left
    .frame(maxWidth: .infinity, alignment: .leading)
  }

  private func fontForHeading(_ level: Int) -> Font {
    switch level {
    case 1:
      return TypeScale.title
    case 2:
      return TypeScale.headline
    case 3:
      return TypeScale.subhead
    default:
      return font
    }
  }

  private func topPadding(for index: Int) -> CGFloat {
    guard index > 0 else { return 0 }
    let previous = blocks[index - 1].kind
    let current = blocks[index].kind
    return spacing(between: previous, and: current)
  }

  private func spacing(between previous: MarkdownBlock.Kind, and current: MarkdownBlock.Kind)
    -> CGFloat
  {
    switch (previous, current) {
    case (.heading, .heading):
      return Space.sm
    case (.heading, .paragraph),
      (.heading, .orderedList),
      (.heading, .unorderedList):
      return Space.md
    case (.paragraph, .heading):
      return Space.lg
    case (.paragraph, .paragraph):
      return Space.sm
    case (.paragraph, .orderedList),
      (.paragraph, .unorderedList):
      return Space.md
    case (.orderedList, .paragraph),
      (.unorderedList, .paragraph):
      return Space.md
    case (.orderedList, .heading),
      (.unorderedList, .heading):
      return Space.lg
    case (.orderedList, .orderedList),
      (.unorderedList, .unorderedList):
      return Space.sm
    default:
      return Space.sm
    }
  }

  private var listItemSpacing: CGFloat {
    max(lineSpacing + 4, Space.sm)
  }

  private func makeAttributedText(from content: String) -> AttributedString {
    do {
      return try AttributedString(
        markdown: content,
        options: AttributedString.MarkdownParsingOptions(
          interpretedSyntax: .inlineOnlyPreservingWhitespace,
          failurePolicy: .returnPartiallyParsedIfPossible
        )
      )
    } catch {
      return AttributedString(content)
    }
  }
}

private struct MarkdownBlock: Identifiable {
  enum Kind: Hashable {
    case heading(level: Int, content: String)
    case paragraph(String)
    case orderedList([MarkdownListItem])
    case unorderedList([MarkdownListItem])
  }

  // Use stable ID based on content hash to prevent re-renders
  let id: Int
  let kind: Kind
  
  init(kind: Kind, index: Int) {
    self.kind = kind
    // Create stable ID from content hash and index
    var hasher = Hasher()
    hasher.combine(kind)
    hasher.combine(index)
    self.id = hasher.finalize()
  }
}

private struct MarkdownListItem: Identifiable, Hashable {
  // Use stable ID based on content
  let id: Int
  let number: Int?
  let content: String
  
  init(number: Int?, content: String) {
    self.number = number
    self.content = content
    // Create stable ID from content
    var hasher = Hasher()
    hasher.combine(number)
    hasher.combine(content)
    self.id = hasher.finalize()
  }
}

private enum MarkdownParser {
  static func parseBlocks(from markdown: String) -> [MarkdownBlock] {
    var blocks: [MarkdownBlock] = []
    let lines = markdown.components(separatedBy: .newlines)
    var index = 0

    while index < lines.count {
      let rawLine = lines[index]
      let trimmedLine = rawLine.trimmingCharacters(in: .whitespaces)

      if trimmedLine.isEmpty {
        index += 1
        continue
      }

      if let heading = headingInfo(from: trimmedLine) {
        blocks.append(
          MarkdownBlock(kind: .heading(level: heading.level, content: heading.content), index: blocks.count)
        )
        index += 1
        continue
      }

      if let orderedItem = orderedListItem(from: trimmedLine) {
        var items: [MarkdownListItem] = [
          MarkdownListItem(number: orderedItem.number, content: orderedItem.content)
        ]
        index += 1

        while index < lines.count {
          let candidate = lines[index].trimmingCharacters(in: .whitespaces)
          guard let nextItem = orderedListItem(from: candidate) else {
            break
          }
          items.append(
            MarkdownListItem(number: nextItem.number, content: nextItem.content)
          )
          index += 1
        }

        blocks.append(MarkdownBlock(kind: .orderedList(items), index: blocks.count))
        continue
      }

      if let unorderedItem = unorderedListItem(from: trimmedLine) {
        var items: [MarkdownListItem] = [
          MarkdownListItem(number: nil, content: unorderedItem)
        ]
        index += 1

        while index < lines.count {
          let candidate = lines[index].trimmingCharacters(in: .whitespaces)
          guard let nextItem = unorderedListItem(from: candidate) else {
            break
          }
          items.append(
            MarkdownListItem(number: nil, content: nextItem)
          )
          index += 1
        }

        blocks.append(MarkdownBlock(kind: .unorderedList(items), index: blocks.count))
        continue
      }

      var paragraphLines: [String] = [trimmedLine]
      index += 1

      while index < lines.count {
        let candidate = lines[index].trimmingCharacters(in: .whitespaces)
        if candidate.isEmpty {
          index += 1
          break
        }
        if headingInfo(from: candidate) != nil
          || orderedListItem(from: candidate) != nil
          || unorderedListItem(from: candidate) != nil
        {
          break
        }
        paragraphLines.append(candidate)
        index += 1
      }

      let paragraphText = paragraphLines.joined(separator: "\n")
      blocks.append(MarkdownBlock(kind: .paragraph(paragraphText), index: blocks.count))
    }

    return blocks
  }

  private static func headingInfo(from line: String) -> (level: Int, content: String)? {
    var level = 0
    var index = line.startIndex

    while index < line.endIndex && line[index] == "#" {
      level += 1
      index = line.index(after: index)
    }

    guard level > 0 && level <= 6 else {
      return nil
    }

    if index < line.endIndex && line[index] == " " {
      index = line.index(after: index)
    }

    let content = line[index...].trimmingCharacters(in: .whitespaces)
    return (level, content)
  }

  private static func orderedListItem(from line: String) -> (number: Int, content: String)? {
    guard let dotIndex = line.firstIndex(of: ".") else {
      return nil
    }

    let numberPart = line[..<dotIndex].trimmingCharacters(in: .whitespaces)

    guard let number = Int(numberPart) else {
      return nil
    }

    let contentStart = line.index(after: dotIndex)
    let content = line[contentStart...].trimmingCharacters(in: .whitespaces)

    guard !content.isEmpty else {
      return nil
    }

    return (number, content)
  }

  private static func unorderedListItem(from line: String) -> String? {
    if line.hasPrefix("- ") || line.hasPrefix("* ") {
      return String(line.dropFirst(2)).trimmingCharacters(in: .whitespaces)
    }
    return nil
  }
}

private enum MarkdownPreprocessor {
  static func normalize(_ raw: String) -> String {
    let newlineNormalized = raw.replacingOccurrences(of: "\r\n", with: "\n")
    let insertedOrderedBreaks = insertingBreaks(
      in: newlineNormalized,
      patterns: [
        #"(?<=\.)\s+(?=\d+\.)"#,
        #"(?<=[:;])\s+(?=\d+\.)"#,
        #"(?<=\))\s+(?=\d+\.)"#,
        #"\s{2,}(?=\d+\.)"#,
      ]
    )
    let insertedBulletBreaks = insertingBreaks(
      in: insertedOrderedBreaks,
      patterns: [
        #"(?<=\.)\s+(?=[-*•]\s)"#,
        #"(?<=[:;])\s+(?=[-*•]\s)"#,
        #"(?<=\d+\.)\s+(?=[-*•]\s)"#,
        #"(?<=\))\s+(?=[-*•]\s)"#,
        #"\s{2,}(?=[-*•]\s)"#,
      ]
    )
    let trimmedLeading = trimLeadingListWhitespace(in: insertedBulletBreaks)
    return collapseExcessBlankLines(in: trimmedLeading)
  }

  private static func insertingBreaks(in text: String, patterns: [String]) -> String {
    patterns.reduce(text) { partialResult, pattern in
      replaceMatches(of: pattern, in: partialResult, with: "\n")
    }
  }

  private static func trimLeadingListWhitespace(in text: String) -> String {
    let components = text.components(separatedBy: .newlines)
    let sanitized = components.map { line -> String in
      guard !line.isEmpty else { return line }
      if orderedListRegex.firstMatch(in: line, range: NSRange(line.startIndex..., in: line)) != nil
        || unorderedListRegex.firstMatch(in: line, range: NSRange(line.startIndex..., in: line))
          != nil
      {
        return line.trimmingCharacters(in: .whitespaces)
      }
      return line
    }
    return sanitized.joined(separator: "\n")
  }

  private static func collapseExcessBlankLines(in text: String) -> String {
    replaceMatches(of: #"\n{3,}"#, in: text, with: "\n\n")
  }

  private static func replaceMatches(of pattern: String, in text: String, with replacement: String)
    -> String
  {
    guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else {
      return text
    }
    let range = NSRange(text.startIndex..., in: text)
    return regex.stringByReplacingMatches(
      in: text, options: [], range: range, withTemplate: replacement)
  }

  private static let orderedListRegex: NSRegularExpression = try! NSRegularExpression(
    pattern: #"^\s*\d+\.\s"#,
    options: []
  )

  private static let unorderedListRegex: NSRegularExpression = try! NSRegularExpression(
    pattern: #"^\s*[-*•]\s"#,
    options: []
  )
}
