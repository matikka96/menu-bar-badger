import BadgerCore
import Observation

@Observable
final class AppModel {
    private(set) var config = Config()
    private(set) var configError: ConfigError?

    func apply(_ result: Result<Config, ConfigError>) {
        switch result {
        case .success(let config):
            self.config = config
            configError = nil
        case .failure(let error):
            configError = error
        }
    }
}
