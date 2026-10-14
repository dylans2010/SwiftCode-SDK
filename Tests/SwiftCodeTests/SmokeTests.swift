import Testing
@testable import SwiftCode
@Test func smokeTest() { #expect(SDKVersion.current.description == "1.0.0") }
