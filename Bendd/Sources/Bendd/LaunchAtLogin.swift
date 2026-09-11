import ServiceManagement

enum LaunchAtLogin {
    static var isRegistered: Bool {
        SMAppService.mainApp.status == .enabled
    }

    static func setEnabled(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            print("launch at login: could not \(enabled ? "register" : "unregister"): \(error)")
        }
    }
}
