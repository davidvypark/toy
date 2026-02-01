//
//  TOYSharedTests.swift
//  TOYSharedTests
//
//  Tests for the TOYShared package.
//

import Testing
@testable import TOYShared

@Test func testVersion() async throws {
    #expect(TOYShared.version == "1.0.0")
}
