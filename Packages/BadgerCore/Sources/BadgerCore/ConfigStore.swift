import Foundation

@MainActor
public final class ConfigStore {
    public enum WriteError: Error, Equatable {
        case blockedByConfigError
    }

    public static let settleDelay: Duration = .milliseconds(300)

    private let fileURL: URL
    private let onChange: @MainActor (Result<Config, ConfigError>) -> Void
    private var folderSource: DispatchSourceFileSystemObject?
    private var fileSource: DispatchSourceFileSystemObject?
    private var settleTask: Task<Void, Never>?
    private var lastContent: Data?
    private var isInErrorState = false
    private var hasReported = false

    public init(fileURL: URL, onChange: @escaping @MainActor (Result<Config, ConfigError>) -> Void) {
        self.fileURL = fileURL
        self.onChange = onChange
    }

    public func start() {
        let fileManager = FileManager.default
        try? fileManager.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        if !fileManager.fileExists(atPath: fileURL.path) {
            try? write(Config())
        }
        watchFolder()
        reload()
    }

    public func stop() {
        settleTask?.cancel()
        folderSource?.cancel()
        fileSource?.cancel()
        folderSource = nil
        fileSource = nil
    }

    public func reload() {
        let result = read()
        let content: Data?
        switch result {
        case .success(let value): content = value.content
        case .failure(let failure): content = failure.content
        }
        watchFile()
        if hasReported, content == lastContent, isInErrorState == result.isFailure { return }
        hasReported = true
        lastContent = content
        isInErrorState = result.isFailure
        onChange(result.map(\.config).mapError(\.error))
    }

    @discardableResult
    public func save(_ config: Config) throws -> Bool {
        guard !isInErrorState else { throw WriteError.blockedByConfigError }
        return try write(config)
    }

    @discardableResult
    private func write(_ config: Config) throws -> Bool {
        let data = ConfigCodec.encode(config)
        if data == lastContent { return false }
        try data.write(to: fileURL, options: .atomic)
        lastContent = data
        return true
    }

    private struct Loaded {
        var config: Config
        var content: Data
    }

    private struct Failed: Error {
        var error: ConfigError
        var content: Data?
    }

    private func read() -> Result<Loaded, Failed> {
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            return .failure(Failed(error: .missing, content: nil))
        }
        let data: Data
        do {
            data = try Data(contentsOf: fileURL)
        } catch {
            return .failure(Failed(error: .unreadable(error.localizedDescription), content: nil))
        }
        do {
            return .success(Loaded(config: try ConfigCodec.decode(data), content: data))
        } catch {
            return .failure(Failed(error: error, content: data))
        }
    }

    private func watchFolder() {
        folderSource = makeSource(path: fileURL.deletingLastPathComponent().path, events: [.write, .rename, .delete])
    }

    private func watchFile() {
        fileSource?.cancel()
        fileSource = makeSource(path: fileURL.path, events: [.write, .extend, .rename, .delete])
    }

    private func makeSource(path: String, events: DispatchSource.FileSystemEvent) -> DispatchSourceFileSystemObject? {
        let descriptor = open(path, O_EVTONLY)
        guard descriptor >= 0 else { return nil }
        let source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: descriptor, eventMask: events, queue: .main
        )
        source.setEventHandler { [weak self] in
            MainActor.assumeIsolated { self?.scheduleReload() }
        }
        source.setCancelHandler { close(descriptor) }
        source.resume()
        return source
    }

    private func scheduleReload() {
        settleTask?.cancel()
        settleTask = Task { [weak self] in
            try? await Task.sleep(for: Self.settleDelay)
            guard !Task.isCancelled else { return }
            self?.reload()
        }
    }
}

private extension Result {
    var isFailure: Bool {
        if case .failure = self { return true }
        return false
    }
}
