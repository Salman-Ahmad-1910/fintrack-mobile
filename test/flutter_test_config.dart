import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Golden tests render with a bitmap test font (every glyph is a box) unless
/// the real family is loaded first, so fonts declared in `pubspec.yaml` are
/// registered here for every test in this directory.
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  await _loadInter();
  return testMain();
}

Future<void> _loadInter() async {
  const paths = [
    'assets/fonts/Inter-Regular.ttf',
    'assets/fonts/Inter-Medium.ttf',
    'assets/fonts/Inter-SemiBold.ttf',
    'assets/fonts/Inter-Bold.ttf',
  ];

  final loader = FontLoader('Inter');
  for (final path in paths) {
    final bytes = await File(path).readAsBytes();
    loader.addFont(Future<ByteData>.value(ByteData.view(bytes.buffer)));
  }
  await loader.load();
}
