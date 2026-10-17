import SwiftUI
import BusLisbonCore

struct LineStar: View {
    let lineId: String
    let chosen: Bool
    let toggle: () -> Void

    var body: some View {
        Button(action: toggle) {
            Image(systemName: chosen ? "star.fill" : "star")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(chosen ? Theme.yellow : Color.secondary)
                .contentTransition(.symbolEffect(.replace))
                .frame(width: 28, height: 28)
                .contentShape(Circle())
        }
        .buttonStyle(.borderless)
        .sensoryFeedback(.impact(weight: .light), trigger: chosen)
        .accessibilityLabel(chosen ? "Tirar a linha \(lineId) das minhas" : "Juntar a linha \(lineId) às minhas")
    }
}

extension TrustLevel {
    var colour: Color {
        switch self {
        case .high: Color(red: 0.204, green: 0.827, blue: 0.600)
        case .good: Color(red: 0.431, green: 0.906, blue: 0.718)
        case .uneven: Theme.yellow
        case .low: Color(red: 0.984, green: 0.573, blue: 0.235)
        }
    }
}

@Observable
@MainActor
final class LineRankingModel {
    private(set) var ranking: LineRanking?
    private(set) var failed = false

    func load() async {
        failed = false
        do {
            ranking = try await AppServices.api.ranking()
        } catch {
            failed = ranking == nil
        }
    }
}

struct LineRankingSheet: View {
    let favourites: Favourites

    @State private var model = LineRankingModel()

    var body: some View {
        NavigationStack {
            content
                .navigationTitle("Pontualidade das linhas")
                .navigationBarTitleDisplayMode(.inline)
                .toolbarBackground(.hidden, for: .navigationBar)
                .navigationDestination(for: RankedLine.self) { line in
                    LineTrustDetail(line: line, toleranceSeconds: model.ranking?.toleranceSeconds ?? 300)
                }
        }
        .task { await model.load() }
    }

    @ViewBuilder
    private var content: some View {
        if let ranking = model.ranking {
            if ranking.lines.isEmpty {
                message("Ainda não há passagens suficientes para comparar linhas.", footnote: describeFreshness(computedAtUnix: ranking.computedAtUnix, now: Int(Date().timeIntervalSince1970)))
            } else {
                list(ranking)
            }
        } else if model.failed {
            message("Não consegui ir buscar os dados. Tenta daqui a pouco.", footnote: nil)
        } else {
            ProgressView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private func list(_ ranking: LineRanking) -> some View {
        let split = splitByFavourites(ranking.lines, favourites: favourites.ids)

        return List {
            Text(explanation(ranking))
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .listRowBackground(Color.clear)

            if !split.mine.isEmpty || !split.missing.isEmpty {
                Section {
                    ForEach(split.mine) { line in row(line) }
                    ForEach(split.missing, id: \.self) { lineId in missingRow(lineId) }
                } header: {
                    header("As minhas linhas", colour: Theme.yellow.opacity(0.7))
                }
            }

            Section {
                ForEach(split.rest) { line in row(line) }
            } header: {
                if !split.mine.isEmpty || !split.missing.isEmpty {
                    header("Todas as linhas", colour: .secondary)
                }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .animation(.snappy, value: favourites.ids)
    }

    private func row(_ line: RankedLine) -> some View {
        let percent = punctualityPercent(line)
        let trust = describeTrust(percent)

        return NavigationLink(value: line) {
            HStack(spacing: 10) {
                LineBadge(line: line.lineId)
                VStack(alignment: .leading, spacing: 6) {
                    GeometryReader { proxy in
                        Capsule()
                            .fill(Color.white.opacity(0.1))
                            .overlay(alignment: .leading) {
                                Capsule()
                                    .fill(trust.level.colour)
                                    .frame(width: proxy.size.width * CGFloat(percent) / 100)
                            }
                    }
                    .frame(height: 6)
                    HStack(spacing: 0) {
                        Text(trust.label)
                            .fontWeight(.semibold)
                            .foregroundStyle(trust.level.colour)
                        Text(" · \(line.passages) passagens")
                            .foregroundStyle(.secondary)
                    }
                    .font(.system(size: 11))
                    .lineLimit(1)
                }
                Text("\(percent)%")
                    .font(.system(size: 14, weight: .bold).monospacedDigit())
                    .frame(width: 44, alignment: .trailing)
                LineStar(lineId: line.lineId, chosen: favourites.contains(line.lineId)) {
                    favourites.toggle(line.lineId)
                }
            }
        }
        .listRowBackground(Color.clear)
        .accessibilityLabel("Linha \(line.lineId), \(trust.label), \(percent)%")
    }

    private func missingRow(_ lineId: String) -> some View {
        HStack(spacing: 10) {
            Text(lineId)
                .font(.system(size: 14, weight: .black))
                .foregroundStyle(Color.secondary)
                .frame(width: 56, height: 32)
                .background(Color.white.opacity(0.1), in: RoundedRectangle(cornerRadius: 10))
            Text("Ainda sem passagens observadas")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
            Spacer()
            LineStar(lineId: lineId, chosen: true) { favourites.toggle(lineId) }
        }
        .listRowBackground(Color.clear)
    }

    private func header(_ text: String, colour: Color) -> some View {
        Text(text.uppercased())
            .font(.system(size: 11, weight: .bold))
            .tracking(1)
            .foregroundStyle(colour)
    }

    private func explanation(_ ranking: LineRanking) -> String {
        "Uma passagem é um autocarro a passar numa das paragens que vigiamos, e uma linha serve várias — por isso os números sobem depressa. A percentagem é a fatia dessas passagens que chegou \(describeToleranceLabel(ranking.toleranceSeconds)) publicado, comparando a hora a que o autocarro passou mesmo com a hora da tabela e não com a previsão da app. \(describeFreshness(computedAtUnix: ranking.computedAtUnix, now: Int(Date().timeIntervalSince1970)))."
    }

    private func message(_ text: String, footnote: String?) -> some View {
        VStack(spacing: 8) {
            Text(text)
                .font(.system(size: 14))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            if let footnote {
                Text(footnote)
                    .font(.system(size: 11))
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct LineTrustDetail: View {
    let line: RankedLine
    let toleranceSeconds: Int

    var body: some View {
        let percent = punctualityPercent(line)
        let trust = describeTrust(percent)
        let tolerance = describeToleranceLabel(toleranceSeconds)
        let minutes = Int((Double(toleranceSeconds) / 60).rounded())

        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 12) {
                    LineBadge(line: line.lineId)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(trust.label)
                            .font(.system(size: 15, weight: .bold))
                            .foregroundStyle(trust.level.colour)
                        Text("\(percent)% \(tolerance)")
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                    }
                }

                Text("\(line.passages) passagens observadas · \(describeServiceWindow(line.firstServiceDate, line.lastServiceDate))")
                    .font(.system(size: 12))

                VStack(alignment: .leading, spacing: 0) {
                    count(line.withinTolerance, "chegaram \(tolerance)")
                    count(line.late, "chegaram mais de \(minutes) min atrasadas")
                    count(line.early, "passaram mais de \(minutes) min adiantadas")
                }
                .padding(.vertical, 4)
                .overlay(alignment: .top) { Divider() }

                Text("Em média, \(describeAverage(line.averageLatenessSeconds)).")
                    .font(.system(size: 12))

                if line.passages < thinEvidence {
                    Text("Ainda são poucas passagens. Com mais dias, este número pode mudar bastante.")
                        .font(.system(size: 11))
                        .foregroundStyle(Theme.yellow.opacity(0.8))
                }

                Text("Uma passagem é este autocarro a passar numa das paragens que vigiamos. Comparamos a hora a que passou mesmo com a hora da tabela publicada, não com a previsão da app.")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .navigationTitle("Linha \(line.lineId)")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
    }

    private func count(_ value: Int, _ text: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Text("\(value)")
                .font(.system(size: 14, weight: .bold).monospacedDigit())
                .frame(width: 48, alignment: .trailing)
            Text(text)
                .foregroundStyle(.secondary)
            + Text(line.passages > 0 && value > 0 ? " · \(Int((Double(value) / Double(line.passages) * 100).rounded()))%" : "")
                .foregroundStyle(.tertiary)
        }
        .font(.system(size: 12))
        .padding(.vertical, 6)
    }
}
