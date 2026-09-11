import simd

public enum BendTransform {
    /// Lid angle sensor readings run roughly 0 (closed) to this value (fully open).
    public static let fullyOpenLidAngleDegrees: Double = 130
    public static let maxTiltDegrees: Double = 80

    /// Converts a raw lid angle reading into a bend tilt: flat when the lid is
    /// fully open, maximal as it approaches closed.
    public static func tiltDegrees(forLidAngleDegrees lidAngle: Double) -> Float {
        let openness = max(0, min(1, lidAngle / fullyOpenLidAngleDegrees))
        return Float((1 - openness) * maxTiltDegrees)
    }

    public static func matrix(angleDegrees: Float, aspectRatio: Float) -> float4x4 {
        let hinge = rotationAroundBottomEdge(angleDegrees: angleDegrees)
        let projection = perspective(fovYRadians: .pi / 3, aspectRatio: aspectRatio, near: 0.1, far: 10)
        let view = translation(x: 0, y: 0, z: -3)
        return projection * view * hinge
    }

    private static func rotationAroundBottomEdge(angleDegrees: Float) -> float4x4 {
        let radians = angleDegrees * .pi / 180
        let moveHingeToOrigin = translation(x: 0, y: 1, z: 0)
        let moveHingeBack = translation(x: 0, y: -1, z: 0)
        return moveHingeBack * rotationX(radians: radians) * moveHingeToOrigin
    }

    private static func translation(x: Float, y: Float, z: Float) -> float4x4 {
        float4x4(rows: [
            SIMD4(1, 0, 0, x),
            SIMD4(0, 1, 0, y),
            SIMD4(0, 0, 1, z),
            SIMD4(0, 0, 0, 1),
        ])
    }

    private static func rotationX(radians: Float) -> float4x4 {
        let c = cos(radians)
        let s = sin(radians)
        return float4x4(rows: [
            SIMD4(1, 0, 0, 0),
            SIMD4(0, c, -s, 0),
            SIMD4(0, s, c, 0),
            SIMD4(0, 0, 0, 1),
        ])
    }

    private static func perspective(fovYRadians: Float, aspectRatio: Float, near: Float, far: Float) -> float4x4 {
        let yScale = 1 / tan(fovYRadians * 0.5)
        let xScale = yScale / aspectRatio
        let zRange = far - near
        let zScale = -(far + near) / zRange
        let wzScale = -2 * far * near / zRange
        return float4x4(rows: [
            SIMD4(xScale, 0, 0, 0),
            SIMD4(0, yScale, 0, 0),
            SIMD4(0, 0, zScale, wzScale),
            SIMD4(0, 0, -1, 0),
        ])
    }
}
