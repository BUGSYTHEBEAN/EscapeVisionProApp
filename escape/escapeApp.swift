//
//  escapeApp.swift
//  escape
//
//  Created by Andrei Freund on 6/29/24.
//

import SwiftUI
import RealityKitContent

@main
struct escapeApp: App {
    @State private var level = 1
    
    init() {
        RealityKitContent.ButtonComponent.registerComponent()
        RealityKitContent.GestureComponent.registerComponent()
    }
    
    var body: some Scene {
        // https://developer.apple.com/documentation/SwiftUI/EnvironmentValues/openImmersiveSpace
        ImmersiveSpace(id: "Room01") {
            Room01()
        }.immersionStyle(selection: .constant(.full), in: .full)
        
        WindowGroup(id: "Menu") {
            Menu()
        }.windowStyle(.volumetric)
    }
}
