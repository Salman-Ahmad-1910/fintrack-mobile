import 'package:flutter/material.dart';

/// Tailwind's default palette, used verbatim by the web client's marketing,
/// login and signup pages. Kept in one place so the Flutter screens can quote
/// the exact same hex values as the `className`s in
/// `client/src/app/{page,login,signup}/page.tsx`.
class Tw {
  Tw._();

  // gray
  static const Color gray50 = Color(0xFFF9FAFB);
  static const Color gray100 = Color(0xFFF3F4F6);
  static const Color gray200 = Color(0xFFE5E7EB);
  static const Color gray300 = Color(0xFFD1D5DB);
  static const Color gray400 = Color(0xFF9CA3AF);
  static const Color gray500 = Color(0xFF6B7280);
  static const Color gray600 = Color(0xFF4B5563);
  static const Color gray700 = Color(0xFF374151);
  static const Color gray800 = Color(0xFF1F2937);
  static const Color gray900 = Color(0xFF111827);

  // slate (hero copy)
  static const Color slate200 = Color(0xFFE2E8F0);
  static const Color slate300 = Color(0xFFCBD5E1);

  // headings on the light sections
  static const Color navy900 = Color(0xFF0F172A);

  // landing / auth dark surfaces
  static const Color nightHero = Color(0xFF04070F); // bg-[#04070F]
  static const Color cyan100 = Color(0xFFCFFAFE);

  // gradient stops used by the hero headline + feature icon tiles
  static const Color cyan300 = Color(0xFF67E8F9);
  static const Color sky300 = Color(0xFF7DD3FC);
  static const Color indigo300 = Color(0xFFA5B4FC);
  static const Color cyan50 = Color(0xFFECFEFF);
  static const Color cyan400 = Color(0xFF22D3EE);
  static const Color cyan600 = Color(0xFF0891B2);
  static const Color blue600 = Color(0xFF2563EB);
  static const Color indigo500 = Color(0xFF6366F1);

  // status colours used by the message dialog
  static const Color red500 = Color(0xFFEF4444);
  static const Color red600 = Color(0xFFDC2626);
  static const Color emerald500 = Color(0xFF10B981);
  static const Color emerald600 = Color(0xFF059669);
  static const Color green400 = Color(0xFF4ADE80);
}
