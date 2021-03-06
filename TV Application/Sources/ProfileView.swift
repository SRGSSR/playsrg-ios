//
//  Copyright (c) SRG SSR. All rights reserved.
//
//  License information is available from the LICENSE file.
//

import SRGUserData
import SwiftUI

struct ProfileView: View {
    @StateObject var model = ProfileModel()
    
    var synchronizationMessage: String? {
        guard model.isLoggedIn else { return nil }
        let dateString = (model.synchronizationDate != nil) ? DateFormatter.play_relativeDateAndTime.string(from: model.synchronizationDate!) : NSLocalizedString("Never", comment: "Text displayed when no data synchronization has been made yet")
        return String(format: NSLocalizedString("Last synchronization: %@", comment: "Introductory text for the most recent data synchronization date"), dateString)
    }
    
    var body: some View {
        List {
            if model.supportsLogin {
                Section(header: Text(NSLocalizedString("Profile", comment: "Profile section header")).srgFont(.headline1),
                        footer: Text(NSLocalizedString("Synchronize playback history, favorites and content saved for later on all devices connected to your account.", comment: "Login benefits description footer")).srgFont(.overline).opacity(0.8)) {
                    ProfileListItem(model: model)
                }
            }
            if let synchronizationMessage = synchronizationMessage {
                Section(header: Text(NSLocalizedString("Content", comment: "Profile content section header")).srgFont(.headline1),
                        footer: Text(synchronizationMessage).srgFont(.overline).opacity(0.8)) {
                    HistoryRemovalListItem(model: model)
                    FavoritesRemovalListItem(model: model)
                    WatchLaterRemovalListItem(model: model)
                }
            }
            else {
                Section(header: Text(NSLocalizedString("Content", comment: "Profile content section header")).srgFont(.headline1)) {
                    HistoryRemovalListItem(model: model)
                    FavoritesRemovalListItem(model: model)
                    WatchLaterRemovalListItem(model: model)
                }
            }
            if ApplicationConfiguration.shared.isContinuousPlaybackAvailable {
                Section(header: Text(PlaySRGSettingsLocalizedString("Playback", "Playback settings section header")),
                        footer: Text(PlaySRGSettingsLocalizedString("When enabled, more content is automatically played after playback of the current content ends.", "Playback description footer")).srgFont(.overline).opacity(0.8)) {
                    AutoplayListItem()
                }
            }
            Section(header: Text(PlaySRGSettingsLocalizedString("Information", "Information section header")).srgFont(.headline1)) {
                VersionListItem(model: model)
            }
        }
        .listStyle(GroupedListStyle())
        .frame(maxWidth: 1054)
        .tracked(withTitle: analyticsPageTitle, levels: analyticsPageLevels)
    }
    
    struct ProfileListItem: View {
        @ObservedObject var model: ProfileModel
        @State var alertDisplayed = false
        
        var text: String {
            guard model.isLoggedIn else { return NSLocalizedString("Login", comment: "Login button on Apple TV") }
            if let username = model.username {
                return NSLocalizedString("Logout", comment: "Logout button on Apple TV").appending(" (\(username))")
            }
            else {
                return NSLocalizedString("Logout", comment: "Logout button on Apple TV")
            }
        }
        
        func alert() -> Alert {
            let primaryButton = Alert.Button.cancel(Text(NSLocalizedString("Cancel", comment: "Title of the cancel button in the alert view when logout"))) {}
            let secondaryButton = Alert.Button.destructive(Text(NSLocalizedString("Logout", comment: "Logout button on Apple TV"))) {
                model.logout()
            }
            return Alert(title: Text(NSLocalizedString("Logout", comment: "Logout alert view title on Apple TV")),
                         message: Text(NSLocalizedString("Playback history, favorites and content saved for later will be deleted from this Apple TV.", comment: "Message displayed when the user is about to log out")),
                         primaryButton: primaryButton,
                         secondaryButton: secondaryButton)
        }
        
        var body: some View {
            Button(action: {
                if model.isLoggedIn {
                    alertDisplayed = true
                }
                else {
                    model.login()
                }
            }) {
                Text(text)
                    .srgFont(.button1)
            }
            .padding()
            .alert(isPresented: $alertDisplayed, content: alert)
        }
    }
    
    struct AutoplayListItem: View {
        @AppStorage(PlaySRGSettingAutoplayEnabled) var isAutoplayEnabled = false
        
        var body: some View {
            Button(action: {
                isAutoplayEnabled = !isAutoplayEnabled
            }) {
                HStack {
                    Text(PlaySRGSettingsLocalizedString("Autoplay", "Autoplay setting"))
                        .srgFont(.button1)
                    Spacer()
                    Text(isAutoplayEnabled ? PlaySRGSettingsLocalizedString("On", "Enabled state label on Apple TV") : PlaySRGSettingsLocalizedString("Off", "Disabled state label on Apple TV"))
                        .srgFont(.button1)
                        .foregroundColor(.secondary)
                }
            }
            .padding()
        }
    }
    
    struct HistoryRemovalListItem: View {
        @ObservedObject var model: ProfileModel
        @State var alertDisplayed = false
        
        func alert() -> Alert {
            let primaryButton = Alert.Button.cancel(Text(NSLocalizedString("Cancel", comment: "Title of a cancel button"))) {}
            let secondaryButton = Alert.Button.destructive(Text(NSLocalizedString("Delete", comment: "Title of a delete button"))) {
                model.removeHistory()
            }
            if model.isLoggedIn {
                return Alert(title: Text(NSLocalizedString("Delete history", comment: "Title of the message displayed when the user is about to delete the history")),
                             message: Text(NSLocalizedString("The history will be deleted on all devices connected to your account.", comment: "Message displayed when the user is about to delete the history")),
                             primaryButton: primaryButton,
                             secondaryButton: secondaryButton)
            }
            else {
                return Alert(title: Text(NSLocalizedString("Delete history", comment: "Title of the message displayed when the user is about to delete the history")),
                             primaryButton: primaryButton,
                             secondaryButton: secondaryButton)
            }
        }
        
        var body: some View {
            Button(action: {
                if model.hasHistoryEntries {
                    alertDisplayed = true
                }
            }) {
                Text(NSLocalizedString("Delete history", comment: "Delete history button title"))
                    .srgFont(.button1)
                    .foregroundColor(model.hasHistoryEntries ? .primary : .secondary)
            }
            .padding()
            .alert(isPresented: $alertDisplayed, content: alert)
        }
    }
    
    struct FavoritesRemovalListItem: View {
        @ObservedObject var model: ProfileModel
        @State var alertDisplayed = false
        
        func alert() -> Alert {
            let primaryButton = Alert.Button.cancel(Text(NSLocalizedString("Cancel", comment: "Title of a cancel button"))) {}
            let secondaryButton = Alert.Button.destructive(Text(NSLocalizedString("Delete", comment: "Title of a delete button"))) {
                model.removeFavorites()
            }
            if model.isLoggedIn {
                return Alert(title: Text(NSLocalizedString("Delete favorites", comment: "Title of the message displayed when the user is about to delete all favorites")),
                             message: Text(NSLocalizedString("Favorites and notification subscriptions will be deleted on all devices connected to your account.", comment: "Message displayed when the user is about to delete all favorites")),
                             primaryButton: primaryButton,
                             secondaryButton: secondaryButton)
            }
            else {
                return Alert(title: Text(NSLocalizedString("Delete favorites", comment: "Title of the message displayed when the user is about to delete all favorites")),
                             primaryButton: primaryButton,
                             secondaryButton: secondaryButton)
            }
        }
        
        var body: some View {
            Button(action: {
                if model.hasFavorites {
                    alertDisplayed = true
                }
            }) {
                Text(NSLocalizedString("Delete favorites", comment: "Delete favorites button title"))
                    .srgFont(.button1)
                    .foregroundColor(model.hasFavorites ? .primary : .secondary)
            }
            .padding()
            .alert(isPresented: $alertDisplayed, content: alert)
        }
    }
    
    struct WatchLaterRemovalListItem: View {
        @ObservedObject var model: ProfileModel
        @State var alertDisplayed = false
        
        func alert() -> Alert {
            let primaryButton = Alert.Button.cancel(Text(NSLocalizedString("Cancel", comment: "Title of a cancel button"))) {}
            let secondaryButton = Alert.Button.destructive(Text(NSLocalizedString("Delete", comment: "Title of a delete button"))) {
                model.removeWatchLaterItems()
            }
            if model.isLoggedIn {
                return Alert(title: Text(NSLocalizedString("Delete content saved for later", comment: "Title of the message displayed when the user is about to delete content saved for later")),
                             message: Text(NSLocalizedString("Content saved for later will be deleted on all devices connected to your account.", comment: "Message displayed when the user is about to delete content saved for later")),
                             primaryButton: primaryButton,
                             secondaryButton: secondaryButton)
            }
            else {
                return Alert(title: Text(NSLocalizedString("Delete content saved for later", comment: "Title of the message displayed when the user is about to delete content saved for later")),
                             primaryButton: primaryButton,
                             secondaryButton: secondaryButton)
            }
        }
        
        var body: some View {
            Button(action: {
                if model.hasWatchLaterItems {
                    alertDisplayed = true
                }
            }) {
                Text(NSLocalizedString("Delete content saved for later", comment: "Title of the button to delete content saved for later"))
                    .srgFont(.button1)
                    .foregroundColor(model.hasWatchLaterItems ? .primary : .secondary)
            }
            .padding()
            .alert(isPresented: $alertDisplayed, content: alert)
        }
    }
    
    struct VersionListItem: View {
        var model: ProfileModel
        
        var body: some View {
            Button(action: {}) {
                HStack {
                    Text(PlaySRGSettingsLocalizedString("Version", "Version introductory label"))
                        .srgFont(.button1)
                    Spacer()
                    Text(model.version)
                        .srgFont(.button1)
                }
                .foregroundColor(.secondary)
            }
            .padding()
        }
    }
}

extension ProfileView {
    private var analyticsPageTitle: String {
        return AnalyticsPageTitle.home.rawValue
    }
    
    private var analyticsPageLevels: [String]? {
        return [AnalyticsPageLevel.play.rawValue, AnalyticsPageLevel.user.rawValue]
    }
}
