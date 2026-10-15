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

public func searchStops(_ query: String, in stops: [Stop], limit: Int = 30) -> [Stop] {
    let trimmed = query.trimmingCharacters(in: .whitespaces)
    let words = fold(trimmed).split(separator: " ").map(String.init)
    guard !words.isEmpty else { return [] }

    let byNumber = stops.filter { $0.id.hasPrefix(trimmed) }
    let byName = stops.filter { stop in
        guard !stop.id.hasPrefix(trimmed) else { return false }
        let text = fold(stop.name + " " + (stop.locality ?? ""))
        return words.allSatisfy { text.contains($0) }
    }

    return Array((byNumber + byName).prefix(limit))
}
