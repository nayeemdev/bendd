import AppKit

guard let path = CommandLine.arguments.dropFirst().first else {
    print("usage: metalspike <path-to-image>")
    exit(1)
}

let textureURL = URL(fileURLWithPath: path)
let app = NSApplication.shared
let delegate = AppDelegate(textureURL: textureURL)
app.delegate = delegate
app.setActivationPolicy(.regular)
app.run()
