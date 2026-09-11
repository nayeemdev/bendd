public struct BendConfiguration: Codable, Equatable, Sendable {
    public var style: BendStyle
    public var isEffectEnabled: Bool
    public var launchAtLogin: Bool

    /// Lid angle in degrees above which the desktop renders untouched.
    public var clearAngleDegrees: Double
    /// Maximum tilt in degrees applied at a fully closed lid.
    public var perspectiveDepth: Double
    /// Multiplier on the style's base blur amount.
    public var blurAmount: Double
    /// Multiplier on the style's base shadow amount.
    public var shadowStrength: Double

    public static let clearAngleRange: ClosedRange<Double> = 60...130
    public static let perspectiveDepthRange: ClosedRange<Double> = 20...100
    public static let blurAmountRange: ClosedRange<Double> = 0...2
    public static let shadowStrengthRange: ClosedRange<Double> = 0...2

    public static let `default` = BendConfiguration(
        style: .silk,
        isEffectEnabled: true,
        launchAtLogin: false,
        clearAngleDegrees: 110,
        perspectiveDepth: 80,
        blurAmount: 1.0,
        shadowStrength: 1.0
    )

    public init(
        style: BendStyle,
        isEffectEnabled: Bool,
        launchAtLogin: Bool,
        clearAngleDegrees: Double,
        perspectiveDepth: Double,
        blurAmount: Double,
        shadowStrength: Double
    ) {
        self.style = style
        self.isEffectEnabled = isEffectEnabled
        self.launchAtLogin = launchAtLogin
        self.clearAngleDegrees = clearAngleDegrees
        self.perspectiveDepth = perspectiveDepth
        self.blurAmount = blurAmount
        self.shadowStrength = shadowStrength
    }
}
