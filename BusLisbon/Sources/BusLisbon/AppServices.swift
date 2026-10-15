import Foundation
import BusLisbonCore

enum AppServices {
    static let api = BusLisbonAPI { url, timeout in
        let request = URLRequest(url: url, timeoutInterval: timeout)
        let (data, response) = try await URLSession.shared.data(for: request)
        return (data, (response as? HTTPURLResponse)?.statusCode ?? 0)
    }

    static let cache = DiskCache(
        directory: FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("BusLisbon", isDirectory: true)
    )
}
