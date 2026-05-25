import Foundation

/// A helper to fetch the latest release version from a GitHub repository.
public struct UpdateChecker: Sendable {
    private let currentVersion: String
    private let repo: String

    public init(currentVersion: String, repo: String) {
        self.currentVersion = currentVersion
        self.repo = repo
    }

    private struct ReleaseInfo: Decodable {
        let tag_name: String
        let html_url: String
    }

    /// Queries GitHub API for the latest release and compares it to the current version.
    /// Returns the remote version tag and release URL if a newer version is available.
    public func checkForUpdates() async -> (version: String, url: URL)? {
        let urlString = "https://api.github.com/repos/\(repo)/releases/latest"
        guard let url = URL(string: urlString) else { return nil }

        var request = URLRequest(url: url)
        request.setValue("Lyra/\(currentVersion) (macOS)", forHTTPHeaderField: "User-Agent")
        request.timeoutInterval = 10.0

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                return nil
            }

            let release = try JSONDecoder().decode(ReleaseInfo.self, from: data)
            let remoteTag = release.tag_name.trimmingCharacters(in: CharacterSet(charactersIn: "vV"))
            let currentTag = currentVersion.trimmingCharacters(in: CharacterSet(charactersIn: "vV"))

            if isVersionNewer(remote: remoteTag, current: currentTag),
               let releaseUrl = URL(string: release.html_url) {
                return (release.tag_name, releaseUrl)
            }
        } catch {
            // Silently ignore network failures to avoid disturbing the user
            return nil
        }
        return nil
    }

    private func isVersionNewer(remote: String, current: String) -> Bool {
        let remoteParts = remote.split(separator: ".").compactMap { Int($0) }
        let currentParts = current.split(separator: ".").compactMap { Int($0) }

        let maxLength = max(remoteParts.count, currentParts.count)
        for i in 0..<maxLength {
            let rPart = i < remoteParts.count ? remoteParts[i] : 0
            let cPart = i < currentParts.count ? currentParts[i] : 0
            if rPart > cPart { return true }
            if rPart < cPart { return false }
        }
        return false
    }
}
