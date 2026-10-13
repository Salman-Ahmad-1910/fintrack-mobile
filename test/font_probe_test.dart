import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('Inter loads and has different metrics than the fallback font', () async {
    final loader = FontLoader('Inter');
    for (final path in [
      'assets/fonts/Inter-Regular.ttf',
      'assets/fonts/Inter-Medium.ttf',
      'assets/fonts/Inter-SemiBold.ttf',
      'assets/fonts/Inter-Bold.ttf',
    ]) {
      final bytes = await File(path).readAsBytes();
      loader.addFont(Future<ByteData>.value(ByteData.view(bytes.buffer)));
    }
    await loader.load();

    double widthOf(String family) {
      final painter = TextPainter(
        text: TextSpan(
          text: 'Fintrack ERP',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, fontFamily: family),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      return painter.width;
    }

    final inter = widthOf('Inter');
    final fallback = widthOf('NoSuchFamily');
    // ignore: avoid_print
    print('Inter width=$inter fallback width=$fallback');
    expect(inter, isNot(equals(fallback)));
  });
}
