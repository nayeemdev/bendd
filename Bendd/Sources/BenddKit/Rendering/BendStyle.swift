public struct BendStyleParameters {
    public let blurScale: Float
    public let shadowScale: Float
    public let desaturation: Float
}

public enum BendStyle: String, CaseIterable, Sendable, Codable {
    case silk
    case shade
    case frost

    public var displayName: String {
        switch self {
        case .silk: "Silk"
        case .shade: "Shade"
        case .frost: "Frost"
        }
    }

    public var parameters: BendStyleParameters {
        switch self {
        case .silk:
            BendStyleParameters(blurScale: 1.3, shadowScale: 0.7, desaturation: 0)
        case .shade:
            BendStyleParameters(blurScale: 0.7, shadowScale: 1.3, desaturation: 0)
        case .frost:
            BendStyleParameters(blurScale: 1.1, shadowScale: 1.1, desaturation: 0.35)
        }
    }
}
