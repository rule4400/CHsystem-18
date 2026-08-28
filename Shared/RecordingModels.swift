import Foundation

/// A known period for which a recording has no video data.
public struct RecordingGap: Identifiable, Codable, Equatable, Sendable {
  public let id: UUID
  public let startedAt: Date
  public let endedAt: Date
  public let reason: String?

  public init(
    id: UUID = UUID(),
    startedAt: Date,
    endedAt: Date,
    reason: String? = nil
  ) {
    self.id = id
    self.startedAt = startedAt
    self.endedAt = endedAt
    self.reason = reason
  }

  /// The non-negative duration represented by this gap before clipping or
  /// overlap removal.
  public var duration: TimeInterval {
    max(0, endedAt.timeIntervalSince(startedAt))
  }
}

/// A logical site recording, which may consist of multiple media files.
public struct RecordingItem: Identifiable, Codable, Equatable, Sendable {
  public let id: UUID
  public let siteID: UUID
  public let siteName: String
  public let startedAt: Date
  public let endedAt: Date?
  public let gaps: [RecordingGap]
  public let expiresAt: Date?

  public init(
    id: UUID,
    siteID: UUID,
    siteName: String,
    startedAt: Date,
    endedAt: Date? = nil,
    gaps: [RecordingGap] = [],
    expiresAt: Date? = nil
  ) {
    self.id = id
    self.siteID = siteID
    self.siteName = siteName
    self.startedAt = startedAt
    self.endedAt = endedAt
    self.gaps = gaps
    self.expiresAt = expiresAt
  }
}

/// Calculated availability for a recording interval.
public struct RecordingCoverage: Equatable, Sendable {
  public let totalDuration: TimeInterval
  public let gapDuration: TimeInterval
  public let recordedDuration: TimeInterval

  /// A value from zero through one. A zero-length or invalid interval has a
  /// ratio of zero because it contains no recorded media.
  public let ratio: Double

  public init(
    totalDuration: TimeInterval,
    gapDuration: TimeInterval,
    recordedDuration: TimeInterval,
    ratio: Double
  ) {
    self.totalDuration = totalDuration
    self.gapDuration = gapDuration
    self.recordedDuration = recordedDuration
    self.ratio = ratio
  }

  public var percentage: Double {
    ratio * 100
  }
}

/// Deterministic calculations for gap duration and recording coverage.
///
/// Overlapping gaps are merged, gaps are clipped to the requested recording
/// interval, and invalid reversed gaps are ignored.
public enum RecordingCalculations {
  public static func gapDuration(
    from recordingStart: Date,
    to recordingEnd: Date,
    gaps: [RecordingGap]
  ) -> TimeInterval {
    guard recordingEnd > recordingStart else { return 0 }

    let clippedIntervals = gaps.compactMap { gap -> (start: Date, end: Date)? in
      guard gap.endedAt > gap.startedAt else { return nil }

      let start = max(gap.startedAt, recordingStart)
      let end = min(gap.endedAt, recordingEnd)
      guard end > start else { return nil }
      return (start, end)
    }
    .sorted { lhs, rhs in
      if lhs.start == rhs.start {
        return lhs.end < rhs.end
      }
      return lhs.start < rhs.start
    }

    guard var current = clippedIntervals.first else { return 0 }
    var total: TimeInterval = 0

    for interval in clippedIntervals.dropFirst() {
      if interval.start <= current.end {
        current.end = max(current.end, interval.end)
      } else {
        total += current.end.timeIntervalSince(current.start)
        current = interval
      }
    }

    total += current.end.timeIntervalSince(current.start)
    return total
  }

  public static func coverage(
    from recordingStart: Date,
    to recordingEnd: Date,
    gaps: [RecordingGap]
  ) -> RecordingCoverage {
    let totalDuration = max(
      0,
      recordingEnd.timeIntervalSince(recordingStart)
    )

    guard totalDuration > 0 else {
      return RecordingCoverage(
        totalDuration: 0,
        gapDuration: 0,
        recordedDuration: 0,
        ratio: 0
      )
    }

    let gapDuration = min(
      totalDuration,
      gapDuration(
        from: recordingStart,
        to: recordingEnd,
        gaps: gaps
      )
    )
    let recordedDuration = totalDuration - gapDuration

    return RecordingCoverage(
      totalDuration: totalDuration,
      gapDuration: gapDuration,
      recordedDuration: recordedDuration,
      ratio: recordedDuration / totalDuration
    )
  }

  /// Calculates coverage for either a completed or ongoing item. For an
  /// ongoing item, `evaluationDate` is the caller's explicit snapshot time.
  /// A completed item's own end date always wins over a later evaluation.
  public static func coverage(
    for recording: RecordingItem,
    through evaluationDate: Date
  ) -> RecordingCoverage {
    coverage(
      from: recording.startedAt,
      to: recording.endedAt ?? evaluationDate,
      gaps: recording.gaps
    )
  }
}
