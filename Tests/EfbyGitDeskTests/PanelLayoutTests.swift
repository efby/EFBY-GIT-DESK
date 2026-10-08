import AppKit
import SwiftUI
import Testing
import EfbyGitDeskApplication
import EfbyGitDeskInfrastructure
@testable import EfbyGitDeskPresentation

@MainActor struct PanelLayoutTests {
    @Test func nativePanelsKeepPreferredWidthAndHostedViewsAcrossWindowResize() async {
        let split = PersistentSplitContainer(frame: NSRect(x: 0, y: 0, width: 1000, height: 500))
        let history = NSView(), detail = NSView()
        split.addArrangedSubview(history); split.addArrangedSubview(detail)
        split.anchoredLeading = false; split.minimum = 340; split.maximum = .greatestFiniteMagnitude; split.otherMinimum = 370
        split.applyPreferredWidth()
        #expect(abs(detail.frame.width - 340) < 1)
        // The same native operation used by dragging the divider.
        split.setPosition(550, ofDividerAt: 0)
        split.rememberDividerWidth()
        let preferred = split.preferredWidth
        #expect(preferred > 340)
        split.setFrameSize(NSSize(width: 750, height: 650))
        split.applyPreferredWidth()
        #expect(detail.frame.width < preferred)
        #expect(split.preferredWidth == preferred)
        #expect(detail.frame.height == 650)
        split.setFrameSize(NSSize(width: 1200, height: 700))
        split.applyPreferredWidth()
        #expect(abs(detail.frame.width - preferred) < 1)
        #expect(split.arrangedSubviews[0] === history)
        #expect(split.arrangedSubviews[1] === detail)
    }
    @Test func sidebarStartsExpandedAndRetainsDraggedWidth() {
        let split = PersistentSplitContainer(frame: NSRect(x: 0, y: 0, width: 1200, height: 700))
        split.addArrangedSubview(NSView()); split.addArrangedSubview(NSView())
        split.otherMinimum = 710; split.applyPreferredWidth()
        #expect(abs(split.arrangedSubviews[0].frame.width - 340) < 1)
        split.setPosition(250, ofDividerAt: 0); split.rememberDividerWidth()
        split.setFrameSize(NSSize(width: 1400, height: 750)); split.applyPreferredWidth()
        #expect(abs(split.arrangedSubviews[0].frame.width - 250) < 1)
        #expect(split.preferredWidth == 250)
    }
    @Test func workspaceRestoresWidthsWithoutRecreatingPanels() async throws {
        let fixture = try await GitFixture.make(); defer { fixture.cleanup() }
        let registry = try SQLiteRegistry(path: fixture.folder.appendingPathComponent("workspace.sqlite").path)
        try await registry.save(fixture.repository)
        let service = DeskService(git: fixture.adapter, registry: registry, cloud: BitbucketClient(vault: KeychainVault()))
        let model = DeskModel(service: service, terminalFactory: { PTYTerminal(shell: "/bin/sh", login: false) })
        model.repositories = [fixture.repository]; model.selectedID = fixture.repository.id
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 1280, height: 800), styleMask: .borderless, backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false; defer { window.close() }
        window.appearance = NSAppearance(named: .darkAqua)
        let host = NSHostingView(rootView: WorkspaceView(model: model))
        host.sizingOptions = []; host.appearance = window.appearance; window.contentView = host
        func allSplits(_ view: NSView) -> [PersistentSplitContainer] {
            ((view as? PersistentSplitContainer).map { [$0] } ?? []) + view.subviews.flatMap { allSplits($0) }
        }
        let deadline = ContinuousClock.now.advanced(by: .seconds(20))
        while model.gitVersion.isEmpty || allSplits(host).count < 2 {
            guard ContinuousClock.now < deadline else { break }
            host.layoutSubtreeIfNeeded()
            try await Task.sleep(for: .milliseconds(50))
        }
        let panels = allSplits(host)
        #expect(panels.count == 2)
        let sidebar = try #require(panels.first { $0.anchoredLeading })
        let comparison = try #require(panels.first { !$0.anchoredLeading })
        let initial = ContinuousClock.now.advanced(by: .seconds(20))
        while abs(sidebar.arrangedSubviews[0].frame.width - 340) >= 1 || abs(comparison.arrangedSubviews[1].frame.width - 340) >= 1 {
            guard ContinuousClock.now < initial else { break }
            host.layoutSubtreeIfNeeded()
            try await Task.sleep(for: .milliseconds(50))
        }
        #expect(abs(sidebar.arrangedSubviews[0].frame.width - 340) < 1)
        #expect(abs(comparison.arrangedSubviews[1].frame.width - 340) < 1)
        model.sidebarWidth = 250; model.detailWidth = 430
        let resized = ContinuousClock.now.advanced(by: .seconds(20))
        while abs(sidebar.arrangedSubviews[0].frame.width - 250) >= 1 || abs(comparison.arrangedSubviews[1].frame.width - 430) >= 1 {
            guard ContinuousClock.now < resized else { break }
            host.layoutSubtreeIfNeeded()
            try await Task.sleep(for: .milliseconds(50))
        }
        #expect(allSplits(host).contains { $0 === sidebar })
        #expect(allSplits(host).contains { $0 === comparison })
        #expect(abs(sidebar.arrangedSubviews[0].frame.width - 250) < 1)
        #expect(abs(comparison.arrangedSubviews[1].frame.width - 430) < 1)
        if let path = ProcessInfo.processInfo.environment["EFBY_LAYOUT_PREVIEW_PATH"] {
            host.displayIfNeeded()
            let bitmap = try #require(host.bitmapImageRepForCachingDisplay(in: host.bounds))
            host.cacheDisplay(in: host.bounds, to: bitmap)
            try #require(bitmap.representation(using: .png, properties: [:])).write(to: URL(fileURLWithPath: path))
        }
    }
    @Test func panelPreferencesRestoreOnNextSessionAndRejectInvalidSizes() async throws {
        let fixture = try await GitFixture.make(); defer { fixture.cleanup() }
        let registry = try SQLiteRegistry(path: fixture.folder.appendingPathComponent("layout.sqlite").path)
        let service = DeskService(git: fixture.adapter, registry: registry, cloud: BitbucketClient(vault: KeychainVault()))
        func model() -> DeskModel { DeskModel(service: service, terminalFactory: { PTYTerminal(shell: "/bin/sh", login: false) }) }
        let first = model()
        #expect(first.detailWidth == 340 && first.sidebarWidth == 340)
        first.detailWidth = 520; first.sidebarWidth = 255; first.persistLayout()
        var persisted = false
        for _ in 0..<30 {
            if try await registry.preference("workspace.detailWidth") == "520.0",
               try await registry.preference("workspace.sidebarWidth") == "255.0" {
                persisted = true
                break
            }
            try await Task.sleep(for: .milliseconds(100))
        }
        #expect(persisted)
        let next = model(); await next.load()
        #expect(next.detailWidth == 520 && next.sidebarWidth == 255)
        #expect(next.error == nil)
        #expect(DeskModel.panelWidth("nan", default: 340, minimum: 210, maximum: 340) == 340)
        #expect(DeskModel.panelWidth("-5", default: 340, minimum: 340) == 340)
        #expect(DeskModel.panelWidth("999", default: 340, minimum: 210, maximum: 340) == 340)
    }
}
