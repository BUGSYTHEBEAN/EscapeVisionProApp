//
//  Room01.swift
//  escape
//
//  Created by Andrei Freund on 6/29/24.
//

import SwiftUI
import RealityKit
import RealityKitContent
import CoreData

struct Room01: View, Room {
    @Environment(\.openWindow) private var openWindow
    @Environment(\.dismissWindow) private var dismissWindow
    @Environment(\.dismissImmersiveSpace) private var dismissImmersiveSpace
    @Environment(\.managedObjectContext) private var viewContext
    // Protocol vars for all rooms
    static let LEVEL_TIME = 5 * 60
    @State internal var timeRemaining = LEVEL_TIME
    // Subscriptions, subs are permanent
    @State private var subs: [EventSubscription] = []
    @State private var safeTopSubscription: EventSubscription?
    @State private var lighterSubscription: EventSubscription?
    @State private var fireSubscription: EventSubscription?
    @State private var lockSubscription: EventSubscription?
    // Game Progression
    @State private var isIntroDonutComplete = false
    @State private var isIntroButtonComplete = false
    @State private var isIntroComplete = false
    @State private var isFireLit = false
    @State private var isSafeOpened = false
    @State private var isLockOpened = false
    @State private var isLevelComplete = false
    // Misc
    @State private var safePin: String = ""
    let safeButtonNames = ["Safe_Red", "Safe_Blue", "Safe_Green", "Safe_Pink"]
    @State private var timeEntity: ModelEntity?
    @State private var fireParticleEmitter: Entity?
    @State private var fireLastUpdated = Date()
    @State private var fireColor = 0
    @State private var isLightOn = true
    @State private var lightEntity: Entity?
    // Sounds
    @State private var clickSound: AudioFileResource?
    @State private var ghostIntro1: AudioFileResource?
    @State private var ghostIntro2: AudioFileResource?
    @State private var ghostIntro3: AudioFileResource?
    // Ghost Intro, negative value is offset for intro starting
    @State private var ghostTimer = -2
    @State private var ghostEntity: Entity?
    let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    let ghostTransforms = [
        3: Transform(rotation: simd_quatf(ix: 0, iy: 0, iz: 0.5, r: 0.866), translation: SIMD3(x: -1.15, y: 0.1, z: 0)),
        7: Transform(rotation: simd_quatf(ix: 0, iy: 0, iz: -0.676, r: 0.737), translation: SIMD3(x: 1.50, y: -1.20, z: 0.4)),
        14: Transform(rotation: simd_quatf(ix: 0, iy: 0, iz: 0.462, r: 0.887), translation: SIMD3(x: -1.1, y: -0.75, z: -0.4)),
        20: Transform(rotation: simd_quatf(ix: 0, iy: 0, iz: -0.676, r: 0.737), translation: SIMD3(x: 1.50, y: -1.25, z: 0.15)),
        34: Transform(rotation: simd_quatf(ix: 0, iy: 0, iz: 0.462, r: 0.887), translation: SIMD3(x: -0.95, y: -0.35, z: 0.20))
    ]
    let introCompleteAtSec = 36
    
    var body: some View {
        RealityView { content in
            // Add the entire room
            if let immersiveContentEntity = try? await Entity(named: "Room01", in: realityKitContentBundle) {
                content.add(immersiveContentEntity)
                dismissWindow(id: "Menu")

                // Add an ImageBasedLight for the immersive content
                // TODO: light is broken
//                guard let resource = try? await EnvironmentResource(named: "ImageBasedLight") else { return }
//                let iblComponent = ImageBasedLightComponent(source: .single(resource), intensityExponent: 0.25)
//                immersiveContentEntity.components.set(iblComponent)
//                immersiveContentEntity.components.set(ImageBasedLightReceiverComponent(imageBasedLight: immersiveContentEntity))
                
                if let ghost = immersiveContentEntity.findEntity(named: "Ghost") {
                    ghostEntity = ghost
                    if let ghostAni = ghost.availableAnimations.first {
                        ghost.playAnimation(ghostAni.repeat())
                    }
                }
                
                // Setup timer
                timeEntity = generateTimeTextEntity()
                if let timeTransform = immersiveContentEntity.findEntity(named: "Timer_Transform") {
                    if (timeEntity != nil) {
                        timeTransform.addChild(timeEntity!)
                        timeTransform.components.set(HoverEffectComponent())
                    }
                }
                
                if let topSafe = immersiveContentEntity.findEntity(named: "Safe_Top_Hitbox") as? ModelEntity {
                    topSafe.model?.materials = [SimpleMaterial(color: .clear, isMetallic: false)]
                    safeTopSubscription = content.subscribe(to: CollisionEvents.Began.self, on: topSafe, { event in
                        if (event.entityB.name == "Donut") {
                            isIntroDonutComplete = true
                            topSafe.removeFromParent()
                            safeTopSubscription?.cancel()
                        }
                    })
                }
                
                if let fireplace = immersiveContentEntity.findEntity(named: "FireplaceHitbox") as? ModelEntity {
                    fireplace.model?.materials = [SimpleMaterial(color: .clear, isMetallic: false)]
                    lighterSubscription = content.subscribe(to: CollisionEvents.Began.self, on: fireplace, { event in
                        if (event.entityB.name == "Lighter") {
                            isFireLit = true
                            fireplace.removeFromParent()
                            lighterSubscription?.cancel()
                        }
                    })
                }
                
                if let fire = immersiveContentEntity.findEntity(named: "FireParticleEmitter") {
                    fireParticleEmitter = fire
                    setupFireParticlePuzzle(content: content)
                }
                
                // Safe buttons
                safeButtonNames.forEach({ buttonName in
                    if let safeButton = immersiveContentEntity.findEntity(named: buttonName) {
                        safeButton.components.set(HoverEffectComponent())
                    }
                })
                
                if let lock = immersiveContentEntity.findEntity(named: "Lock") {
                    lockSubscription = content.subscribe(to: CollisionEvents.Began.self, on: lock, { event in
                        if (event.entityB.name == "Key") {
                            if (!isLockOpened) {
                                let lockEntity = event.entityA
                                if let lockAni = lockEntity.availableAnimations.first {
                                    lockEntity.playAnimation(lockAni)
                                }
                                event.entityB.removeFromParent()
                                isLockOpened = true
                                lockSubscription?.cancel()
                            }
                        }
                    })
                }
                
                if let light = immersiveContentEntity.findEntity(named: "PointLight") {
                    lightEntity = light
                }
            }
            // Load Assets
            if let click = try? AudioFileResource.load(named: "/Root/Sounds/Click", from: "Room01.usda", in: realityKitContentBundle) {
                clickSound = click
            }
            if let intro1 = try? AudioFileResource.load(named: "/Root/Sounds/Intro_1", from: "Room01.usda", in: realityKitContentBundle) {
                ghostIntro1 = intro1
            }
            if let intro2 = try? AudioFileResource.load(named: "/Root/Sounds/Intro_2", from: "Room01.usda", in: realityKitContentBundle) {
                ghostIntro2 = intro2
            }
            if let intro3 = try? AudioFileResource.load(named: "/Root/Sounds/Intro_3", from: "Room01.usda", in: realityKitContentBundle) {
                ghostIntro3 = intro3
            }
        } update: { content in
        }
        // Handle all moveable objects
        .installGestures()
        // Handle safe buttons and opening
        .gesture(SpatialTapGesture().targetedToEntity(where: .has(ButtonComponent.self)).onEnded({ safeButton in
            if (isSafeOpened) {
                return
            }
            let correctPin = "23214"
            if let buttonComponent = safeButton.entity.components[ButtonComponent.self] {
                if (!isIntroComplete) {
                    isIntroButtonComplete = true
                } else {
                    safePin.append(buttonComponent.getSecondaryName())
                }
                safeButton.entity.stopAllAnimations()
                safeButton.entity.position.z = 0
                if let buttonAnimation = try? AnimationResource.generate(
                    with: FromToByAnimation(
                        by: Transform(translation: SIMD3(x: 0, y: 0, z: -0.02)),
                        duration: 0.3,
                        timing: .easeOut,
                        bindTarget: .transform,
                        repeatMode: .autoReverse,
                        trimDuration: 0.6
                    )) {
                    safeButton.entity.playAnimation(buttonAnimation)
                    if (clickSound != nil) {
                        safeButton.entity.playAudio(clickSound!)
                    }
                }
                if let clickSound = try? AudioFileResource.load(named: "/Root/Sounds/Click", from: "Room01.usda", in: realityKitContentBundle) {
                    safeButton.entity.playAudio(clickSound)
                }
            }
            if (safePin.contains(correctPin)) {
                safeButton.entity.parent?.move(to: Transform(rotation: simd_quatf(angle: 1.9, axis: SIMD3(x: 0, y: 1, z: 0))), relativeTo: safeButton.entity.parent, duration: 3.0, timingFunction: .easeInOut)
                isSafeOpened = true
            }
        }))
        .gesture(SpatialTapGesture().targetedToAnyEntity().onEnded({ e in
            if (e.entity.name == "LightSwitch") {
                let ani = e.entity.availableAnimations.first
                if (ani != nil) {
                    if (isLightOn) {
                        e.entity.playAnimation(ani!)
                        setLight(brightness: 5000)
                    } else {
                        var reversedDef = ani!.definition
                        reversedDef.speed = -1
                        if let reversedAni = try? AnimationResource.generate(with: reversedDef) {
                            e.entity.playAnimation(reversedAni)
                        }
                        setLight(brightness: 15000)
                    }
                }
                isLightOn = !isLightOn
            }
            if (isLockOpened && e.entity.name == "WoodDoor") {
                let ani = e.entity.availableAnimations.first
                if (ani != nil) {
                    e.entity.playAnimation(ani!)
                }
                // Room Win
                isLevelComplete = true
                saveRoomComplete()
            }
            if (e.entity.name == "Timer_Transform") {
                Task {
                    openWindow(id: "Menu")
                    await dismissImmersiveSpace()
                }
            }
        }))
        .onReceive(timer, perform: {time in
            // Intro before timer starts
            if (!isIntroComplete) {
                if (ghostTimer < 18 || (isIntroDonutComplete && ghostTimer < 29) || isIntroButtonComplete) {
                    ghostTimer += 1
                }
                // Play intro 1 immediatley
                if (ghostTimer == 0 && ghostIntro1 != nil && ghostEntity != nil) {
                    ghostEntity!.playAudio(ghostIntro1!)
                }
                // Play intro 2 after first task complete
                if (ghostTimer == 19 && ghostIntro2 != nil && ghostEntity != nil) {
                    ghostEntity!.playAudio(ghostIntro2!)
                }
                // Play intro 2 after first task complete
                if (ghostTimer == 30 && ghostIntro3 != nil && ghostEntity != nil) {
                    ghostEntity!.playAudio(ghostIntro3!)
                }
                // Move ghost at specific times with sounds
                if let transform = ghostTransforms[ghostTimer] {
                    if (ghostEntity != nil) {
                        ghostEntity!.move(to: transform, relativeTo: ghostEntity!, duration: 1.5)
                    }
                }
                // Intro complete
                if (ghostTimer > introCompleteAtSec) {
                    isIntroComplete = true
                }
                return
            }
            if (!isLevelComplete) {
                timeRemaining = updateTimeTextEntity(timeText: timeEntity)
            }
        })
    }
    
    func handleFireParticleComponent() {
        let fireColors: [UIColor] = [.green, .blue, .green, .red, .magenta, .clear]
        if var emitterComponent = fireParticleEmitter?.components[ParticleEmitterComponent.self] {
            if (isSafeOpened) {
                emitterComponent.mainEmitter.color = .constant(.single(.orange))
                fireSubscription?.cancel()
            } else {
                emitterComponent.mainEmitter.color = .constant(.single(fireColors[fireColor % 6]))
            }
            // First time turning on
            if (fireColor == 0) {
                emitterComponent.isEmitting = true
            }
            fireParticleEmitter?.components.set(emitterComponent)
        }
        fireColor += 1
    }
    
    func setupFireParticlePuzzle(content: RealityViewContent) {
        fireSubscription = content.subscribe(to: SceneEvents.Update.self) { ce in
            if (isFireLit && fireLastUpdated.timeIntervalSinceNow.magnitude > 2.4) {
                handleFireParticleComponent()
                fireLastUpdated = Date()
            }
        }
    }
    
    func saveRoomComplete() {
        let fetchData = NSFetchRequest<NSFetchRequestResult>(entityName: "RoomState")
        if let result = try? viewContext.fetch(fetchData) as? [RoomState] {
            if let state = result.first(where: {state in state.roomNum == 1}) {
                state.isRoomComplete = true
                if (state.bestTime > Int64(Room01.LEVEL_TIME - timeRemaining)) {
                    state.bestTime = Int64(Room01.LEVEL_TIME - timeRemaining)
                }
                do {
                    try viewContext.save()
                } catch {}
                return
            }
        }
        let save = RoomState(context: viewContext)
        save.isRoomComplete = true
        save.roomName = "Room01"
        save.roomNum = 1
        save.bestTime = Int64(Room01.LEVEL_TIME - timeRemaining)
        do {
            try viewContext.save()
        } catch {}
    }
    
    func setLight(brightness: Float) {
        if var pointLightComponent = lightEntity?.components[PointLightComponent.self] {
            pointLightComponent.intensity = brightness
            lightEntity!.components.set(pointLightComponent)
        }
    }
}
