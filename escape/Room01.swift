//
//  Room01.swift
//  escape
//
//  Created by Andrei Freund on 6/29/24.
//

import SwiftUI
import RealityKit
import RealityKitContent

struct Room01: View, Room {
    @Environment(\.openWindow) private var openWindow
    @Environment(\.dismissWindow) private var dismissWindow
    @Environment(\.dismissImmersiveSpace) private var dismissImmersiveSpace
    // Protocol vars for all rooms
    @State internal var timeRemaining = 5 * 60
    // Subscriptions, subs are permanent
    @State private var subs: [EventSubscription] = []
    @State private var lighterSubscription: EventSubscription?
    @State private var fireSubscription: EventSubscription?
    @State private var lockSubscription: EventSubscription?
    // Game Progression
    @State private var isFireLit = false
    @State private var isSafeOpened = false
    @State private var isLockOpened = false
    // Misc
    @State private var safePin: String = ""
    @State private var timeEntity: ModelEntity?
    @State private var fireParticleEmitter: Entity?
    @State private var fireLastUpdated = Date()
    @State private var fireColor = 0
    // Sounds
    @State private var clickSound: AudioFileResource?
    
    let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    
    var body: some View {
        RealityView { content in
            // Add the entire room
            if let immersiveContentEntity = try? await Entity(named: "Room01", in: realityKitContentBundle) {
                content.add(immersiveContentEntity)
                dismissWindow(id: "Menu")

                // Add an ImageBasedLight for the immersive content
                guard let resource = try? await EnvironmentResource(named: "ImageBasedLight") else { return }
                let iblComponent = ImageBasedLightComponent(source: .single(resource), intensityExponent: 0.25)
                immersiveContentEntity.components.set(iblComponent)
                immersiveContentEntity.components.set(ImageBasedLightReceiverComponent(imageBasedLight: immersiveContentEntity))
                
                if let ghost = immersiveContentEntity.findEntity(named: "Ghost") {
                    if let ghostAni = ghost.availableAnimations.first {
                        ghost.playAnimation(ghostAni.repeat())
                    }
                }
                
                // Setup timer
                timeEntity = generateTimeTextEntity()
                if let timeTransform = immersiveContentEntity.findEntity(named: "Timer_Transform") {
                    if (timeEntity != nil) {
                        timeTransform.addChild(timeEntity!)
                    }
                }
                
                if let fireplace = immersiveContentEntity.findEntity(named: "FireplaceHitbox") as? ModelEntity {
                    fireplace.model?.materials = [UnlitMaterial(color: .clear)]
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
            }
            // Load Assets
            if let click = try? AudioFileResource.load(named: "/Root/Sounds/Click", from: "Room01.usda", in: realityKitContentBundle) {
                clickSound = click
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
                safePin.append(buttonComponent.getButtonNum().description)
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
            if (isLockOpened && e.entity.name == "WoodDoor") {
                let ani = e.entity.availableAnimations.first
                if (ani != nil) {
                    e.entity.playAnimation(ani!)
                }
            }
            if (e.entity.name == "Timer_Transform") {
                Task {
                    openWindow(id: "Menu")
                    await dismissImmersiveSpace()
                }
            }
        }))
        .onReceive(timer, perform: {time in
            timeRemaining = updateTimeTextEntity(timeText: timeEntity)
            // TODO Lose state
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
}
