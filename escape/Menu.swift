//
//  Menu.swift
//  escape
//
//  Created by Andrei Freund on 8/27/24.
//

import SwiftUI
import RealityKit
import RealityKitContent

struct Menu: View {
    @Environment(\.openImmersiveSpace) private var openImmersiveSpace
    
    var body: some View {
        RealityView { content in
            // Add the options
            if let menu = try? await Entity(named: "Menu", in: realityKitContentBundle) {
                content.add(menu)
            }
        }
        .toolbar {
            ToolbarItemGroup(placement: .bottomOrnament) {
                HStack (spacing: 12) {
                    Button("Left", systemImage: "arrowshape.left", action: {print("left")})
                        .labelStyle(.iconOnly).font(.title)
                    Button("Play", systemImage: "play", action: {handlePlay()})
                        .labelStyle(.iconOnly).font(.title)
                    Button("Right", systemImage: "arrowshape.right", action: {print("right")})
                        .labelStyle(.iconOnly).font(.title)
                }.padding(.horizontal, 12)
            }
        }
    }
    
    func handlePlay() {
        Task {
            let result = await openImmersiveSpace(id: "Room01")
            if case .error = result {
                print("An error occurred")
            }
        }
    }
}

#Preview(windowStyle: .volumetric) {
    Menu()
}
