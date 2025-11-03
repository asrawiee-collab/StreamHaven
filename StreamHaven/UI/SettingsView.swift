#if os(iOS) || os(tvOS)
import AVKit
import SwiftUI

/// A view for managing user settings.
public struct SettingsView: View {
    @Environment(\.managedObjectContext) private var context
    @EnvironmentObject var settingsManager: SettingsManager
    @EnvironmentObject var profileManager: ProfileManager
    @EnvironmentObject var subscriptionManager: SubscriptionManager
    @StateObject private var sourceManager = PlaylistSourceManager()

    /// The body of the view.
    public var body: some View {
        Form {
            if MonetizationConfig.isMonetizationEnabled {
                Section(header: Text(NSLocalizedString("Subscription", comment: "Settings section header for subscription"))) {
                    HStack {
                        Text(NSLocalizedString("Status", comment: "Subscription status label"))
                        Spacer()
                        if subscriptionManager.isSubscribed {
                            let planName = subscriptionManager.currentPlan == .plusYearly ? NSLocalizedString("Plus Yearly", comment: "Yearly plan") : NSLocalizedString("Plus Monthly", comment: "Monthly plan")
                            Text(planName).foregroundColor(.secondary)
                        } else {
                            Text(NSLocalizedString("Not Subscribed", comment: "Not subscribed status")).foregroundColor(.secondary)
                        }
                    }

                    // Plan benefits
                    VStack(alignment: .leading, spacing: 6) {
                        Text(NSLocalizedString("Plus Benefits", comment: "Header for plan benefits"))
                            .font(.subheadline)
                        Group {
                            Text("• " + NSLocalizedString("Ad-free browsing and viewing", comment: "Benefit: ad-free"))
                            #if !os(tvOS)
                            Text("• " + NSLocalizedString("Offline downloads on iPhone/iPad", comment: "Benefit: offline downloads"))
                            #endif
                            Text("• " + NSLocalizedString("Priority feature access and updates", comment: "Benefit: priority access"))
                            Text("• " + NSLocalizedString("Support StreamHaven development", comment: "Benefit: support development"))
                        }
                        .foregroundColor(.secondary)
                        .font(.caption)
                    }

                    // Purchase buttons
                    Button(action: { Task { await subscriptionManager.purchaseMonthly() } }) {
                        let price = subscriptionManager.products.first(where: { $0.id == MonetizationConfig.ProductID.plusMonthly })?.displayPrice ?? ""
                        Text(String(format: NSLocalizedString("Subscribe Monthly %@", comment: "Subscribe monthly button with price"), price))
                    }
                    .disabled(subscriptionManager.currentPlan == .plusMonthly)

                    Button(action: { Task { await subscriptionManager.purchaseYearly() } }) {
                        let price = subscriptionManager.products.first(where: { $0.id == MonetizationConfig.ProductID.plusYearly })?.displayPrice ?? ""
                        Text(String(format: NSLocalizedString("Subscribe Yearly %@", comment: "Subscribe yearly button with price"), price))
                    }
                    .disabled(subscriptionManager.currentPlan == .plusYearly)

                    Button(NSLocalizedString("Restore Purchases", comment: "Restore purchases button")) {
                        Task { await subscriptionManager.restore() }
                    }

                    #if os(iOS) || os(tvOS)
                    if subscriptionManager.isSubscribed {
                        Button(NSLocalizedString("Manage Subscription", comment: "Button to open subscription management")) {
                            SubscriptionUtilities.openManageSubscriptions()
                        }
                    }
                    #endif

                    if let error = subscriptionManager.errorMessage, !error.isEmpty {
                        Text(error)
                            .font(.caption)
                            .foregroundColor(.red)
                    }

                    // Privacy/Terms footnote
                    VStack(alignment: .leading, spacing: 2) {
                        Text(NSLocalizedString("By subscribing, you agree to our ", comment: "Subscription footnote prefix")) +
                        Text(NSLocalizedString("Privacy Policy", comment: "Privacy Policy link text"))
                            .underline()
                            .foregroundColor(.blue)
                            .onTapGesture {
                                if let url = URL(string: "https://streamhaven.app/privacy") {
                                    #if canImport(UIKit)
                                    UIApplication.shared.open(url)
                                    #endif
                                }
                            }
                        Text(NSLocalizedString(" and ", comment: "Subscription footnote middle")) +
                        Text(NSLocalizedString("Terms of Service", comment: "Terms of Service link text"))
                            .underline()
                            .foregroundColor(.blue)
                            .onTapGesture {
                                if let url = URL(string: "https://streamhaven.app/terms") {
                                    #if canImport(UIKit)
                                    UIApplication.shared.open(url)
                                    #endif
                                }
                            }
                        Text(NSLocalizedString(".", comment: "Subscription footnote end"))
                    }
                    .font(.caption)
                    .foregroundColor(.secondary)
                }
            }
            
            Section(header: Text(NSLocalizedString("Playlists", comment: "Settings section header for playlists"))) {
                if let profile = profileManager.currentProfile {
                    NavigationLink(destination: PlaylistSourcesView(profile: profile)
                        .environment(\.managedObjectContext, context)
                        .onAppear {
                            sourceManager.loadSources(for: profile)
                        }) {
                        HStack {
                            Image(systemName: "list.bullet.rectangle")
                            Text(NSLocalizedString("Manage Sources", comment: "Settings option to manage playlist sources"))
                            Spacer()
                            if !sourceManager.sources.isEmpty {
                                Text("\(sourceManager.sources.count)")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    
                    Text(NSLocalizedString("Add and manage multiple M3U playlists and Xtream Codes logins.", comment: "Informational text for manage sources"))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
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
                
                #if os(iOS)
                if AVPictureInPictureController.isPictureInPictureSupported() {
                    Toggle(NSLocalizedString("Enable Picture-in-Picture", comment: "Settings option to enable PiP"), isOn: $settingsManager.enablePiP)
                    Text(NSLocalizedString("Continue watching while using other apps or viewing your Home Screen.", comment: "Informational text for PiP"))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                #endif
                
                Toggle(NSLocalizedString("Pre-buffer Next Episode", comment: "Settings option to enable pre-buffering"), isOn: $settingsManager.enablePreBuffer)
                Text(NSLocalizedString("Automatically prepare the next episode for seamless playback.", comment: "Informational text for pre-buffer"))
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                if settingsManager.enablePreBuffer {
                    VStack(alignment: .leading) {
                        Text(NSLocalizedString("Pre-buffer Start Time", comment: "Settings option for pre-buffer timing"))
                        Slider(value: $settingsManager.preBufferTimeSeconds, in: 30...300, step: 30) {
                            Text(String(format: "%.0f seconds", settingsManager.preBufferTimeSeconds))
                        }
                        Text(String(format: "%.0f seconds before episode ends", settingsManager.preBufferTimeSeconds))
                            .font(.caption)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .foregroundColor(.secondary)
                    }
                }
                
                Toggle(NSLocalizedString("Enable Skip Intro Button", comment: "Settings option to enable skip intro"), isOn: $settingsManager.enableSkipIntro)
                Text(NSLocalizedString("Show 'Skip Intro' button during episode intros.", comment: "Informational text for skip intro"))
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                if settingsManager.enableSkipIntro {
                    Toggle(NSLocalizedString("Auto-Skip Intros", comment: "Settings option to automatically skip intros"), isOn: $settingsManager.autoSkipIntro)
                    Text(NSLocalizedString("Automatically skip intros without showing a button.", comment: "Informational text for auto-skip"))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            Section(header: Text(NSLocalizedString("Content Filtering", comment: "Settings section header for content filtering"))) {
                if let profile = profileManager.currentProfile, profile.isAdult {
                    Toggle(NSLocalizedString("Hide Adult Content (NC-17)", comment: "Settings option to hide adult content"), isOn: $settingsManager.hideAdultContent)
                    Text(NSLocalizedString("Filters out NC-17 rated content from all views.", comment: "Informational text for adult content filter"))
                        .font(.caption)
                        .foregroundColor(.secondary)
                } else {
                    Text(NSLocalizedString("Kids profiles automatically filter adult content (R and NC-17 ratings).", comment: "Informational text for kids profile filtering"))
                        .font(.caption)
                        .foregroundColor(.secondary)
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

            Section(header: Text(NSLocalizedString("Accessibility", comment: "Settings section header for accessibility"))) {
                Toggle(NSLocalizedString("Enable Accessibility Mode", comment: "Settings option to enable accessibility mode"), isOn: $settingsManager.accessibilityModeEnabled)
                Text(NSLocalizedString("Enhances focus navigation, larger touch targets, and supports Dwell Control for hands-free interaction.", comment: "Informational text for accessibility mode"))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Section(header: Text(NSLocalizedString("iCloud Sync", comment: "Settings section header for iCloud sync"))) {
                Toggle(NSLocalizedString("Enable iCloud Sync", comment: "Settings option to enable iCloud sync"), isOn: $settingsManager.enableCloudSync)
                Text(NSLocalizedString("Sync profiles, favorites, and watch history across all your devices using iCloud.", comment: "Informational text for iCloud sync"))
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                if settingsManager.enableCloudSync {
                    if let lastSync = settingsManager.lastCloudSyncDate {
                        Text(NSLocalizedString("Last synced: \(lastSync.formatted())", comment: "Last sync timestamp"))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    } else {
                        Text(NSLocalizedString("Never synced", comment: "Never synced message"))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Button(NSLocalizedString("Sync Now", comment: "Button to trigger manual sync")) {
                        Task {
                            // TODO: Trigger manual sync via CloudKitSyncManager
                        }
                    }
                }
            }
            
            #if os(iOS)
            Section(header: Text(NSLocalizedString("Live Activities", comment: "Settings section header for Live Activities"))) {
                Toggle(NSLocalizedString("Enable Live Activities", comment: "Settings option to enable Live Activities"), isOn: $settingsManager.enableLiveActivities)
                Text(NSLocalizedString("Show playback controls on Lock Screen and Dynamic Island (iOS 16.1+).", comment: "Informational text for Live Activities"))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            #endif
            
#if !os(tvOS)
            // Downloads Section (iOS only)
            Section(header: Text(NSLocalizedString("Downloads", comment: "Settings section header for Downloads"))) {
                Stepper(value: $settingsManager.maxDownloadStorageGB, in: 1...100, step: 5) {
                    HStack {
                        Text(NSLocalizedString("Max Storage", comment: "Settings label for maximum download storage"))
                        Spacer()
                        Text("\(settingsManager.maxDownloadStorageGB) GB")
                            .foregroundColor(.secondary)
                    }
                }
                
                Picker(NSLocalizedString("Download Quality", comment: "Settings label for download quality"), selection: $settingsManager.downloadQuality) {
                    Text(NSLocalizedString("Low (~720p)", comment: "Low download quality option")).tag("low")
                    Text(NSLocalizedString("Medium (~1080p)", comment: "Medium download quality option")).tag("medium")
                    Text(NSLocalizedString("High (~4K)", comment: "High download quality option")).tag("high")
                    Text(NSLocalizedString("Auto (Best)", comment: "Auto download quality option")).tag("auto")
                }
                
                Toggle(NSLocalizedString("Auto-Delete Watched", comment: "Settings option to auto-delete watched downloads"), isOn: $settingsManager.autoDeleteWatchedDownloads)
                
                Stepper(value: $settingsManager.downloadExpirationDays, in: 7...90, step: 7) {
                    HStack {
                        Text(NSLocalizedString("Expiration", comment: "Settings label for download expiration"))
                        Spacer()
                        Text("\(settingsManager.downloadExpirationDays) days")
                            .foregroundColor(.secondary)
                    }
                }
                
                Text(NSLocalizedString("Downloads expire after the set number of days and are automatically deleted.", comment: "Informational text for Downloads expiration"))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            #endif
            
            // Up Next Queue Section
            Section(header: Text(NSLocalizedString("Up Next Queue", comment: "Settings section header for Up Next Queue"))) {
                Toggle(NSLocalizedString("Auto-Generate Suggestions", comment: "Settings option to enable auto-generated queue suggestions"), isOn: $settingsManager.enableAutoQueue)
                
                if settingsManager.enableAutoQueue {
                    Stepper(value: $settingsManager.autoQueueSuggestions, in: 1...10) {
                        HStack {
                            Text(NSLocalizedString("Suggestions Count", comment: "Settings label for number of suggestions"))
                            Spacer()
                            Text("\(settingsManager.autoQueueSuggestions)")
                                .foregroundColor(.secondary)
                        }
                    }
                }
                
                Stepper(value: $settingsManager.maxQueueSize, in: 10...100, step: 10) {
                    HStack {
                        Text(NSLocalizedString("Max Queue Size", comment: "Settings label for maximum queue size"))
                        Spacer()
                        Text("\(settingsManager.maxQueueSize) items")
                            .foregroundColor(.secondary)
                    }
                }
                
                Toggle(NSLocalizedString("Clear on Profile Switch", comment: "Settings option to clear queue when switching profiles"), isOn: $settingsManager.clearQueueOnProfileSwitch)
                
                Text(NSLocalizedString("The Up Next queue automatically suggests content based on your watching habits.", comment: "Informational text for Up Next Queue"))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            // TMDb Integration Section
            Section(header: Text(NSLocalizedString("TMDb Integration", comment: "Settings section header for TMDb Integration"))) {
                Toggle(NSLocalizedString("Fetch Actor Information", comment: "Settings option to fetch actor information from TMDb"), isOn: $settingsManager.fetchActorInfo)
                
                Text(NSLocalizedString("Automatically fetch cast information from The Movie Database (TMDb) for movies and series.", comment: "Informational text for TMDb Integration"))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            #if os(tvOS)
            // tvOS Hover Previews Section
            Section(header: Text(NSLocalizedString("Hover Previews", comment: "Settings section header for tvOS hover previews"))) {
                Toggle(NSLocalizedString("Enable Hover Previews", comment: "Settings option to enable video previews on focus"), isOn: $settingsManager.enableHoverPreviews)
                
                if settingsManager.enableHoverPreviews {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text(NSLocalizedString("Preview Delay", comment: "Settings label for preview delay"))
                            Spacer()
                            Text(String(format: "%.1f s", settingsManager.hoverPreviewDelay))
                                .foregroundColor(.secondary)
                        }
                        
                        Slider(value: $settingsManager.hoverPreviewDelay, in: 0.5...3.0, step: 0.5)
                    }
                }
                
                Text(NSLocalizedString("When enabled, video previews will play automatically when you focus on content. Adjust the delay to control how quickly previews start.", comment: "Informational text for hover previews"))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            #endif
        }
        .navigationTitle(NSLocalizedString("Settings", comment: "Settings view navigation title"))
        .task {
            subscriptionManager.loadCachedEntitlements()
            await subscriptionManager.load()
        }
    }
}
#endif
