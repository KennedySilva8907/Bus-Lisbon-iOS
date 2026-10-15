import Foundation

extension KeyedDecodingContainer {
    func decodeNumberIfPresent(forKey key: Key) -> Double? {
        if let number = try? decodeIfPresent(Double.self, forKey: key) { return number }
        if let text = try? decodeIfPresent(String.self, forKey: key) { return Double(text) }
        return nil
    }

    func decodeTextIfPresent(forKey key: Key) -> String? {
        if let text = try? decodeIfPresent(String.self, forKey: key) { return text }
        if let whole = try? decodeIfPresent(Int.self, forKey: key) { return String(whole) }
        return nil
    }
}

struct LossyArray<Element: Decodable>: Decodable {
    let elements: [Element]

    init(from decoder: any Decoder) throws {
        var container = try decoder.unkeyedContainer()
        var elements: [Element] = []

        while !container.isAtEnd {
            if let element = try? container.decode(Element.self) {
                elements.append(element)
            } else {
                _ = try container.decode(Skip.self)
            }
        }

        self.elements = elements
    }
}

private struct Skip: Decodable {
    init(from decoder: any Decoder) throws {}
}
