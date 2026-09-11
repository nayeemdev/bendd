import Foundation
import Combine
import BenddKit

final class SettingsStore: ObservableObject {
    private static let defaultsKey = "com.bendd.configuration"

    @Published var configuration: BendConfiguration {
        didSet { persist() }
    }

    /// Transient lid angle override while the user drags the preview slider.
    /// Not persisted; nil means "use the real sensor".
    @Published var previewAngleOverride: Double?

    init() {
        configuration = Self.load()
    }

    private static func load() -> BendConfiguration {
        guard let data = UserDefaults.standard.data(forKey: defaultsKey),
              let decoded = try? JSONDecoder().decode(BendConfiguration.self, from: data)
        else {
            return .default
        }
        return decoded
    }

    private func persist() {
        guard let data = try? JSONEncoder().encode(configuration) else { return }
        UserDefaults.standard.set(data, forKey: Self.defaultsKey)
    }
}
