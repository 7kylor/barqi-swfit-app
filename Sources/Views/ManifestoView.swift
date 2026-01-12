import SwiftUI

struct ManifestoView: View {
  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: Space.xxl) {
        // Header
        VStack(alignment: .leading, spacing: Space.md) {
          Text("BarQi")
            .font(.system(size: 64, weight: .bold, design: .serif))
            .foregroundStyle(
              LinearGradient(
                colors: [Brand.primary, Brand.primary.opacity(0.8)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
              )
            )

          Text("One prompt. Many minds. One verdict.")
            .font(TypeScale.title)
            .italic()
            .foregroundStyle(Brand.textSecondary)
        }
        .padding(.top, 60)
        .padding(.bottom, Space.xl)

        // The Core Philosophy
        ManifestoParagraph(
          text:
            "BarQi was born from a quiet suspicion:\na single mind, no matter how fast, is still a single point of failure."
        )

        ManifestoParagraph(
          text:
            "Human truth first.\nWhen something matters, we don’t trust one voice.\nWe assemble a jury.\nWe argue.\nWe test logic against logic.\nWe let weak ideas crack under pressure."
        )

        ManifestoParagraph(
          text: "BarQi takes that ancient instinct and turns it into an AI system."
        )

        // The Split
        HStack(alignment: .top, spacing: Space.xl) {
          VStack(alignment: .leading, spacing: Space.sm) {
            Image(systemName: "xmark.circle")
              .font(.title2)
              .foregroundStyle(Brand.error.opacity(0.7))
            Text("Not a model that answers.")
              .font(TypeScale.headline)
          }

          VStack(alignment: .leading, spacing: Space.sm) {
            Image(systemName: "checkmark.circle")
              .font(.title2)
              .foregroundStyle(Brand.success.opacity(0.7))
            Text("A council that deliberates.")
              .font(TypeScale.headline)
          }
        }
        .padding(.vertical, Space.lg)

        ManifestoParagraph(
          text:
            "Inside BarQi, many intelligences sit at the same table.\nEach one trained differently.\nEach one biased in its own honest way.\nOne hunts contradictions.\nAnother challenges assumptions.\nAnother refines clarity.\nAnother asks: “Is this actually useful in the real world?”"
        )

        ManifestoParagraph(
          text: "Your prompt enters the room like a case file."
        )

        ManifestoParagraph(
          text: "No instant verdict.\nNo premature confidence."
        )

        ManifestoParagraph(
          text:
            "Each model examines it independently, then collectively.\nThey cross-examine the reasoning.\nThey sand down exaggeration.\nThey correct blind spots.\nThey tighten loose logic.\nThey strip away fluff that sounds smart but means nothing."
        )

        ManifestoParagraph(
          text:
            "What survives is not the loudest answer.\nIt’s the one that can’t be easily attacked."
        )

        ManifestoParagraph(
          text: "BarQi doesn’t aim to sound impressive.\nIt aims to stand up in court."
        )

        ManifestoParagraph(
          text:
            "The result is something rare in AI:\nanswers that feel earned.\nThoughts that feel considered.\nClarity without arrogance.\nDepth without noise."
        )

        ManifestoParagraph(
          text:
            "In a world drowning in fast takes and fragile intelligence,\nBarQi slows down just enough to be right."
        )

        VStack(alignment: .leading, spacing: Space.md) {
          Text("Because truth isn’t produced by speed.")
            .font(TypeScale.headline)
            .foregroundStyle(Brand.textSecondary)

          Text("It’s produced by pressure.")
            .font(TypeScale.title)
            .fontWeight(.bold)
            .foregroundStyle(Brand.textPrimary)
        }
        .padding(.vertical, Space.xl)

        // Final Footer
        VStack(spacing: Space.md) {
          Divider()
            .padding(.vertical, Space.xxl)

          Text("BarQi")
            .font(.system(size: 32, weight: .bold, design: .serif))
            .foregroundStyle(Brand.primary)

          Text("One prompt. Many minds. One verdict.")
            .font(TypeScale.caption)
            .foregroundStyle(Brand.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.bottom, 80)
      }
      .padding(.horizontal, Space.xxl)
      .frame(maxWidth: Layout.maxReadableWidth)
    }
    .background(Brand.surface)
    .navigationTitle("Manifesto")
  }
}

struct ManifestoParagraph: View {
  let text: String

  var body: some View {
    Text(text)
      .font(TypeScale.body)
      .lineSpacing(8)
      .foregroundStyle(Brand.textPrimary)
      .fixedSize(horizontal: false, vertical: true)
  }
}

#Preview {
  ManifestoView()
}
