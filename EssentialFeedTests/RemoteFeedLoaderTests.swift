import Foundation
import XCTest
import EssentialFeed

final class HTTPClientSpy: HTTPClient {
    var messages = [(url: URL,
                     completion: (Result<HTTPURLResponse, Error>) -> Void)]()

    var requestedURLs: [URL] {
        messages.map { $0.url }
    }

    func get(from url: URL,
             completion: @escaping (Result<HTTPURLResponse, Error>) -> Void) {
        messages.append((url, completion))
    }

    func complete(with error: Error, at index: Int = 0) {
        messages[index].completion(.failure(error))
    }

    func complete(withStatusCode statusCode: Int, at index: Int = 0) {
        let httpResponse = HTTPURLResponse(url: requestedURLs[index], statusCode: statusCode, httpVersion: nil, headerFields: nil)!
        messages[index].completion(.success(httpResponse))
    }
}

final class RemoteFeedLoaderTests: XCTestCase {
    func test_init_doesNotRequestDataFromURL() {
        let (_, client) = makeSUT()

        XCTAssertTrue(client.requestedURLs.isEmpty)
    }

    func test_load_requestsDataFromURL() {
        let url = URL(string: "https://given-a-url.com")!
        let (sut, client) = makeSUT(url: url)

        sut.load { _ in }

        XCTAssertEqual(client.requestedURLs, [url])
    }

    func test_load_requestsDataFromURLTwice() {
        let url = URL(string: "https://given-a-url.com")!
        let (sut, client) = makeSUT(url: url)

        sut.load { _ in }
        sut.load { _ in }

        XCTAssertEqual(client.requestedURLs, [url, url])
    }

    func test_load_deliversErrorOnClientError() {
        let (sut, client) = makeSUT()
        let clientError = NSError(domain: "RemoteLoader", code: 0)

        var capturedError = [RemoteFeedLoader.Error]()
        sut.load { error in capturedError.append(error) }
        client.complete(with: clientError)

        XCTAssertEqual(capturedError, [.connectivity])
    }

    func test_load_deliversErrorOnNon200HttpResponse() {
        let (sut, client) = makeSUT()

        let samples = [199, 201, 300, 400, 500]
        samples.enumerated().forEach { index, code in
            var capturedError = [RemoteFeedLoader.Error]()
            sut.load { error in capturedError.append(error) }
            client.complete(withStatusCode: code, at: index)

            XCTAssertEqual(capturedError, [.invalidData])
        }
    }

    // MARK: Helpers
    private func makeSUT(url: URL = URL(string: "https://an-url.com")!) -> (sut: RemoteFeedLoader, client: HTTPClientSpy) {
        let client = HTTPClientSpy()
        let sut = RemoteFeedLoader(url: url, client: client)
        return (sut, client)
    }
}
