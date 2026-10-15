import Foundation

let foldedLetters: [Character: Character] = [
    "á": "a", "à": "a", "â": "a", "ã": "a", "ä": "a",
    "é": "e", "è": "e", "ê": "e", "ë": "e",
    "í": "i", "ì": "i", "î": "i", "ï": "i",
    "ó": "o", "ò": "o", "ô": "o", "õ": "o", "ö": "o",
    "ú": "u", "ù": "u", "û": "u", "ü": "u",
    "ç": "c", "ñ": "n",
]

public func fold(_ text: String) -> String {
    String(text.lowercased().map { foldedLetters[$0] ?? $0 })
}

public struct StopSearchIndex: Sendable {
    private let stops: [Stop]
    private let texts: [String]

    public init(_ stops: [Stop]) {
        self.stops = stops
        texts = stops.map { fold($0.name + " " + ($0.locality ?? "")) }
    }

    public func search(_ query: String, limit: Int = 8) -> [Stop] {
        let trimmed = query.trimmingCharacters(in: .whitespaces)
        let words = fold(trimmed).split(separator: " ").map(String.init)
        guard !words.isEmpty else { return [] }

        var byNumber: [Stop] = []
        var byName: [Stop] = []

        for (stop, text) in zip(stops, texts) {
            if stop.id.hasPrefix(trimmed) {
                byNumber.append(stop)
            } else if words.allSatisfy({ text.contains($0) }) {
                byName.append(stop)
            }
        }

        return Array((byNumber + byName).prefix(limit))
    }
}

public func searchStops(_ query: String, in stops: [Stop], limit: Int = 8) -> [Stop] {
    StopSearchIndex(stops).search(query, limit: limit)
}
