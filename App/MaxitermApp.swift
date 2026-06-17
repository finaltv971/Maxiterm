//
//  MaxitermApp.swift
//  Maxiterm
//
//  Client SSH / SFTP / remote — 100% open source, sans abonnement.
//

import Persistence
import SwiftUI

@main
struct MaxitermApp: App {
    @StateObject private var store: ProfileStore
    @StateObject private var logStore: SessionLogStore

    init() {
        // Profils : iCloud si possible, repli local puis mémoire.
        let store: ProfileStore
        if let disk = try? ProfileStore.makeDefault() {
            store = disk
        } else {
            store = try! ProfileStore.makeInMemory() // swiftlint:disable:this force_try
        }
        _store = StateObject(wrappedValue: store)

        // Journaux : stockage local.
        let logStore = (try? SessionLogStore.makeDefault())
            ?? (try! SessionLogStore.makeInMemory()) // swiftlint:disable:this force_try
        _logStore = StateObject(wrappedValue: logStore)
    }

    var body: some Scene {
        WindowGroup {
            ProfileListView()
                .environmentObject(store)
                .environmentObject(logStore)
                .modelContainer(store.container)
        }
    }
}
