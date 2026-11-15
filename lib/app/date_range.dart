import 'formatters.dart';

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
