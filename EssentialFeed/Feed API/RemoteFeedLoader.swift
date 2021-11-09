import Foundation

public final class RemoteFeedLoader {
    private let url: URL
    private let client: HTTPClient

    public enum Error: Swift.Error {
        case conectivity
        case invalidData
    }

    public init(url: URL, client: HTTPClient) {
        self.url = url
        self.client = client
    }

    public func load(completion: @escaping (Result<[FeedItem], Error>) -> Void) {
        client.get(from: url) { [weak self] result in
            guard let self = self else {
                return
            }
            switch result {
            case let .success((data, response)):
                completion(self.map(data, from: response))
            case .failure:
                completion(.failure(.conectivity))
            }
        }
    }

    private func map(_ data: Data, from response: HTTPURLResponse) -> Result<[FeedItem], Error> {
        do {
            let items = try FeedItemsMapper.map(data, response)
            return .success(items)
        } catch {
            return .failure(.invalidData)
        }
    }
}
