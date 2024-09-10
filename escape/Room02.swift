//
//  Room02.swift
//  escape
//
//  Created by Andrei Freund on 9/9/24.
//

import SwiftUI
import RealityKit
import RealityKitContent
import CoreData

struct Room02: View, Room {
    @Environment(\.openWindow) private var openWindow
    @Environment(\.dismissWindow) private var dismissWindow
    @Environment(\.dismissImmersiveSpace) private var dismissImmersiveSpace
    @Environment(\.managedObjectContext) private var viewContext
    // Protocol vars for all rooms
    static let LEVEL_TIME = 10 * 60
    @State internal var timeRemaining = LEVEL_TIME
    
    var body: some View {
        RealityView { content in
            // Add the skybox
            if let skybox = createSkybox(name: "spaceskybox") {
                dismissWindow(id: "Menu")
                content.add(skybox)
            }
            // Add interactive room content
            if let immersiveContentEntity = try? await Entity(named: "Room02", in: realityKitContentBundle) {
                content.add(immersiveContentEntity)
                
                // Add an ImageBasedLight for the immersive content
                guard let resource = try? await EnvironmentResource(named: "ImageBasedLight") else { return }
                let iblComponent = ImageBasedLightComponent(source: .single(resource), intensityExponent: 0.25)
                immersiveContentEntity.components.set(iblComponent)
                immersiveContentEntity.components.set(ImageBasedLightReceiverComponent(imageBasedLight: immersiveContentEntity))
            }
        }
    }
}
