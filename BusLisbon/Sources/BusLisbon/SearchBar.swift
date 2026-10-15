import SwiftUI
import BusLisbonCore

struct SearchBar: View {
    let index: StopSearchIndex?
    let tucked: Bool
    let onPick: (Stop) -> Void

    @State private var query = ""
    @State private var searched = ""
    @State private var results: [Stop] = []
    @State private var reopened = false
    @AppStorage("searchBarCollapsed") private var swipedAway = false
    @State private var fullWidth: CGFloat = 0
    @State private var dragX: CGFloat = 0
    @FocusState private var focused: Bool

    private let circle: CGFloat = 48
    private let settle = Animation.spring(response: 0.35, dampingFraction: 0.78)

    private var collapsed: Bool { (tucked && !reopened) || swipedAway }

    private var barWidth: CGFloat {
        let resting = collapsed ? circle : fullWidth
        return min(max(resting + dragX, circle), max(fullWidth, circle))
    }

    private var openness: CGFloat {
        guard fullWidth > circle else { return collapsed ? 0 : 1 }
        return (barWidth - circle) / (fullWidth - circle)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            bar
            if focused && openness > 0.99 && searched.count >= 2 {
                dropdown
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            GeometryReader { proxy in
                Color.clear
                    .onAppear { fullWidth = proxy.size.width }
                    .onChange(of: proxy.size.width) { _, width in fullWidth = width }
            }
        )
        .animation(settle, value: collapsed)
        .sensoryFeedback(.impact(weight: .light), trigger: collapsed)
        .onChange(of: tucked) { _, isTucked in
            if isTucked {
                reopened = false
                focused = false
            }
        }
        .task(id: query) {
            try? await Task.sleep(for: .milliseconds(200))
            guard !Task.isCancelled else { return }
            let trimmed = query.trimmingCharacters(in: .whitespaces)
            results = trimmed.count >= 2 ? index?.search(trimmed) ?? [] : []
            searched = trimmed
        }
    }

    private var bar: some View {
        HStack(spacing: 10 * openness) {
            if openness > 0 {
                TextField("", text: $query, prompt: Text("Pesquisar paragens, IDs ou locais...").foregroundStyle(Color.gray))
                    .focused($focused)
                    .foregroundStyle(.white)
                    .tint(Theme.yellow)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                    .submitLabel(.search)
                    .opacity(openness)
            }
            icon
                .frame(width: circle - (circle - 24) * openness, height: circle)
        }
        .padding(.leading, 16 * openness)
        .padding(.trailing, 12 * openness)
        .frame(width: fullWidth > 0 ? barWidth : nil, height: circle + 8 * openness, alignment: .trailing)
        .frame(maxWidth: fullWidth > 0 ? nil : .infinity)
        .background(Theme.ink.opacity(0.9), in: RoundedRectangle(cornerRadius: 14 + 10 * (1 - openness)))
        .overlay(
            RoundedRectangle(cornerRadius: 14 + 10 * (1 - openness))
                .stroke(focused ? Theme.yellow : Color.white.opacity(0.08), lineWidth: focused ? 2 : 1)
        )
        .overlay {
            if collapsed && dragX == 0 {
                Circle()
                    .fill(Color.clear)
                    .contentShape(Circle())
                    .onTapGesture { expand(typing: true) }
                    .accessibilityLabel("Pesquisar")
                    .accessibilityAddTraits(.isButton)
            }
        }
        .shadow(color: .black.opacity(0.3), radius: 12, y: 4)
        .highPriorityGesture(
            DragGesture(minimumDistance: 10)
                .onChanged { drag in
                    guard abs(drag.translation.width) > abs(drag.translation.height) else { return }
                    if !collapsed { focused = false }
                    dragX = drag.translation.width
                }
                .onEnded(finishDrag)
        )
    }

    @ViewBuilder
    private var icon: some View {
        if openness < 0.5 || query.isEmpty {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 17 + 3 * (1 - openness), weight: .semibold))
                .foregroundStyle(Theme.yellow)
        } else {
            Button {
                clear()
            } label: {
                Image(systemName: "xmark")
                    .foregroundStyle(Color.gray)
            }
            .accessibilityLabel("Limpar")
        }
    }

    private var dropdown: some View {
        Group {
            if results.isEmpty {
                Text("Nenhuma paragem encontrada.")
                    .foregroundStyle(Color.gray)
                    .frame(maxWidth: .infinity)
                    .padding(16)
            } else {
                ScrollView {
                    VStack(spacing: 0) {
                        ForEach(results) { stop in
                            Button {
                                pick(stop)
                            } label: {
                                SearchRow(stop: stop)
                            }
                            if stop.id != results.last?.id {
                                Rectangle()
                                    .fill(Color.white.opacity(0.06))
                                    .frame(height: 1)
                            }
                        }
                    }
                }
                .frame(maxHeight: 256)
                .fixedSize(horizontal: false, vertical: true)
            }
        }
        .background(Theme.ink.opacity(0.95), in: RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.white.opacity(0.1)))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .shadow(color: .black.opacity(0.3), radius: 12, y: 4)
        .transition(.opacity.combined(with: .move(edge: .top)))
    }

    private func finishDrag(_ drag: DragGesture.Value) {
        let moved = drag.translation.width
        let flung = drag.predictedEndTranslation.width

        withAnimation(settle) {
            if !collapsed, moved < -fullWidth * 0.25 || flung < -fullWidth * 0.5 {
                clear()
                swipedAway = true
                reopened = false
            } else if collapsed, moved > fullWidth * 0.25 || flung > fullWidth * 0.5 {
                swipedAway = false
                reopened = true
            }
            dragX = 0
        }
    }

    private func expand(typing: Bool) {
        swipedAway = false
        reopened = true
        guard typing else { return }
        Task {
            try? await Task.sleep(for: .milliseconds(50))
            focused = true
        }
    }

    private func pick(_ stop: Stop) {
        onPick(stop)
        clear()
        focused = false
        reopened = false
    }

    private func clear() {
        query = ""
        searched = ""
        results = []
    }
}

struct SearchRow: View {
    let stop: Stop

    var body: some View {
        HStack(spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
                Text(stop.name)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                Text(stop.locality ?? "")
                    .font(.caption)
                    .foregroundStyle(Color.gray)
            }
            Spacer(minLength: 8)
            Text("#\(stop.id)")
                .font(.caption2.bold())
                .tracking(1)
                .foregroundStyle(Theme.yellow)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.black.opacity(0.5), in: RoundedRectangle(cornerRadius: 4))
        }
        .padding(12)
        .contentShape(Rectangle())
    }
}
