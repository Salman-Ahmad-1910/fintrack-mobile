import 'dart:ui';

import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';
import '../../theme/tailwind.dart';

/// Port of `client/src/app/page.tsx` — the marketing page a visitor sees
/// before login/signup.
class LandingScreen extends StatefulWidget {
  const LandingScreen({super.key});

  static const routeName = '/landing';

  @override
  State<LandingScreen> createState() => _LandingScreenState();
}

class _LandingScreenState extends State<LandingScreen>
    with SingleTickerProviderStateMixin {
  // Tailwind's `animate-pulse`: 2s ease-in-out, opacity 1 -> 0.5.
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2000),
  )..repeat(reverse: true);

  final _featuresKey = GlobalKey();
  final _aboutKey = GlobalKey();
  final _contactKey = GlobalKey();

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  void _scrollTo(GlobalKey key) {
    final ctx = key.currentContext;
    if (ctx == null) return;
    Scrollable.ensureVisible(
      ctx,
      duration: const Duration(milliseconds: 450),
      curve: Curves.easeOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          _LandingHeader(
            onFeatures: () => _scrollTo(_featuresKey),
            onAbout: () => _scrollTo(_aboutKey),
            onContact: () => _scrollTo(_contactKey),
          ),
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  _HeroSection(pulse: _pulse),
                  _FeaturesSection(key: _featuresKey),
                  _RolesSection(),
                  _AboutSection(key: _aboutKey),
                  _CtaSection(),
                  _LandingFooter(key: _contactKey),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Tailwind's responsive `.container` max-widths.
double _containerMax(double width) {
  if (width >= 1536) return 1536;
  if (width >= 1280) return 1280;
  if (width >= 1024) return 1024;
  if (width >= 768) return 768;
  if (width >= 640) return 640;
  return width;
}

/// `container mx-auto px-4 md:px-6`
class _Container extends StatelessWidget {
  const _Container({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: _containerMax(width)),
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: width >= 768 ? 24 : 16),
          child: child,
        ),
      ),
    );
  }
}

/// shadcn `<Badge>` (rounded-full px-2.5 py-0.5 text-xs font-semibold) with the
/// light-section overrides used on the marketing page.
class _Badge extends StatelessWidget {
  const _Badge({
    required this.label,
    this.background,
    this.foreground,
    this.border,
  });

  final String label;
  final Color? background;
  final Color? foreground;
  final Color? border;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
      decoration: BoxDecoration(
        color: background ?? AppColors.primary,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: border ?? Colors.transparent),
        boxShadow: const [
          BoxShadow(
            color: Color(0x1A000000),
            blurRadius: 6,
            offset: Offset(0, 1),
          ),
        ],
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: foreground ?? AppColors.primaryForeground,
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------- header ---

class _LandingHeader extends StatelessWidget {
  const _LandingHeader({
    required this.onFeatures,
    required this.onAbout,
    required this.onContact,
  });

  final VoidCallback onFeatures;
  final VoidCallback onAbout;
  final VoidCallback onContact;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final showNav = width >= 768;

    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
        child: Container(
          height: 64,
          decoration: BoxDecoration(
            color: const Color(0xB204070F), // bg-[#04070F]/70
            border: Border(
              bottom: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
            ),
          ),
          child: _Container(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // logo + wordmark
                if (showNav)
                  const _BrandLogo()
                else
                  const Expanded(child: _BrandLogo()),
                if (showNav)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _NavLink(label: 'Features', onTap: onFeatures),
                      const SizedBox(width: 24),
                      _NavLink(label: 'About', onTap: onAbout),
                      const SizedBox(width: 24),
                      _NavLink(label: 'Contact', onTap: onContact),
                    ],
                  ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      height: 40,
                      child: TextButton(
                        onPressed: () =>
                            Navigator.of(context).pushNamed('/login'),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          foregroundColor: Tw.slate200,
                          textStyle: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        child: const Text('Login'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    SizedBox(
                      height: 40,
                      child: ElevatedButton(
                        onPressed: () =>
                            Navigator.of(context).pushNamed('/signup'),
                        style: ElevatedButton.styleFrom(
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          backgroundColor: Colors.white,
                          foregroundColor: Tw.gray900,
                          textStyle: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(6),
                          ),
                        ),
                        child: const Text('Sign Up'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _BrandLogo extends StatelessWidget {
  const _BrandLogo();

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () {},
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 32,
            height: 32,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0x4D22D3EE), Color(0x4D6366F1)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.25),
              ),
            ),
            child: const Text(
              'F',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(width: 8),
          const Flexible(
            child: Text(
              'Fintrack ERP',
              softWrap: false,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _NavLink extends StatelessWidget {
  const _NavLink({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Text(
          label,
          style: const TextStyle(fontSize: 16, color: Tw.slate300),
        ),
      ),
    );
  }
}

// ------------------------------------------------------------------ hero ---

class _HeroSection extends StatelessWidget {
  const _HeroSection({required this.pulse});

  final Animation<double> pulse;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final md = width >= 768;

    return ConstrainedBox(
      constraints: BoxConstraints(minHeight: MediaQuery.sizeOf(context).height),
      child: Stack(
        children: [
          Positioned.fill(
            child: Image.asset(
              'assets/images/hero-towers.jpg',
              fit: BoxFit.cover,
              alignment: Alignment.bottomCenter,
            ),
          ),
          Positioned.fill(
            child: Opacity(
              opacity: 0.7,
              child: Image.asset(
                'assets/images/hero-fiber.jpg',
                fit: BoxFit.cover,
                alignment: Alignment.center,
              ),
            ),
          ),
          const Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Color(0xED0B1220), // from-[#0B1220]/93
                    Color(0xD10F172A), // via-[#0F172A]/82
                    Color(0xF2020617), // to-[#020617]/95
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
            ),
          ),
          Positioned(
            top: 96,
            left: width * 0.12,
            child: _Glow(
              size: 320,
              pulse: pulse,
              color: const Color(0x4022D3EE), // [#22D3EE]/25
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          Positioned(
            top: 208,
            right: width * 0.14,
            child: _Glow(
              size: 384,
              pulse: pulse,
              color: const Color(0x4D4F46E5), // [#4F46E5]/30
              begin: Alignment.topRight,
              end: Alignment.bottomLeft,
            ),
          ),
          Positioned(
            bottom: 96,
            left: width / 2 - 192,
            child: _Glow(
              size: 384,
              pulse: pulse,
              color: const Color(0x33A855F7), // [#A855F7]/20
              begin: Alignment.bottomLeft,
              end: Alignment.topRight,
            ),
          ),
          const Positioned.fill(child: CustomPaint(painter: _GridPainter())),
          const Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Color(0xBF020617), // /75
                    Color(0x66020617), // /40
                    Color(0xF2020617), // /95
                  ],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(md ? 24 : 16, 96, md ? 24 : 16, 96),
            child: Center(child: _GlassPanel(md: md)),
          ),
        ],
      ),
    );
  }
}

class _Glow extends StatelessWidget {
  const _Glow({
    required this.size,
    required this.pulse,
    required this.color,
    required this.begin,
    required this.end,
  });

  final double size;
  final Animation<double> pulse;
  final Color color;
  final Alignment begin;
  final Alignment end;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: pulse,
      builder: (context, _) {
        final opacity = 1.0 - 0.5 * Curves.easeInOut.transform(pulse.value);
        return ImageFiltered(
          imageFilter: ImageFilter.blur(sigmaX: 64, sigmaY: 64),
          child: Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [
                  color.withValues(alpha: color.a * opacity),
                  color.withValues(alpha: 0),
                ],
                begin: begin,
                end: end,
              ),
            ),
          ),
        );
      },
    );
  }
}

class _GridPainter extends CustomPainter {
  const _GridPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color =
          const Color(0x0A94A3B8) // rgba(148,163,184,0.04)
      ..strokeWidth = 1;

    for (double x = 0; x < size.width; x += 50) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y < size.height; y += 50) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _GridPainter oldDelegate) => false;
}

class _GlassPanel extends StatelessWidget {
  const _GlassPanel({required this.md});

  final bool md;

  @override
  Widget build(BuildContext context) {
    final content = ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 1024), // max-w-5xl
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.all(md ? 56 : 32),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.07),
          borderRadius: BorderRadius.circular(32),
          border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
          boxShadow: const [
            BoxShadow(
              color: Color(0x5922D3EE),
              blurRadius: 60,
              spreadRadius: -12,
              offset: Offset(0, 8),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 40, sigmaY: 40),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.25),
                  ),
                ),
                child: const Text(
                  'Enterprise-Grade ISP Management Platform',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.35,
                    color: Tw.cyan100,
                  ),
                ),
              ),
              const SizedBox(height: 32),
              Text(
                'Complete Business Management',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: md ? 72 : 48,
                  fontWeight: FontWeight.w700,
                  height: 1.25,
                  letterSpacing: -1.5,
                  color: Colors.white,
                  shadows: const [
                    Shadow(
                      color: Color(0x40000000),
                      blurRadius: 24,
                      offset: Offset(0, 12),
                    ),
                  ],
                ),
              ),
              ShaderMask(
                shaderCallback: (rect) => const LinearGradient(
                  colors: [Tw.cyan300, Tw.sky300, Tw.indigo300],
                ).createShader(rect),
                child: Text(
                  'Simplified & Powerful',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: md ? 72 : 48,
                    fontWeight: FontWeight.w700,
                    height: 1.25,
                    letterSpacing: -1.5,
                    color: Colors.white,
                    shadows: const [
                      Shadow(
                        color: Color(0x40000000),
                        blurRadius: 24,
                        offset: Offset(0, 12),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 768),
                child: Text(
                  'Transform your Internet Service Provider operations with our '
                  'comprehensive ERP solution. From subscriber management to '
                  'network monitoring, everything you need in one powerful platform.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: md ? 24 : 20,
                    fontWeight: FontWeight.w300,
                    height: 1.625,
                    color: Tw.slate200.withValues(alpha: 0.9),
                  ),
                ),
              ),
              const SizedBox(height: 48),
            ],
          ),
        ),
      ),
    );

    return content;
  }
}

// ------------------------------------------------------------- features ---

class _FeaturesSection extends StatelessWidget {
  const _FeaturesSection({super.key});

  static const _items = [
    (
      icon: Icons.groups_outlined,
      title: 'Customer Management',
      description: 'Complete CRM system with detailed customer profiles, guarantor management, and communication tracking.',
    ),
    (
      icon: Icons.monetization_on_outlined,
      title: 'Billing & Payments',
      description: 'Automated invoice generation, multiple payment methods, installment plans, and due date reminders.',
    ),
    (
      icon: Icons.inventory_2_outlined,
      title: 'Inventory Management',
      description: 'Real-time stock tracking, product catalog management, service plans, and equipment allocation.',
    ),
    (
      icon: Icons.headset_mic_outlined,
      title: 'Support System',
      description: 'Complaint tracking, alert management, support tickets, and resolution tracking.',
    ),
    (
      icon: Icons.settings_outlined,
      title: 'Admin & Control',
      description: 'User role management, company administration, dealer management, and system configuration.',
    ),
    (
      icon: Icons.bar_chart_rounded,
      title: 'Analytics & Reports',
      description: 'Real-time analytics, custom reports, revenue tracking, and business intelligence dashboards.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(vertical: 80),
      child: _Container(
        child: Column(
          children: [
            const _Badge(
              label: 'Features',
              background: Tw.gray100,
              foreground: Tw.gray800,
              border: Tw.gray300,
            ),
            const SizedBox(height: 16),
            const Text(
              'Everything You Need to Succeed',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 36,
                fontWeight: FontWeight.w700,
                color: Tw.navy900,
              ),
            ),
            const SizedBox(height: 16),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 768),
              child: const Text(
                'Comprehensive tools designed specifically for ISP operations and growth',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 20, color: Tw.gray600),
              ),
            ),
            const SizedBox(height: 64),
            LayoutBuilder(
              builder: (context, constraints) {
                final cols = constraints.maxWidth >= 1024
                    ? 3
                    : constraints.maxWidth >= 768
                    ? 2
                    : 1;
                final cardWidth =
                    (constraints.maxWidth - 32 * (cols - 1)) / cols;

                return Wrap(
                  spacing: 32,
                  runSpacing: 32,
                  children: [
                    for (final item in _items)
                      SizedBox(
                        width: cardWidth,
                        child: _FeatureCard(
                          icon: item.icon,
                          title: item.title,
                          description: item.description,
                        ),
                      ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _FeatureCard extends StatelessWidget {
  const _FeatureCard({
    required this.icon,
    required this.title,
    required this.description,
  });

  final IconData icon;
  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Tw.gray200),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0D000000),
            blurRadius: 2,
            offset: Offset(0, 1),
          ),
        ],
      ),
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 56,
            height: 56,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              gradient: const LinearGradient(
                colors: [Color(0x1A06B6D4), Tw.blue600],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Icon(icon, size: 28, color: Colors.white),
          ),
          const SizedBox(height: 16),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: Tw.navy900,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            description,
            style: const TextStyle(
              fontSize: 14,
              height: 1.625,
              color: Tw.gray600,
            ),
          ),
        ],
      ),
    );
  }
}

// ----------------------------------------------------------------- roles ---

class _RolesSection extends StatelessWidget {
  const _RolesSection();

  static const _roles = [
    (
      initials: 'KB',
      title: 'Super Admin',
      subtitle: 'Complete system control',
      bullets: [
        'Full system access',
        'User management',
        'Company administration',
        'System configuration',
      ],
    ),
    (
      initials: 'AD',
      title: 'Admin',
      subtitle: 'Company-level management',
      bullets: [
        'Company operations',
        'Staff management',
        'Report access',
        'Customer support',
      ],
    ),
    (
      initials: 'BI',
      title: 'Billing Staff',
      subtitle: 'Financial operations',
      bullets: [
        'Invoice management',
        'Payment processing',
        'Ledger management',
        'Financial reports',
      ],
    ),
    (
      initials: 'SP',
      title: 'Support Staff',
      subtitle: 'Customer service',
      bullets: [
        'Complaint handling',
        'Customer support',
        'Ticket management',
        'Service requests',
      ],
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Tw.gray50, Color(0xFFFAFAFA)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      padding: const EdgeInsets.symmetric(vertical: 80),
      child: _Container(
        child: Column(
          children: [
            const _Badge(
              label: 'User Roles',
              background: Tw.gray100,
              foreground: Tw.gray800,
              border: Tw.gray300,
            ),
            const SizedBox(height: 16),
            const Text(
              'Perfect for Every Team Member',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 36,
                fontWeight: FontWeight.w700,
                color: Tw.gray900,
              ),
            ),
            const SizedBox(height: 16),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 768),
              child: const Text(
                'Role-based access control ensures everyone has the right tools for their job',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 20, color: Tw.gray600),
              ),
            ),
            const SizedBox(height: 64),
            LayoutBuilder(
              builder: (context, constraints) {
                final cols = constraints.maxWidth >= 1024
                    ? 4
                    : constraints.maxWidth >= 768
                    ? 2
                    : 1;
                final cardWidth =
                    (constraints.maxWidth - 24 * (cols - 1)) / cols;

                return Wrap(
                  spacing: 24,
                  runSpacing: 24,
                  children: [
                    for (final role in _roles)
                      SizedBox(
                        width: cardWidth,
                        child: _RoleCard(
                          initials: role.initials,
                          title: role.title,
                          subtitle: role.subtitle,
                          bullets: role.bullets,
                        ),
                      ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _RoleCard extends StatelessWidget {
  const _RoleCard({
    required this.initials,
    required this.title,
    required this.subtitle,
    required this.bullets,
  });

  final String initials;
  final String title;
  final String subtitle;
  final List<String> bullets;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xE6FFFFFF), // bg-white/90
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Tw.gray200),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0D000000),
            blurRadius: 2,
            offset: Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 64,
            height: 64,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(
                colors: [Tw.gray100, Tw.gray200],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x1A000000),
                  blurRadius: 6,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            child: Text(
              initials,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w700,
                color: Tw.gray900,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w600,
              color: Tw.gray900,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 14, color: Tw.gray600),
          ),
          const SizedBox(height: 16),
          Align(
            alignment: Alignment.centerLeft,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final bullet in bullets) ...[
                  if (bullet != bullets.first) const SizedBox(height: 8),
                  Text(
                    bullet,
                    style: const TextStyle(fontSize: 12, color: Tw.gray600),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ----------------------------------------------------------------- about ---

class _AboutSection extends StatelessWidget {
  const _AboutSection({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(vertical: 80),
      child: _Container(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 896), // max-w-4xl
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Center(
                child: Column(
                  children: [
                    _Badge(
                      label: 'About Fintrack ERP',
                      background: Tw.gray100,
                      foreground: Tw.gray800,
                      border: Tw.gray300,
                    ),
                    SizedBox(height: 16),
                    Text(
                      'Empowering ISPs Worldwide Since 2020',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 36,
                        fontWeight: FontWeight.w700,
                        color: Tw.gray900,
                      ),
                    ),
                    SizedBox(height: 16),
                    Text(
                      'Built by professionals, for Internet Service Providers globally',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 20, color: Tw.gray600),
                    ),
                    SizedBox(height: 64),
                  ],
                ),
              ),
              const Text(
                'Our Mission',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  color: Tw.gray900,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'To provide ISPs worldwide with world-class management software '
                'that understands global business needs, regulatory requirements, '
                'and market challenges. We are committed to helping ISPs grow their '
                'business while providing exceptional service to their customers.',
                style: TextStyle(fontSize: 16, height: 1.6, color: Tw.gray600),
              ),
              const SizedBox(height: 24),
              const Text(
                'Why Choose Fintrack ERP?',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  color: Tw.gray900,
                ),
              ),
              const SizedBox(height: 16),
              _Bullet('Designed for global market conditions and regulations'),
              const SizedBox(height: 12),
              _Bullet('Support for multiple payment methods and currencies'),
              const SizedBox(height: 12),
              _Bullet('24/7 multilingual customer support'),
            ],
          ),
        ),
      ),
    );
  }
}

class _Bullet extends StatelessWidget {
  const _Bullet(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 8,
          height: 8,
          margin: const EdgeInsets.only(top: 8),
          decoration: const BoxDecoration(
            color: Tw.gray900,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              fontSize: 16,
              height: 1.6,
              color: Tw.gray600,
            ),
          ),
        ),
      ],
    );
  }
}

// ------------------------------------------------------------------- cta ---

class _CtaSection extends StatelessWidget {
  const _CtaSection();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Tw.gray900, Colors.black],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
      ),
      padding: const EdgeInsets.symmetric(vertical: 80),
      child: _Container(
        child: Column(
          children: [
            const Text(
              'Ready to Transform Your ISP Business?',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 36,
                fontWeight: FontWeight.w700,
                color: Colors.white,
                shadows: [Shadow(color: Color(0x40000000), blurRadius: 16)],
              ),
            ),
            const SizedBox(height: 16),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 768),
              child: const Text(
                'Join thousands of ISPs worldwide who trust Fintrack ERP for their '
                'daily operations',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 20, color: Tw.gray300),
              ),
            ),
            const SizedBox(height: 32),
            SizedBox(
              height: 44,
              child: ElevatedButton(
                onPressed: () => Navigator.of(context).pushNamed('/signup'),
                style: ElevatedButton.styleFrom(
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  backgroundColor: Colors.white,
                  foregroundColor: Tw.gray900,
                  textStyle: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w500,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(6),
                  ),
                  shadowColor: const Color(0x33000000),
                ),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: const [
                      Text('Start Your Free Trial'),
                      SizedBox(width: 8),
                      Icon(Icons.arrow_forward, size: 20),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------- footer ---

class _LandingFooter extends StatelessWidget {
  const _LandingFooter({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Tw.gray50,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      padding: const EdgeInsets.symmetric(vertical: 48),
      child: const _Container(
        child: Text(
          '2026 Fintrack ERP. All rights reserved.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 14, color: Tw.gray600),
        ),
      ),
    );
  }
}
