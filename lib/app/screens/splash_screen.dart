import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app_services.dart';
import '../app_sizes.dart';
import '../controllers/splash_controller.dart';
import 'app_shell.dart';

/// Brand splash: gradient backdrop, animated logo + name, and the database
/// opening in the background. Moves on to [AppShell] once the intro has
/// played **and** the data is ready; shows a retry on failure.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key, required this.services});
  final AppServices services;

  static const appName = 'Hissab';
  static const tagline = 'Know where your money stands';

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late final SplashController controller;
  late final AnimationController _intro;
  late final AnimationController _ambient;
  bool _introDone = false;
  bool _navigated = false;
  bool _motionChecked = false;

  @override
  void initState() {
    super.initState();
    controller = SplashController(widget.services)..addListener(_maybeContinue);
    _intro =
        AnimationController(
            vsync: this,
            duration: const Duration(milliseconds: 1900),
          )
          ..addStatusListener((status) {
            if (status == AnimationStatus.completed) {
              _introDone = true;
              _maybeContinue();
            }
          });
    _ambient = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 9),
    )..repeat();
    controller.initialize();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_motionChecked) return;
    _motionChecked = true;
    if (MediaQuery.maybeDisableAnimationsOf(context) ?? false) {
      _ambient.stop();
      _intro.value = 1;
      _introDone = true;
      _maybeContinue();
    } else {
      _intro.forward();
    }
  }

  @override
  void dispose() {
    controller
      ..removeListener(_maybeContinue)
      ..dispose();
    _intro.dispose();
    _ambient.dispose();
    super.dispose();
  }

  void _maybeContinue() {
    if (_navigated || !_introDone || !controller.ready || !mounted) return;
    _navigated = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        PageRouteBuilder<void>(
          transitionDuration: const Duration(milliseconds: 450),
          pageBuilder: (_, _, _) => AppShell(services: widget.services),
          transitionsBuilder: (_, animation, _, child) {
            final curved = CurvedAnimation(
              parent: animation,
              curve: Curves.easeOutCubic,
            );
            return FadeTransition(
              opacity: curved,
              child: ScaleTransition(
                scale: Tween(begin: 0.97, end: 1.0).animate(curved),
                child: child,
              ),
            );
          },
        ),
      );
    });
  }

  Animation<double> _phase(double begin, double end, [Curve? curve]) =>
      CurvedAnimation(
        parent: _intro,
        curve: Interval(begin, end, curve: curve ?? Curves.easeOutCubic),
      );

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final palette = dark ? _SplashPalette.dark : _SplashPalette.light;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light.copyWith(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: palette.gradient.last,
      ),
      child: Scaffold(
        backgroundColor: palette.gradient.first,
        body: Stack(
          fit: StackFit.expand,
          children: [
            RepaintBoundary(
              child: CustomPaint(
                painter: _BackdropPainter(_ambient, palette),
              ),
            ),
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: SpaceSize.huge,
                ),
                child: Column(
                  children: [
                    const Spacer(flex: 5),
                    _AnimatedLogo(
                      tile: _phase(0, .42, Curves.easeOutBack),
                      tileFade: _phase(0, .22),
                      pages: _phase(.22, .55),
                      lines: _phase(.4, .72, Curves.easeOut),
                      chart: _phase(.56, .86, Curves.easeInOutCubic),
                      dot: _phase(.82, 1, Curves.elasticOut),
                      ambient: _ambient,
                    ),
                    const SizedBox(height: SpaceSize.section),
                    _AnimatedName(
                      text: SplashScreen.appName,
                      intro: _intro,
                    ),
                    const SizedBox(height: SpaceSize.small),
                    _Reveal(
                      animation: _phase(.66, .94),
                      child: Text(
                        SplashScreen.tagline,
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: Colors.white.withValues(alpha: .78),
                          letterSpacing: .2,
                        ),
                      ),
                    ),
                    const Spacer(flex: 4),
                    FadeTransition(
                      opacity: _phase(.75, 1),
                      child: AnimatedBuilder(
                        animation: controller,
                        builder: (context, _) => _StatusArea(
                          error: controller.error,
                          loading: controller.loading,
                          onRetry: controller.initialize,
                          accent: palette.gradient[1],
                        ),
                      ),
                    ),
                    const SizedBox(height: SpaceSize.huge),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SplashPalette {
  const _SplashPalette(this.gradient);
  final List<Color> gradient;

  static const light = _SplashPalette([
    Color(0xFF1A36A8),
    Color(0xFF2C5BE0),
    Color(0xFF5585FF),
  ]);
  static const dark = _SplashPalette([
    Color(0xFF060A1A),
    Color(0xFF112358),
    Color(0xFF1D3A94),
  ]);
}

/// Diagonal brand gradient with slow-drifting soft glows.
class _BackdropPainter extends CustomPainter {
  _BackdropPainter(this.t, this.palette) : super(repaint: t);
  final Animation<double> t;
  final _SplashPalette palette;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.drawRect(
      rect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: palette.gradient,
        ).createShader(rect),
    );

    final a = t.value * 2 * math.pi;
    final w = size.width;
    final h = size.height;
    void glow(Offset center, double radius, Color color) {
      canvas.drawCircle(
        center,
        radius,
        Paint()
          ..shader = RadialGradient(
            colors: [color, color.withValues(alpha: 0)],
          ).createShader(Rect.fromCircle(center: center, radius: radius)),
      );
    }

    glow(
      Offset(w * .88 + 24 * math.cos(a), h * .14 + 18 * math.sin(a)),
      w * .75,
      Colors.white.withValues(alpha: .16),
    );
    glow(
      Offset(w * .05 + 20 * math.sin(a), h * .82 + 26 * math.cos(a)),
      w * .8,
      Colors.white.withValues(alpha: .10),
    );
    glow(
      Offset(w * .9 - 30 * math.sin(a), h * .95 - 20 * math.cos(a)),
      w * .55,
      const Color(0xFF12B76A).withValues(alpha: .22),
    );
  }

  @override
  bool shouldRepaint(_BackdropPainter old) => old.palette != palette;
}

class _AnimatedLogo extends StatelessWidget {
  const _AnimatedLogo({
    required this.tile,
    required this.tileFade,
    required this.pages,
    required this.lines,
    required this.chart,
    required this.dot,
    required this.ambient,
  });

  final Animation<double> tile, tileFade, pages, lines, chart, dot, ambient;

  @override
  Widget build(BuildContext context) {
    const size = ComponentSize.splashLogo;
    return SizedBox.square(
      dimension: ComponentSize.splashGlow,
      child: AnimatedBuilder(
        animation: Listenable.merge([tile, ambient]),
        builder: (context, _) {
          final pulse = 1 + .06 * math.sin(ambient.value * 2 * math.pi * 3);
          return Stack(
            alignment: Alignment.center,
            children: [
              Opacity(
                opacity: tileFade.value,
                child: Transform.scale(
                  scale: pulse,
                  child: const DecoratedBox(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [Color(0x55FFFFFF), Color(0x00FFFFFF)],
                      ),
                    ),
                    child: SizedBox.expand(),
                  ),
                ),
              ),
              Opacity(
                opacity: tileFade.value,
                child: Transform.scale(
                  scale: .5 + .5 * tile.value,
                  child: Container(
                    width: size,
                    height: size,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(size * .26),
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [Color(0xFF4F7DFF), Color(0xFF2C5BE0)],
                      ),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: .35),
                        width: 1.2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF0B1B4D).withValues(alpha: .4),
                          blurRadius: 36,
                          offset: const Offset(0, 18),
                        ),
                      ],
                    ),
                    child: CustomPaint(
                      painter: _LogoPainter(
                        pages: pages,
                        lines: lines,
                        chart: chart,
                        dot: dot,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// The app mark (open ledger with a rising trend) drawn on a 100×100 grid so
/// each stroke can animate on its own.
class _LogoPainter extends CustomPainter {
  _LogoPainter({
    required this.pages,
    required this.lines,
    required this.chart,
    required this.dot,
  }) : super(repaint: Listenable.merge([pages, lines, chart, dot]));

  final Animation<double> pages, lines, chart, dot;

  static const _lineColor = Color(0xFFA9C7FB);
  static const _green = Color(0xFF0BA35A);

  static final Path _rightPage = Path()
    ..moveTo(50, 35.5)
    ..cubicTo(54, 30, 66, 28.3, 77, 28.3)
    ..quadraticBezierTo(83, 28.5, 83, 34)
    ..lineTo(83, 64)
    ..quadraticBezierTo(83, 67.2, 79.8, 66.2)
    ..cubicTo(70, 63.6, 56, 64, 50, 70)
    ..close();

  static final Path _trend = Path()
    ..moveTo(55.8, 55.2)
    ..lineTo(63.2, 47.7)
    ..lineTo(67.5, 51.8)
    ..lineTo(75.6, 42.7);

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 100);

    // Pages open outward from the spine.
    final p = pages.value.clamp(0.0, 1.0);
    if (p > 0) {
      final pagePaint = Paint()..color = Colors.white.withValues(alpha: p);
      for (final side in const [-1.0, 1.0]) {
        canvas.save();
        canvas.translate(50, 0);
        canvas.scale(side * p, 1);
        canvas.translate(-50, 0);
        canvas.drawPath(_rightPage, pagePaint);
        canvas.restore();
      }
      canvas.drawLine(
        const Offset(50, 36.5),
        const Offset(50, 69),
        Paint()
          ..color = _lineColor.withValues(alpha: p)
          ..strokeWidth = .9,
      );
    }

    // Ledger lines write in one after another.
    final linePaint = Paint()
      ..color = _lineColor
      ..strokeWidth = 3.8
      ..strokeCap = StrokeCap.round;
    const ys = [40.2, 47.9, 55.3];
    for (var i = 0; i < ys.length; i++) {
      final t = ((lines.value - i * .2) / .6).clamp(0.0, 1.0);
      if (t <= 0) continue;
      canvas.drawLine(
        Offset(23.5, ys[i]),
        Offset(23.5 + 19.5 * t, ys[i]),
        linePaint,
      );
    }

    // Trend line draws itself, then the dot pops.
    final c = chart.value.clamp(0.0, 1.0);
    if (c > 0) {
      final metric = _trend.computeMetrics().first;
      canvas.drawPath(
        metric.extractPath(0, metric.length * c),
        Paint()
          ..color = _green
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.6
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round,
      );
    }
    if (dot.value > 0) {
      canvas.drawCircle(
        const Offset(76.4, 41.9),
        2.9 * dot.value,
        Paint()..color = _green,
      );
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_LogoPainter old) => false;
}

/// App name with letters rising in one after another.
class _AnimatedName extends StatelessWidget {
  const _AnimatedName({required this.text, required this.intro});
  final String text;
  final Animation<double> intro;

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.displaySmall?.copyWith(
      color: Colors.white,
      fontSize: TextSize.brand,
      fontWeight: FontWeight.w800,
      letterSpacing: 1.2,
      height: 1.1,
    );
    final letters = text.characters.toList();
    return Semantics(
      label: text,
      excludeSemantics: true,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < letters.length; i++)
            _Reveal(
              offset: 22,
              animation: CurvedAnimation(
                parent: intro,
                curve: Interval(
                  math.min(.46 + i * .045, .8),
                  math.min(.46 + i * .045 + .24, 1),
                  curve: Curves.easeOutBack,
                ),
              ),
              child: Text(letters[i], style: style),
            ),
        ],
      ),
    );
  }
}

/// Fades a child in while sliding it up by [offset] logical pixels.
class _Reveal extends StatelessWidget {
  const _Reveal({
    required this.animation,
    required this.child,
    this.offset = 14,
  });
  final Animation<double> animation;
  final Widget child;
  final double offset;

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: animation,
    child: child,
    builder: (context, child) => Opacity(
      opacity: animation.value.clamp(0.0, 1.0),
      child: Transform.translate(
        offset: Offset(0, offset * (1 - animation.value)),
        child: child,
      ),
    ),
  );
}

class _StatusArea extends StatelessWidget {
  const _StatusArea({
    required this.error,
    required this.loading,
    required this.onRetry,
    required this.accent,
  });

  final String? error;
  final bool loading;
  final VoidCallback onRetry;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final muted = Colors.white.withValues(alpha: .7);
    return SizedBox(
      height: 132,
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 250),
        child: error == null
            ? Column(
                key: const ValueKey('loading'),
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  SizedBox(
                    width: 132,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(RadiusSize.small),
                      child: LinearProgressIndicator(
                        minHeight: 3,
                        color: Colors.white,
                        backgroundColor: Colors.white.withValues(alpha: .2),
                      ),
                    ),
                  ),
                  const SizedBox(height: SpaceSize.large),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.lock_outline_rounded,
                        size: IconSize.small - 4,
                        color: muted,
                      ),
                      const SizedBox(width: SpaceSize.extraSmall + 2),
                      Flexible(
                        child: Text(
                          'Private · stays on this device',
                          overflow: TextOverflow.ellipsis,
                          style: textTheme.bodySmall?.copyWith(color: muted),
                        ),
                      ),
                    ],
                  ),
                ],
              )
            : Column(
                key: const ValueKey('error'),
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: SpaceSize.large,
                      vertical: SpaceSize.medium,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: .14),
                      borderRadius: BorderRadius.circular(RadiusSize.medium),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: .22),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.error_outline_rounded,
                          size: IconSize.medium,
                          color: Colors.white,
                        ),
                        const SizedBox(width: SpaceSize.small),
                        Flexible(
                          child: Text(
                            'Couldn’t open your data. Please try again.',
                            style: textTheme.bodyMedium?.copyWith(
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: SpaceSize.medium),
                  FilledButton.icon(
                    onPressed: loading ? null : onRetry,
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: accent,
                    ),
                    icon: const Icon(Icons.refresh_rounded),
                    label: const Text('Try again'),
                  ),
                ],
              ),
      ),
    );
  }
}
