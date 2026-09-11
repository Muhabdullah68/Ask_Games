import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../theme/app_theme.dart';
import 'main_shell.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _Particle {
  final double fx;
  final double fy;
  final double radius;
  final double speed;
  final double phase;
  final double drift;
  final Color color;

  const _Particle({
    required this.fx,
    required this.fy,
    required this.radius,
    required this.speed,
    required this.phase,
    required this.drift,
    required this.color,
  });
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late final AnimationController _entrance;
  late final AnimationController _ambient;
  late final List<_Particle> _particles;
  Timer? _navTimer;
  bool _navigating = false;

  static const Color _gold = Color(0xFFFBBF24);
  static const Color _pink = Color(0xFFEC4899);
  static const Color _purple = Color(0xFF7C3AED);

  static const Duration _entranceDuration = Duration(milliseconds: 2500);
  static const Duration _transitionDuration = Duration(milliseconds: 650);
  static const Duration _totalSplashDuration = Duration(seconds: 6);

  @override
  void initState() {
    super.initState();
    final rng = math.Random(42);

    _particles = List.generate(14, (i) {
      const colors = [
        Color(0xFFFBBF24),
        Color(0xFFEC4899),
        Color(0xFFA78BFA),
        Color(0xFF38BDF8),
      ];
      return _Particle(
        fx: 0.08 + rng.nextDouble() * 0.84,
        fy: 0.15 + rng.nextDouble() * 0.7,
        radius: 1.5 + rng.nextDouble() * 2.5,
        speed: 0.35 + rng.nextDouble() * 0.5,
        phase: rng.nextDouble() * math.pi * 2,
        drift: 0.06 + rng.nextDouble() * 0.12,
        color: colors[i % colors.length],
      );
    });

    _entrance = AnimationController(vsync: this, duration: _entranceDuration)
      ..addStatusListener((status) {
        if (status == AnimationStatus.completed) {
          _scheduleNavigation();
        }
      });

    _ambient = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat();

    _entrance.forward();
  }

  @override
  void dispose() {
    _navTimer?.cancel();
    _entrance.dispose();
    _ambient.dispose();
    super.dispose();
  }

  void _scheduleNavigation() {
    if (_navigating || !mounted) return;
    _navigating = true;
    final dwell =
        _totalSplashDuration - _entranceDuration - _transitionDuration;
    _navTimer = Timer(dwell > Duration.zero ? dwell : Duration.zero, _goToApp);
  }

  void _goToApp() {
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        transitionDuration: _transitionDuration,
        pageBuilder: (_, _, _) => const MainShell(),
        transitionsBuilder: (_, animation, _, child) {
          return FadeTransition(
            opacity: animation,
            child: ScaleTransition(
              scale: Tween<double>(begin: 1.05, end: 1.0).animate(
                CurvedAnimation(parent: animation, curve: Curves.easeOut),
              ),
              child: child,
            ),
          );
        },
      ),
    );
  }

  // ------------------------------------------------------------ timeline

  double _ease01(double t, Curve curve) => curve.transform(t.clamp(0.0, 1.0));

  double _fade(double t, double start, double end) {
    if (t <= start) return 0;
    if (t >= end) return 1;
    return Curves.easeOut.transform((t - start) / (end - start));
  }

  double _interval(double t, double start, double end) {
    if (t <= start) return 0;
    if (t >= end) return 1;
    return (t - start) / (end - start);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AnimatedBuilder(
        animation: _entrance,
        builder: (context, _) {
          final t = _entrance.value;
          return Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color.lerp(
                    const Color(0xFF0B0616),
                    const Color(0xFF1E1638),
                    _ease01(t, Curves.easeInOut),
                  )!,
                  Color.lerp(
                    const Color(0xFF151025),
                    const Color(0xFF2A1F52),
                    _ease01(t, Curves.easeInOut),
                  )!,
                  Color.lerp(
                    const Color(0xFF1E1638),
                    const Color(0xFF4C1D95),
                    _fade(t, 0.0, 0.6),
                  )!,
                ],
              ),
            ),
            child: Stack(
              children: [
                _buildGlow(t),
                _buildParticles(),
                _buildRings(t),
                _buildCenter(t),
                _buildFooter(t),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildGlow(double t) {
    final alpha = (90 + 165 * _fade(t, 0.1, 0.9)).round();
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      bottom: 0,
      child: IgnorePointer(
        child: Center(
          child: Container(
            width: 420,
            height: 420,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  _gold.withValues(alpha: (alpha * 0.35) / 255),
                  _purple.withValues(alpha: (alpha * 0.12) / 255),
                  Colors.transparent,
                ],
                stops: const [0.0, 0.45, 1.0],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildParticles() {
    return Positioned.fill(
      child: IgnorePointer(
        child: AnimatedBuilder(
          animation: _ambient,
          builder: (context, _) {
            return LayoutBuilder(
              builder: (context, constraints) {
                final w = constraints.maxWidth;
                final h = constraints.maxHeight;
                return Stack(
                  children: [
                    for (final p in _particles) _buildParticle(p, w, h),
                  ],
                );
              },
            );
          },
        ),
      ),
    );
  }

  Widget _buildParticle(_Particle p, double w, double h) {
    final av = _ambient.value;
    final travel = p.drift * h;
    final rawY = p.fy * h - travel * (av * p.speed + 0.0001);
    final py = rawY % (h + 40) - 20;
    final twinkle =
        0.35 + 0.65 * (0.5 + 0.5 * math.sin(p.phase + av * math.pi * 2));
    return Positioned(
      left: p.fx * w,
      top: py,
      child: Container(
        width: p.radius * 2,
        height: p.radius * 2,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: p.color.withValues(alpha: twinkle),
          boxShadow: [
            BoxShadow(
              color: p.color.withValues(alpha: twinkle * 0.6),
              blurRadius: 6,
              spreadRadius: 1,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRings(double t) {
    final ringIntensity = _fade(t, 0.18, 0.75);
    return Positioned.fill(
      child: IgnorePointer(
        child: AnimatedBuilder(
          animation: _ambient,
          builder: (context, _) {
            final av = _ambient.value;
            return Center(
              child: Stack(
                alignment: Alignment.center,
                children: [
                  for (final (k, maxR) in [(0, 150.0), (1, 190.0)])
                    _buildRing(k, av, maxR, ringIntensity),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildRing(int k, double av, double maxR, double intensity) {
    final progress = ((av + k * 0.5) % 1.0);
    final radius = 30 + progress * maxR;
    final opacity = (1 - progress) * 0.65 * intensity;
    return Container(
      width: radius * 2,
      height: radius * 2,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.transparent,
        border: Border.all(color: _gold.withValues(alpha: opacity), width: 1.6),
        boxShadow: [
          BoxShadow(
            color: _pink.withValues(alpha: opacity * 0.4),
            blurRadius: 14,
            spreadRadius: 2,
          ),
        ],
      ),
    );
  }

  Widget _buildCenter(double t) {
    final flipAngle = (1 - _ease01(t, Curves.easeOutCubic)) * 1.35;
    final scale = _ease01(t, Curves.easeOutBack).clamp(0.0, 1.4);
    final rise = (1 - _ease01(t, Curves.easeOutCubic)) * 36;

    final titleFade = _fade(t, 0.42, 0.7);
    final tagFade = _fade(t, 0.55, 0.8);
    final titleSlide = (1 - _fade(t, 0.42, 0.7)) * 24;

    return Positioned.fill(
      child: Center(
        child: Transform.translate(
          offset: Offset(0, rise),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedBuilder(
                animation: _ambient,
                builder: (context, _) {
                  final av = _ambient.value;
                  final bob = math.sin(av * math.pi * 2) * 6;
                  final yaw = math.sin(av * math.pi) * 0.045;
                  return Transform.translate(
                    offset: Offset(0, bob),
                    child: Transform(
                      alignment: Alignment.center,
                      transform: Matrix4.identity()
                        ..setEntry(3, 2, 0.0016)
                        ..rotateX(flipAngle)
                        ..rotateY(yaw),
                      child: Transform.scale(
                        scale: scale,
                        child: _buildLogo(t),
                      ),
                    ),
                  );
                },
              ),
              SizedBox(height: 26 + titleSlide),
              Opacity(
                opacity: titleFade,
                child: ShaderMask(
                  shaderCallback: (rect) => const LinearGradient(
                    colors: [_gold, _pink, _gold],
                  ).createShader(rect),
                  blendMode: BlendMode.srcATop,
                  child: Text(
                    'ASK GAMES',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 34,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 6,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Opacity(
                opacity: tagFade,
                child: Text(
                  'PLAY  \u00B7  COMPETE  \u00B7  WIN',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 3,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLogo(double t) {
    return Container(
      width: 190,
      height: 190,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(30),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF3B0764), Color(0xFF6D28D9)],
        ),
        boxShadow: [
          BoxShadow(
            color: _gold.withValues(alpha: 0.45 * _fade(t, 0.1, 0.8)),
            blurRadius: 34,
            spreadRadius: 6,
          ),
          BoxShadow(
            color: _pink.withValues(alpha: 0.3 * _fade(t, 0.1, 0.8)),
            blurRadius: 60,
            spreadRadius: 12,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(26),
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.asset(
              'assets/images/ask_games_logo.png',
              fit: BoxFit.cover,
              gaplessPlayback: true,
            ),
            _buildShine(t),
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(26),
                border: Border.all(
                  color: _gold.withValues(alpha: 0.5),
                  width: 1.5,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildShine(double t) {
    final sweep = _interval(t, 0.22, 0.55);
    final entranceDone = t >= 0.55;
    return AnimatedBuilder(
      animation: _ambient,
      builder: (context, _) {
        final av = _ambient.value;
        final progress = entranceDone ? ((av * 0.5) % 1.0) : sweep;
        final x = -0.8 + (1.7 * Curves.easeInOut.transform(progress));
        return Align(
          alignment: Alignment.center,
          child: ClipRect(
            child: Transform.translate(
              offset: Offset(x * 260, 0),
              child: Transform.rotate(
                angle: -0.5,
                child: Container(
                  width: 90,
                  height: 320,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.transparent,
                        Colors.white.withValues(alpha: 0.18),
                        Colors.white.withValues(alpha: 0.4),
                        Colors.white.withValues(alpha: 0.18),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildFooter(double t) {
    final fade = _fade(t, 0.7, 0.95);
    return Positioned(
      left: 0,
      right: 0,
      bottom: 42,
      child: Opacity(
        opacity: fade,
        child: Column(
          children: [
            AnimatedBuilder(
              animation: _ambient,
              builder: (context, _) {
                final av = _ambient.value;
                return Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(3, (i) {
                    final phase = (av + i * 0.33) % 1.0;
                    final dotOpacity = (1 - phase).clamp(0.15, 1.0);
                    return AnimatedContainer(
                      duration: const Duration(milliseconds: 100),
                      width: 8,
                      height: 8,
                      margin: const EdgeInsets.symmetric(horizontal: 5),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _gold.withValues(alpha: dotOpacity),
                      ),
                    );
                  }),
                );
              },
            ),
            const SizedBox(height: 14),
            Text(
              'GameHub',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 11,
                letterSpacing: 3,
                color: AppColors.textMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
