import Testing

@testable import PlumageBarCore

@Suite("PlumageBarCore module")
struct PlumageBarCoreTests {

    @Test("Module exposes a non-empty semver-ish version string")
    func versionIsExposed() {
        let version = PlumageBarCore.version
        #expect(!version.isEmpty)
        #expect(version.contains("."))
    }
}
