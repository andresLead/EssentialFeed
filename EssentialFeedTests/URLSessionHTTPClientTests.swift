import Foundation
import EssentialFeed
import XCTest

final class URLSessionHTTPClient {
    let session: URLSession

    init(session: URLSession = .shared) {
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

    func test_getFromURL_failsOnRequestError() {
        URLProtocolStub.startInterceptingRequests()
        let url = URL(string: "https://a-url.com")!
        let error = NSError(domain: "an error", code: 1)
        URLProtocolStub.stub(url: url, data: nil, response: nil, error: error)

        let sut = URLSessionHTTPClient()

        let expectation = expectation(description: "Wait for completion")
        sut.get(from: url) { result in
            switch result {
            case .failure(let err as NSError):
                XCTAssertEqual(error.domain, err.domain)
                XCTAssertEqual(error.code, err.code)
            default:
                XCTFail("Expected failure with error \(error), got \(result) instead.")
            }
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 1.0)
        URLProtocolStub.stopInterceptingRequests()
    }

    // MARK: helpers
    private final class URLProtocolStub: URLProtocol {
        private static var stubs = [URL: Stub]()

        private struct Stub {
            let data: Data?
            let response: URLResponse?
            let error: Error?
        }

        static func stub(url: URL, data: Data?, response: URLResponse?, error: Error?) {
            stubs[url] = Stub(data: data, response: response, error: error)
        }

        static func startInterceptingRequests() {
            URLProtocol.registerClass(self)
        }

        static func stopInterceptingRequests() {
            URLProtocol.unregisterClass(self)
            stubs = [:]
        }

        override class func canInit(with request: URLRequest) -> Bool {
            guard let url = request.url else { return false }
            return stubs[url] != nil
        }

        override class func canonicalRequest(for request: URLRequest) -> URLRequest {
            return request
        }

        override func startLoading() {
            guard let url = request.url,
                  let stub = URLProtocolStub.stubs[url] else {
                      return
                  }

            if let data = stub.data {
                client?.urlProtocol(self, didLoad: data)
            }

            if let response = stub.response {
                client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            }

            if let error = stub.error {
                client?.urlProtocol(self, didFailWithError: error)
            }

            client?.urlProtocolDidFinishLoading(self)
        }

        override func stopLoading() {
        }
    }
}
