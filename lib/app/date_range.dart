import 'formatters.dart';

/// Period choices shared by Reports and Export.
enum ReportPeriod { month, sixMonths, year, custom }

/// A period `start <= date < end`, always on whole days.
class DateRange {
  const DateRange(this.start, this.end);

  /// The calendar month containing [date].
  factory DateRange.month(DateTime date) => DateRange(
    DateTime(date.year, date.month),
    DateTime(date.year, date.month + 1),
  );

  /// The [count] calendar months ending with the month containing [date].
  factory DateRange.months(DateTime date, int count) => DateRange(
    DateTime(date.year, date.month - count + 1),
    DateTime(date.year, date.month + 1),
  );

  factory DateRange.year(int year) =>
      DateRange(DateTime(year), DateTime(year + 1));

  /// From [first] to [last], both days included.
  factory DateRange.days(DateTime first, DateTime last) => DateRange(
    DateTime(first.year, first.month, first.day),
    DateTime(last.year, last.month, last.day + 1),
  );

  final DateTime start;
  final DateTime end;

  /// The [period] containing [today]; null for [ReportPeriod.custom].
  static DateRange? current(ReportPeriod period, DateTime today) =>
      switch (period) {
        ReportPeriod.month => DateRange.month(today),
        ReportPeriod.sixMonths => DateRange.months(today, 6),
        ReportPeriod.year => DateRange.year(today.year),
        ReportPeriod.custom => null,
      };

  /// The previous (−1) or next (+1) period of the same length.
  DateRange step(ReportPeriod period, int direction) => switch (period) {
    ReportPeriod.month => DateRange.month(
      DateTime(start.year, start.month + direction),
    ),
    ReportPeriod.sixMonths => DateRange(
      DateTime(start.year, start.month + 6 * direction),
      DateTime(end.year, end.month + 6 * direction),
    ),
    ReportPeriod.year => DateRange.year(start.year + direction),
    ReportPeriod.custom => this,
  };

  /// Whether a next period exists that has already started.
  bool canStepForward(ReportPeriod period, DateTime today) =>
      period != ReportPeriod.custom && !step(period, 1).start.isAfter(today);

  /// The last day included in the range.
  DateTime get lastDay => DateTime(end.year, end.month, end.day - 1);

  bool contains(DateTime date) => !date.isBefore(start) && date.isBefore(end);

  String get label => formatRange(start, end);

  @override
  bool operator ==(Object other) =>
      other is DateRange && other.start == start && other.end == end;

  @override
  int get hashCode => Object.hash(start, end);
}
