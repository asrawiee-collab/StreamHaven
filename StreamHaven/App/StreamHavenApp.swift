import SwiftUI

/// The main entry point of the StreamHaven application.
@main
public struct StreamHavenApp: App {
    /// The shared `PersistenceController` for Core Data.
    let persistenceController = PersistenceController.shared

    /// The body of the app.
    public var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
        }
    }
}
