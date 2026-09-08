import SwiftUI

/// Platform-specific steps for enabling the extension.
struct SetupInstructions: View {
    private var steps: [String] {
        #if os(macOS)
        [
            "Open Safari Settings and switch to the Extensions tab.",
            "Enable “Startpage Extension”, then allow it on every website.",
            "In the Search tab, set the search engine to DuckDuckGo or Ecosia.",
            "In the extension's settings, enable only that same engine."
        ]
        #else
        [
            "Open Settings, then Apps, then Safari, then Extensions.",
            "Enable “Startpage Extension” and choose Allow on Every Website.",
            "In Safari's settings, set the search engine to DuckDuckGo or Ecosia.",
            "In the extension's settings, enable only that same engine."
        ]
        #endif
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Setup")
                .font(.headline)

            ForEach(Array(steps.enumerated()), id: \.offset) { index, step in
                HStack(alignment: .firstTextBaseline, spacing: 10) {
                    Text("\(index + 1).")
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                    Text(step)
                }
                .accessibilityElement(children: .combine)
            }
        }
    }
}

#Preview {
    SetupInstructions()
        .padding()
}
