import Foundation
import EssentialFeed
import XCTest

final class URLSessionHTTPClient {
    let session: URLSession

    init(session: URLSession) {
        self.session = session
    }

    func get(from url: URL, completion: @escaping (Result<[FeedItem], Error>) -> Void) {
        session.dataTask(with: url) { _, _, error in
            if let error = error {
                completion(.failure(error))
            }
        }
        .resume()
    }
}

final class URLSessionHTTPClientTests: XCTestCase {

    func test_getFromURL_resumesDataTaskWithURL() {
        let url = URL(string: "https://a-url.com")!
        let session = URLSessionSpy()
        let dataTask = URLSessionDataTaskSpy()
        session.stub(url: url, dataTask: dataTask)
        let sut = URLSessionHTTPClient(session: session)

        sut.get(from: url) { _ in }

        XCTAssertEqual(dataTask.resumeCallCount, 1)
    }

    func test_getFromURL_failsOnRequestError() {
        let url = URL(string: "https://a-url.com")!
        let error = NSError(domain: "an error", code: 1)
        let session = URLSessionSpy()
        session.stub(url: url, error: error)

        let sut = URLSessionHTTPClient(session: session)

        let expectation = expectation(description: "Wait for completion")
        sut.get(from: url) { result in
            switch result {
            case .failure(let err as NSError):
                XCTAssertEqual(error, err)
            default:
                XCTFail("Expected failure with error \(error), got \(result) instead.")
            }
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 1.0)
    }

    private final class URLSessionSpy: URLSession {
        private var stubs = [URL: Stub]()

        private struct Stub {
            let dataTask: URLSessionDataTask
            var error: Error?
        }

        func stub(url: URL, dataTask: URLSessionDataTask = FakeURLSessionDataTask(), error: Error? = nil) {
            stubs[url] = Stub(dataTask: dataTask, error: error)
        }

        override func dataTask(with url: URL, completionHandler: @escaping (Data?, URLResponse?, Error?) -> Void) -> URLSessionDataTask {
            guard let stub = stubs[url] else {
                fatalError("couldn't find a stub for the url: \(url)")
            }
            completionHandler(nil, nil, stub.error)
            return stub.dataTask
        }
    }

    private final class FakeURLSessionDataTask: URLSessionDataTask {
        override func resume() {}
    }
    private final class URLSessionDataTaskSpy: URLSessionDataTask {
        var resumeCallCount = 0

        override func resume() {
            resumeCallCount += 1
        }
    }
}
