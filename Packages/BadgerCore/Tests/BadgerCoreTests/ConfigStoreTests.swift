import Foundation
import Testing
@testable import BadgerCore

@MainActor
struct ConfigStoreTests {
    private func makeFolder() throws -> URL {
        let folder = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        return folder
    }

    private func wait(until condition: () -> Bool) async {
        let deadline = ContinuousClock.now + .seconds(1)
        while !condition(), ContinuousClock.now < deadline {
            try? await Task.sleep(for: .milliseconds(20))
        }
    }

    @Test func missingFileGetsTheDefaults() throws {
        let folder = try makeFolder()
        let file = folder.appending(path: "nested/config.json")
        var results: [Result<Config, ConfigError>] = []
        let store = ConfigStore(fileURL: file) { results.append($0) }
        store.start()
        defer { store.stop() }
        #expect(results == [.success(Config())])
        #expect(try Data(contentsOf: file) == ConfigCodec.encode(Config()))
    }

    @Test func handEditReachesTheModelInUnderASecond() async throws {
        let folder = try makeFolder()
        let file = folder.appending(path: "config.json")
        var latest: Result<Config, ConfigError>?
        let store = ConfigStore(fileURL: file) { latest = $0 }
        store.start()
        defer { store.stop() }

        try Data(#"{"version": 1, "badgeStyle": "iconOnly"}"#.utf8).write(to: file)
        await wait { latest == .success(Config(badgeStyle: .iconOnly)) }
        #expect(latest == .success(Config(badgeStyle: .iconOnly)))
    }

    @Test func badFileGivesAnErrorAndStaysUnchanged() async throws {
        let folder = try makeFolder()
        let file = folder.appending(path: "config.json")
        var latest: Result<Config, ConfigError>?
        let store = ConfigStore(fileURL: file) { latest = $0 }
        store.start()
        defer { store.stop() }

        let bad = Data("{ nope".utf8)
        try bad.write(to: file)
        await wait { if case .failure = latest { true } else { false } }
        guard case .failure(.invalidJSON) = latest else {
            Issue.record("expected an invalidJSON error")
            return
        }
        #expect(throws: ConfigStore.WriteError.blockedByConfigError) { try store.save(Config()) }
        #expect(try Data(contentsOf: file) == bad)
    }

    @Test func identicalSaveDoesNotWriteAgain() throws {
        let folder = try makeFolder()
        let store = ConfigStore(fileURL: folder.appending(path: "config.json")) { _ in }
        store.start()
        defer { store.stop() }

        let changed = Config(badgeStyle: .number)
        #expect(try store.save(changed))
        #expect(try store.save(changed) == false)
    }
}
