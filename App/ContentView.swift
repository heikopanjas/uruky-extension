import SwiftUI

/// The container app exists only to host the appex and tell the user how to
/// switch the extension on. There is nothing else for it to do.
struct ContentView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                header
                Divider()
                SetupInstructions()
                Divider()
                caveat

                #if os(macOS)
                Button("Open Safari Extension Settings", systemImage: "safari") {
                    SafariSettingsLauncher.open()
                }
                .buttonStyle(.borderedProminent)
                #endif
            }
            .padding(28)
            .frame(maxWidth: 520, alignment: .leading)
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Uruky for Safari")
                .font(.title2.weight(.semibold))
            Text("Sends Safari searches to Uruky.")
                .foregroundStyle(.secondary)
        }
        .accessibilityElement(children: .combine)
    }

    private var caveat: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("What this cannot do", systemImage: "info.circle")
                .font(.headline)
            Text("""
                 Safari provides no way to add a custom search engine, so the \
                 search is first sent to whichever engine Safari is configured \
                 to use and then redirected. Address-bar suggestions still come \
                 from that engine and cannot be intercepted. Pick an engine you \
                 do not mind leaking to, and enable only that one in the \
                 extension's settings.
                 """)
            .foregroundStyle(.secondary)
            .font(.callout)
        }
    }
}

#Preview {
    ContentView()
}
