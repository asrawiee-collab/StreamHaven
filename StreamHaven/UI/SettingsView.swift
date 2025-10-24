import SwiftUI

/// A view for managing user settings.
public struct SettingsView: View {
    @EnvironmentObject var settingsManager: SettingsManager

    /// The body of the view.
    public var body: some View {
        Form {
            Section(header: Text(NSLocalizedString("Appearance", comment: "Settings section header for appearance"))) {
                Picker(NSLocalizedString("Theme", comment: "Settings option for app theme"), selection: $settingsManager.theme) {
                    ForEach(SettingsManager.AppTheme.allCases) { theme in
                        Text(theme.rawValue).tag(theme)
                    }
                }
            }

            Section(header: Text(NSLocalizedString("Playback", comment: "Settings section header for playback"))) {
                VStack(alignment: .leading) {
                    Text(NSLocalizedString("Subtitle Size", comment: "Settings option for subtitle size"))
                    Slider(value: $settingsManager.subtitleSize, in: 50...200, step: 10) {
                        Text(String(format: "%.0f%%", settingsManager.subtitleSize))
                    }
                    Text(String(format: "%.0f%%", settingsManager.subtitleSize))
                        .font(.caption)
                        .frame(maxWidth: .infinity, alignment: .center)
                }
            }

            Section(header: Text(NSLocalizedString("Parental Controls", comment: "Settings section header for parental controls"))) {
                Toggle(NSLocalizedString("Enable Parental Lock", comment: "Settings option to enable parental lock"), isOn: $settingsManager.isParentalLockEnabled)
                if settingsManager.isParentalLockEnabled {
                    Text(NSLocalizedString("Note: PIN functionality will be added in a future update.", comment: "Informational text for parental lock"))
                        .font(.caption)
                        .foregroundColor(.gray)
                }
            }
        }
        .navigationTitle(NSLocalizedString("Settings", comment: "Settings view navigation title"))
    }
}
