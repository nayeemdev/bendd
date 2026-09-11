import Foundation
import IOKit.hid

setvbuf(stdout, nil, _IONBF, 0)

// The lid angle sensor shows up as a HID device on the standard sensor usage
// page, reporting orientation. Vendor and product IDs, usage page and usage
// were found by enumerating the HID device tree on this hardware.
let appleVendorID = 0x05AC
let lidSensorProductID = 0x8104
let sensorUsagePage = 0x0020
let orientationUsage = 0x008A
let angleReportID: CFIndex = 1

// Kept alive for the life of the process. If this is allowed to deallocate,
// the devices it vended stop responding to report reads.
let hidManager = IOHIDManagerCreate(kCFAllocatorDefault, IOOptionBits(kIOHIDOptionsTypeNone))

func openLidSensor() -> IOHIDDevice? {
    guard IOHIDManagerOpen(hidManager, IOOptionBits(kIOHIDOptionsTypeNone)) == kIOReturnSuccess else {
        return nil
    }

    let matching: [String: Any] = [
        kIOHIDVendorIDKey as String: appleVendorID,
        kIOHIDProductIDKey as String: lidSensorProductID,
        kIOHIDPrimaryUsagePageKey as String: sensorUsagePage,
        kIOHIDPrimaryUsageKey as String: orientationUsage,
    ]
    IOHIDManagerSetDeviceMatching(hidManager, matching as CFDictionary)

    guard let devices = IOHIDManagerCopyDevices(hidManager) as? Set<IOHIDDevice>,
          let device = devices.first else {
        return nil
    }

    guard IOHIDDeviceOpen(device, IOOptionBits(kIOHIDOptionsTypeNone)) == kIOReturnSuccess else {
        return nil
    }

    return device
}

func readAngle(from device: IOHIDDevice) -> Double? {
    var report = [UInt8](repeating: 0, count: 8)
    var length = CFIndex(report.count)

    let result = IOHIDDeviceGetReport(device, kIOHIDReportTypeFeature, angleReportID, &report, &length)
    guard result == kIOReturnSuccess, length >= 3 else { return nil }

    let raw = UInt16(report[2]) << 8 | UInt16(report[1])
    return Double(raw)
}

print("Looking for the lid angle sensor...")

guard let device = openLidSensor() else {
    print("No lid angle sensor found. This Mac may not have one, or the HID interface changed.")
    exit(1)
}

print("Sensor found. Reading angle, press Ctrl-C to stop.")

while true {
    if let angle = readAngle(from: device) {
        print(String(format: "lid angle: %.0f degrees", angle))
    } else {
        print("read failed")
    }
    Thread.sleep(forTimeInterval: 0.2)
}
