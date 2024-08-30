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
    @State private var rootEntity: Entity?
    @State private var dragStartPos: SIMD3<Float>?
    @State private var isDragging = false
    @State private var instructionTop: Entity?
    @State private var instructionBottom: Entity?
    private let ROUND_X_DRAG: Float = 0.5
    private let MIN_X_DRAG: Float = -1
    private let MAX_X_DRAG: Float = 0
    
    var body: some View {
        RealityView { content in
            // Add the options
            if let menu = try? await Entity(named: "Menu", in: realityKitContentBundle) {
                content.add(menu)
                rootEntity = menu.children.first
                // Play all animations
                menu.children.first?.children.forEach({ room in
                    if let ani = room.availableAnimations.first {
                        room.playAnimation(ani.repeat())
                    }
                })
                instructionTop = getTextEntity(text: "Drag to select level")
                if (instructionTop != nil) {
                    instructionTop!.position = SIMD3(x: -0.40, y: 0.15, z: 0)
                    rootEntity?.addChild(instructionTop!)
                }
                instructionBottom = getTextEntity(text: "Tap to play!")
                if (instructionBottom != nil) {
                    instructionBottom!.position = SIMD3(x: -0.25, y: -0.45, z: 0)
                    content.add(instructionBottom!)
                }
            }
        }
        .gesture(SpatialTapGesture().targetedToEntity(where: .has(ButtonComponent.self)).onEnded({ roomSelect in
            if let buttonComponent = roomSelect.entity.components[ButtonComponent.self] {
                handlePlay(room: buttonComponent.getSecondaryName())
            }
        }))
        // Custom drag instead of gesture to preserve taps on rooms
        .gesture(DragGesture().targetedToAnyEntity().onChanged({ drag in
            if (rootEntity != nil) {
                if (!isDragging) {
                    dragStartPos = rootEntity!.position
                    isDragging = true
                }
                let translation3D = drag.translation3D
                
                let offset = SIMD3<Float>(x: Float(translation3D.x) / 1000, y: 0, z: 0)
                
                rootEntity!.position = dragStartPos! + offset
            }
        }).onEnded({ dragEnd in
            if (rootEntity != nil) {
                isDragging = false
                let pos = rootEntity!.position
                rootEntity!.move(to: Transform(translation: SIMD3(x: roundTo(x: pos.x, to: ROUND_X_DRAG) - pos.x, y: 0, z: 0)), relativeTo: rootEntity!, duration: 0.3)
            }
        }))
    }
    
    func handlePlay(room: String = "Room01") {
        Task {
            let result = await openImmersiveSpace(id: room)
            if case .error = result {
                print("Invalid room name.")
            }
        }
    }
    
    func roundTo(x: Float, to: Float) -> Float {
        let rounded = round(x / to) * to
        if (rounded < MIN_X_DRAG) {
            return MIN_X_DRAG
        } else if (rounded > MAX_X_DRAG) {
            return MAX_X_DRAG
        }
        return rounded
    }
    
    func getTextEntity(text: String) -> ModelEntity {
        let textMaterial = SimpleMaterial(color: UIColor(red: 140/255, green: 210/255, blue: 240/255, alpha: 1), isMetallic: false)
        let textEntity = ModelEntity(mesh: .generateText(
            text,
            extrusionDepth: 0.02,
            font: UIFont.monospacedSystemFont(ofSize: 0.07, weight: .semibold),
            alignment: .center
        ), materials: [textMaterial])
        return textEntity
    }
}

#Preview(windowStyle: .volumetric) {
    Menu()
}
