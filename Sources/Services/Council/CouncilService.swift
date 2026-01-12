import Foundation
import Observation
import SwiftData

@MainActor
@Observable
final class CouncilService: ChatServing {
  private var providers: [LLMProvider] = []

  // State of the current deliberation
  var isDeliberating: Bool = false
  var activeProviders: [String] = []  // IDs of providers currently working
  var providerOutputs: [String: String] = [:]  // ID -> Output

  init() {
    // Bootstrap the Council
    self.providers = [
      MockProvider(id: "gemini", name: "Gemini", icon: "sparkles", description: "The Synthesizer"),
      MockProvider(id: "gpt4", name: "OpenAI", icon: "bolt", description: "The Logician"),
      MockProvider(id: "claude", name: "Anthropic", icon: "brain", description: "The Writer"),
      MockProvider(id: "deepseek", name: "DeepSeek", icon: "eye", description: "The Coder"),
    ]
  }

  func sendMessage(_ text: String, in conversation: Conversation) async {
    isDeliberating = true
    activeProviders = providers.map { $0.id }
    providerOutputs = [:]

    // 1. Add User Message
    let userMsg = ChatMessage(role: .user, text: text)
    conversation.messages.append(userMsg)

    // 2. Add Verdict Placeholder (Assistant Message)
    let verdictMsg = ChatMessage(role: .assistant, text: "")
    conversation.messages.append(verdictMsg)

    // 3. Concurrent Deliberation (Fan-out)
    await withTaskGroup(of: (String, String).self) { group in
      for provider in providers {
        group.addTask {
          let response = try? await provider.generate(prompt: text)
          return (provider.id, response ?? "Abstained.")
        }
      }

      for await (id, response) in group {
        await MainActor.run {
          self.providerOutputs[id] = response
          // Remove from active list as they finish
          self.activeProviders.removeAll { $0 == id }

          // Optional: Stream intermediate thoughts to the verdict message
          // (For now we'll just wait for the final synthesis)
        }
      }
    }

    // 4. Final Verdict Synthesis (Fan-in)
    // In a real app, we'd send all testimonies to a judge model.
    // Here we mock the judge.

    let allTestimonies = providerOutputs.values.joined(separator: "\n\n---\n\n")
    let finalVerdict = """
      # The Council Has Spoken

      After deliberating with \(providers.count) distinct intelligences, we have reached a verdict.

      **Consensus:**
      The prompt requires a nuanced approach...

      **Key Insights:**
      - Gemini noted that X.
      - OpenAI argued for Y.

      **Final Answer:**
      Here is the synthesized response to your query: "\(text)"

      (This is a mock verdict based on the BarQi architecture)
      """

    // Stream the verdict to the message
    for char in finalVerdict {
      try? await Task.sleep(nanoseconds: 10_000_000)  // 10ms
      verdictMsg.text.append(char)
    }

    isDeliberating = false
    NotificationCenter.default.post(name: .generationComplete, object: nil)
  }

  func stopGeneration() async {
    isDeliberating = false
    // Cancel tasks
  }
}
