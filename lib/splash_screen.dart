import 'features/shell/app_shell.dart';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

// ─── Home Screen ──────────────────────────────────────────────────────────────

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF04091A),
      body: Stack(
        fit: StackFit.expand,
        children: [
          const _StadiumBackground(),
          SafeArea(
            child: Column(
              children: [
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  child: Row(
                    children: [
                      // Hero ball — clipped circle so no rectangular bg
                      Hero(
                        tag: 'splash_ball',
                        child: ClipOval(
                          child: Image.asset(
                            'assets/images/sport_sphere_ball.png',
                            width: 40,
                            height: 40,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) =>
                                const _CircleFallback(size: 40),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: const [
                          Text(
                            'SPORT SPHERE',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 3,
                            ),
                          ),
                          Text(
                            'YOUR WORLD OF SPORTS',
                            style: TextStyle(
                              color: Color(0xFF7FD820),
                              fontSize: 9,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 2,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const Divider(color: Color(0xFF1A2A45), height: 1),
                const Expanded(
                  child: Center(
                    child: Text(
                      'Welcome to Sport Sphere',
                      style: TextStyle(
                        color: Colors.white54,
                        fontSize: 18,
                        letterSpacing: 1,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Splash Screen ────────────────────────────────────────────────────────────

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  // Ball entrance
  late AnimationController _entranceCtrl;
  late Animation<double> _entranceScale;
  late Animation<double> _entranceOpacity;

  // Continuous spin (idle + through loading)
  late AnimationController _spinCtrl;

  // Progress 0 → 1
  late AnimationController _progressCtrl;
  late Animation<double> _progress;

  // Exit: fast burst spin + scale up + fade out
  late AnimationController _exitCtrl;
  late Animation<double> _exitAngle;
  late Animation<double> _exitScale;
  late Animation<double> _exitOpacity;

  // Screen fade-out
  late AnimationController _screenFadeCtrl;
  late Animation<double> _screenOpacity;

  bool _exiting = false;

  @override
  void initState() {
    super.initState();

    // 1. Ball pops in
    _entranceCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _entranceScale = Tween<double>(begin: 0.3, end: 1.0).animate(
      CurvedAnimation(parent: _entranceCtrl, curve: Curves.elasticOut),
    );
    _entranceOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _entranceCtrl,
        curve: const Interval(0.0, 0.4, curve: Curves.easeIn),
      ),
    );

    // 2. Continuous spin — starts immediately, loops until exit
    _spinCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat();

    // 3. Progress ring 0→100%
    _progressCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3000),
    );
    _progress = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _progressCtrl, curve: Curves.easeInOut),
    );

    // 4. Exit spin: 3 fast turns, ball scales up and vanishes
    _exitCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _exitAngle = Tween<double>(begin: 0.0, end: 6 * math.pi).animate(
      CurvedAnimation(parent: _exitCtrl, curve: Curves.easeInOut),
    );
    _exitScale = Tween<double>(begin: 1.0, end: 2.2).animate(
      CurvedAnimation(parent: _exitCtrl, curve: Curves.easeIn),
    );
    _exitOpacity = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _exitCtrl,
        curve: const Interval(0.4, 1.0, curve: Curves.easeIn),
      ),
    );

    // 5. Whole-screen fade out
    _screenFadeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _screenOpacity = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(parent: _screenFadeCtrl, curve: Curves.easeIn),
    );

    // Sequence
    _entranceCtrl.forward().then((_) {
      _progressCtrl.forward().then((_) => _triggerExit());
    });
  }

  void _triggerExit() {
    if (!mounted) return;
    setState(() => _exiting = true);
    _spinCtrl.stop();
    _exitCtrl.forward().then((_) {
      _screenFadeCtrl.forward().then((_) {
        if (!mounted) return;
        context.go('/home');
      });
    });
  }

  @override
  void dispose() {
    _entranceCtrl.dispose();
    _spinCtrl.dispose();
    _progressCtrl.dispose();
    _exitCtrl.dispose();
    _screenFadeCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _screenOpacity,
      child: Scaffold(
        backgroundColor: const Color(0xFF04091A),
        body: Stack(
          fit: StackFit.expand,
          children: [
            const _StadiumBackground(),
            const _EnergyStreaks(),

            // ── Main column ──
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const SizedBox(height: 40),

                // Rotating ball
                AnimatedBuilder(
                  animation: Listenable.merge(
                      [_entranceCtrl, _spinCtrl, _exitCtrl]),
                  builder: (context, child) {
                    final idleAngle = _spinCtrl.value * 2 * math.pi;
                    final angle = _exiting ? _exitAngle.value : idleAngle;
                    final scale = _exiting
                        ? _entranceScale.value * _exitScale.value
                        : _entranceScale.value;
                    final opacity = _exiting
                        ? _exitOpacity.value
                        : _entranceOpacity.value;

                    return Opacity(
                      opacity: opacity.clamp(0.0, 1.0),
                      child: Transform.scale(
                        scale: scale,
                        child: Transform.rotate(
                          angle: angle,
                          // ClipOval hides the PNG's rectangular dark corners —
                          // only the circular ball is visible as it spins.
                          child: ClipOval(
                            child: Hero(
                              tag: 'splash_ball',
                              child: child!,
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                  child: _BallWithGlow(size: 190),
                ),

                const SizedBox(height: 44),

                // Title — pure text, no image
                _SplashTitle(),

                const SizedBox(height: 52),

                // Progress ring + live %
                AnimatedBuilder(
                  animation: _progress,
                  builder: (context, _) {
                    final pct = (_progress.value * 100).round();
                    return _ProgressRing(
                      progress: _progress.value,
                      label: '$pct%',
                    );
                  },
                ),
              ],
            ),

            // ── Single footer ──
            const Positioned(
              bottom: 36,
              left: 0,
              right: 0,
              child: _Footer(),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Ball with glow halo ──────────────────────────────────────────────────────

class _BallWithGlow extends StatelessWidget {
  final double size;
  const _BallWithGlow({required this.size});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Glow halo behind the ball
          Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF00A8FF).withValues(alpha: 0.45),
                  blurRadius: 55,
                  spreadRadius: 8,
                ),
                BoxShadow(
                  color: const Color(0xFF00A8FF).withValues(alpha: 0.18),
                  blurRadius: 90,
                  spreadRadius: 24,
                ),
              ],
            ),
          ),
          // The ball image itself — no clip here; ClipOval sits above in the tree
          Image.asset(
            'assets/images/sport_sphere_ball.png',
            width: size,
            height: size,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => _CircleFallback(size: size),
          ),
        ],
      ),
    );
  }
}

// ─── Fallback when asset is missing ──────────────────────────────────────────

class _CircleFallback extends StatelessWidget {
  final double size;
  const _CircleFallback({required this.size});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const SweepGradient(
          colors: [
            Color(0xFF00A8FF),
            Color(0xFFFF8800),
            Color(0xFF7FD820),
            Color(0xFFFFFFFF),
            Color(0xFF00A8FF),
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF00A8FF).withValues(alpha: 0.6),
            blurRadius: 30,
          ),
        ],
      ),
    );
  }
}

// ─── Splash title (text only) ─────────────────────────────────────────────────

class _SplashTitle extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            _titleText('SP'),
            // Inline ball icon replacing the 'O'
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 1),
              child: ClipOval(
                child: Image.asset(
                  'assets/images/sport_sphere_ball.png',
                  width: 36,
                  height: 36,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => const _CircleFallback(size: 36),
                ),
              ),
            ),
            _titleText('RT'),
          ],
        ),
        const SizedBox(height: 2),
        _titleText('SPHERE', size: 34, spacing: 14),
        const SizedBox(height: 8),
        const Text(
          'YOUR WORLD OF SPORTS',
          style: TextStyle(
            color: Color(0xFF7FD820),
            fontSize: 11,
            fontWeight: FontWeight.w600,
            letterSpacing: 3.5,
          ),
        ),
      ],
    );
  }

  Widget _titleText(String t, {double size = 50, double spacing = 4}) {
    return Text(
      t,
      style: TextStyle(
        color: Colors.white,
        fontSize: size,
        fontWeight: FontWeight.w900,
        letterSpacing: spacing,
        height: 1.0,
        shadows: [
          Shadow(
            color: const Color(0xFF00A8FF).withValues(alpha: 0.4),
            blurRadius: 18,
          ),
        ],
      ),
    );
  }
}

// ─── Progress ring ────────────────────────────────────────────────────────────

class _ProgressRing extends StatelessWidget {
  final double progress;
  final String label;

  const _ProgressRing({required this.progress, required this.label});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          width: 72,
          height: 72,
          child: CustomPaint(
            painter: _RingPainter(progress: progress),
            child: Center(
              child: Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 18),
        _LoadingDots(),
      ],
    );
  }
}

class _RingPainter extends CustomPainter {
  final double progress;
  const _RingPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2);
    final r = size.width / 2 - 5;
    const sw = 5.0;

    // Track
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..color = const Color(0xFF1A2A45)
        ..style = PaintingStyle.stroke
        ..strokeWidth = sw,
    );

    if (progress <= 0) return;

    // Gradient arc
    final rect = Rect.fromCircle(center: c, radius: r);
    canvas.drawArc(
      rect,
      -math.pi / 2,
      2 * math.pi * progress,
      false,
      Paint()
        ..shader = SweepGradient(
          colors: const [Color(0xFF00A8FF), Color(0xFF7FD820)],
          startAngle: -math.pi / 2,
          endAngle: -math.pi / 2 + 2 * math.pi,
        ).createShader(rect)
        ..style = PaintingStyle.stroke
        ..strokeWidth = sw
        ..strokeCap = StrokeCap.round,
    );

    // Glowing tip dot
    final tipAngle = -math.pi / 2 + 2 * math.pi * progress;
    final tip = Offset(c.dx + r * math.cos(tipAngle), c.dy + r * math.sin(tipAngle));
    canvas.drawCircle(
      tip,
      4.5,
      Paint()
        ..color = const Color(0xFF7FD820).withValues(alpha: 0.9)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
    );
  }

  @override
  bool shouldRepaint(covariant _RingPainter old) => old.progress != progress;
}

// ─── Loading dots ─────────────────────────────────────────────────────────────

class _LoadingDots extends StatefulWidget {
  @override
  State<_LoadingDots> createState() => _LoadingDotsState();
}

class _LoadingDotsState extends State<_LoadingDots>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, __) {
        final dots = '.' * ((_ctrl.value * 4).floor() % 4);
        return Text(
          'L O A D I N G$dots',
          style: const TextStyle(
            color: Color(0xAAFFFFFF),
            fontSize: 11,
            fontWeight: FontWeight.w400,
            letterSpacing: 4,
          ),
        );
      },
    );
  }
}

// ─── Single footer ────────────────────────────────────────────────────────────

class _Footer extends StatelessWidget {
  const _Footer();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: 40,
          height: 1,
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.transparent, Color(0xFF00A8FF)],
            ),
          ),
        ),
        const SizedBox(width: 12),
        const Text(
          'Mbazza Codes Inc.',
          style: TextStyle(
            color: Color(0xFF7FD820),
            fontSize: 12,
            fontWeight: FontWeight.w600,
            letterSpacing: 1.5,
          ),
        ),
        const SizedBox(width: 12),
        Container(
          width: 40,
          height: 1,
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF7FD820), Colors.transparent],
            ),
          ),
        ),
      ],
    );
  }
}

// ─── Stadium background ───────────────────────────────────────────────────────

class _StadiumBackground extends StatelessWidget {
  const _StadiumBackground();

  @override
  Widget build(BuildContext context) {
    return CustomPaint(painter: _StadiumPainter());
  }
}

class _StadiumPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF060E22), Color(0xFF04091A)],
        ).createShader(Offset.zero & size),
    );

    void spotlight(Offset center) {
      for (final r in [120.0, 200.0, 320.0]) {
        canvas.drawCircle(
          center,
          r,
          Paint()
            ..color = const Color(0xFF4488FF)
                .withValues(alpha: r == 120 ? 0.12 : r == 200 ? 0.07 : 0.03)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 60),
        );
      }
    }

    spotlight(Offset(size.width * 0.14, size.height * 0.05));
    spotlight(Offset(size.width * 0.86, size.height * 0.05));
  }

  @override
  bool shouldRepaint(covariant CustomPainter _) => false;
}

// ─── Energy streaks ───────────────────────────────────────────────────────────

class _EnergyStreaks extends StatelessWidget {
  const _EnergyStreaks();

  @override
  Widget build(BuildContext context) {
    return CustomPaint(painter: _StreaksPainter());
  }
}

class _StreaksPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final lines = [
      _S(Offset(0, size.height * .36), Offset(size.width * .38, size.height * .66), const Color(0xFF00A8FF), 2.5),
      _S(Offset(0, size.height * .39), Offset(size.width * .35, size.height * .69), const Color(0xFFFF8800), 1.5),
      _S(Offset(0, size.height * .42), Offset(size.width * .30, size.height * .71), const Color(0xFF7FD820), 1.0),
      _S(Offset(size.width, size.height * .36), Offset(size.width * .62, size.height * .66), const Color(0xFF00A8FF), 2.5),
      _S(Offset(size.width, size.height * .39), Offset(size.width * .65, size.height * .69), const Color(0xFF7FD820), 1.5),
      _S(Offset(size.width, size.height * .42), Offset(size.width * .70, size.height * .71), const Color(0xFFFF8800), 1.0),
    ];
    for (final l in lines) {
      canvas.drawLine(
        l.a, l.b,
        Paint()
          ..color = l.color.withValues(alpha: 0.5)
          ..strokeWidth = l.w
          ..strokeCap = StrokeCap.round
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, l.w),
      );
    }

    // Bottom wave
    final path = Path();
    final y = size.height * 0.89;
    path.moveTo(0, y);
    for (var i = 0; i <= size.width.toInt(); i++) {
      path.lineTo(i.toDouble(),
          y + math.sin((i / size.width) * math.pi * 3) * 5);
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = const Color(0xFF00A8FF).withValues(alpha: 0.12)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter _) => false;
}

class _S {
  final Offset a, b;
  final Color color;
  final double w;
  const _S(this.a, this.b, this.color, this.w);
}




