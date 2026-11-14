import 'package:flutter_test/flutter_test.dart';
import 'package:money_tracker/app/formatters.dart';

void main() {
  test('money groups thousands and uses currency symbols', () {
    expect(money(0, 'PKR'), 'Rs 0.00');
    expect(money(123456789, 'PKR'), 'Rs 1,234,567.89');
    expect(money(-50000, 'PKR'), '−Rs 500.00');
    expect(money(100000, 'USD'), r'$1,000.00');
    expect(money(2500, 'GBP', signed: true), '+£25.00');
    expect(money(-2500, 'EUR', signed: true), '−€25.00');
    expect(money(100, 'XYZ'), 'XYZ 1.00');
  });

  test('amountInputText produces editable amounts', () {
    expect(amountInputText(120000), '1200');
    expect(amountInputText(125050), '1250.5');
    expect(amountInputText(125005), '1250.05');
  });

  test('dates read naturally', () {
    final now = DateTime(2026, 11, 15, 10);
    expect(relativeDay(DateTime(2026, 11, 15, 23), now: now), 'Today');
    expect(relativeDay(DateTime(2026, 11, 14), now: now), 'Yesterday');
    expect(relativeDay(DateTime(2026, 11, 10), now: now), 'Tue, 10 Nov');
    expect(relativeDay(DateTime(2025, 3, 2), now: now), '2 Mar 2025');
    expect(formatDate(DateTime(2026, 1, 5)), '5 Jan 2026');
    expect(formatMonthYear(DateTime(2026, 11)), 'November 2026');
    expect(formatLongDate(DateTime(2026, 11, 15)), 'Sunday, 15 November');
  });
}
