import SwiftUI

struct UsageIndicator: View {
  let level: EntitlementLevel
  let trialActive: Bool
  @Environment(AppModel.self) private var app

  // Trial banner display logic:
  // - Free users with active trial: Show "Trial Active" banner (creates scarcity/urgency)
  // - Pro users (including those in trial period): NO banner - let them enjoy without distractions
  private var shouldShowTrialBanner: Bool {
    level != .pro && trialActive
  }
  
  // For pro users, always treat trial as inactive for display purposes
  // Pro users get pro benefits regardless of trial status, so no need to show trial messaging
  private var effectiveTrialActive: Bool {
    level == .pro ? false : trialActive
  }

  var body: some View {
    HStack(spacing: Space.sm) {
      let remainingDaily = app.usageMeter.remainingDailyMessages(
        for: level, trialActive: effectiveTrialActive)
      let remainingMonthly = app.usageMeter.remainingMonthlyMessages(
        for: level, trialActive: effectiveTrialActive)

      if shouldShowTrialBanner {
        Label(L("trial_active"), systemImage: "sparkles")
          .font(TypeScale.caption)
          .fontWeight(.medium)
          .foregroundStyle(Brand.primary)
      } else {
        Label(levelLabel, systemImage: levelIcon)
          .font(TypeScale.caption)
          .fontWeight(.medium)
          .foregroundStyle(Brand.textSecondary)
      }

      Spacer()

      if shouldShowTrialBanner {
        let trialDaysRemaining = calculateTrialDaysRemaining()
        Text(String(format: L("%lld days left"), trialDaysRemaining))
          .font(TypeScale.caption)
          .fontWeight(.medium)
          .foregroundStyle(Brand.textSecondary)
      } else if level == .free {
        Text(String(format: L("%lld left today"), max(0, remainingDaily)))
          .font(TypeScale.caption)
          .fontWeight(.medium)
          .foregroundStyle(Brand.textSecondary)
      } else if level == .pro {
        if remainingMonthly != Int.max {
          Text(String(format: L("%lld msgs left"), max(0, remainingMonthly)))
            .font(TypeScale.caption)
            .fontWeight(.medium)
            .foregroundStyle(Brand.textSecondary)
        }
      }
    }
    .padding(.horizontal, Space.md)
    .padding(.vertical, Space.sm)
    .liquidGlass(
      cornerRadius: Radius.md,
      tintColor: shouldShowTrialBanner ? Brand.primary.opacity(0.1) : nil
    )
    .accessibilityElement(children: .combine)
    .accessibilityLabel(accessibilityLabel)
  }
  
  private var accessibilityLabel: String {
    if shouldShowTrialBanner {
      let days = calculateTrialDaysRemaining()
      return L("trial_active") + ", " + String(format: L("%lld days left"), days)
    } else if level == .free {
      let remaining = app.usageMeter.remainingDailyMessages(for: level, trialActive: effectiveTrialActive)
      return levelLabel + ", " + String(format: L("%lld left today"), max(0, remaining))
    } else {
      let remaining = app.usageMeter.remainingMonthlyMessages(for: level, trialActive: effectiveTrialActive)
      if remaining != Int.max {
        return levelLabel + ", " + String(format: L("%lld msgs left"), max(0, remaining))
      }
      return levelLabel
    }
  }
  
  private func calculateTrialDaysRemaining() -> Int {
    guard let endDate = app.subscriptionService.trialEndDate else {
      return 0
    }
    let calendar = Calendar.current
    let components = calendar.dateComponents([.day], from: Date(), to: endDate)
    let days = max(0, components.day ?? 0)
    // Cap at 30 days maximum
    return min(days, 30)
  }

  private var levelLabel: String {
    switch level {
    case .free: return "Free"
    case .pro: return "Pro"
    }
  }

  private var levelIcon: String {
    switch level {
    case .free: return "leaf"
    case .pro: return "crown"
    }
  }
}
