//
//  Room.swift
//  Protocol for rooms
//  escape
//
//  Created by Andrei Freund on 8/19/24.
//

import SwiftUI
import RealityKit

protocol Room {
    var timeRemaining: Int { get }
}

extension Room {
    func generateTimeTextEntity() -> ModelEntity {
        let timeMaterial = SimpleMaterial(color: UIColor(red: 80/255, green: 255/255, blue: 80/255, alpha: 1), isMetallic: false)
        let timeEntity = ModelEntity(mesh: generateTimeTextMesh(), materials: [timeMaterial])
        timeEntity.position = SIMD3(x: -0.08, y: 0, z: 0)
        timeEntity.name = "TimeEntity"
        return timeEntity
    }
    
    func generateTimeTextMesh() -> MeshResource {
        return .generateText(
            String(Duration.seconds(timeRemaining).formatted(.time(pattern: .minuteSecond))),
            extrusionDepth: 0.02,
            font: UIFont.monospacedSystemFont(ofSize: 0.07, weight: .semibold),
            alignment: .center
        )
    }
    
    func updateTimeTextEntity(timeText: ModelEntity?) -> Int {
        if (timeRemaining == 3 * 60) {
            // Switch material to yellow with 3 min left
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
}
