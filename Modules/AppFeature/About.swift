import Foundation
import SwiftUI

struct AboutView: View {
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
        NavigationLink {
          AcknowledgementsView()
        } label: {
          Text(
            LocalizedStringResource(
              "about.privacy.link.acknowledgements",
              bundle: .module
            )
          )
        }
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

private struct AcknowledgementsView: View {
  @State private var acknowledgements: AttributedString?
  @State private var hasFailedToLoadAcknowledgements = false

  var body: some View {
    Group {
      if let acknowledgements {
        ScrollView {
          Text(acknowledgements)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
        }
        .textSelection(.enabled)
      } else if hasFailedToLoadAcknowledgements {
        Text(
          LocalizedStringResource(
            "about.privacy.acknowledgements.load.failed",
            bundle: .module
          )
        )
      } else {
        ProgressView()
      }
    }
    .navigationTitle(
      LocalizedStringResource(
        "about.privacy.acknowledgements.title",
        bundle: .module
      )
    )
    .navigationBarTitleDisplayMode(.inline)
    .task {
      loadAcknowledgementsIfNeeded()
    }
  }

  private func loadAcknowledgementsIfNeeded() {
    guard acknowledgements == nil else { return }

    guard
      let acknowledgementsURL = Bundle.module.url(
        forResource: "ACKNOWLEDGEMENTS",
        withExtension: "md"
      ),
      let acknowledgementsText = try? String(
        contentsOf: acknowledgementsURL,
        encoding: .utf8
      ),
      let acknowledgementsMarkdown = try? AttributedString(
        markdown: acknowledgementsText,
        options: .init(
          allowsExtendedAttributes: true,
          interpretedSyntax: .inlineOnlyPreservingWhitespace,
          failurePolicy: .returnPartiallyParsedIfPossible,
          appliesSourcePositionAttributes: true
        )
      )
    else {
      hasFailedToLoadAcknowledgements = true
      return
    }

    acknowledgements = acknowledgementsMarkdown
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
