import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('fonts provided by flutter_test_config are active', () {
    double widthOf(String family) {
      final painter = TextPainter(
        text: TextSpan(
          text: 'Forgot password?',
          style: TextStyle(fontSize: 14, fontFamily: family),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      return painter.width;
    }

    // ignore: avoid_print
    print('Inter=${widthOf('Inter')} fallback=${widthOf('NoSuchFamily')}');
    expect(widthOf('Inter'), isNot(equals(widthOf('NoSuchFamily'))));
  });
}
