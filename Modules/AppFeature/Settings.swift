import Sharing
import SwiftUI

enum AppStorageKeys {
  static let itemFormAutofocusEnabled = "isItemFormAutofocusEnabled"
  static let itemFormSuggestionsEnabled = "isItemFormSuggestionsEnabled"
  static let itemFormEmojiSuggestionsEnabled = "isItemFormEmojiSuggestionsEnabled"
  static let isReminderSkipEnabled = "isReminderSkipEnabled"
}

extension SharedKey where Self == AppStorageKey<Bool>.Default {
  static var isItemFormAutofocusEnabled: Self {
    Self[.appStorage(AppStorageKeys.itemFormAutofocusEnabled), default: true]
  }

  static var isItemFormSuggestionsEnabled: Self {
    Self[.appStorage(AppStorageKeys.itemFormSuggestionsEnabled), default: true]
  }

  static var isItemFormEmojiSuggestionsEnabled: Self {
    Self[.appStorage(AppStorageKeys.itemFormEmojiSuggestionsEnabled), default: true]
  }

  static var isReminderSkipEnabled: Self {
    Self[.appStorage(AppStorageKeys.isReminderSkipEnabled), default: true]
  }
}

struct SettingsView: View {
  @Shared(.isItemFormAutofocusEnabled) private var isItemFormAutofocusEnabled
  @Shared(.isItemFormSuggestionsEnabled) private var isItemFormSuggestionsEnabled
  @Shared(.isItemFormEmojiSuggestionsEnabled)
  private var isItemFormEmojiSuggestionsEnabled
  @Shared(.isReminderSkipEnabled)
  private var isReminderSkipEnabled

  var body: some View {
    Form {
      Section {
        Toggle(isOn: Binding($isItemFormAutofocusEnabled)) {
          SettingsToggleLabel(
            title: LocalizedStringResource(
              "settings.item-form.autofocus",
              bundle: .module
            ),
            subtitle: LocalizedStringResource(
              "settings.item-form.autofocus.subtitle",
              bundle: .module
            )
          )
        }
        .tint(.accentColor)

        Toggle(isOn: Binding($isItemFormSuggestionsEnabled)) {
          SettingsToggleLabel(
            title: LocalizedStringResource(
              "settings.item-form.suggestions",
              bundle: .module
            ),
            subtitle: LocalizedStringResource(
              "settings.item-form.suggestions.subtitle",
              bundle: .module
            )
          )
        }
        .tint(.accentColor)

        Toggle(isOn: Binding($isItemFormEmojiSuggestionsEnabled)) {
          SettingsToggleLabel(
            title: LocalizedStringResource(
              "settings.item-form.emoji-suggestions",
              bundle: .module
            ),
            subtitle: LocalizedStringResource(
              "settings.item-form.emoji-suggestions.subtitle",
              bundle: .module
            )
          )
        }
        .tint(.accentColor)
      } header: {
        Text(
          LocalizedStringResource(
            "settings.item-form.section.title",
            bundle: .module
          )
        )
      } footer: {
        Text(
          LocalizedStringResource(
            "settings.item-form.section.description",
            bundle: .module
          )
        )
      }

      Section {
        Toggle(isOn: Binding($isReminderSkipEnabled)) {
          SettingsToggleLabel(
            title: LocalizedStringResource(
              "settings.reminders.skip-tracked-same-day",
              bundle: .module
            ),
            subtitle: LocalizedStringResource(
              "settings.reminders.skip-tracked-same-day.subtitle",
              bundle: .module
            )
          )
        }
        .tint(.accentColor)
      } header: {
        Text(
          LocalizedStringResource(
            "settings.reminders.section.title",
            bundle: .module
          )
        )
      } footer: {
        Text(
          LocalizedStringResource(
            "settings.reminders.section.description",
            bundle: .module
          )
        )
      }
    }
    .navigationTitle(
      LocalizedStringResource("settings.title", bundle: .module)
    )
  }
}

private struct SettingsToggleLabel: View {
  let title: LocalizedStringResource
  let subtitle: LocalizedStringResource

  var body: some View {
    VStack(alignment: .leading, spacing: 2) {
      Text(title)
      Text(subtitle)
        .font(.footnote)
        .foregroundStyle(.secondary)
    }
  }
}
