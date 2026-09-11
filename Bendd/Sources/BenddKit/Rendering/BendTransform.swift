import simd

public enum BendTransform {
    public static func isClear(lidAngleDegrees: Double, clearAngleDegrees: Double) -> Bool {
        lidAngleDegrees >= clearAngleDegrees
    }

    public static func bendFraction(forLidAngleDegrees lidAngle: Double, clearAngleDegrees: Double) -> Double {
        let openness = max(0, min(1, lidAngle / clearAngleDegrees))
        return 1 - openness
    }

    public static func tiltDegrees(forLidAngleDegrees lidAngle: Double, clearAngleDegrees: Double, maxTiltDegrees: Double) -> Float {
        Float(bendFraction(forLidAngleDegrees: lidAngle, clearAngleDegrees: clearAngleDegrees) * maxTiltDegrees)
    }

    private static let fovYRadians: Float = .pi / 4

    public static func matrix(angleDegrees: Float) -> float4x4 {
        let hinge = rotationAroundBottomEdge(angleDegrees: angleDegrees)
        let projection = perspective(fovYRadians: fovYRadians, near: 0.1, far: 10)
        let viewDistance = 1 / tan(fovYRadians * 0.5)
        let view = translation(x: 0, y: 0, z: -viewDistance)
        return projection * view * hinge
    }

    private static func rotationAroundBottomEdge(angleDegrees: Float) -> float4x4 {
        let radians = -angleDegrees * .pi / 180
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

    private static func perspective(fovYRadians: Float, near: Float, far: Float) -> float4x4 {
        let yScale = 1 / tan(fovYRadians * 0.5)
        let xScale = yScale
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
