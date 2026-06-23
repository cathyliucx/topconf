import SwiftUI

struct ContentView: View {
    var body: some View {
        VStack(spacing: 12) {
            Text("TopConf")
                .font(.title)
                .fontWeight(.semibold)

            Text("Conference deadline tracking is being initialized.")
                .foregroundStyle(.secondary)
        }
        .padding(32)
        .frame(minWidth: 420, minHeight: 240)
    }
}

