import SwiftUI

struct OnboardingView: View {
    let onFinish: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Image(systemName: "laptopcomputer")
                .font(.system(size: 40))
                .foregroundStyle(.tint)

            Text("Welcome to Bendd")
                .font(.title)
                .bold()

            Text("Bendd makes your desktop visually bend as you close the lid, like the screen is folding away. It lives in the menu bar and stays out of your way otherwise.")
                .fixedSize(horizontal: false, vertical: true)

            Text("To do this, Bendd needs Screen Recording permission so it can see what's on your desktop and render it tilting closed. Nothing is recorded, saved, or sent anywhere, it's only ever drawn live on your own screen.")
                .fixedSize(horizontal: false, vertical: true)
                .foregroundStyle(.secondary)

            Button("Grant Screen Recording Access") {
                if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture") {
                    NSWorkspace.shared.open(url)
                }
                _ = CGRequestScreenCaptureAccess()
            }
            .keyboardShortcut(.defaultAction)

            HStack {
                Spacer()
                Button("Get Started") { onFinish() }
            }
        }
        .padding(28)
        .frame(width: 420)
    }
}
