import Foundation

/// Stream-safe parser for extracting reasoning enclosed in <think>...</think> while producing the visible answer text.
/// Designed to work incrementally as tokens stream in from the inference engine.
/// Also filters out raw ChatML tokens that should not be shown to users.
struct ReasoningAccumulator: Sendable {
  private(set) var answer: String = ""
  private(set) var reasoning: String = ""

  // Internal mutable buffer and state for tag detection across token boundaries
  private var buffer: String = ""
  private var insideThink: Bool = false
  private let openTag = "<think>"
  private let closeTag = "</think>"

  // ChatML tokens that should be stripped from output (include partial variations)
  private static let chatMLTokens = [
    // Full tokens
    "<|im_end|>",
    "<|im_start|>",
    "<|im_start|>user",
    "<|im_start|>assistant",
    "<|im_start|>system",
    "<|endoftext|>",
    "<|eot_id|>",
    "<|start_header_id|>",
    "<|end_header_id|>",
    // Partial tokens (missing closing >)
    "<|im_end|",
    "<|im_start|",
    "<|endoftext|",
    "<|eot_id|",
    // Even more partial
    "<|im_end",
    "<|im_start",
    // Role labels that might leak
    "\nuser\n",
    "\nassistant\n",
    "\nsystem\n",
    // Think tags (in case they leak to answer)
    "</think>",
    "<think>",
  ]

  /// Append a new streamed token and update answer/reasoning outputs.
  /// - Parameter token: Next token chunk from the model.
  /// - Returns: Tuple of the current answer and reasoning strings after processing.
  mutating func append(token: String) -> (answer: String, reasoning: String) {
    // Check if this token contains special token markers - if so, don't add it
    // Any token with <| is a ChatML/special token that shouldn't be shown
    if token.contains("<|") || token.contains("</s>") {
      // Don't process special tokens, return current state
      return (Self.stripChatMLTokens(from: answer), Self.stripChatMLTokens(from: reasoning))
    }

    // Also check against known token list
    for chatMLToken in Self.chatMLTokens {
      if token.contains(chatMLToken) {
        return (Self.stripChatMLTokens(from: answer), Self.stripChatMLTokens(from: reasoning))
      }
    }

    buffer += token

    // Process as much as we can whenever a whole tag is present in the buffer
    while true {
      if insideThink {
        if let range = buffer.range(of: closeTag, options: [.caseInsensitive]) {
          let before = String(buffer[..<range.lowerBound])
          reasoning += before
          buffer.removeSubrange(..<range.upperBound)
          insideThink = false
          continue
        } else {
          // We cannot flush the entire buffer to reasoning as the closing tag may be split across tokens.
          // However, we can safely flush up to a point where a potential prefix of the closing tag starts.
          let safeCount = safeFlushCount(in: buffer, lookingFor: closeTag)
          if safeCount > 0 {
            let idx = buffer.index(buffer.startIndex, offsetBy: safeCount)
            reasoning += String(buffer[..<idx])
            buffer.removeSubrange(..<idx)
          }
          break
        }
      } else {
        if let range = buffer.range(of: openTag, options: [.caseInsensitive]) {
          let before = String(buffer[..<range.lowerBound])
          answer += before
          buffer.removeSubrange(..<range.upperBound)
          insideThink = true
          continue
        } else {
          // Similar logic: flush only safe content that cannot be part of an upcoming openTag sequence
          let safeCount = safeFlushCount(in: buffer, lookingFor: openTag)
          if safeCount > 0 {
            let idx = buffer.index(buffer.startIndex, offsetBy: safeCount)
            answer += String(buffer[..<idx])
            buffer.removeSubrange(..<idx)
          }
          break
        }
      }
    }

    // Return cleaned versions to strip any partial ChatML tokens
    return (Self.stripChatMLTokens(from: answer), Self.stripChatMLTokens(from: reasoning))
  }

  /// Get current answer and reasoning without modifying state.
  /// Useful for batch processing where we want to read state after multiple appends.
  /// - Returns: Current answer and reasoning strings.
  func current() -> (answer: String, reasoning: String) {
    return (Self.stripChatMLTokens(from: answer), Self.stripChatMLTokens(from: reasoning))
  }

  /// Flush any remaining buffered content at end of stream.
  /// Ensures no content is lost if the stream ends without a closing tag.
  /// Also strips any ChatML tokens that leaked through.
  /// - Returns: Final answer and reasoning strings.
  mutating func finalize() -> (answer: String, reasoning: String) {
    if !buffer.isEmpty {
      if insideThink {
        reasoning += buffer
      } else {
        answer += buffer
      }
      buffer.removeAll(keepingCapacity: false)
    }
    // Strip any ChatML tokens from the final output
    let cleanedAnswer = Self.stripChatMLTokens(from: answer)
    let cleanedReasoning = Self.stripChatMLTokens(from: reasoning)
    return (cleanedAnswer, cleanedReasoning)
  }

  /// Remove ChatML tokens from text that should not be visible to users
  private static func stripChatMLTokens(from text: String) -> String {
    var result = text

    // First pass: remove known tokens
    for token in chatMLTokens {
      result = result.replacingOccurrences(of: token, with: "")
    }

    // Second pass: aggressively remove anything starting with <|
    // This pattern matches <| followed by any non-whitespace characters
    if let regex = try? NSRegularExpression(pattern: "<\\|[^\\s]*", options: []) {
      result = regex.stringByReplacingMatches(
        in: result,
        options: [],
        range: NSRange(result.startIndex..., in: result),
        withTemplate: ""
      )
    }

    // Also remove </s> end tokens
    result = result.replacingOccurrences(of: "</s>", with: "")

    // Strip trailing < or | that might be partial special tokens
    result = result.trimmingCharacters(in: .whitespacesAndNewlines)
    while result.hasSuffix("<") || result.hasSuffix("|") || result.hasSuffix("\n<") {
      result = String(result.dropLast())
      result = result.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    return result
  }

  /// Computes how many leading characters are safe to flush because they cannot be part of the target tag.
  /// This keeps enough characters in the buffer to detect a tag that might be split across tokens.
  private func safeFlushCount(in text: String, lookingFor tag: String) -> Int {
    if text.isEmpty { return 0 }

    // If the tag exists anywhere in text, only flush content that appears before the first occurrence
    if let range = text.range(of: tag, options: [.caseInsensitive]) {
      return text.distance(from: text.startIndex, to: range.lowerBound)
    }

    // Otherwise, retain up to tag.count - 1 trailing characters to handle partial tag prefixes on the next token
    let retain = max(0, min(tag.count - 1, text.count))
    return text.count - retain
  }
}
