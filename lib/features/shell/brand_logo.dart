import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';

/// The emerald gradient square + dollar mark used in both the web header and
/// sidebar (`from-emerald-500 to-green-600`).
class BrandLogo extends StatelessWidget {
  const BrandLogo({super.key, this.size = 36});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.emerald500, AppColors.green600],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(size * 0.27),
        boxShadow: const [
          BoxShadow(
            color: Color(0x4010B981),
            blurRadius: 6,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Icon(
        Icons.monetization_on_outlined,
        size: size * 0.55,
        color: Colors.white,
      ),
    );
  }
}
