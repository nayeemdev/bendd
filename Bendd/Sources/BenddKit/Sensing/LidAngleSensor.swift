import Foundation
import IOKit.hid

public final class LidAngleSensor {
    private static let vendorID = 0x05AC
    private static let productID = 0x8104
    private static let usagePage = 0x0020
    private static let usage = 0x008A
    private static let reportID: CFIndex = 1
    /// Fast enough for smooth tracking while the bend effect is visible.
    private static let activePollingInterval: TimeInterval = 1.0 / 60.0
    /// Coarse enough to keep idle cost near zero while the lid sits open;
    /// still responsive enough that starting to close the lid is never noticeably late.
    private static let idlePollingInterval: TimeInterval = 1.0 / 10.0
    private static let smoothingFactor = 0.25

    private let manager: IOHIDManager
    private let device: IOHIDDevice
    private var timer: Timer?
    private var hasReading = false

    /// Defaults to "open" rather than 0/"closed": if the one-time synchronous
    /// read in init ever fails, assuming closed would make the controller
    /// think the lid just slammed shut and eagerly start capture.
    public private(set) var angleDegrees: Double = BendConfiguration.default.clearAngleDegrees

    /// Overrides the sensor reading, for previewing the effect without moving the lid.
    public var debugAngleOverride: Double?

    public var effectiveAngleDegrees: Double {
        debugAngleOverride ?? angleDegrees
    }

    public var onAngleChange: ((Double) -> Void)?

    public static func make() -> LidAngleSensor? {
        let manager = IOHIDManagerCreate(kCFAllocatorDefault, IOOptionBits(kIOHIDOptionsTypeNone))
        guard IOHIDManagerOpen(manager, IOOptionBits(kIOHIDOptionsTypeNone)) == kIOReturnSuccess else {
            return nil
        }

        let matching: [String: Any] = [
            kIOHIDVendorIDKey as String: vendorID,
            kIOHIDProductIDKey as String: productID,
            kIOHIDPrimaryUsagePageKey as String: usagePage,
            kIOHIDPrimaryUsageKey as String: usage,
        ]
        IOHIDManagerSetDeviceMatching(manager, matching as CFDictionary)

        guard let devices = IOHIDManagerCopyDevices(manager) as? Set<IOHIDDevice>,
              let device = devices.first,
              IOHIDDeviceOpen(device, IOOptionBits(kIOHIDOptionsTypeNone)) == kIOReturnSuccess
        else {
            return nil
        }

        let sensor = LidAngleSensor(manager: manager, device: device)
        if let raw = ProcessInfo.processInfo.environment["BENDD_DEBUG_ANGLE"], let override = Double(raw) {
            sensor.debugAngleOverride = override
        }
        return sensor
    }

    private init(manager: IOHIDManager, device: IOHIDDevice) {
        self.manager = manager
        self.device = device

        // Read once synchronously so angleDegrees reflects the Mac's actual
        // lid position from the moment this object exists, not a guessed
        // default: starting at 0 (fully closed) would make the controller
        // think the lid just slammed shut on every single launch.
        if let raw = Self.readRawAngle(from: device) {
            angleDegrees = raw
            hasReading = true
        }
    }

    deinit {
        timer?.invalidate()
        IOHIDDeviceClose(device, IOOptionBits(kIOHIDOptionsTypeNone))
    }

    public func start() {
        guard timer == nil else { return }
        reschedule(interval: Self.idlePollingInterval)
    }

    public func stop() {
        timer?.invalidate()
        timer = nil
    }

    /// Poll quickly while the effect is active and visible; fall back to a
    /// coarse rate the rest of the time so idle cost stays near zero.
    public func setTrackingActive(_ isActive: Bool) {
        guard timer != nil else { return }
        reschedule(interval: isActive ? Self.activePollingInterval : Self.idlePollingInterval)
    }

    private func reschedule(interval: TimeInterval) {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            self?.poll()
        }
    }

    private func poll() {
        guard let raw = Self.readRawAngle(from: device) else { return }

        if hasReading {
            angleDegrees = Self.smoothingFactor * raw + (1 - Self.smoothingFactor) * angleDegrees
        } else {
            angleDegrees = raw
            hasReading = true
        }
        onAngleChange?(effectiveAngleDegrees)
    }

    private static func readRawAngle(from device: IOHIDDevice) -> Double? {
        var report = [UInt8](repeating: 0, count: 8)
        var length = CFIndex(report.count)

        let result = IOHIDDeviceGetReport(device, kIOHIDReportTypeFeature, reportID, &report, &length)
        guard result == kIOReturnSuccess, length >= 3 else { return nil }

        return Double(UInt16(report[2]) << 8 | UInt16(report[1]))
    }
}
