//
//  StreamHavenAppApp.swift
//  StreamHavenApp
//
//  Created by Ahmed Elkasrawi on 07/11/2025.
//

import SwiftUI
import StreamHaven

@main
struct StreamHavenAppApp: App {
    let provider: PersistenceProviding = DefaultPersistenceProvider(controller: PersistenceController())
    var body: some Scene {
        WindowGroup {
            ContentView(persistenceProvider: provider)
        }
    }
}
