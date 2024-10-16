//
//  Room.swift
//  Protocol for rooms
//  escape
//
//  Created by Andrei Freund on 8/19/24.
//

import SwiftUI
import RealityKit
import RealityKitContent

protocol Room {
    var timeRemaining: Int { get }
}

extension Room {
    func generateTimeTextEntity() -> ModelEntity {
        let timeMaterial = SimpleMaterial(color: UIColor(red: 80/255, green: 255/255, blue: 80/255, alpha: 1), isMetallic: false)
        let timeEntity = ModelEntity(mesh: generateTimeTextMesh(), materials: [timeMaterial])
        timeEntity.position = SIMD3(x: -0.09, y: 0, z: 0)
        timeEntity.name = "TimeEntity"
        return timeEntity
    }
    
    func generateTimeTextMesh() -> MeshResource {
        return .generateText(
            String(Duration.seconds(timeRemaining).formatted(.time(pattern: .minuteSecond(padMinuteToLength: 2)))),
            extrusionDepth: 0.02,
            font: UIFont.monospacedSystemFont(ofSize: 0.06, weight: .semibold),
            alignment: .right
        )
    }
    
    func updateTimeTextEntity(timeText: ModelEntity?) -> Int {
        if (timeRemaining == 5 * 60) {
            // Switch material to yellow with 5 min left
            let yellowMaterial = SimpleMaterial(color: UIColor(red: 255/255, green: 255/255, blue: 60/255, alpha: 1), isMetallic: false)
            timeText?.model?.materials = [yellowMaterial]
        } else if (timeRemaining == 60) {
            // Switch material to red with 1 min left
            let redMaterial = SimpleMaterial(color: UIColor(red: 255/255, green: 60/255, blue: 60/255, alpha: 1), isMetallic: false)
            timeText?.model?.materials = [redMaterial]
        }
        
        if (timeRemaining >= 0) {
            if (timeText != nil) {
                try? timeText!.model?.mesh.replace(with: generateTimeTextMesh().contents)
            }
            return timeRemaining - 1
        }
        return 0
    }
    
    func createSkybox(name: String) -> Entity? {
        let sphere = MeshResource.generateSphere(radius: 1E3) // 1000
        var skyboxMaterial = UnlitMaterial()
        if let skyboxPng = try? TextureResource.load(named: name) {
            skyboxMaterial.color = .init(texture: .init(skyboxPng))
        }
        let skybox = Entity()
        skybox.components.set(ModelComponent(mesh: sphere, materials: [skyboxMaterial]))
        skybox.orientation = .init(ix: 0, iy: 1, iz: 0, r: 0)
        skybox.scale = .init(x: -1, y: 1, z: 1)
        return skybox
    }
    
    func fillWinBoard(winBoard: Entity, levelTime: Int) {
        winBoard.components.set(BillboardComponent())
        winBoard.position = .init(x: 0, y: 1.2, z: -1)
        let line1 = timeRemaining > 0 ? generateTextEntity(text: "You Win!", name: "Line1", size: 0.10)
            : generateTextEntity(text: "Out of Time", name: "Line1", size: 0.10)
        line1.position = .init(x: timeRemaining > 0 ? -0.25 : -0.33, y: 0.06, z: 0)
        winBoard.addChild(line1)
        let line2 = generateTextEntity(text: String(Duration.seconds(levelTime - timeRemaining).formatted(.time(pattern: .minuteSecond))), name: "Line2", size: 0.08)
        line2.position = .init(x: -0.08, y: -0.06, z: 0)
        winBoard.addChild(line2)
        let line3 = generateTextEntity(text: "tap to return to menu", name: "Line3", size: 0.04)
        line3.position = .init(x: -0.27, y: -0.14, z: 0)
        winBoard.addChild(line3)
    }
    
    func generateTextEntity(text: String, name: String, size: CGFloat) -> ModelEntity {
        let textMesh = MeshResource.generateText(
            text,
            extrusionDepth: 0.02,
            font: UIFont.monospacedSystemFont(ofSize: size, weight: .semibold),
            alignment: .center
        )
        let textMaterial = SimpleMaterial(color: UIColor(red: 190/255, green: 146/255, blue: 201/255, alpha: 1), isMetallic: false)
        let textEntity = ModelEntity(mesh: textMesh, materials: [textMaterial])
        textEntity.name = name
        return textEntity
    }
}
