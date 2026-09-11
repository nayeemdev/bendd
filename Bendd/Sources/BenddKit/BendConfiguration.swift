public struct BendConfiguration: Codable, Equatable, Sendable {
    public var style: BendStyle
    public var isEffectEnabled: Bool
    public var isSoundEnabled: Bool
    public var launchAtLogin: Bool

    public var clearAngleDegrees: Double
    public var perspectiveDepth: Double
    public var blurAmount: Double
    public var shadowStrength: Double

    public static let clearAngleRange: ClosedRange<Double> = 60...130
    public static let perspectiveDepthRange: ClosedRange<Double> = 20...50
    public static let blurAmountRange: ClosedRange<Double> = 0...2
    public static let shadowStrengthRange: ClosedRange<Double> = 0...2

    public static let `default` = BendConfiguration(
        style: .silk,
        isEffectEnabled: true,
        isSoundEnabled: true,
        launchAtLogin: false,
        clearAngleDegrees: 110,
        perspectiveDepth: 45,
        blurAmount: 1.0,
        shadowStrength: 1.0
    )

    public init(
        style: BendStyle,
        isEffectEnabled: Bool,
        isSoundEnabled: Bool,
        launchAtLogin: Bool,
        clearAngleDegrees: Double,
        perspectiveDepth: Double,
        blurAmount: Double,
        shadowStrength: Double
    ) {
        self.style = style
        self.isEffectEnabled = isEffectEnabled
        self.isSoundEnabled = isSoundEnabled
        self.launchAtLogin = launchAtLogin
        self.clearAngleDegrees = clearAngleDegrees
        self.perspectiveDepth = perspectiveDepth
        self.blurAmount = blurAmount
        self.shadowStrength = shadowStrength
    }
}
