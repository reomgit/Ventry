import Foundation

struct SupportedPathResolver {
    struct ResolvedDirectory {
        let name: String
        let path: String
        let type: DirectoryType
        let exists: Bool
    }

    static func resolveDirectories(
        for supportedApp: SupportedApplication,
        appVersion: String?,
        appBundlePath: String? = nil
    ) -> [ResolvedDirectory] {
        supportedApp.paths.flatMap { supportedPath in
            resolveDirectory(
                for: supportedPath,
                appVersion: appVersion,
                appBundlePath: appBundlePath
            )
        }
    }

    static func compareVersionStrings(_ lhs: String?, _ rhs: String?) -> ComparisonResult {
        let left = lhs?.trimmingCharacters(in: .whitespacesAndNewlines)
        let right = rhs?.trimmingCharacters(in: .whitespacesAndNewlines)

        switch (left?.isEmpty == false ? left : nil, right?.isEmpty == false ? right : nil) {
        case (nil, nil):
            return .orderedSame
        case (nil, _):
            return .orderedAscending
        case (_, nil):
            return .orderedDescending
        case let (.some(leftValue), .some(rightValue)):
            let leftComponents = versionComponents(from: leftValue)
            let rightComponents = versionComponents(from: rightValue)

            if let leftComponents, let rightComponents {
                let maxCount = max(leftComponents.count, rightComponents.count)
                for index in 0..<maxCount {
                    let leftPart = index < leftComponents.count ? leftComponents[index] : 0
                    let rightPart = index < rightComponents.count ? rightComponents[index] : 0
                    if leftPart < rightPart {
                        return .orderedAscending
                    }
                    if leftPart > rightPart {
                        return .orderedDescending
                    }
                }
                return .orderedSame
            }

            return leftValue.localizedStandardCompare(rightValue)
        }
    }

    private static func resolveDirectory(
        for supportedPath: SupportedPath,
        appVersion: String?,
        appBundlePath: String?
    ) -> [ResolvedDirectory] {
        let expandedTemplate = expandTemplateTokens(in: supportedPath.path, appBundlePath: appBundlePath)
        let directoryType = DirectoryType(rawValue: supportedPath.type) ?? .other

        guard expandedTemplate.contains("{version}") else {
            return [
                ResolvedDirectory(
                    name: supportedPath.name,
                    path: expandedTemplate,
                    type: directoryType,
                    exists: FileManager.default.fileExists(atPath: expandedTemplate)
                )
            ]
        }

        return resolveVersionedDirectories(
            templatePath: expandedTemplate,
            displayName: supportedPath.name,
            type: directoryType,
            appVersion: appVersion
        )
    }

    private static func resolveVersionedDirectories(
        templatePath: String,
        displayName: String,
        type: DirectoryType,
        appVersion: String?
    ) -> [ResolvedDirectory] {
        let token = "{version}"
        let parts = templatePath.components(separatedBy: token)

        guard parts.count == 2 else {
            return [
                ResolvedDirectory(
                    name: displayName,
                    path: templatePath,
                    type: type,
                    exists: FileManager.default.fileExists(atPath: templatePath)
                )
            ]
        }

        let versionRootPath = parts[0]
        let discoveredVersions = discoverVersionFolders(at: versionRootPath)
        let shouldAnnotateVersion = discoveredVersions.count > 1

        var resolvedDirectories = discoveredVersions.map { version in
            let resolvedPath = templatePath.replacingOccurrences(of: token, with: version)
            return ResolvedDirectory(
                name: shouldAnnotateVersion ? "\(displayName) (\(version))" : displayName,
                path: resolvedPath,
                type: type,
                exists: FileManager.default.fileExists(atPath: resolvedPath)
            )
        }

        if resolvedDirectories.isEmpty, let normalizedVersion = normalizedVersionCandidate(from: appVersion) {
            let resolvedPath = templatePath.replacingOccurrences(of: token, with: normalizedVersion)
            resolvedDirectories = [
                ResolvedDirectory(
                    name: displayName,
                    path: resolvedPath,
                    type: type,
                    exists: FileManager.default.fileExists(atPath: resolvedPath)
                )
            ]
        }

        if resolvedDirectories.isEmpty {
            resolvedDirectories = [
                ResolvedDirectory(
                    name: displayName,
                    path: templatePath,
                    type: type,
                    exists: FileManager.default.fileExists(atPath: templatePath)
                )
            ]
        }

        return resolvedDirectories
    }

    private static func expandTemplateTokens(in path: String, appBundlePath: String?) -> String {
        var expandedPath = path.replacingOccurrences(of: "~", with: FileManager.default.homeDirectoryForCurrentUser.path)

        if expandedPath.contains("{year}") {
            let resolvedYear = yearCandidate(from: appBundlePath)
                ?? String(Calendar.current.component(.year, from: Date()))
            expandedPath = expandedPath.replacingOccurrences(of: "{year}", with: resolvedYear)
        }

        return expandedPath
    }

    private static func yearCandidate(from appBundlePath: String?) -> String? {
        guard let appBundlePath, !appBundlePath.isEmpty else {
            return nil
        }

        let bundleURL = URL(fileURLWithPath: appBundlePath)
        let candidates = [
            bundleURL.deletingPathExtension().lastPathComponent,
            bundleURL.deletingLastPathComponent().lastPathComponent,
            bundleURL.lastPathComponent
        ]

        for candidate in candidates {
            if let year = extractFourDigitYear(from: candidate) {
                return year
            }
        }

        return nil
    }

    private static func extractFourDigitYear(from text: String) -> String? {
        let separators = CharacterSet.alphanumerics.inverted
        let tokens = text.components(separatedBy: separators).filter { !$0.isEmpty }

        for token in tokens.reversed() {
            guard token.count == 4,
                  token.allSatisfy(\.isNumber),
                  let year = Int(token),
                  (2000...2099).contains(year) else {
                continue
            }

            return token
        }

        return nil
    }

    private static func discoverVersionFolders(at rootPath: String) -> [String] {
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: rootPath, isDirectory: &isDirectory), isDirectory.boolValue else {
            return []
        }

        let rootURL = URL(fileURLWithPath: rootPath, isDirectory: true)
        guard let contents = try? FileManager.default.contentsOfDirectory(
            at: rootURL,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else {
            return []
        }

        let versions = Set(contents.compactMap { url -> String? in
            let resourceValues = try? url.resourceValues(forKeys: [.isDirectoryKey])
            guard resourceValues?.isDirectory == true else {
                return nil
            }

            let candidate = url.lastPathComponent
            return isNumericVersionFolderName(candidate) ? candidate : nil
        })

        return versions.sorted { left, right in
            let order = compareVersionStrings(left, right)
            if order == .orderedSame {
                return left.localizedStandardCompare(right) == .orderedAscending
            }
            return order == .orderedDescending
        }
    }

    private static func isNumericVersionFolderName(_ name: String) -> Bool {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return false
        }

        let parts = trimmed.split(separator: ".", omittingEmptySubsequences: false)
        guard !parts.isEmpty else {
            return false
        }

        return parts.allSatisfy { part in
            !part.isEmpty && part.allSatisfy(\.isNumber)
        }
    }

    private static func normalizedVersionCandidate(from appVersion: String?) -> String? {
        guard let appVersion else {
            return nil
        }

        var extracted = ""
        var started = false

        for character in appVersion {
            if character.isNumber {
                extracted.append(character)
                started = true
                continue
            }

            if character == ".", started {
                extracted.append(character)
                continue
            }

            if started {
                break
            }
        }

        let normalized = extracted.trimmingCharacters(in: CharacterSet(charactersIn: "."))
        guard isNumericVersionFolderName(normalized) else {
            return nil
        }

        return normalized
    }

    private static func versionComponents(from version: String) -> [Int]? {
        let parts = version.split(separator: ".", omittingEmptySubsequences: false)
        guard !parts.isEmpty else {
            return nil
        }

        var numericParts: [Int] = []
        for part in parts {
            let digits = part.filter(\.isNumber)
            guard !digits.isEmpty, let value = Int(digits) else {
                return nil
            }
            numericParts.append(value)
        }

        return numericParts.isEmpty ? nil : numericParts
    }
}
