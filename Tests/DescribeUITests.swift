import Testing
import Foundation

@Suite("Describe UI Command Surface Tests")
struct DescribeUICommandSurfaceTests {
    @Test("--point appears in describe-ui --help")
    func describeUIHelpIncludesPoint() async throws {
        let result = try await TestHelpers.runAxeCommand("describe-ui --help")
        #expect(result.output.contains("--point <x,y>"))
    }

    @Test("--point appears in help describe-ui")
    func helpDescribeUIIncludesPoint() async throws {
        let result = try await TestHelpers.runAxeCommand("help describe-ui")
        #expect(result.output.contains("--point <x,y>"))
    }

    @Test("Invalid --point format fails with guidance")
    func invalidPointFormatFails() async throws {
        let result = try await TestHelpers.runAxeCommandAllowFailure("describe-ui --udid invalid --point nope")
        #expect(result.exitCode != 0)
        #expect(result.output.contains("--point must be in the form x,y using non-negative numbers."))
    }

    @Test("Web content options appear in describe-ui --help")
    func describeUIHelpIncludesWebContentOptions() async throws {
        let result = try await TestHelpers.runAxeCommand("describe-ui --help")
        #expect(result.output.contains("--include-web-content"))
        #expect(result.output.contains("--web-content-grid-step"))
        #expect(result.output.contains("--web-content-max-points"))
    }

    @Test("Non-positive --web-content-grid-step fails with guidance")
    func nonPositiveGridStepFails() async throws {
        let result = try await TestHelpers.runAxeCommandAllowFailure(
            "describe-ui --udid invalid --include-web-content --web-content-grid-step 0"
        )
        #expect(result.exitCode != 0)
        #expect(result.output.contains("--web-content-grid-step must be greater than zero."))
    }

    @Test("--include-web-content is rejected alongside --point")
    func webContentWithPointFails() async throws {
        let result = try await TestHelpers.runAxeCommandAllowFailure(
            "describe-ui --udid invalid --point 10,10 --include-web-content"
        )
        #expect(result.exitCode != 0)
        #expect(result.output.contains("--include-web-content cannot be combined with --point"))
    }
}

@Suite("Describe UI Command Tests", .serialized, .enabled(if: isE2EEnabled))
struct DescribeUITests {
    @Test("Basic describe-ui returns valid JSON")
    func basicDescribeUI() async throws {
        // Arrange
        try await TestHelpers.launchPlaygroundApp(to: "tap-test")
        
        // Act
        let uiState = try await TestHelpers.getUIState()
        
        // Assert - Should have basic structure (which means JSON was parsed successfully)
        #expect(uiState.type != "", "Root element should have a type")
    }
    
    @Test("Describe-ui captures UI hierarchy")
    func describeUIHierarchy() async throws {
        // Arrange
        try await TestHelpers.launchPlaygroundApp(to: "tap-test")
        
        // Act
        let uiState = try await TestHelpers.getUIState()
        
        // Assert - Should have basic structure
        #expect(uiState.type != "", "Root element should have a type")
        #expect(uiState.children != nil, "Root element should have children")
        #expect(uiState.children?.count ?? 0 > 0, "Should have at least one child element")
    }

    @Test("Describe-ui exposes SwiftUI TabView tabs as real elements")
    func describeUIExposesSwiftUITabViewTabsAsRealElements() async throws {
        try await TestHelpers.launchPlaygroundApp(to: "tab-view-test")

        let uiState = try await TestHelpers.getUIState()
        let homeTab = UIStateParser.findElementByLabel(in: uiState, label: "Home")
        let settingsTab = UIStateParser.findElementByLabel(in: uiState, label: "Settings")

        #expect(homeTab?.type == "RadioButton")
        #expect(homeTab?.frame != nil)
        #expect(settingsTab?.type == "RadioButton")
        #expect(settingsTab?.frame != nil)
    }

    @Test("Describe-ui exposes navigation searchable field")
    func describeUIExposesNavigationSearchableField() async throws {
        try await TestHelpers.launchPlaygroundApp(to: "searchable-test")

        let uiState = try await TestHelpers.getUIState()
        let searchField = UIStateParser.findElement(in: uiState) { element in
            element.type == "TextField" && element.value == "Search Books"
        }

        #expect(searchField?.frame != nil)
    }

    @Test("Describe-ui exposes toolbar segmented picker and navigation back button")
    func describeUIExposesToolbarPickerAndBackButton() async throws {
        try await TestHelpers.launchPlaygroundApp(to: "toolbar-picker-test")

        let uiState = try await TestHelpers.getUIState()
        let backButton = UIStateParser.findElement(in: uiState, withIdentifier: "BackButton")
        let allOption = UIStateParser.findElementByLabel(in: uiState, label: "All")
        let unreadOption = UIStateParser.findElementByLabel(in: uiState, label: "Unread")
        let readOption = UIStateParser.findElementByLabel(in: uiState, label: "Read")

        #expect(backButton?.type == "Button")
        #expect(allOption?.type == "RadioButton")
        #expect(unreadOption?.type == "RadioButton")
        #expect(readOption?.type == "RadioButton")
    }

    @Test("Describe-ui --point returns the targeted element")
    func describeUIAtPoint() async throws {
        let simulatorUDID = try TestHelpers.requireSimulatorUDID()
        try await TestHelpers.launchPlaygroundApp(to: "tap-test", simulatorUDID: simulatorUDID)

        let uiState = try await TestHelpers.getUIState(simulatorUDID: simulatorUDID)
        guard let backButton = UIStateParser.findElement(in: uiState, withIdentifier: "BackButton"),
              let frame = backButton.frame
        else {
            throw TestError.elementNotFound("BackButton with frame was not found in describe-ui output")
        }

        let centerX = frame.x + (frame.width / 2)
        let centerY = frame.y + (frame.height / 2)
        let point = "\(centerX),\(centerY)"

        let result = try await TestHelpers.runAxeCommand(
            "describe-ui --point \(point)",
            simulatorUDID: simulatorUDID
        )

        let roots = try UIStateParser.parseDescribeUIRoots(result.output)
        #expect(roots.count == 1, "Point-based describe-ui should return a single top-level element")

        let targetedElement = try #require(roots.first)
        let targetedFrame = try #require(targetedElement.frame)

        #expect(targetedElement.identifier == "BackButton")
        #expect(targetedElement.label == "AXe Playground")
        #expect(targetedElement.type == "Button")
        #expect(targetedElement.role == "AXButton")
        #expect(targetedElement.roleDescription == "back button")
        #expect(targetedElement.enabled == true)
        #expect(targetedElement.contentRequired == false)
        #expect(targetedElement.title == nil)
        #expect(targetedElement.helpText == nil)
        #expect(targetedElement.subrole == nil)
        #expect(targetedElement.AXFrame == "{{16, 62}, {44, 44}}")
        #expect(targetedElement.children?.isEmpty == true)
        #expect(targetedElement.customActions?.isEmpty == true)
        #expect(targetedFrame.x == 16)
        #expect(targetedFrame.y == 62)
        #expect(targetedFrame.width == 44)
        #expect(targetedFrame.height == 44)
    }

    @Test("Describe-ui omits WKWebView page content by default")
    func describeUIOmitsWebContentByDefault() async throws {
        try await TestHelpers.launchPlaygroundApp(to: "web-content-test")
        let simulatorUDID = try TestHelpers.requireSimulatorUDID()
        // Wait until the page is discoverable, so "absent" below means unreachable, not unpainted.
        _ = try await Self.waitForWebContent(simulatorUDID: simulatorUDID)

        let uiState = try await TestHelpers.getUIState()

        // The screen itself is up...
        #expect(UIStateParser.findElement(in: uiState, withIdentifier: "web-content-test-webview") != nil)
        // ...but its page content is rendered by a separate process the in-process walk cannot reach.
        for label in Self.webFixtureLabels {
            #expect(
                UIStateParser.findElementByLabel(in: uiState, label: label) == nil,
                "\(label) should not appear without --include-web-content"
            )
        }
    }

    @Test("Describe-ui returns WKWebView page content with --include-web-content")
    func describeUIReturnsWebContentWhenRequested() async throws {
        try await TestHelpers.launchPlaygroundApp(to: "web-content-test")
        let simulatorUDID = try TestHelpers.requireSimulatorUDID()

        let roots = try await Self.waitForWebContent(simulatorUDID: simulatorUDID)

        for (label, expectedType) in Self.webFixtureElements {
            let element = try #require(
                UIStateParser.findElement(in: roots, matching: { $0.label == label }),
                "\(label) should be discovered with --include-web-content"
            )
            #expect(element.type == expectedType)
            #expect(element.isRemote == "point_grid")
            // A hit-tested element carries a real on-screen frame, so it stays tappable by coordinate.
            let frame = try #require(element.frame)
            #expect(frame.width > 0)
            #expect(frame.height > 0)
        }
    }

    // WKWebView paints its page asynchronously after the native screen settles; poll until the
    // fixture heading is discoverable so assertions key on a rendered page.
    private static func waitForWebContent(simulatorUDID: String) async throws -> [UIElement] {
        var roots: [UIElement] = []
        for _ in 0..<20 {
            let result = try await TestHelpers.runAxeCommand(
                "describe-ui --include-web-content",
                simulatorUDID: simulatorUDID
            )
            roots = try UIStateParser.parseDescribeUIRoots(result.output)
            if UIStateParser.findElement(in: roots, matching: { $0.label == "AXE_WEB_HEADING" }) != nil {
                return roots
            }
            try await Task.sleep(nanoseconds: 500_000_000)
        }
        return roots
    }

    private static let webFixtureElements: [(String, String)] = [
        ("AXE_WEB_HEADING", "Heading"),
        ("AXE_WEB_LINK", "Link"),
        ("AXE_WEB_BUTTON", "Button"),
        ("AXE_WEB_FIELD", "TextField"),
    ]

    private static let webFixtureLabels: [String] = webFixtureElements.map(\.0)
}
