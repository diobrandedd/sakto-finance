import 'package:flutter_test/flutter_test.dart';
import 'package:sakto/app.dart';

void main() {
  test('formats Philippine peso amounts', () {
    expect(money.format(1234.5), contains('1,234.50'));
  });
}
