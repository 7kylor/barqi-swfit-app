import Foundation

enum TextSanitizer {
  /// Sanitizes assistant text for UI display:
  /// - Removes thinking content (<think>...</think>)
  /// - Removes ChatML special tokens
  /// - Truncates at conversation turn markers (User:, Human:, etc.)
  /// - Removes line-leading "Assistant:" prefixes
  /// - Deduplicates consecutive identical lines/paragraphs
  /// - Collapses excessive blank lines
  /// - Trims outer whitespace
  static func sanitizeAssistantText(_ text: String) -> String {
    let withoutThinking = removeThinkingContent(from: text)
    let withoutTokens = removeChatMLTokens(from: withoutThinking)
    let truncated = truncateAtConversationMarkers(withoutTokens)
    let withoutPrefixes = removeAssistantPrefixes(from: truncated)
    let withoutMeta = removeMetaCommentary(from: withoutPrefixes)
    let dedupedLines = deduplicateConsecutiveLines(in: withoutMeta)
    let collapsed = collapseBlankLines(in: dedupedLines)
    return collapsed.trimmingCharacters(in: .whitespacesAndNewlines)
  }
  
  /// Truncate text at conversation turn markers - model should only output one response
  private static func truncateAtConversationMarkers(_ text: String) -> String {
    // Note: "###" was removed as it conflicts with markdown headings (### Heading)
    // Only truncate at actual conversation role markers
    let markers = [
      "\nUser:",
      "\nuser:",
      "\nHuman:",
      "\nhuman:",
      "\nAssistant:",
      "\nassistant:",
      "\n\nUser:",
      "\n\nHuman:",
    ]
    
    var result = text
    for marker in markers {
      if let range = result.range(of: marker, options: .caseInsensitive) {
        result = String(result[..<range.lowerBound])
      }
    }
    
    // Also check if the output ends with role markers (with colon) at the end
    // This can happen when the model outputs "... User:" at the end
    let suffixes = ["User:", "user:", "Human:", "human:", "Assistant:", "assistant:"]
    for suffix in suffixes {
      if result.hasSuffix(suffix) || result.hasSuffix(" " + suffix) {
        if let range = result.range(of: suffix, options: [.backwards, .caseInsensitive]) {
          result = String(result[..<range.lowerBound])
        }
      }
    }
    
    return result
  }
  
  /// Remove meta-commentary like "Note:" that shouldn't be in responses
  private static func removeMetaCommentary(from text: String) -> String {
    var result = text
    
    // Remove lines starting with "Note:" (meta-commentary)
    let lines = result.components(separatedBy: .newlines)
    let filtered = lines.filter { line in
      let trimmed = line.trimmingCharacters(in: .whitespaces).lowercased()
      return !trimmed.hasPrefix("note:")
    }
    result = filtered.joined(separator: "\n")
    
    return result
  }
  
  /// Remove <think>...</think> blocks from text
  private static func removeThinkingContent(from text: String) -> String {
    var result = text
    
    // Remove full <think>...</think> blocks (case insensitive, including newlines)
    if let regex = try? NSRegularExpression(
      pattern: "<think>[\\s\\S]*?</think>",
      options: [.caseInsensitive]
    ) {
      result = regex.stringByReplacingMatches(
        in: result,
        options: [],
        range: NSRange(result.startIndex..., in: result),
        withTemplate: ""
      )
    }
    
    // Remove standalone tags that might have leaked
    result = result.replacingOccurrences(of: "<think>", with: "", options: .caseInsensitive)
    result = result.replacingOccurrences(of: "</think>", with: "", options: .caseInsensitive)
    
    return result
  }
  
  /// Remove ChatML special tokens like <|im_end|>, <|im_start|>, etc.
  private static func removeChatMLTokens(from text: String) -> String {
    var result = text
    
    // Remove <|...|> patterns
    if let regex = try? NSRegularExpression(pattern: "<\\|[^|>]*\\|?>?", options: []) {
      result = regex.stringByReplacingMatches(
        in: result,
        options: [],
        range: NSRange(result.startIndex..., in: result),
        withTemplate: ""
      )
    }
    
    // Remove </s> tokens
    result = result.replacingOccurrences(of: "</s>", with: "")
    
    // Remove trailing < or | that might be partial tokens
    while result.hasSuffix("<") || result.hasSuffix("|") {
      result = String(result.dropLast())
    }
    
    return result
  }

  private static func removeAssistantPrefixes(from text: String) -> String {
    let lines = text.components(separatedBy: .newlines)
    let cleaned = lines.map { line in
      let trimmed = line.trimmingCharacters(in: .whitespaces)
      let lower = trimmed.lowercased()
      if lower.hasPrefix("assistant:") {
        // Drop the prefix and any following single space
        let after = trimmed.dropFirst("assistant:".count)
        if after.first == " " { return String(after.dropFirst()) }
        return String(after)
      }
      return line
    }
    return cleaned.joined(separator: "\n")
  }

  private static func deduplicateConsecutiveLines(in text: String) -> String {
    var result: [String] = []
    var previous: String? = nil
    for line in text.components(separatedBy: .newlines) {
      let key = line.trimmingCharacters(in: .whitespaces)
      if previous == key && !key.isEmpty {
        // skip exact consecutive duplicate non-empty lines
        continue
      }
      result.append(line)
      previous = key
    }
    return result.joined(separator: "\n")
  }

  private static func collapseBlankLines(in text: String) -> String {
    var result: [String] = []
    var blankRun = 0
    for line in text.components(separatedBy: .newlines) {
      if line.trimmingCharacters(in: .whitespaces).isEmpty {
        blankRun += 1
        if blankRun <= 1 { result.append("") }
      } else {
        blankRun = 0
        result.append(line)
      }
    }
    return result.joined(separator: "\n")
  }
}
