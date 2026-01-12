import SwiftUI

/// Lightweight feedback widget shown on AI responses.
/// Allows users to rate responses and optionally provide reasons.
struct FeedbackChip: View {
    let messageId: UUID
    @State private var feedbackState: FeedbackState = .none
    @State private var showReasonPicker = false
    @ObservedObject var presetManager = PresetManager.shared
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    
    enum FeedbackState {
        case none
        case positive
        case negative
    }
    
    var body: some View {
        HStack(spacing: Space.sm) {
            // Thumbs up
            FeedbackButton(
                icon: feedbackState == .positive ? "hand.thumbsup.fill" : "hand.thumbsup",
                isSelected: feedbackState == .positive,
                tint: Brand.success
            ) {
                handleFeedback(positive: true)
            }
            
            // Thumbs down
            FeedbackButton(
                icon: feedbackState == .negative ? "hand.thumbsdown.fill" : "hand.thumbsdown",
                isSelected: feedbackState == .negative,
                tint: Brand.error
            ) {
                handleFeedback(positive: false)
            }
        }
        .sheet(isPresented: $showReasonPicker) {
            FeedbackReasonPicker(messageId: messageId) { reason in
                submitNegativeFeedback(reason: reason)
            }
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
        }
    }
    
    private func handleFeedback(positive: Bool) {
        HapticFeedback.selection()
        
        let animation: Animation? = reduceMotion ? nil : .snappy(duration: 0.2)
        withAnimation(animation) {
            if positive {
                feedbackState = feedbackState == .positive ? .none : .positive
                if feedbackState == .positive {
                    AnalyticsService.shared.trackFeedback(
                        positive: true,
                        preset: presetManager.activePreset,
                        reason: nil
                    )
                }
            } else {
                if feedbackState != .negative {
                    feedbackState = .negative
                    showReasonPicker = true
                } else {
                    feedbackState = .none
                }
            }
        }
    }
    
    private func submitNegativeFeedback(reason: String?) {
        AnalyticsService.shared.trackFeedback(
            positive: false,
            preset: presetManager.activePreset,
            reason: reason
        )
    }
}

struct FeedbackButton: View {
    let icon: String
    let isSelected: Bool
    let tint: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(isSelected ? tint : Brand.textSecondary.opacity(0.6))
                .frame(width: 32, height: 32)
                .liquidGlassCircle(tintColor: isSelected ? tint.opacity(0.15) : nil)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(isSelected ? PS.feedback_selected : PS.feedback_tap_to_select)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

/// Picker for negative feedback reasons
struct FeedbackReasonPicker: View {
    let messageId: UUID
    let onSubmit: (String?) -> Void
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.layoutDirection) private var layoutDirection
    @State private var selectedReason: FeedbackReason?
    @State private var sheetOpenTime: Date?
    @State private var reasonSelectionTime: Date?
    @State private var hasTrackedDismissal: Bool = false
    
    private var isRTL: Bool {
        RTLUtilities.isRTL
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                ScrollView(.vertical, showsIndicators: false) {
                    LazyVStack(spacing: Space.lg) {
                        // Header section
                        VStack(spacing: Space.md) {
                            Image(systemName: "bubble.left.and.exclamationmark.bubble.right")
                                .font(.system(size: 48, weight: .light))
                                .foregroundStyle(Brand.primary.opacity(0.7))
                                .accessibilityHidden(true)
                            
                            VStack(spacing: Space.xs) {
                                Text(PS.feedback_help_us_improve)
                                    .font(TypeScale.headline)
                                    .foregroundStyle(Brand.textPrimary)
                                    .multilineTextAlignment(isRTL ? .trailing : .leading)
                                    .environment(\.layoutDirection, RTLUtilities.layoutDirection)
                                
                                Text(PS.feedback_what_went_wrong)
                                    .font(TypeScale.body)
                                    .foregroundStyle(Brand.textSecondary)
                                    .multilineTextAlignment(isRTL ? .trailing : .leading)
                                    .padding(.horizontal, Space.lg)
                                    .environment(\.layoutDirection, RTLUtilities.layoutDirection)
                            }
                        }
                        .padding(.top, Space.lg)
                        .padding(.horizontal, Space.lg)
                        .padding(.bottom, Space.md)
                        
                        // Reason chips - using LazyVStack for performance
                        LazyVStack(spacing: Space.sm) {
                            ForEach(FeedbackReason.allCases) { reason in
                                FeedbackReasonChip(
                                    reason: reason,
                                    isSelected: selectedReason == reason
                                ) {
                                    let animation = reduceMotion ? nil : Animation.snappy(duration: 0.15)
                                    withAnimation(animation) {
                                        selectedReason = reason
                                        reasonSelectionTime = Date()
                                        if let openTime = sheetOpenTime {
                                            let timeSinceOpen = reasonSelectionTime!.timeIntervalSince(openTime)
                                            AnalyticsService.shared.trackFeedbackReasonSelected(
                                                messageId: messageId,
                                                reason: reason.rawValue,
                                                timeSinceOpen: timeSinceOpen
                                            )
                                        }
                                    }
                                }
                                .id(reason.id)
                            }
                        }
                        .padding(.horizontal, Space.lg)
                        
                        // Action buttons
                        VStack(spacing: Space.md) {
                            // Submit button
                            Button {
                                HapticFeedback.selection()
                                let animation = reduceMotion ? nil : Animation.snappy(duration: 0.15)
                                withAnimation(animation) {
                                    onSubmit(selectedReason?.rawValue)
                                    trackDismissal(method: "submit")
                                    dismiss()
                                }
                            } label: {
                                Text(PS.submit_feedback)
                                    .font(TypeScale.headline)
                                    .foregroundStyle(.white)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, Space.md)
                            }
                            .background(Brand.primary)
                            .clipShape(Capsule())
                            .disabled(selectedReason == nil)
                            .opacity(selectedReason == nil ? 0.6 : 1.0)
                            .accessibilityLabel(PS.submit_feedback)
                            .accessibilityHint(selectedReason == nil ? PS.feedback_tap_to_select : "")
                            
                            // Skip button
                            Button {
                                HapticFeedback.selection()
                                let animation = reduceMotion ? nil : Animation.snappy(duration: 0.15)
                                withAnimation(animation) {
                                    onSubmit(nil)
                                    trackDismissal(method: "skip")
                                    dismiss()
                                }
                            } label: {
                                Text(PS.skip)
                                    .font(TypeScale.body)
                                    .foregroundStyle(Brand.textSecondary)
                            }
                            .accessibilityLabel(PS.skip)
                        }
                        .padding(.horizontal, Space.lg)
                        .padding(.top, Space.lg)
                        .padding(.bottom, Space.xl)
                    }
                }
            }
            .background(Brand.surface)
            .navigationTitle(PS.feedback_help_us_improve)
            #if os(iOS)
              .navigationBarTitleDisplayMode(.inline)
              .toolbar {
                  ToolbarItem(placement: isRTL ? .topBarTrailing : .topBarLeading) {
                      Button(PS.cancel) {
                          HapticFeedback.selection()
                          let animation = reduceMotion ? nil : Animation.snappy(duration: 0.15)
                          withAnimation(animation) {
                              trackDismissal(method: "cancel")
                              dismiss()
                          }
                      }
                      .foregroundStyle(Brand.primary)
                      .font(TypeScale.headline)
                      .accessibilityLabel(PS.cancel)
                  }
              }
            #else
              .toolbar {
                  ToolbarItem(placement: .cancellationAction) {
                      Button(PS.cancel) {
                          let animation = reduceMotion ? nil : Animation.snappy(duration: 0.15)
                          withAnimation(animation) {
                              trackDismissal(method: "cancel")
                              dismiss()
                          }
                      }
                      .foregroundStyle(Brand.primary)
                      .font(TypeScale.headline)
                      .accessibilityLabel(PS.cancel)
                  }
              }
            #endif
        }
        .environment(\.layoutDirection, RTLUtilities.layoutDirection)
        .onAppear {
            sheetOpenTime = Date()
            AnalyticsService.shared.trackFeedbackSheetOpened(messageId: messageId)
        }
        .onDisappear {
            if sheetOpenTime != nil {
                trackDismissal(method: "swipe")
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(PS.feedback_help_us_improve)
    }
    
    private func trackDismissal(method: String) {
        guard !hasTrackedDismissal, let openTime = sheetOpenTime else { return }
        hasTrackedDismissal = true
        let dismissalTime = Date()
        let interactionDuration = dismissalTime.timeIntervalSince(openTime)
        AnalyticsService.shared.trackFeedbackSheetDismissed(
            messageId: messageId,
            duration: interactionDuration,
            method: method
        )
    }
}

enum FeedbackReason: String, CaseIterable, Identifiable {
    case inaccurate = "inaccurate"
    case unhelpful = "unhelpful"
    case tooLong = "too_long"
    case tooShort = "too_short"
    case confusing = "confusing"
    case offTopic = "off_topic"
    
    var id: String { rawValue }
    
    var label: String {
        switch self {
        case .inaccurate: return PS.feedback_inaccurate
        case .unhelpful: return PS.feedback_unhelpful
        case .tooLong: return PS.feedback_too_long
        case .tooShort: return PS.feedback_too_short
        case .confusing: return PS.feedback_confusing
        case .offTopic: return PS.feedback_off_topic
        }
    }
    
    var icon: String {
        switch self {
        case .inaccurate: return "xmark.circle"
        case .unhelpful: return "questionmark.circle"
        case .tooLong: return "arrow.down.left.and.arrow.up.right"
        case .tooShort: return "arrow.up.left.and.arrow.down.right"
        case .confusing: return "exclamationmark.triangle"
        case .offTopic: return "arrow.uturn.left"
        }
    }
}

struct FeedbackReasonChip: View {
    let reason: FeedbackReason
    let isSelected: Bool
    let onTap: () -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    
    private var isRTL: Bool {
        RTLUtilities.isRTL
    }
    
    var body: some View {
        Button(action: {
            HapticFeedback.selection()
            onTap()
        }) {
            HStack(spacing: Space.md) {
                // Icon
                ZStack {
                    RoundedRectangle(cornerRadius: Radius.sm, style: .continuous)
                        .fill(Brand.primary.opacity(isSelected ? 0.15 : 0.1))
                        .frame(width: 40, height: 40)
                    
                    Image(systemName: reason.icon)
                        .foregroundStyle(Brand.primary.opacity(isSelected ? 1.0 : 0.7))
                        .font(.system(size: 16, weight: .medium))
                }
                .accessibilityHidden(true)
                
                // Reason text
                Text(reason.label)
                    .font(TypeScale.body)
                    .foregroundStyle(Brand.textPrimary)
                    .multilineTextAlignment(isRTL ? .trailing : .leading)
                    .frame(maxWidth: .infinity, alignment: isRTL ? .trailing : .leading)
                    .environment(\.layoutDirection, RTLUtilities.layoutDirection)
                
                // Selection indicator
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(Brand.primary)
                        .font(.system(size: 20))
                        .transition(.opacity.combined(with: .scale(scale: 0.9)))
                }
            }
            .padding(Space.md)
            .liquidGlass(
                cornerRadius: Radius.md,
                tintColor: isSelected ? Brand.primary.opacity(0.1) : Brand.surface.opacity(0.2)
            )
            .overlay(
                RoundedRectangle(cornerRadius: Radius.md)
                    .stroke(isSelected ? Brand.primary.opacity(0.3) : Color.clear, lineWidth: 1.5)
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(reason.label)
        .accessibilityHint(isSelected ? PS.feedback_selected : PS.feedback_tap_to_select)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .id(reason.id)
    }
}

/// Inline survey prompt shown after successful tasks
struct InlineSurveyPrompt: View {
    let onDismiss: () -> Void
    let onTakeSurvey: () -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    
    var body: some View {
        VStack(spacing: Space.md) {
            HStack {
                Image(systemName: "star.bubble")
                    .font(.title2)
                    .foregroundStyle(Brand.primary)
                
                VStack(alignment: .leading, spacing: Space.xs) {
                    Text(PS.survey_enjoying_mawj)
                        .font(TypeScale.headline)
                        .foregroundStyle(Brand.textPrimary)
                    
                    Text(PS.survey_quick_feedback)
                        .font(TypeScale.caption)
                        .foregroundStyle(Brand.textSecondary)
                }
                
                Spacer()
                
                Button {
                    HapticFeedback.selection()
                    onDismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(Brand.textSecondary)
                        .frame(width: 28, height: 28)
                        .liquidGlassCircle()
                }
                .buttonStyle(.plain)
                .accessibilityLabel(PS.cancel)
            }
            
            HStack(spacing: Space.md) {
                Button {
                    HapticFeedback.selection()
                    onDismiss()
                } label: {
                    Text(PS.not_now)
                        .font(TypeScale.subhead)
                        .foregroundStyle(Brand.textSecondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, Space.sm)
                        .liquidGlassCapsule()
                }
                .buttonStyle(.plain)
                .accessibilityLabel(PS.not_now)
                
                Button {
                    HapticFeedback.selection()
                    onTakeSurvey()
                } label: {
                    Text(PS.sure)
                        .font(TypeScale.subhead)
                        .fontWeight(.medium)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, Space.sm)
                        .background(Brand.primary)
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(PS.sure)
            }
        }
        .padding(Space.lg)
        .liquidGlass(cornerRadius: Radius.lg, tintColor: Brand.primary.opacity(0.05))
        .overlay(
            RoundedRectangle(cornerRadius: Radius.lg)
                .stroke(Brand.primary.opacity(0.2), lineWidth: 1)
        )
        .shadow(color: Brand.primary.opacity(0.1), radius: 10, y: 5)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(PS.survey_enjoying_mawj)
    }
}

#Preview {
    VStack(spacing: Space.xl) {
        FeedbackChip(messageId: UUID())
        
        InlineSurveyPrompt(onDismiss: {}, onTakeSurvey: {})
            .padding()
    }
    .background(Brand.surface)
}
