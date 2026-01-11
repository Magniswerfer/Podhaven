//
//  PodhavenApp.swift
//  Podhaven
//
//  Created by Magnus Kaspersen on 11/01/2026.
//

import SwiftUI
import CoreData

@main
struct PodhavenApp: App {
    let persistenceController = PersistenceController.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
        }
    }
}
