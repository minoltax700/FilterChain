import Foundation

public struct Filter {
    public let vertexFunction: String
    public let fragmentFunction: String
    public let bundle: Bundle
    
    public init(vertexFunction: String, fragmentFunction: String, bundle: Bundle) {
        self.vertexFunction = vertexFunction
        self.fragmentFunction = fragmentFunction
        self.bundle = bundle
    }
}
