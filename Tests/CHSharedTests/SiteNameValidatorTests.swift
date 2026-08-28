import XCTest

@testable import CHShared

final class SiteNameValidatorTests: XCTestCase {
  func testValidateTrimsSurroundingWhitespace() throws {
    XCTAssertEqual(
      try SiteNameValidator.validate("  ○○道路改良工事　"),
      "○○道路改良工事"
    )
  }

  func testValidateRejectsEmptyNameAfterTrimming() {
    XCTAssertThrowsError(try SiteNameValidator.validate(" 　 ")) { error in
      XCTAssertEqual(error as? SiteNameValidationError, .empty)
    }
  }

  func testValidateRejectsNewlinesIncludingAtEdges() {
    for input in ["工事\n名称", "\n工事名称", "工事名称\r"] {
      XCTAssertThrowsError(try SiteNameValidator.validate(input)) { error in
        XCTAssertEqual(
          error as? SiteNameValidationError,
          .containsNewline
        )
      }
    }
  }

  func testValidateAcceptsExactlyEightyCharacters() throws {
    let input = String(repeating: "工", count: 80)
    XCTAssertEqual(try SiteNameValidator.validate(input), input)
  }

  func testValidateRejectsMoreThanEightyCharacters() {
    let input = String(repeating: "工", count: 81)

    XCTAssertThrowsError(try SiteNameValidator.validate(input)) { error in
      XCTAssertEqual(
        error as? SiteNameValidationError,
        .tooLong(maximum: 80)
      )
    }
  }

  func testIsValidUsesTheSameRules() {
    XCTAssertTrue(SiteNameValidator.isValid("工事名称"))
    XCTAssertFalse(SiteNameValidator.isValid("工事\n名称"))
  }
}
