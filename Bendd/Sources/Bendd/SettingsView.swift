import SwiftUI
import CoreGraphics
import BenddKit

struct SettingsView: View {
    @ObservedObject var store: SettingsStore
    let currentAngleProvider: () -> Double

    @State private var displayedAngle: Double = BendConfiguration.default.clearAngleDegrees
    @State private var isPreviewing = false
    @State private var isScreenRecordingGranted = CGPreflightScreenCaptureAccess()

    private let previewTimer = Timer.publish(every: 1.0 / 30.0, on: .main, in: .common).autoconnect()

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            header

            if !store.isSensorAvailable {
                banner(
                    "No lid angle sensor was found on this Mac, so Bendd has nothing to react to.",
                    symbol: "exclamationmark.triangle"
                )
            }

            permissionRow

            if let message = store.captureErrorMessage {
                captureErrorBanner(message)
            }

            preview
                .frame(height: 110)
                .frame(maxWidth: .infinity)
                .opacity(store.isSensorAvailable ? 1 : 0.4)

            Toggle("Effect enabled", isOn: $store.configuration.isEffectEnabled)
                .disabled(!store.isSensorAvailable)

            Toggle("Play a sound when fully open", isOn: $store.configuration.isSoundEnabled)
                .disabled(!store.isSensorAvailable)

            Picker("Style", selection: $store.configuration.style) {
                ForEach(BendStyle.allCases, id: \.self) { style in
                    Text(style.displayName).tag(style)
                }
            }
            .pickerStyle(.segmented)
            .disabled(!store.isSensorAvailable)

            sliders
                .disabled(!store.isSensorAvailable)

            previewSlider
                .disabled(!store.isSensorAvailable)

            Divider()

            Toggle("Launch at login", isOn: $store.configuration.launchAtLogin)
                .onChange(of: store.configuration.launchAtLogin) { _, enabled in
                    LaunchAtLogin.setEnabled(enabled)
                }

            aboutFooter

            HStack {
                Spacer()
                Button("Quit Bendd") { NSApplication.shared.terminate(nil) }
            }
        }
        .padding(20)
        .frame(width: 320)
        .onExitCommand {
            NSApp.keyWindow?.close()
        }
        .onReceive(previewTimer) { _ in
            guard !isPreviewing else { return }
            displayedAngle = currentAngleProvider()
            isScreenRecordingGranted = CGPreflightScreenCaptureAccess()
        }
    }

    private var permissionRow: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(isScreenRecordingGranted ? Color.green : Color.orange)
                .frame(width: 7, height: 7)
            Text(isScreenRecordingGranted ? "Screen Recording access granted" : "Screen Recording access not granted")
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
            if !isScreenRecordingGranted {
                Button("Grant…") {
                    if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture") {
                        NSWorkspace.shared.open(url)
                    }
                }
                .font(.caption)
            }
        }
    }

    private var header: some View {
        HStack {
            Image(systemName: "laptopcomputer")
                .font(.title2)
            Text("Bendd")
                .font(.title2)
                .bold()
            Spacer()
        }
    }

    private var preview: some View {
        let configuration = store.configuration
        let fraction = BendTransform.bendFraction(forLidAngleDegrees: displayedAngle, clearAngleDegrees: configuration.clearAngleDegrees)
        let tilt = BendTransform.tiltDegrees(
            forLidAngleDegrees: displayedAngle,
            clearAngleDegrees: configuration.clearAngleDegrees,
            maxTiltDegrees: configuration.perspectiveDepth
        )
        let style = configuration.style.parameters

        return ZStack {
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(nsColor: .windowBackgroundColor))
            LinearGradient(colors: [.blue, .purple, .pink], startPoint: .topLeading, endPoint: .bottomTrailing)
                .clipShape(RoundedRectangle(cornerRadius: 6))
                .saturation(1 - Double(fraction) * Double(style.desaturation))
                .brightness(-Double(fraction) * 0.5 * Double(style.shadowScale) * configuration.shadowStrength)
                .blur(radius: Double(fraction) * 6 * Double(style.blurScale) * configuration.blurAmount)
                .padding(10)
                .rotation3DEffect(
                    .degrees(Double(tilt)),
                    axis: (x: 1, y: 0, z: 0),
                    anchor: .bottom,
                    perspective: 0.4
                )
        }
    }

    private var sliders: some View {
        VStack(alignment: .leading, spacing: 10) {
            labeledSlider("Perspective depth", value: $store.configuration.perspectiveDepth, range: BendConfiguration.perspectiveDepthRange)
            labeledSlider("Blur amount", value: $store.configuration.blurAmount, range: BendConfiguration.blurAmountRange)
            labeledSlider("Shadow strength", value: $store.configuration.shadowStrength, range: BendConfiguration.shadowStrengthRange)
            labeledSlider("Clear angle", value: $store.configuration.clearAngleDegrees, range: BendConfiguration.clearAngleRange)
        }
    }

    private var previewSlider: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Preview lid angle")
                .font(.caption)
                .foregroundStyle(.secondary)
            Slider(
                value: Binding(
                    get: { displayedAngle },
                    set: { displayedAngle = $0 }
                ),
                in: 0...130,
                onEditingChanged: { editing in
                    isPreviewing = editing
                    store.previewAngleOverride = editing ? displayedAngle : nil
                }
            )
            .onChange(of: displayedAngle) { _, newValue in
                guard isPreviewing else { return }
                store.previewAngleOverride = newValue
            }
        }
    }

    private var aboutFooter: some View {
        HStack(spacing: 6) {
            Text("Bendd \(Self.versionString)")
            Text("·")
            Link("Source & issues", destination: URL(string: "https://github.com/nayeemdev/bendd")!)
        }
        .font(.caption)
        .foregroundStyle(.secondary)
    }

    private static var versionString: String {
        guard let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String else {
            return "(development build)"
        }
        return "v\(version)"
    }

    private func banner(_ message: String, symbol: String) -> some View {
        Label(message, systemImage: symbol)
            .font(.caption)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
    }

    private func captureErrorBanner(_ message: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            banner("Bendd can't see the desktop to bend it: \(message)", symbol: "exclamationmark.triangle")
            Button("Open Screen Recording Settings") {
                if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture") {
                    NSWorkspace.shared.open(url)
                }
            }
            .font(.caption)
        }
    }

    private func labeledSlider(_ title: String, value: Binding<Double>, range: ClosedRange<Double>) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Slider(value: value, in: range)
        }
    }
}
