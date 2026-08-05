import ArgumentParser
import FBControlCore
import Foundation

struct DescribeUI: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "Describes the UI hierarchy of a booted simulator using accessibility information."
    )

    @Option(name: .customLong("udid"), help: "The UDID of the simulator.")
    var simulatorUDID: String

    @Option(
        name: .customLong("point"),
        help: ArgumentHelp(
            "Describe only the accessibility element at screen coordinates x,y.",
            valueName: "x,y"
        )
    )
    var point: String?

    @Flag(
        name: .customLong("include-web-content"),
        help: "Also describe WKWebView and SFSafariViewController page content, which the in-process accessibility walk cannot reach. Discovered elements report \"is_remote\": \"point_grid\"."
    )
    var includeWebContent = false

    @Option(
        name: .customLong("web-content-grid-step"),
        help: ArgumentHelp(
            "Spacing in points between web-content hit-test samples; smaller is more thorough but slower. Only applies with --include-web-content.",
            valueName: "points"
        )
    )
    // 25pt, not the library's 50pt default: at 50pt the gaps between probe rows miss a standard
    // 20pt-tall link while still returning a complete-looking tree.
    var webContentGridStep: Double = 25

    @Option(
        name: .customLong("web-content-max-points"),
        help: ArgumentHelp(
            "Cap on hit-tested points when discovering web content (0 = unlimited). Only applies with --include-web-content.",
            valueName: "count"
        )
    )
    var webContentMaxPoints: UInt = 0

    func validate() throws {
        _ = try parsedPoint()

        if includeWebContent {
            guard webContentGridStep > 0 else {
                throw ValidationError("--web-content-grid-step must be greater than zero.")
            }
            // --point already resolves the element under the cursor across the process boundary.
            if point != nil {
                throw ValidationError(
                    "--include-web-content cannot be combined with --point; a point lookup already resolves web content."
                )
            }
        }
    }

    func run() async throws {
        let logger = AxeLogger()
        try await performGlobalSetup(logger: logger)

        let jsonData = try await AccessibilityFetcher.fetchAccessibilityInfoJSONData(
            for: simulatorUDID,
            point: try parsedPoint(),
            remoteContent: remoteContentOptions(),
            logger: logger
        )
        guard let jsonString = String(data: jsonData, encoding: .utf8) else {
            throw CLIError(errorDescription: "Failed to convert accessibility info to JSON string.")
        }
        print(jsonString)
    }

    private func remoteContentOptions() -> FBAccessibilityRemoteContentOptions? {
        guard includeWebContent else {
            return nil
        }
        return FBAccessibilityRemoteContentOptions(
            gridStepSize: CGFloat(webContentGridStep),
            maxPoints: webContentMaxPoints
        )
    }

    private func parsedPoint() throws -> AccessibilityPoint? {
        guard let point else {
            return nil
        }

        let coordinates = point
            .split(separator: ",", omittingEmptySubsequences: false)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }

        guard coordinates.count == 2,
              let x = Double(coordinates[0]),
              let y = Double(coordinates[1]),
              x.isFinite,
              y.isFinite,
              x >= 0,
              y >= 0
        else {
            throw ValidationError("--point must be in the form x,y using non-negative numbers.")
        }

        return AccessibilityPoint(x: x, y: y)
    }
}
