import Foundation
import Testing
import EfbyGitDeskDomain
import EfbyGitDeskInfrastructure

@Suite(.serialized) struct BitbucketTests {
    private func client(mode: String) -> BitbucketClient {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [CatalogProtocol.self]
        configuration.httpAdditionalHeaders = ["X-Fixture": mode]
        return BitbucketClient(vault: KeychainVault(), configuration: configuration, tokenLoader: { _ in Data("fixture".utf8) }, retryWait: { _ in })
    }
    @Test func catalogUsesWorkspaceRepositoriesAndFollowsPages() async throws {
        let profile = ConnectionProfile(id: "fixture", email: "fixture@example.invalid")
        let repositories = try await client(mode: "pages").repositories(profile: profile)
        #expect(repositories.map(\.fullName) == ["demo/one", "demo/two"])
        #expect(repositories[0].httpsURL == "https://bitbucket.org/demo/one.git")
    }
    @Test func catalogRejectsExternalPaginationWithoutContactingIt() async {
        let profile = ConnectionProfile(id: "fixture", email: "fixture@example.invalid")
        await #expect(throws: DeskError.self) { try await client(mode: "external").repositories(profile: profile) }
    }
    @Test func catalogReportsAuthenticationAndRateLimitFailures() async {
        let profile = ConnectionProfile(id: "fixture", email: "fixture@example.invalid")
        for mode in ["401", "403", "429"] {
            await #expect(throws: DeskError.self) { try await client(mode: mode).repositories(profile: profile) }
        }
    }
}

// Immutable instance request data; no shared mutable fixtures or credentials.
private final class CatalogProtocol: URLProtocol, @unchecked Sendable {
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        guard let url = request.url, url.host == "api.bitbucket.org", request.value(forHTTPHeaderField: "Authorization") != nil else {
            client?.urlProtocol(self, didFailWithError: DeskError("A request escaped the fixture API origin.")); return
        }
        let mode = request.value(forHTTPHeaderField: "X-Fixture") ?? "pages"
        let status = Int(mode) ?? 200
        let response = HTTPURLResponse(url: url, statusCode: status, httpVersion: "HTTP/1.1", headerFields: ["Content-Type": "application/json"])!
        let body: String
        if mode == "external" {
            body = #"{"values": [], "next": "https://other.example.invalid/steal"}"#
        } else if url.path == "/2.0/user/workspaces" {
            body = #"{"values": [{"workspace": {"slug": "demo"}}]}"#
        } else if url.path == "/2.0/repositories/demo" && url.query?.contains("page=2") == true {
            body = #"{"values": [{"uuid": "two", "name": "two", "full_name": "demo/two"}]}"#
        } else if url.path == "/2.0/repositories/demo" {
            body = #"{"values": [{"uuid": "one", "name": "one", "full_name": "demo/one"}], "next": "https://api.bitbucket.org/2.0/repositories/demo?page=2"}"#
        } else {
            client?.urlProtocol(self, didFailWithError: DeskError("Unexpected catalog endpoint.")); return
        }
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: Data(body.utf8))
        client?.urlProtocolDidFinishLoading(self)
    }
    override func stopLoading() {}
}
