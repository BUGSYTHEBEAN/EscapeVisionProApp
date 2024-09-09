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
    @StateObject private var coreDataStack = CoreDataStack.shared
    @State private var level = 1
    
    init() {
        RealityKitContent.ButtonComponent.registerComponent()
        RealityKitContent.GestureComponent.registerComponent()
    }
    
    var body: some Scene {
        // https://developer.apple.com/documentation/SwiftUI/EnvironmentValues/openImmersiveSpace
        ImmersiveSpace(id: "Room01") {
            Room01()
                .environment(\.managedObjectContext, coreDataStack.persistentContainer.viewContext)
        }.immersionStyle(selection: .constant(.full), in: .full)
        
        WindowGroup(id: "Menu") {
            Menu()
                .environment(\.managedObjectContext, coreDataStack.persistentContainer.viewContext)
        }.windowStyle(.volumetric)
    }
}
