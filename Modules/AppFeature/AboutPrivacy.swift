import Foundation
import SwiftUI

struct AboutPrivacyView: View {
  private let privacyPolicyURL: URL?
  private let supportURL: URL?

  init(mainBundle: Bundle = .main) {
    self.privacyPolicyURL = mainBundle.configuredURL(
      forInfoDictionaryKey: "PrivacyPolicyURL"
    )
    self.supportURL = mainBundle.configuredURL(
      forInfoDictionaryKey: "SupportURL"
    )
  }

  var body: some View {
    List {
      Section {
        Text(
          LocalizedStringResource(
            "about.privacy.data.body",
            bundle: .module
          )
        )
      } header: {
        Text(
          LocalizedStringResource(
            "about.privacy.data.title",
            bundle: .module
          )
        )
      }

      Section {
        ConfigurableLinkRow(
          title: LocalizedStringResource(
            "about.privacy.link.privacy.policy",
            bundle: .module
          ),
          url: privacyPolicyURL
        )
        ConfigurableLinkRow(
          title: LocalizedStringResource(
            "about.privacy.link.support",
            bundle: .module
          ),
          url: supportURL
        )
      } header: {
        Text(
          LocalizedStringResource(
            "about.privacy.links.title",
            bundle: .module
          )
        )
      }
    }
    .navigationTitle(
      LocalizedStringResource(
        "about.privacy.title",
        bundle: .module
      )
    )
    .navigationBarTitleDisplayMode(.inline)
  }
}

private struct ConfigurableLinkRow: View {
  let title: LocalizedStringResource
  let url: URL?

  var body: some View {
    if let url {
      Link(destination: url) {
        HStack {
          Text(title)
          Spacer()
          Image(systemName: "arrow.up.forward.square")
            .foregroundStyle(.secondary)
        }
      }
    } else {
      HStack {
        Text(title)
        Spacer()
        Text(
          LocalizedStringResource(
            "about.privacy.link.not.configured",
            bundle: .module
          )
        )
          .foregroundStyle(.secondary)
      }
    }
  }
}

private extension Bundle {
  func configuredURL(forInfoDictionaryKey key: String) -> URL? {
    if let urlValue = object(forInfoDictionaryKey: key) as? URL {
      return urlValue
    }

    guard
      let rawValue = object(forInfoDictionaryKey: key) as? String
    else {
      return nil
    }

    let trimmed = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty else { return nil }
    guard let url = URL(string: trimmed), url.scheme != nil else { return nil }
    return url
  }
}
