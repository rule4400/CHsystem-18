import Foundation

public enum SiteNameValidationError: Error, Equatable, Sendable {
  case empty
  case containsNewline
  case tooLong(maximum: Int)
}

extension SiteNameValidationError: LocalizedError {
  public var errorDescription: String? {
    switch self {
    case .empty:
      "工事名称を入力してください。"
    case .containsNewline:
      "工事名称に改行は使用できません。"
    case .tooLong(let maximum):
      "工事名称は\(maximum)文字以内で入力してください。"
    }
  }
}

/// Normalizes and validates a site name entered on an iPhone.
public enum SiteNameValidator {
  public static let maximumLength = 80

  /// Returns a trimmed valid name or throws a localized validation error.
  public static func validate(_ input: String) throws -> String {
    if input.rangeOfCharacter(from: .newlines) != nil {
      throw SiteNameValidationError.containsNewline
    }

    let trimmed = input.trimmingCharacters(in: .whitespaces)
    guard !trimmed.isEmpty else {
      throw SiteNameValidationError.empty
    }
    guard trimmed.count <= maximumLength else {
      throw SiteNameValidationError.tooLong(maximum: maximumLength)
    }
    return trimmed
  }

  public static func isValid(_ input: String) -> Bool {
    (try? validate(input)) != nil
  }
}
