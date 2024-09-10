//
//  Menu.swift
//  escape
//
//  Created by Andrei Freund on 8/27/24.
//

import SwiftUI
import RealityKit
import RealityKitContent
import CoreData

struct Menu: View {
    @Environment(\.openImmersiveSpace) private var openImmersiveSpace
    @Environment(\.managedObjectContext) private var viewContext
    @State private var rootEntity: Entity?
    @State private var lockEntity: Entity?
    @State private var checkEntity: Entity?
    @State private var warningEntity: Entity?
    @State private var dragStartPos: SIMD3<Float>?
    @State private var isDragging = false
    @State private var instructionTop: Entity?
    @State private var instructionBottom: Entity?
    private let ROUND_X_DRAG: Float = 0.5
    private let MIN_X_DRAG: Float = -1
    private let MAX_X_DRAG: Float = 0
    
    enum RoomStateEnum {
        case open
        case locked
        case complete
    }
    
    var body: some View {
        RealityView { content in
            // Add the options
            if let menu = try? await Entity(named: "Menu", in: realityKitContentBundle) {
                content.add(menu)
                rootEntity = menu.children.first
                // Setup locks and checks
                if let lock = try? await Entity(named: "GreyLock", in: realityKitContentBundle) {
                    lockEntity = lock
                }
                if let check = try? await Entity(named: "Check", in: realityKitContentBundle) {
                    checkEntity = check
                }
                // Play all animations
                menu.children.first?.children.forEach({ room in
                    if let buttonComponent = room.components[ButtonComponent.self] {
                        let state = getRoomState(roomNum: buttonComponent.getButtonNum())
                        addRoomStateEntity(room: room, parent: menu, roomState: state.state, bestTime: state.bestTime)
                    }
                    if let ani = room.availableAnimations.first {
                        room.playAnimation(ani.repeat())
                    }
                })
                instructionBottom = getTextEntity(text: "Tap to play!", color: UIColor(red: 140/255, green: 210/255, blue: 240/255, alpha: 1))
                if (instructionBottom != nil) {
                    instructionBottom!.position = SIMD3(x: -0.25, y: -0.45, z: 0)
                    content.add(instructionBottom!)
                }
            }
        }
        .gesture(SpatialTapGesture().targetedToEntity(where: .has(ButtonComponent.self)).onEnded({ roomSelect in
            if let buttonComponent = roomSelect.entity.components[ButtonComponent.self] {
                if (getRoomState(roomNum: buttonComponent.getButtonNum()).state != RoomStateEnum.locked) {
                    handlePlay(room: buttonComponent.getSecondaryName())
                } else {
                    instructionTop = getTextEntity(text: "Complete previous rooms to unlock", color: UIColor(red: 230/255, green: 100/255, blue: 100/255, alpha: 1))
                    if (instructionTop != nil) {
                        warningEntity?.removeFromParent()
                        instructionTop!.position = SIMD3(x: roomSelect.entity.position.x - 0.28, y: -0.05, z: 0)
                        instructionTop!.scale = SIMD3(x: 0.4, y: 0.4, z: 0.4)
                        warningEntity = instructionTop
                        rootEntity?.addChild(warningEntity!)
                    }
                }
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
    
    func addRoomStateEntity(room: Entity, parent: Entity, roomState: RoomStateEnum, bestTime: Int64) {
        switch roomState {
        case RoomStateEnum.open: return
        case RoomStateEnum.locked:
            if (lockEntity != nil) {
                let lock = lockEntity!.clone(recursive: true)
                var pos = room.position(relativeTo: parent)
                pos.y += 0.25
                room.addChild(lock)
                lock.move(to: Transform(pitch: -1.57, yaw: 0, roll: 0), relativeTo: parent)
                lock.setPosition(pos, relativeTo: parent)
                lock.setScale(SIMD3(x: 2, y: 2, z: 2), relativeTo: lock)
            }
            break
        case RoomStateEnum.complete:
            var pos = room.position(relativeTo: parent)
            if (checkEntity != nil) {
                let check = checkEntity!.clone(recursive: true)
                pos.y += 0.25
                room.addChild(check)
                check.move(to: Transform(pitch: 0, yaw: 0, roll: -1.57), relativeTo: parent)
                check.setPosition(pos, relativeTo: parent)
                check.setScale(SIMD3(x: 0.15, y: 0.15, z: 0.15), relativeTo: check)
            }
            pos.x -= 0.07
            pos.y -= 0.08
            pos.z += 0.01
            let bestTimeText = getTextEntity(text: String(Duration.seconds(bestTime).formatted(.time(pattern: .minuteSecond))), color: UIColor(red: 100/255, green: 230/255, blue: 100/255, alpha: 1))
            room.addChild(bestTimeText)
            bestTimeText.move(to: Transform(pitch: 0, yaw: 0, roll: 0), relativeTo: parent)
            bestTimeText.setPosition(pos, relativeTo: parent)
            bestTimeText.setScale(SIMD3(x: 0.8, y: 0.8, z: 0.8), relativeTo: bestTimeText)
        }
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
    
    func getTextEntity(text: String, color: UIColor) -> ModelEntity {
        let textMaterial = SimpleMaterial(color: color, isMetallic: false)
        let textEntity = ModelEntity(mesh: .generateText(
            text,
            extrusionDepth: 0.02,
            font: UIFont.monospacedSystemFont(ofSize: 0.07, weight: .semibold),
            alignment: .center
        ), materials: [textMaterial])
        return textEntity
    }
    
    func getRoomState(roomNum: Int) -> (state: RoomStateEnum, bestTime: Int64) {
        let roomDependency = [
            2: 1,
            3: 2
        ]
        let fetchData = NSFetchRequest<NSFetchRequestResult>(entityName: "RoomState")
        if let result = try? viewContext.fetch(fetchData) as? [RoomState] {
            // Check if that room has a save
            if let state = result.first(where: {state in state.roomNum == roomNum}) {
                return state.isRoomComplete ? (RoomStateEnum.complete, state.bestTime) : (RoomStateEnum.open, 0)
            }
            // Check room's dependency
            if let state = result.first(where: {state in state.roomNum == roomDependency[roomNum] ?? 0}) {
                return state.isRoomComplete ? (RoomStateEnum.open, 0) : (RoomStateEnum.locked, 0)
            }
        }
        let defaultOverrides = [
            1: (RoomStateEnum.open, Int64(0))
        ]
        return defaultOverrides[roomNum] ?? (RoomStateEnum.locked, 0)
    }
}

#Preview(windowStyle: .volumetric) {
    Menu()
}
