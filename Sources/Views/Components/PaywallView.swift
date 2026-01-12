import SwiftUI

struct PaywallView: View {
  let monthlyPrice: String?
  let annualPrice: String?
  let annualTrialText: String?
  let monthlyTrialText: String?
  let isEligibleForAnnualTrial: Bool
  let isEligibleForMonthlyTrial: Bool
  let onClose: () -> Void
  let onPurchaseMonthly: () -> Void
  let onPurchaseAnnual: () -> Void
  let onRestorePurchases: () -> Void

  @State private var selectedPlan: SubscriptionPlan = .annual
  @State private var isPurchasing = false
  @State private var isRestoring = false
  @State private var signInService = SignInWithAppleService.shared

  private var isRTL: Bool {
    RTLUtilities.isRTL
  }

  private var layoutDirection: LayoutDirection {
    RTLUtilities.layoutDirection
  }

  enum SubscriptionPlan {
    case monthly
    case annual

    var isAnnual: Bool {
      self == .annual
    }
  }

  var body: some View {
    NavigationStack {
      ZStack(alignment: .bottom) {
        ScrollView {
          LazyVStack(spacing: Space.lg, pinnedViews: []) {
            headerSection

            // Pro Benefits
            GlassCard {
              LazyVStack(spacing: 0) {
                ForEach(Array(proFeatures.enumerated()), id: \.element.title) { index, feature in
                  HStack(alignment: .top, spacing: Space.md) {
                    Image(systemName: feature.icon)
                      .font(.title3)
                      .foregroundStyle(Brand.primary)
                      .frame(width: 24, height: 24)

                    VStack(alignment: .leading, spacing: 2) {
                      Text(feature.title)
                        .font(TypeScale.body)
                        .fontWeight(.medium)
                        .foregroundStyle(Brand.textPrimary)

                      Text(feature.description)
                        .font(TypeScale.caption)
                        .foregroundStyle(Brand.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                    }

                    Spacer()
                  }
                  .padding(.vertical, Space.md)

                  if index < proFeatures.count - 1 {
                    Divider()
                      .padding(.leading, 40)
                  }
                }
              }
            }

            // Plan Selection
            VStack(spacing: Space.md) {
              // Annual Plan
              PlanSelectionCard(
                title: L("annual"),
                price: annualPrice ?? "...",
                period: L("per_year"),
                details: annualPlanDetails,
                trialBadge: isEligibleForAnnualTrial ? annualTrialText : nil,
                isSelected: selectedPlan == .annual,
                isRecommended: true
              ) {
                HapticFeedback.selection()
                selectedPlan = .annual
              }

              // Monthly Plan
              PlanSelectionCard(
                title: L("monthly"),
                price: monthlyPrice ?? "...",
                period: L("per_month"),
                details: monthlyPlanDetails,
                trialBadge: isEligibleForMonthlyTrial ? monthlyTrialText : nil,
                isSelected: selectedPlan == .monthly,
                isRecommended: false
              ) {
                HapticFeedback.selection()
                selectedPlan = .monthly
              }
            }

            // Trust & Legal
            VStack(spacing: Space.sm) {
              Button {
                HapticFeedback.selection()
                handleRestorePurchases()
              } label: {
                HStack(spacing: Space.xs) {
                  if isRestoring {
                    ProgressView()
                      .scaleEffect(0.8)
                      .tint(Brand.textSecondary)
                  } else {
                    Image(systemName: "arrow.clockwise")
                      .font(.system(size: 12))
                  }
                  Text(isRestoring ? L("processing") : L("restore_purchases"))
                    .font(TypeScale.caption)
                    .foregroundStyle(Brand.textSecondary)
                    .underline()
                }
              }
              .buttonStyle(.plain)
              .disabled(isRestoring)

              Text(trialInfoText)
                .font(TypeScale.caption2)
                .foregroundStyle(Brand.textSecondary)
                .multilineTextAlignment(.center)
            }
            .padding(.bottom, Space.xxl * 3)  // Space for CTA
          }
          .padding(Space.xxl)
        }
        .scrollBounceBehavior(.basedOnSize)

        // Sticky CTA
        VStack(spacing: 0) {
          Divider()
            .opacity(0.3)

          VStack(spacing: Space.md) {
            GlassButton(
              isPurchasing ? L("processing") : ctaButtonText,
              systemImage: isPurchasing ? nil : "star.fill"
            ) {
              handlePurchase()
            }
            .disabled(isPurchasing || monthlyPrice == nil || annualPrice == nil)

            if selectedPlan == .annual {
              if isEligibleForAnnualTrial {
                Text(L("then_price_per_year", annualPrice ?? "..."))
                  .font(TypeScale.caption)
                  .foregroundStyle(Brand.textSecondary)
              }
            }
          }
          .padding(Space.xl)

          Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: 100)
        .liquidGlass(cornerRadius: Radius.md)
      }
      .background(Brand.surface)
      #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
      #endif
      .environment(\.layoutDirection, layoutDirection)
      .toolbar {
        #if os(iOS)
          ToolbarItem(placement: .navigationBarTrailing) {
            Button {
              HapticFeedback.selection()
              onClose()
            } label: {
              Image(systemName: "xmark.circle.fill")
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(Brand.textSecondary)
                .font(TypeScale.headline)
            }
          }
        #else
          ToolbarItem(placement: .confirmationAction) {
            Button {
              onClose()
            } label: {
              Image(systemName: "xmark.circle.fill")
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(Brand.textSecondary)
                .font(TypeScale.headline)
            }
          }
        #endif
      }
    }
  }

  // MARK: - Header Section
  private var headerSection: some View {
    VStack(alignment: .leading, spacing: Space.md) {
      Image(systemName: "star.fill")
        .font(.system(size: 48))
        .foregroundStyle(Brand.primary)
        .padding(.bottom, Space.xs)

      VStack(alignment: .leading, spacing: Space.xs) {
        Text(L("upgrade_to_pro_title"))
          .font(TypeScale.title)
          .fontWeight(.bold)
          .foregroundStyle(Brand.textPrimary)

        Text(L("unlock_full_power"))
          .font(TypeScale.body)
          .foregroundStyle(Brand.textSecondary)
      }
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding(.top, Space.md)
  }

  // MARK: - Computed Properties
  private var ctaButtonText: String {
    if selectedPlan == .annual && isEligibleForAnnualTrial {
      return L("start_free_trial")
    } else if selectedPlan == .monthly && isEligibleForMonthlyTrial {
      return L("start_free_trial")
    }
    return L("subscribe_now")
  }

  private var trialInfoText: String {
    if selectedPlan == .annual && isEligibleForAnnualTrial {
      return L("trial_info")
    } else if selectedPlan == .monthly && isEligibleForMonthlyTrial {
      return L("trial_info")
    }
    return L("subscription_auto_renews")
  }

  private var annualPlanDetails: String {
    if isEligibleForAnnualTrial, let trialText = annualTrialText {
      return trialText
    }
    return calculateSavings() ?? L("best_value")
  }

  private var monthlyPlanDetails: String {
    if isEligibleForMonthlyTrial, let trialText = monthlyTrialText {
      return trialText
    }
    return L("flexible_billing")
  }

  // MARK: - Helper Methods
  private func handlePurchase() {
    HapticFeedback.impact(style: .medium)
    isPurchasing = true

    if selectedPlan == .annual {
      onPurchaseAnnual()
    } else {
      onPurchaseMonthly()
    }

    // Reset purchasing state after delay
    Task {
      try? await Task.sleep(nanoseconds: 2_000_000_000)
      await MainActor.run {
        isPurchasing = false
      }
    }
  }

  private func calculateSavings() -> String? {
    guard let monthly = monthlyPrice,
      let annual = annualPrice,
      let monthlyValue = extractPrice(from: monthly),
      let annualValue = extractPrice(from: annual)
    else {
      return nil
    }

    let monthlyYearly = monthlyValue * 12
    let savings = monthlyYearly - annualValue
    let savingsPercent = Int((savings / monthlyYearly) * 100)

    if savingsPercent > 0 {
      return L("save_percent", savingsPercent)
    }
    return nil
  }

  private func extractPrice(from priceString: String) -> Double? {
    // Remove common currency symbols and text
    let currencyPatterns = [
      "$", "USD", "SAR", "AED", "KWD", "QAR", "BHD", "OMR", "JOD", "EGP", "ر.س", "د.إ", "ر.ع",
      "ر.ق", "د.ب", "د.ك", "د.أ", "ج.م",
    ]
    var cleaned = priceString
    for pattern in currencyPatterns {
      cleaned = cleaned.replacingOccurrences(of: pattern, with: "")
    }
    cleaned =
      cleaned
      .replacingOccurrences(of: "/month", with: "")
      .replacingOccurrences(of: "/year", with: "")
      .replacingOccurrences(of: ",", with: ".")
      .trimmingCharacters(in: .whitespaces)
    return Double(cleaned)
  }

  private func handleRestorePurchases() {
    guard !isRestoring else { return }

    HapticFeedback.selection()
    isRestoring = true

    Task {
      do {
        if !signInService.isAuthenticated {
          _ = try await signInService.signIn()
        }

        await MainActor.run {
          onRestorePurchases()
        }

        try? await Task.sleep(nanoseconds: 1_500_000_000)

        await MainActor.run {
          isRestoring = false
        }
      } catch {
        await MainActor.run {
          isRestoring = false
        }
      }
    }
  }

  private var proFeatures: [(icon: String, title: String, description: String)] {
    [
      ("lock.shield.fill", L("private_secure"), L("private_secure_desc")),
      ("infinity", L("unlimited_chat"), L("unlimited_chat_desc")),
      ("bolt.fill", L("fast_performance"), L("fast_performance_desc")),
      ("brain.head.profile", L("advanced_models"), L("advanced_models_desc")),
    ]
  }
}

// MARK: - Plan Selection Card
private struct PlanSelectionCard: View {
  let title: String
  let price: String
  let period: String
  let details: String
  let trialBadge: String?
  let isSelected: Bool
  let isRecommended: Bool
  let action: () -> Void

  var body: some View {
    Button(action: action) {
      HStack(spacing: Space.md) {
        // Radio Button
        ZStack {
          Circle()
            .strokeBorder(
              isSelected ? Brand.primary : Brand.textSecondary.opacity(0.3), lineWidth: 2
            )
            .frame(width: 20, height: 20)

          if isSelected {
            Circle()
              .fill(Brand.primary)
              .frame(width: 10, height: 10)
          }
        }

        VStack(alignment: .leading, spacing: Space.xs) {
          HStack(spacing: Space.sm) {
            Text(title)
              .font(TypeScale.headline)
              .foregroundStyle(Brand.textPrimary)

            if isRecommended {
              Text(L("best_value"))
                .font(TypeScale.caption2)
                .fontWeight(.bold)
                .foregroundStyle(.white)
                .padding(.horizontal, Space.sm)
                .padding(.vertical, Space.xs / 2)
                .background(Brand.primary)
                .clipShape(Capsule())
            }
          }

          // Trial badge if eligible
          if let trialBadge {
            HStack(spacing: Space.xs) {
              Image(systemName: "gift.fill")
                .font(.system(size: 10))
              Text(trialBadge)
                .font(TypeScale.caption)
                .fontWeight(.medium)
            }
            .foregroundStyle(Brand.success)
          } else {
            Text(details)
              .font(TypeScale.caption)
              .foregroundStyle(isSelected ? Brand.primary : Brand.textSecondary)
          }
        }

        Spacer()

        VStack(alignment: .trailing, spacing: 0) {
          Text(price)
            .font(TypeScale.title)
            .fontWeight(.semibold)
            .foregroundStyle(Brand.textPrimary)

          Text(period)
            .font(TypeScale.caption2)
            .foregroundStyle(Brand.textSecondary)
        }
      }
      .padding(Space.md)
      .liquidGlass(
        cornerRadius: Radius.lg,
        tintColor: isSelected ? Brand.primary.opacity(0.1) : nil
      )
      .overlay {
        if isSelected {
          RoundedRectangle(cornerRadius: Radius.lg, style: .continuous)
            .strokeBorder(Brand.primary, lineWidth: 2)
        }
      }
    }
    .buttonStyle(.plain)
  }
}
