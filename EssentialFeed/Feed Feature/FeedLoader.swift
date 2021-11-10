import Foundation

public protocol FeedLoader {
    associatedtype Error: Swift.Error
    func load(completion: @escaping (Result<[FeedItem], Error>) -> Void)
}
