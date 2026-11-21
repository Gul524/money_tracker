import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:money_tracker/app/app_theme.dart';
import 'package:money_tracker/app/controllers/amount_calculator.dart';
import 'package:money_tracker/app/widgets/app_widgets.dart';

AmountCalculator _type(String keys, [String start = '']) {
  final calc = AmountCalculator(start);
  for (final k in keys.split(' ')) {
    switch (k) {
      case '+':
        calc.inputOperator(CalcOp.add);
      case '-':
        calc.inputOperator(CalcOp.subtract);
      case '*':
        calc.inputOperator(CalcOp.multiply);
      case '/':
        calc.inputOperator(CalcOp.divide);
      case '<':
        calc.backspace();
      case '=':
        calc.collapse();
      case '':
        break;
      default:
        for (final ch in k.split('')) {
          calc.inputDigit(ch);
        }
    }
  }
  return calc;
}

void main() {
  group('AmountCalculator', () {
    test('four operations with exact decimals', () {
      expect(_type('1200 + 350.5').resultMinor, 155050);
      expect(_type('1000 - 250.25').resultMinor, 74975);
      expect(_type('350 * 3').resultMinor, 105000);
      expect(_type('100 / 3').resultMinor, 3333);
      expect(_type('0.1 + 0.2').resultMinor, 30);
      expect(_type('100 / 3 * 3').resultMinor, 10000);
      expect(_type('2 / 3').resultMinor, 67); // half away from zero
    });

    test('multiply and divide before add and subtract', () {
      final calc = _type('1200 + 350 * 2');
      expect(calc.expression, '1,200 + 350 × 2');
      expect(calc.resultMinor, 190000);
      expect(_type('1000 - 600 / 2 + 5').resultMinor, 70500);
    });

    test(
      'starts from the field text and previews with a trailing operator',
      () {
        final calc = _type('+', '1250.5');
        expect(calc.expression, '1,250.5 +');
        expect(calc.hasOperation, isFalse);
        expect(calc.resultMinor, 125050);
        calc.inputDigit('5');
        expect(calc.hasOperation, isTrue);
        expect(calc.resultMinor, 125550);
      },
    );

    test('input rules', () {
      expect(_type('+ 5').expression, '5'); // no leading operator
      expect(_type('5 + * 2').expression, '5 × 2'); // operator replaced
      expect(_type('1.239').expression, '1.23'); // two decimals max
      expect(_type('1..5').expression, '1.5');
      expect(_type('.5').expression, '0.5');
      expect(_type('007').expression, '7');
      expect(_type('12 + 3 < <').expression, '12');
      expect(AmountCalculator('abc').isEmpty, isTrue);
      expect(AmountCalculator('').resultMinor, isNull);
    });

    test('division by zero and negative results', () {
      final calc = _type('5 / 0');
      expect(calc.resultMinor, isNull);
      expect(calc.problem, 'Can’t divide by 0');
      expect(_type('5 - 8').resultMinor, -300);
    });

    test('equals collapses to the result so you can continue', () {
      final calc = _type('100 / 8 =');
      expect(calc.expression, '12.5');
      calc.inputOperator(CalcOp.multiply);
      calc.inputDigit('2');
      expect(calc.resultMinor, 2500);
    });
  });

  testWidgets('calculator button fills the amount field', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final text = TextEditingController(text: '1200');
    addTearDown(text.dispose);
    String? changed;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: AmountField(
            controller: text,
            currency: 'PKR',
            onChanged: (v) => changed = v,
          ),
        ),
      ),
    );

    await tester.tap(find.text('Calculator'));
    await tester.pumpAndSettle();
    expect(find.text('1,200'), findsOneWidget);
    expect(find.text('Rs 1,200.00'), findsOneWidget);

    for (final key in ['Plus', '3', '5', '0', 'Multiply', '2']) {
      await tester.tap(find.bySemanticsLabel(key));
      await tester.pump();
    }
    expect(find.text('1,200 + 350 × 2'), findsOneWidget);
    expect(find.text('= Rs 1,900.00'), findsOneWidget);

    await tester.tap(find.text('Use Rs 1,900.00'));
    await tester.pumpAndSettle();
    expect(text.text, '1900');
    expect(changed, '1900');
  });
}
