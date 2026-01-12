import Foundation
import StoreKit
import SwiftUI
#if os(iOS)
import UIKit
#endif

struct AppInfoView: View {
  @Environment(\.dismiss) private var dismiss

  var body: some View {
    ScrollView {
      LazyVStack(spacing: Space.xl, pinnedViews: []) {
        appInformationSection
        aboutSection
        developerSection
      }
      .padding(.horizontal, Space.lg)
      .padding(.vertical, Space.xl)
    }
    .scrollBounceBehavior(.basedOnSize)
    .background(Brand.surface)
    .navigationTitle(L("about"))
  }
  
  private var appInformationSection: some View {
    VStack(alignment: .leading, spacing: 0) {
      GlassSectionHeader(L("app_information"))
      
      GlassCard {
        VStack(spacing: 0) {
          GlassInfoRow(L("version"), value: appVersion, systemImage: "number.circle.fill")
          
          Divider()
          
          GlassInfoRow(L("build"), value: buildNumber, systemImage: "hammer.circle.fill")
          
          Divider()
          
          GlassInfoRow(L("bundle_id"), value: bundleIdentifier, systemImage: "barcode.viewfinder")
        }
      }
    }
  }
  
  private var aboutSection: some View {
    VStack(alignment: .leading, spacing: 0) {
      GlassSectionHeader(L("about"))

      GlassCard {
        Text(L("app_description"))
          .font(TypeScale.subhead)
          .foregroundStyle(Brand.textSecondary)
          .frame(maxWidth: .infinity, alignment: .leading)
      }
    }
  }

  private var developerSection: some View {
    VStack(alignment: .leading, spacing: 0) {
      GlassSectionHeader(L("developer"))

      GlassCard {
        VStack(spacing: Space.md) {
          Text(L("developer_story"))
            .font(TypeScale.subhead)
            .foregroundStyle(Brand.textSecondary)
            .frame(maxWidth: .infinity, alignment: .leading)

          HStack(spacing: Space.md) {
            Link(destination: URL(string: "https://x.com/7alkiumi")!) {
              HStack(spacing: Space.sm) {
                Image(systemName: "bird.fill")
                  .foregroundStyle(.blue)
                Text("7alkiumi")
                  .font(TypeScale.caption)
                  .foregroundStyle(.blue)
              }
            }

            Link(destination: URL(string: "https://taher.ai")!) {
              HStack(spacing: Space.sm) {
                Image(systemName: "globe")
                  .foregroundStyle(.blue)
                Text("taher.ai")
                  .font(TypeScale.caption)
                  .foregroundStyle(.blue)
              }
            }
          }
        }
      }
    }
  }
  
  private var appVersion: String {
    Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown"
  }
  
  private var buildNumber: String {
    Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "Unknown"
  }
  
  private var bundleIdentifier: String {
    Bundle.main.bundleIdentifier ?? "Unknown"
  }
}

