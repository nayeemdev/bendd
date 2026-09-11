import Foundation
import IOKit.hid

public final class LidAngleSensor {
    private static let vendorID = 0x05AC
    private static let productID = 0x8104
    private static let usagePage = 0x0020
    private static let usage = 0x008A
    private static let reportID: CFIndex = 1
    private static let pollingInterval: TimeInterval = 1.0 / 60.0

    private let manager: IOHIDManager
    private let device: IOHIDDevice
    private var timer: Timer?

    public private(set) var angleDegrees: Double = 0

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

        return LidAngleSensor(manager: manager, device: device)
    }

    private init(manager: IOHIDManager, device: IOHIDDevice) {
        self.manager = manager
        self.device = device
    }

    deinit {
        timer?.invalidate()
        IOHIDDeviceClose(device, IOOptionBits(kIOHIDOptionsTypeNone))
    }

    public func start() {
        guard timer == nil else { return }
        timer = Timer.scheduledTimer(withTimeInterval: Self.pollingInterval, repeats: true) { [weak self] _ in
            self?.poll()
        }
    }

    public func stop() {
        timer?.invalidate()
        timer = nil
    }

    private func poll() {
        var report = [UInt8](repeating: 0, count: 8)
        var length = CFIndex(report.count)

        let result = IOHIDDeviceGetReport(device, kIOHIDReportTypeFeature, Self.reportID, &report, &length)
        guard result == kIOReturnSuccess, length >= 3 else { return }

        let raw = UInt16(report[2]) << 8 | UInt16(report[1])
        angleDegrees = Double(raw)
        onAngleChange?(angleDegrees)
    }
}
