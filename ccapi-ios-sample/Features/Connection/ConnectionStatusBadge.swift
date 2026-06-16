import SwiftUI

// MARK: - 接続状態バッジ

/// 接続状態を色付きのカプセルで表示する常時表示用バッジ。
struct ConnectionStatusBadge: View {
    let state: ConnectionState

    var body: some View {
        HStack(spacing: 5) {
            Image(systemName: symbolName)
            Text(label)
                .font(.caption.bold())
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(color, in: Capsule())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("接続状態: \(label)")
    }

    // MARK: - 表示マッピング

    private var label: String {
        switch state {
        case .connected: return "接続中"
        case .unstable: return "不安定"
        case .disconnected: return "切断"
        }
    }

    private var symbolName: String {
        switch state {
        case .connected: return "wifi"
        case .unstable: return "wifi.exclamationmark"
        case .disconnected: return "wifi.slash"
        }
    }

    private var color: Color {
        switch state {
        case .connected: return .green
        case .unstable: return .orange
        case .disconnected: return .red
        }
    }
}

#Preview {
    VStack(spacing: 12) {
        ConnectionStatusBadge(state: .connected)
        ConnectionStatusBadge(state: .unstable)
        ConnectionStatusBadge(state: .disconnected)
    }
    .padding()
}
