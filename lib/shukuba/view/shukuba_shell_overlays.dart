import 'dart:math' as math;
import 'dart:ui' show ImageFilter;

import 'package:kage_no_machi/shukuba/model/shukuba_types.dart';
import 'package:kage_no_machi/shukuba/view/shukuba_boot_models.dart';
import 'package:material_ui/material_ui.dart';

const Color _urushiBlack = Color(0xFF0E1015);
const Color _urushiDark = Color(0xFF161A23);
const Color _washiInk = Color(0xFFF4EAD7);
const Color _goldAccent = Color(0xFFE89B42);
const Color _goldLeaf = Color(0xFFD4AF37);
const Color _cinnabarRed = Color(0xFFD9533F);
const Color _borderStroke = Color(0x42DECBAE);
const Color _mutedSand = Color(0xFFDECBAE);
const Color _overlayBackdrop = Color(0xCC0A0D14);

class KinpakuPainter extends CustomPainter {
  const new();

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;

    final paint = Paint()..style = PaintingStyle.fill;
    for (var i = 0; i < 48; i++) {
      final randX = ((i * 73 + 19) % 100) / 100.0;
      final randY = ((i * 41 + 37) % 100) / 100.0;
      final fleckSize = 1.5 + (i % 5) * 1.2;
      final opacity = 0.12 + (i % 7) * 0.05;
      final rot = i * 0.45;

      final cx = size.width * randX;
      final cy = size.height * randY;

      paint.color = _goldLeaf.withValues(alpha: opacity);

      canvas
        ..save()
        ..translate(cx, cy)
        ..rotate(rot);

      final path = Path()
        ..moveTo(-fleckSize, -fleckSize * 0.6)
        ..lineTo(fleckSize * 0.8, -fleckSize)
        ..lineTo(fleckSize, fleckSize * 0.7)
        ..lineTo(-fleckSize * 0.5, fleckSize)
        ..close();

      canvas
        ..drawPath(path, paint)
        ..restore();
    }
  }

  @override
  bool shouldRepaint(covariant KinpakuPainter oldDelegate) => false;
}

class AutumnLeavesPainter extends CustomPainter {
  const new({this.progress = 0.0, Animation<double>? repaint})
    : _repaint = repaint,
      super(repaint: repaint);

  final double progress;
  final Animation<double>? _repaint;

  double get _effectiveProgress => _repaint?.value ?? progress;

  static const int _leafCount = 38;
  static const List<Color> _momijiPalette = [
    Color(0xFFC84628),
    Color(0xFFDF6E32),
    Color(0xFF9E3321),
    Color(0xFFDDA03A),
  ];
  static const Color _ichoColor = Color(0xFFE4B444);

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;

    final t = _effectiveProgress.isFinite ? _effectiveProgress : 0.0;
    const margin = 28.0;
    final spanH = size.height + margin * 2.0;

    for (var i = 0; i < _leafCount; i++) {
      final plane = i < 16 ? 0 : (i < 30 ? 1 : 2);
      final alpha = plane == 0 ? 0.24 : (plane == 1 ? 0.48 : 0.72);
      final planeScale = plane == 0 ? 0.72 : (plane == 1 ? 1.0 : 1.32);
      final cycles = plane == 0 ? 1 : (plane == 1 ? 2 : 3);

      final y0 = ((i / _leafCount) + ((i * 37) % 13) * 0.007) % 1.0;
      final yFrac = (y0 + t * cycles) % 1.0;
      final cy = -margin + yFrac * spanH;

      var x0 = ((i * 0.61803398875) % 1.0) * 0.92 + 0.04;
      if (plane == 2 && x0 > 0.28 && x0 < 0.72) {
        x0 = x0 < 0.5 ? x0 * 0.52 + 0.04 : 0.96 - (1.0 - x0) * 0.52;
      }
      final swayCycles = plane == 0 ? 1 : 2;
      final swayPhase = ((i * 19) % 100) / 100.0;
      final driftAmp = (12.0 + (i % 5) * 5.0) * planeScale;
      final dx =
          math.sin(2.0 * math.pi * (swayPhase + t * swayCycles)) * driftAmp;
      final cx = size.width * x0 + dx;

      final baseRot = ((i * 53) % 628) / 100.0;
      final rotPhase = ((i * 29) % 100) / 100.0;
      final rotCycles = plane == 2 ? (i.isEven ? 1 : -1) : 0;
      final rot =
          baseRot +
          math.sin(2.0 * math.pi * (rotPhase + t * (plane + 1))) * 0.65 +
          2.0 * math.pi * t * rotCycles;

      final tiltPhase = ((i * 43) % 100) / 100.0;
      final foreshorten =
          0.55 +
          0.45 *
              (0.5 +
                  0.5 *
                      math.cos(2.0 * math.pi * (tiltPhase + t * (plane + 1))));

      final baseR = (9.0 + ((i * 5) % 5) * 1.1) * planeScale;
      final isGinkgo = i % 7 == 2 || i % 7 == 5;

      canvas
        ..save()
        ..translate(cx, cy)
        ..rotate(rot)
        ..scale(1, foreshorten);

      if (isGinkgo) {
        _drawIcho(canvas, baseR, alpha);
      } else {
        final color = _momijiPalette[i % _momijiPalette.length];
        _drawMomiji(canvas, baseR, color, alpha);
      }

      canvas.restore();
    }
  }

  void _drawMomiji(Canvas canvas, double r, Color color, double alpha) {
    final fillPaint = Paint()
      ..color = color.withValues(alpha: alpha)
      ..style = PaintingStyle.fill;
    final stemPaint = Paint()
      ..color = color.withValues(alpha: (alpha * 0.88).clamp(0.0, 1.0))
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(0.8, r * 0.085)
      ..strokeCap = StrokeCap.round;

    final path = Path()..moveTo(0, r * 0.24);
    const lobeAngles = [-1.32, -0.64, 0.0, 0.64, 1.32];
    const lobeLengths = [0.68, 0.90, 1.05, 0.90, 0.68];
    const lobeWidths = [0.16, 0.19, 0.21, 0.19, 0.16];

    for (var k = 0; k < 5; k++) {
      final ang = lobeAngles[k] - math.pi / 2.0;
      final len = r * lobeLengths[k];
      final hw = r * lobeWidths[k];
      final cosA = math.cos(ang);
      final sinA = math.sin(ang);
      final px = -sinA;
      final py = cosA;

      final tipX = cosA * len;
      final tipY = sinA * len;
      final midX = cosA * (len * 0.58);
      final midY = sinA * (len * 0.58);
      final toothX = cosA * (len * 0.72);
      final toothY = sinA * (len * 0.72);

      path
        ..lineTo(midX - px * hw, midY - py * hw)
        ..lineTo(toothX - px * (hw * 0.55), toothY - py * (hw * 0.55))
        ..lineTo(tipX, tipY)
        ..lineTo(toothX + px * (hw * 0.55), toothY + py * (hw * 0.55))
        ..lineTo(midX + px * hw, midY + py * hw);

      if (k < 4) {
        final sinusAng =
            (lobeAngles[k] + lobeAngles[k + 1]) * 0.5 - math.pi / 2.0;
        final sinusR = r * 0.28;
        path.lineTo(math.cos(sinusAng) * sinusR, math.sin(sinusAng) * sinusR);
      }
    }

    path
      ..lineTo(0, r * 0.24)
      ..close();

    canvas.drawPath(path, fillPaint);

    final stemPath = Path()
      ..moveTo(0, r * 0.22)
      ..quadraticBezierTo(r * 0.06, r * 0.55, r * 0.09, r * 0.85);
    canvas.drawPath(stemPath, stemPaint);

    final veinPaint = Paint()
      ..color = const Color(0xFF4B180E).withValues(alpha: alpha * 0.35)
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(0.6, r * 0.055)
      ..strokeCap = StrokeCap.round;
    for (var k = 0; k < 5; k++) {
      final ang = lobeAngles[k] - math.pi / 2.0;
      final len = r * lobeLengths[k] * 0.72;
      canvas.drawLine(
        Offset(0, r * 0.20),
        Offset(math.cos(ang) * len, math.sin(ang) * len),
        veinPaint,
      );
    }
  }

  void _drawIcho(Canvas canvas, double r, double alpha) {
    final fillPaint = Paint()
      ..color = _ichoColor.withValues(alpha: alpha)
      ..style = PaintingStyle.fill;
    final veinPaint = Paint()
      ..color = const Color(0xFF8C6214).withValues(alpha: alpha * 0.55)
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(0.75, r * 0.075)
      ..strokeCap = StrokeCap.round;

    final path = Path()
      ..moveTo(0, r * 0.44)
      ..quadraticBezierTo(-r * 0.42, r * 0.08, -r * 0.86, -r * 0.26)
      ..quadraticBezierTo(-r * 0.46, -r * 0.76, -r * 0.08, -r * 0.46)
      ..lineTo(0, -r * 0.20)
      ..lineTo(r * 0.08, -r * 0.46)
      ..quadraticBezierTo(r * 0.46, -r * 0.76, r * 0.86, -r * 0.26)
      ..quadraticBezierTo(r * 0.42, r * 0.08, 0, r * 0.44)
      ..close();

    canvas.drawPath(path, fillPaint);

    final stemAndVein = Path()
      ..moveTo(-r * 0.04, r * 0.86)
      ..quadraticBezierTo(0, r * 0.62, 0, r * 0.44)
      ..lineTo(0, -r * 0.20);
    canvas.drawPath(stemAndVein, veinPaint);
  }

  @override
  bool shouldRepaint(covariant AutumnLeavesPainter oldDelegate) =>
      oldDelegate._effectiveProgress != _effectiveProgress ||
      oldDelegate._repaint != _repaint;
}

class HankoSealWidget extends StatelessWidget {
  const new({this.text = '影', this.size = 44.0, super.key});

  final String text;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: const Color(0x1AD9533F),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: _cinnabarRed, width: 2),
      ),
      alignment: Alignment.center,
      child: Text(
        text,
        style: TextStyle(
          color: _cinnabarRed,
          fontSize: size * 0.55,
          fontWeight: FontWeight.w900,
          fontFamily: 'serif',
          height: 1,
        ),
      ),
    );
  }
}

class TitleMenuOverlay extends StatefulWidget {
  const new({
    required this.onEnterValley,
    this.audioDriver,
    this.onFieldNotes,
    this.onSettings,
    super.key,
  });

  final VoidCallback onEnterValley;
  final ShukubaAudioDriver? audioDriver;
  final VoidCallback? onFieldNotes;
  final VoidCallback? onSettings;

  @override
  State<TitleMenuOverlay> createState() => _TitleMenuOverlayState();
}

class _TitleMenuOverlayState extends State<TitleMenuOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _leafController;

  @override
  void initState() {
    super.initState();
    _leafController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 20),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final disableAnimations = MediaQuery.disableAnimationsOf(context);
    if (disableAnimations) {
      if (_leafController.isAnimating) {
        _leafController.stop();
      }
    } else {
      if (!_leafController.isAnimating) {
        _leafController.repeat();
      }
    }
  }

  @override
  void dispose() {
    _leafController.dispose();
    super.dispose();
  }

  void _showFieldNotesDialog(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: _urushiDark,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: const BorderSide(color: _borderStroke),
        ),
        title: const Row(
          children: [
            HankoSealWidget(text: '記', size: 30),
            SizedBox(width: 10),
            Text(
              'Field Notes (野帳)',
              style: TextStyle(color: _washiInk, fontSize: 18),
            ),
          ],
        ),
        content: const SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Welcome to Kage no Machi (影の町), an Edo post-town diorama'
                ' builder.',
                style: TextStyle(color: _washiInk, fontSize: 13),
              ),
              SizedBox(height: 12),
              Text(
                '• Camera Controls: WASD or arrow keys to pan, right-click'
                ' drag or Q and E to orbit, scroll wheel to zoom.\n'
                '• Views Menu: Open Views in the top-left bar or press 1 to 6'
                ' to jump between valley camera presets.\n'
                '• Builder Dock: Click a category tab at the bottom to open'
                ' its drawer of houses, roads, trees, or shrine courts.\n'
                '• Building Variations: Press V (or click Style) to cycle'
                ' farmhouse, townhouse, teahouse, storehouse, and stall'
                ' silhouettes. Each placement advances automatically.\n'
                '• Stamp Rotation: Press R to rotate active stamps by'
                ' 45 degrees.\n'
                '• Esc & F3: Esc cancels strokes, closes the active tool, or'
                ' opens the pause menu. F3 toggles live frame telemetry.',
                style: TextStyle(color: _mutedSand, fontSize: 12, height: 1.5),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(),
            child: const Text(
              'Close (閉じる)',
              style: TextStyle(color: _goldAccent),
            ),
          ),
        ],
      ),
    );
  }

  void _showSettingsDialog(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (dialogCtx) =>
          _TitleSettingsDialog(audioDriver: widget.audioDriver),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment(0, -0.1),
            radius: 1.2,
            colors: [_urushiDark, _urushiBlack],
          ),
        ),
        child: CustomPaint(
          painter: const KinpakuPainter(),
          child: AnimatedBuilder(
            animation: _leafController,
            builder: (context, child) {
              return CustomPaint(
                painter: AutumnLeavesPainter(
                  progress: _leafController.value,
                  repaint: _leafController,
                ),
                child: child,
              );
            },
            child: SafeArea(
              child: Center(
                child: SingleChildScrollView(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 32,
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const HankoSealWidget(size: 52),
                        const SizedBox(height: 18),

                        Text(
                          '影の町',
                          style: TextStyle(
                            color: _washiInk,
                            fontSize: 56,
                            fontWeight: FontWeight.w700,
                            fontFamily: 'serif',
                            letterSpacing: 8,
                            shadows: [
                              Shadow(
                                color: Colors.black.withValues(alpha: 0.8),
                                offset: const Offset(2, 4),
                                blurRadius: 8,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 8),

                        const Text(
                          'KAGE NO MACHI',
                          style: TextStyle(
                            color: _goldAccent,
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 4.2,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Edo Post-Town Diorama Builder',
                          style: TextStyle(
                            color: _mutedSand.withValues(alpha: 0.78),
                            fontSize: 11.5,
                            letterSpacing: 1.2,
                          ),
                        ),
                        const SizedBox(height: 48),

                        SizedBox(
                          width: 300,
                          height: 46,
                          child: ElevatedButton(
                            onPressed: widget.onEnterValley,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _cinnabarRed,
                              foregroundColor: _washiInk,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(6),
                              ),
                              elevation: 4,
                            ),
                            child: const Text(
                              'Enter Valley (渓谷へ入る)',
                              maxLines: 1,
                              softWrap: false,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),

                        SizedBox(
                          width: 300,
                          height: 46,
                          child: OutlinedButton(
                            onPressed: () {
                              if (widget.onFieldNotes != null) {
                                widget.onFieldNotes!();
                              } else {
                                _showFieldNotesDialog(context);
                              }
                            },
                            style: OutlinedButton.styleFrom(
                              foregroundColor: _washiInk,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                              ),
                              side: const BorderSide(color: _borderStroke),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(6),
                              ),
                            ),
                            child: const Text(
                              'Field Notes (野帳)',
                              maxLines: 1,
                              softWrap: false,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),

                        SizedBox(
                          width: 300,
                          height: 46,
                          child: OutlinedButton(
                            onPressed: () {
                              if (widget.onSettings != null) {
                                widget.onSettings!();
                              } else {
                                _showSettingsDialog(context);
                              }
                            },
                            style: OutlinedButton.styleFrom(
                              foregroundColor: _mutedSand,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                              ),
                              side: const BorderSide(color: _borderStroke),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(6),
                              ),
                            ),
                            child: const Text(
                              'Settings (設定)',
                              maxLines: 1,
                              softWrap: false,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w500,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class LoadingCurtainOverlay extends StatelessWidget {
  const new({
    required this.activeStage,
    required this.completedTimings,
    super.key,
  });

  final BootStageId activeStage;
  final List<BootStageTiming> completedTimings;

  @override
  Widget build(BuildContext context) {
    final timingsByStage = <BootStageId, BootStageTiming>{
      for (final t in completedTimings) t.stage: t,
    };
    final progress = (completedTimings.length / 6.0).clamp(0.0, 1.0);

    return Material(
      color: Colors.transparent,
      child: DecoratedBox(
        decoration: const BoxDecoration(color: Color(0xF20E1015)),
        child: Center(
          child: SingleChildScrollView(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Padding(
                padding: const EdgeInsets.all(28),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Row(
                      children: [
                        HankoSealWidget(text: '組', size: 34),
                        SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Preparing Shukuba Valley',
                                style: TextStyle(
                                  color: _washiInk,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.8,
                                ),
                              ),
                              Text(
                                '宿場町の構築 (Staged Warmup)',
                                style: TextStyle(
                                  color: _goldAccent,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    for (final stage in BootStageId.values) ...[
                      _buildStageRow(stage, timingsByStage[stage]),
                      const SizedBox(height: 10),
                    ],
                    const SizedBox(height: 16),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(2),
                      child: SizedBox(
                        height: 4,
                        child: LinearProgressIndicator(
                          value: progress,
                          backgroundColor: const Color(0x33DECBAE),
                          valueColor: const AlwaysStoppedAnimation<Color>(
                            _goldAccent,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStageRow(BootStageId stage, BootStageTiming? timing) {
    final isDone = timing != null;
    final isActive = stage == activeStage && !isDone;

    return Row(
      children: [
        SizedBox(
          width: 22,
          height: 22,
          child: Center(
            child: isDone
                ? const Text(
                    '✓',
                    style: TextStyle(
                      color: _goldAccent,
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                    ),
                  )
                : (isActive
                      ? const SizedBox(
                          width: 12,
                          height: 12,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              _cinnabarRed,
                            ),
                          ),
                        )
                      : Container(
                          width: 6,
                          height: 6,
                          decoration: const BoxDecoration(
                            color: Color(0x44DECBAE),
                            shape: BoxShape.circle,
                          ),
                        )),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                stage.label,
                style: TextStyle(
                  color: isDone
                      ? _washiInk
                      : (isActive
                            ? _goldAccent
                            : _mutedSand.withValues(alpha: 0.45)),
                  fontSize: 12,
                  fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
              if (isActive)
                Text(
                  stage.detail,
                  style: TextStyle(
                    color: _mutedSand.withValues(alpha: 0.72),
                    fontSize: 10,
                  ),
                ),
            ],
          ),
        ),
        if (isDone)
          Text(
            '${timing.durationMs.toStringAsFixed(1)} ms',
            style: const TextStyle(
              color: _goldAccent,
              fontSize: 11,
              fontFamily: 'monospace',
            ),
          ),
      ],
    );
  }
}

class PauseMenuOverlay extends StatefulWidget {
  const new({
    required this.onResume,
    required this.onReturnToTitle,
    required this.audioDriver,
    super.key,
  });

  final VoidCallback onResume;
  final VoidCallback onReturnToTitle;
  final ShukubaAudioDriver audioDriver;

  @override
  State<PauseMenuOverlay> createState() => _PauseMenuOverlayState();
}

class _PauseMenuOverlayState extends State<PauseMenuOverlay> {
  late double _volume = widget.audioDriver.masterVolume;
  late bool _muted = widget.audioDriver.isMuted;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Stack(
        fit: StackFit.expand,
        children: [
          BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
            child: const ColoredBox(color: _overlayBackdrop),
          ),
          Center(
            child: SingleChildScrollView(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 520),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: _urushiDark,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: _borderStroke),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.6),
                        blurRadius: 20,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(26),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Row(
                          children: [
                            HankoSealWidget(text: '休', size: 32),
                            SizedBox(width: 12),
                            Text(
                              'PAUSE — 一服 (Ippuku)',
                              style: TextStyle(
                                color: _washiInk,
                                fontSize: 17,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 1,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),

                        const Text(
                          'Audio & Ambience (音量設定)',
                          style: TextStyle(
                            color: _goldAccent,
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.6,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            IconButton(
                              icon: Icon(
                                _muted ? Icons.volume_off : Icons.volume_up,
                                color: _muted ? _cinnabarRed : _goldAccent,
                              ),
                              tooltip: _muted ? 'Unmute' : 'Mute',
                              onPressed: () {
                                setState(() {
                                  _muted = !_muted;
                                  widget.audioDriver.setMuted(_muted);
                                });
                              },
                            ),
                            Expanded(
                              child: Slider(
                                value: _volume,
                                activeColor: _goldAccent,
                                inactiveColor: const Color(0x33DECBAE),
                                onChanged: (val) {
                                  setState(() {
                                    _volume = val;
                                    widget.audioDriver.setMasterVolume(val);
                                  });
                                },
                              ),
                            ),
                            SizedBox(
                              width: 44,
                              child: Text(
                                '${(_volume * 100).round()}%',
                                style: const TextStyle(
                                  color: _washiInk,
                                  fontSize: 11,
                                  fontFamily: 'monospace',
                                ),
                                textAlign: TextAlign.right,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),

                        const Text(
                          'Keybindings (操作手引き)',
                          style: TextStyle(
                            color: _goldAccent,
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.6,
                          ),
                        ),
                        const SizedBox(height: 8),
                        DecoratedBox(
                          decoration: BoxDecoration(
                            color: const Color(0x18000000),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: const Color(0x22DECBAE)),
                          ),
                          child: const Padding(
                            padding: EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 10,
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      _KeyRow(
                                        keys: 'W A S D',
                                        action: 'Pan Camera',
                                      ),
                                      SizedBox(height: 4),
                                      _KeyRow(
                                        keys: 'Q / E',
                                        action: 'Orbit View',
                                      ),
                                      SizedBox(height: 4),
                                      _KeyRow(
                                        keys: 'Scroll',
                                        action: 'Zoom View',
                                      ),
                                      SizedBox(height: 4),
                                      _KeyRow(
                                        keys: '1 – 6',
                                        action: 'Camera Presets',
                                      ),
                                    ],
                                  ),
                                ),
                                SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      _KeyRow(
                                        keys: 'V',
                                        action: 'Building Style',
                                      ),
                                      SizedBox(height: 4),
                                      _KeyRow(
                                        keys: 'R',
                                        action: 'Rotate Stamp',
                                      ),
                                      SizedBox(height: 4),
                                      _KeyRow(keys: 'Z', action: 'Undo Action'),
                                      SizedBox(height: 4),
                                      _KeyRow(
                                        keys: 'Del / X',
                                        action: 'Demolish',
                                      ),
                                      SizedBox(height: 4),
                                      _KeyRow(
                                        keys: 'F3',
                                        action: 'Telemetry Pill',
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),

                        Row(
                          children: [
                            Expanded(
                              child: SizedBox(
                                height: 44,
                                child: OutlinedButton(
                                  onPressed: widget.onReturnToTitle,
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: _mutedSand,
                                    side: const BorderSide(
                                      color: _borderStroke,
                                    ),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                  ),
                                  child: const Text(
                                    'Return to Title (表紙へ戻る)',
                                    maxLines: 1,
                                    softWrap: false,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: SizedBox(
                                height: 44,
                                child: ElevatedButton(
                                  onPressed: widget.onResume,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: _cinnabarRed,
                                    foregroundColor: _washiInk,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                  ),
                                  child: const Text(
                                    'Resume (再開)',
                                    maxLines: 1,
                                    softWrap: false,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TitleSettingsDialog extends StatefulWidget {
  const new({required this.audioDriver});

  final ShukubaAudioDriver? audioDriver;

  @override
  State<_TitleSettingsDialog> createState() => _TitleSettingsDialogState();
}

class _TitleSettingsDialogState extends State<_TitleSettingsDialog> {
  late double _volume = widget.audioDriver?.masterVolume ?? 1.0;
  late bool _muted = widget.audioDriver?.isMuted ?? false;

  @override
  Widget build(BuildContext context) {
    final driver = widget.audioDriver;
    return AlertDialog(
      backgroundColor: _urushiDark,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: const BorderSide(color: _borderStroke),
      ),
      title: const Row(
        children: [
          HankoSealWidget(text: '設', size: 28),
          SizedBox(width: 10),
          Text(
            'Settings (設定)',
            style: TextStyle(color: _washiInk, fontSize: 18),
          ),
        ],
      ),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (driver != null) ...[
                const Text(
                  'Audio & Ambience (音量設定)',
                  style: TextStyle(
                    color: _goldAccent,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.6,
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    IconButton(
                      icon: Icon(
                        _muted ? Icons.volume_off : Icons.volume_up,
                        color: _muted ? _cinnabarRed : _goldAccent,
                      ),
                      tooltip: _muted ? 'Unmute' : 'Mute',
                      onPressed: () {
                        setState(() {
                          _muted = !_muted;
                          driver.setMuted(_muted);
                        });
                      },
                    ),
                    Expanded(
                      child: Slider(
                        value: _volume,
                        activeColor: _goldAccent,
                        inactiveColor: const Color(0x33DECBAE),
                        onChanged: (val) {
                          setState(() {
                            _volume = val;
                            driver.setMasterVolume(val);
                          });
                        },
                      ),
                    ),
                    SizedBox(
                      width: 44,
                      child: Text(
                        '${(_volume * 100).round()}%',
                        style: const TextStyle(
                          color: _washiInk,
                          fontSize: 11,
                          fontFamily: 'monospace',
                        ),
                        textAlign: TextAlign.right,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
              ],
              const Text(
                'Shortcuts (操作手引き)',
                style: TextStyle(
                  color: _goldAccent,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.6,
                ),
              ),
              const SizedBox(height: 8),
              const _KeyRow(keys: 'W A S D / Drag', action: 'Pan Valley'),
              const SizedBox(height: 4),
              const _KeyRow(keys: 'Right-Drag / Q E', action: 'Orbit View'),
              const SizedBox(height: 4),
              const _KeyRow(keys: '1 – 6', action: 'Camera Views'),
              const SizedBox(height: 4),
              const _KeyRow(keys: 'V / R', action: 'Style / Rotate Stamp'),
              const SizedBox(height: 4),
              const _KeyRow(keys: 'Esc / F3', action: 'Pause / Telemetry'),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('OK', style: TextStyle(color: _goldAccent)),
        ),
      ],
    );
  }
}

class _KeyRow extends StatelessWidget {
  const new({required this.keys, required this.action});

  final String keys;
  final String action;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
          decoration: BoxDecoration(
            color: const Color(0x33DECBAE),
            borderRadius: BorderRadius.circular(3),
          ),
          child: Text(
            keys,
            style: const TextStyle(
              color: _washiInk,
              fontSize: 10,
              fontFamily: 'monospace',
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            action,
            style: TextStyle(
              color: _mutedSand.withValues(alpha: 0.8),
              fontSize: 10.5,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

class TelemetryMonitorPill extends StatefulWidget {
  const new({required this.snapshot, super.key});

  final FrameTelemetrySnapshot snapshot;

  @override
  State<TelemetryMonitorPill> createState() => _TelemetryMonitorPillState();
}

class _TelemetryMonitorPillState extends State<TelemetryMonitorPill> {
  bool _expanded = false;

  Color _fpsColor(double fps) {
    if (fps >= 55) return const Color(0xFF4CAF50);
    if (fps >= 30) return const Color(0xFFFFB300);
    return _cinnabarRed;
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.snapshot;
    final fpsDotColor = _fpsColor(s.fps);

    return GestureDetector(
      onTap: () => setState(() => _expanded = !_expanded),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: const Color(0xEB10141D),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _borderStroke),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.35),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: fpsDotColor,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 7),
                  Text(
                    '${s.fps.toStringAsFixed(0)} FPS',
                    style: TextStyle(
                      color: fpsDotColor,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      fontFamily: 'monospace',
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '| UI: ${s.uiMs.toStringAsFixed(1)}ms',
                    style: const TextStyle(
                      color: _washiInk,
                      fontSize: 10.5,
                      fontFamily: 'monospace',
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Raster: ${s.rasterMs.toStringAsFixed(1)}ms',
                    style: const TextStyle(
                      color: _washiInk,
                      fontSize: 10.5,
                      fontFamily: 'monospace',
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '| St: ${s.structureCount} Ln: ${s.lanternSpanCount}',
                    style: TextStyle(
                      color: _mutedSand.withValues(alpha: 0.8),
                      fontSize: 10.5,
                      fontFamily: 'monospace',
                    ),
                  ),
                  if (s.bootReport != null) ...[
                    const SizedBox(width: 6),
                    Icon(
                      _expanded ? Icons.expand_less : Icons.expand_more,
                      size: 14,
                      color: _goldAccent,
                    ),
                  ],
                ],
              ),
              if (_expanded && s.bootReport != null) ...[
                const SizedBox(height: 8),
                const Divider(color: _borderStroke, height: 1),
                const SizedBox(height: 6),
                Text(
                  'Boot Stages Breakdown (Total: '
                  '${s.bootReport!.totalMs.toStringAsFixed(1)} ms):',
                  style: const TextStyle(
                    color: _goldAccent,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                for (final timing in s.bootReport!.stages)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 1.5),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          width: 140,
                          child: Text(
                            timing.stage.label,
                            style: TextStyle(
                              color: _washiInk.withValues(alpha: 0.85),
                              fontSize: 9.5,
                            ),
                          ),
                        ),
                        Text(
                          '${timing.durationMs.toStringAsFixed(1)} ms',
                          style: const TextStyle(
                            color: _goldAccent,
                            fontSize: 9.5,
                            fontFamily: 'monospace',
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
