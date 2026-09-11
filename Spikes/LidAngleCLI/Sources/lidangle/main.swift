import Foundation
import IOKit.hid

struct LidAngleSensor {
    private static let vendorID = 0x05AC
    private static let productID = 0x8104
    private static let usagePage = 0x0020
    private static let usage = 0x008A
    private static let reportID: CFIndex = 1

    // The manager must outlive every device it vends; if it deallocates,
    // devices from it stop responding to report reads.
    private let manager: IOHIDManager
    private let device: IOHIDDevice

    static func open() -> LidAngleSensor? {
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

    func readAngleDegrees() -> Double? {
        var report = [UInt8](repeating: 0, count: 8)
        var length = CFIndex(report.count)

        let result = IOHIDDeviceGetReport(device, kIOHIDReportTypeFeature, Self.reportID, &report, &length)
        guard result == kIOReturnSuccess, length >= 3 else { return nil }

        let raw = UInt16(report[2]) << 8 | UInt16(report[1])
        return Double(raw)
    }
}

setvbuf(stdout, nil, _IONBF, 0)

guard let sensor = LidAngleSensor.open() else {
    print("No lid angle sensor found on this Mac.")
    exit(1)
}

print("Sensor found, reading angle. Press Ctrl-C to stop.")

while true {
    if let angle = sensor.readAngleDegrees() {
        print(String(format: "lid angle: %.0f degrees", angle))
    } else {
        print("read failed")
    }
    Thread.sleep(forTimeInterval: 0.2)
}
