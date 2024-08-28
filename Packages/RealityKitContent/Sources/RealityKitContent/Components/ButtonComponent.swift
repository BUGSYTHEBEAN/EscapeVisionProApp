import RealityKit

// Component for a color-code button
public struct ButtonComponent: Component, Codable {
    var buttonNum: Int = 0
    
    public init() {
    }
    
    public func getButtonNum() -> Int {
        return buttonNum
    }
}
