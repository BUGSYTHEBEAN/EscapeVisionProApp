//
//  escapeApp.swift
//  escape
//
//  Created by Andrei Freund on 6/29/24.
//

import SwiftUI

@main
struct escapeApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }.windowStyle(.volumetric)

        ImmersiveSpace(id: "ImmersiveSpace") {
            ImmersiveView()
        }.immersionStyle(selection: .constant(.full), in: .full)
    }
}
