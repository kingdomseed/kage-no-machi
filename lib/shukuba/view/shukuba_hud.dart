import 'package:kage_no_machi/shukuba/model/shukuba_types.dart';
import 'package:kage_no_machi/shukuba/view/shukuba_controller.dart';
import 'package:material_ui/material_ui.dart' hide Matrix4;

class ShukubaHud extends StatelessWidget {
  const new({
    required this.controller,
    required this.onSelectPreset,
    this.onOpenMenu,
    super.key,
  });

  final ShukubaController controller;
  final ValueChanged<CameraPreset> onSelectPreset;
  final VoidCallback? onOpenMenu;

  static const Color _lacquerBg = Color(0xDC121318);
  static const Color _washiInk = Color(0xFFF4EAD7);
  static const Color _mutedSand = Color(0xFFBCAFA0);
  static const Color _amberAccent = Color(0xFFE89B42);
  static const Color _vermilionAccent = Color(0xFFD9533F);
  static const Color _borderStroke = Color(0x42DECBAE);

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final rig = controller.timeOfDay;
        final graph = controller.graph;
        final strokeCount = controller.strokePoints.length;
        final showGuidance =
            controller.activeTool is! ExploreTool || strokeCount > 0;

        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                MouseRegion(
                  onEnter: (_) => controller.updateHoverPoint(null),
                  child: SizedBox(
                    width: double.infinity,
                    child: Wrap(
                      spacing: 10,
                      runSpacing: 8,
                      alignment: WrapAlignment.spaceBetween,
                      children: [
                        _WardPlaque(
                          structureCount: graph.structures.length,
                          onSelectPreset: onSelectPreset,
                          onOpenMenu: onOpenMenu,
                        ),
                        _AtmospherePanel(
                          rig: rig,
                          audio: controller.audio,
                          onChangedTime: controller.setTimeOfDay,
                        ),
                      ],
                    ),
                  ),
                ),
                MouseRegion(
                  onEnter: (_) => controller.updateHoverPoint(null),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (showGuidance)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: _ToolGuidanceBar(
                            activeTool: controller.activeTool,
                            preview: controller.activePreview,
                            strokeCount: strokeCount,
                            onCycleVariant: controller.cycleStampVariant,
                            onRotateStamp: controller.rotateStampYaw,
                            onCommitStroke: controller.commitActiveStroke,
                            onCancelStroke: controller.cancelActiveStroke,
                            onExitTool: () =>
                                controller.selectTool(const ExploreTool()),
                          ),
                        ),
                      _CityBuilderDock(
                        activeTool: controller.activeTool,
                        canUndo: controller.canUndo,
                        onSelectTool: controller.toggleTool,
                        onUndo: controller.undo,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _WardPlaque extends StatefulWidget {
  const new({
    required this.structureCount,
    required this.onSelectPreset,
    this.onOpenMenu,
  });

  final int structureCount;
  final ValueChanged<CameraPreset> onSelectPreset;
  final VoidCallback? onOpenMenu;

  @override
  State<_WardPlaque> createState() => _WardPlaqueState();
}

class _WardPlaqueState extends State<_WardPlaque> {
  bool _viewsOpen = false;

  static const List<(String, CameraPreset)> _presets = [
    ('1 Golden Dusk', CameraPreset.duskOverview),
    ('2 Night Market', CameraPreset.nightMarket),
    ('3 Gorge Crossing', CameraPreset.riverCrossing),
    ('4 Gorge & Garden', CameraPreset.meadowCloseup),
    ('5 Valley Vista', CameraPreset.countrysideVista),
    ('6 Canopy Sun', CameraPreset.horizonSunCanopy),
  ];

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: ShukubaHud._lacquerBg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: ShukubaHud._borderStroke),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 6,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Container(
                  width: 18,
                  height: 18,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: const Color(0x1FD9533F),
                    borderRadius: BorderRadius.circular(3),
                    border: Border.all(color: ShukubaHud._vermilionAccent),
                  ),
                  child: const Text(
                    '影',
                    style: TextStyle(
                      color: ShukubaHud._vermilionAccent,
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      fontFamily: 'serif',
                      height: 1,
                    ),
                  ),
                ),
                const Text(
                  'KAGE NO MACHI',
                  style: TextStyle(
                    color: ShukubaHud._washiInk,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.4,
                  ),
                ),
                Text(
                  '· ${widget.structureCount} built',
                  style: const TextStyle(
                    color: ShukubaHud._mutedSand,
                    fontSize: 10.5,
                  ),
                ),
                GestureDetector(
                  onTap: () => setState(() => _viewsOpen = !_viewsOpen),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: _viewsOpen
                          ? ShukubaHud._amberAccent.withValues(alpha: 0.22)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: _viewsOpen
                            ? ShukubaHud._amberAccent
                            : ShukubaHud._borderStroke,
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3.5,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Views',
                            style: TextStyle(
                              color: _viewsOpen
                                  ? ShukubaHud._washiInk
                                  : ShukubaHud._mutedSand,
                              fontSize: 10.5,
                              fontWeight: _viewsOpen
                                  ? FontWeight.w700
                                  : FontWeight.w500,
                            ),
                          ),
                          const SizedBox(width: 2),
                          Icon(
                            _viewsOpen
                                ? Icons.arrow_drop_up
                                : Icons.arrow_drop_down,
                            size: 14,
                            color: _viewsOpen
                                ? ShukubaHud._amberAccent
                                : ShukubaHud._mutedSand,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                if (widget.onOpenMenu != null)
                  _ActionChip(
                    label: 'Menu',
                    active: false,
                    accent: ShukubaHud._mutedSand,
                    onTap: widget.onOpenMenu!,
                  ),
              ],
            ),
            if (_viewsOpen) ...[
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final (label, preset) in _presets)
                    _ActionChip(
                      label: label,
                      active: false,
                      accent: ShukubaHud._amberAccent,
                      onTap: () {
                        setState(() => _viewsOpen = false);
                        widget.onSelectPreset(preset);
                      },
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _AtmospherePanel extends StatefulWidget {
  const new({
    required this.rig,
    required this.audio,
    required this.onChangedTime,
  });

  final TimeOfDayRig rig;
  final ShukubaAudioDriver audio;
  final ValueChanged<double> onChangedTime;

  @override
  State<_AtmospherePanel> createState() => _AtmospherePanelState();
}

class _AtmospherePanelState extends State<_AtmospherePanel> {
  @override
  Widget build(BuildContext context) {
    final rig = widget.rig;
    final muted = widget.audio.isMuted;
    final phaseLabel = rig.isMoonlit ? 'Blue Hour' : 'Golden Dusk';
    return DecoratedBox(
      decoration: BoxDecoration(
        color: ShukubaHud._lacquerBg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: ShukubaHud._borderStroke),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              rig.isMoonlit ? Icons.nights_stay : Icons.wb_twilight,
              size: 14,
              color: rig.celestialHudColor,
            ),
            const SizedBox(width: 6),
            Text(
              phaseLabel,
              style: const TextStyle(
                color: ShukubaHud._washiInk,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
            SizedBox(
              width: 132,
              height: 24,
              child: SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  trackHeight: 2.5,
                  thumbShape: const RoundSliderThumbShape(
                    enabledThumbRadius: 5.5,
                  ),
                  overlayShape: const RoundSliderOverlayShape(
                    overlayRadius: 10,
                  ),
                  activeTrackColor: rig.celestialHudColor,
                  inactiveTrackColor: const Color(0x44F2E8D5),
                  thumbColor: ShukubaHud._washiInk,
                ),
                child: Slider(
                  value: rig.value,
                  onChanged: widget.onChangedTime,
                ),
              ),
            ),
            GestureDetector(
              onTap: () => setState(() => widget.audio.setMuted(!muted)),
              child: Tooltip(
                message: muted ? 'Unmute audio' : 'Mute audio',
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 4,
                    vertical: 2,
                  ),
                  child: Icon(
                    muted ? Icons.volume_off : Icons.volume_up,
                    size: 15,
                    color: muted
                        ? ShukubaHud._vermilionAccent
                        : ShukubaHud._mutedSand,
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

class _ToolGuidanceBar extends StatelessWidget {
  const new({
    required this.activeTool,
    required this.preview,
    required this.strokeCount,
    required this.onCycleVariant,
    required this.onRotateStamp,
    required this.onCommitStroke,
    required this.onCancelStroke,
    required this.onExitTool,
  });

  final PlacementTool activeTool;
  final BuildPreview preview;
  final int strokeCount;
  final VoidCallback onCycleVariant;
  final VoidCallback onRotateStamp;
  final VoidCallback onCommitStroke;
  final VoidCallback onCancelStroke;
  final VoidCallback onExitTool;

  String _describeGuidance() {
    switch (activeTool) {
      case ExploreTool():
        return 'Explore Valley';
      case StampStructureTool(:final kind):
        final spec = kind.spec;
        var spanHint = '';
        if (preview case StampGhostPreview(:final lanternSpans)) {
          if (lanternSpans.isNotEmpty) {
            final n = lanternSpans.length;
            spanHint = ' · +$n lantern${n == 1 ? '' : 's'}';
          }
        }
        return '${spec.displayName} · Click ground to place$spanHint';
      case DrawLaneTool(:final style):
        if (style == RoadStyle.gardenPath) {
          return 'Garden Path · Drag on ground to curve stepping stones';
        }
        return 'Road · Drag on ground to paint a curbed lane';
      case BuildTerraceTool():
        return 'Stone Terrace · Drag on ground to raise a stone plateau';
      case BuildWallTool():
        return 'Courtyard Wall · Drag on ground to enclose a compound';
      case DemolishTool():
        if (preview case DemolishHoverPreview(:final candidate)) {
          return 'Demolish · Click to remove ${candidate.label}';
        }
        return 'Demolish · Click any building, road, wall, terrace, or rock';
      case InspectWatchTool():
        return 'Town View';
    }
  }

  @override
  Widget build(BuildContext context) {
    final tool = activeTool;
    final isDemolish = tool is DemolishTool;
    final borderColor = isDemolish
        ? ShukubaHud._vermilionAccent
        : (strokeCount > 0
              ? ShukubaHud._amberAccent
              : ShukubaHud._borderStroke);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: ShukubaHud._lacquerBg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: borderColor),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        child: Wrap(
          spacing: 8,
          runSpacing: 6,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(
              _describeGuidance(),
              style: const TextStyle(
                color: ShukubaHud._washiInk,
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
            ),
            if (tool is StampStructureTool && tool.kind.spec.variantCount > 1)
              _ActionChip(
                label:
                    'Style: ${tool.kind.spec.variantLabelAt(tool.variant)} [V]',
                active: true,
                accent: ShukubaHud._amberAccent,
                onTap: onCycleVariant,
              ),
            if (tool is StampStructureTool)
              _ActionChip(
                label: 'Rotate [R]',
                active: false,
                accent: ShukubaHud._amberAccent,
                onTap: onRotateStamp,
              ),
            if (strokeCount >= 2)
              _ActionChip(
                label: 'Build [$strokeCount pts · Enter]',
                active: true,
                accent: ShukubaHud._amberAccent,
                onTap: onCommitStroke,
              ),
            if (strokeCount > 0)
              _ActionChip(
                label: 'Cancel [Esc]',
                active: false,
                accent: ShukubaHud._mutedSand,
                onTap: onCancelStroke,
              )
            else if (tool is! ExploreTool)
              _ActionChip(
                label: 'Done [Esc]',
                active: false,
                accent: ShukubaHud._mutedSand,
                onTap: onExitTool,
              ),
          ],
        ),
      ),
    );
  }
}

enum InkBrushIconKind {
  dwellingsTab,
  roadsTab,
  natureTab,
  shrinesTab,

  machiya,
  chaya,
  kura,
  minka,
  marketStall,

  road,
  gardenPath,
  terrace,
  wall,

  bamboo,
  pine,
  willow,
  maple,
  rock,

  shoroBell,
  karesansui,
  stoneWell,
  toriiGate,

  demolish,
  rotate,
  undo,
}

class InkBrushIcon extends StatelessWidget {
  const new({
    required this.icon,
    required this.color,
    this.size = 18.0,
    super.key,
  });

  final InkBrushIconKind icon;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(size, size),
      painter: InkBrushIconPainter(icon: icon, color: color),
    );
  }
}

class InkBrushIconPainter extends CustomPainter {
  const new({required this.icon, required this.color});

  final InkBrushIconKind icon;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final path = Path();

    switch (icon) {
      case InkBrushIconKind.dwellingsTab:
        path
          ..moveTo(w * 0.1, h * 0.45)
          ..quadraticBezierTo(w * 0.5, h * 0.12, w * 0.9, h * 0.45)
          ..moveTo(w * 0.28, h * 0.42)
          ..lineTo(w * 0.28, h * 0.88)
          ..moveTo(w * 0.72, h * 0.42)
          ..lineTo(w * 0.72, h * 0.88)
          ..moveTo(w * 0.28, h * 0.88)
          ..lineTo(w * 0.72, h * 0.88);
      case InkBrushIconKind.roadsTab:
        path
          ..moveTo(w * 0.2, h * 0.88)
          ..cubicTo(w * 0.2, h * 0.5, w * 0.5, h * 0.5, w * 0.5, h * 0.12)
          ..moveTo(w * 0.5, h * 0.88)
          ..cubicTo(w * 0.5, h * 0.5, w * 0.8, h * 0.5, w * 0.8, h * 0.12);
      case InkBrushIconKind.natureTab:
        path
          ..moveTo(w * 0.2, h * 0.88)
          ..quadraticBezierTo(w * 0.35, h * 0.5, w * 0.48, h * 0.2)
          ..moveTo(w * 0.35, h * 0.4)
          ..quadraticBezierTo(w * 0.7, h * 0.35, w * 0.85, h * 0.5)
          ..moveTo(w * 0.5, h * 0.88)
          ..lineTo(w * 0.85, h * 0.88);
      case InkBrushIconKind.shrinesTab:
        path
          ..moveTo(w * 0.12, h * 0.25)
          ..quadraticBezierTo(w * 0.5, h * 0.2, w * 0.88, h * 0.25)
          ..moveTo(w * 0.2, h * 0.4)
          ..lineTo(w * 0.8, h * 0.4)
          ..moveTo(w * 0.3, h * 0.25)
          ..lineTo(w * 0.26, h * 0.88)
          ..moveTo(w * 0.7, h * 0.25)
          ..lineTo(w * 0.74, h * 0.88);
      case InkBrushIconKind.machiya:
        path
          ..moveTo(w * 0.15, h * 0.4)
          ..lineTo(w * 0.5, h * 0.15)
          ..lineTo(w * 0.85, h * 0.4)
          ..moveTo(w * 0.25, h * 0.38)
          ..lineTo(w * 0.25, h * 0.85)
          ..lineTo(w * 0.75, h * 0.85)
          ..lineTo(w * 0.75, h * 0.38)
          ..moveTo(w * 0.4, h * 0.55)
          ..lineTo(w * 0.6, h * 0.55);
      case InkBrushIconKind.chaya:
        path
          ..moveTo(w * 0.1, h * 0.35)
          ..lineTo(w * 0.6, h * 0.15)
          ..lineTo(w * 0.9, h * 0.4)
          ..moveTo(w * 0.2, h * 0.36)
          ..lineTo(w * 0.2, h * 0.85)
          ..lineTo(w * 0.8, h * 0.85)
          ..moveTo(w * 0.6, h * 0.85)
          ..lineTo(w * 0.6, h * 0.5);
      case InkBrushIconKind.kura:
        path
          ..moveTo(w * 0.2, h * 0.35)
          ..lineTo(w * 0.5, h * 0.18)
          ..lineTo(w * 0.8, h * 0.35)
          ..moveTo(w * 0.25, h * 0.35)
          ..lineTo(w * 0.25, h * 0.88)
          ..lineTo(w * 0.75, h * 0.88)
          ..lineTo(w * 0.75, h * 0.35)
          ..moveTo(w * 0.42, h * 0.5)
          ..lineTo(w * 0.58, h * 0.5);
      case InkBrushIconKind.minka:
        path
          ..moveTo(w * 0.1, h * 0.5)
          ..quadraticBezierTo(w * 0.5, h * 0.1, w * 0.9, h * 0.5)
          ..moveTo(w * 0.25, h * 0.48)
          ..lineTo(w * 0.25, h * 0.88)
          ..lineTo(w * 0.75, h * 0.88)
          ..lineTo(w * 0.75, h * 0.48);
      case InkBrushIconKind.marketStall:
        path
          ..moveTo(w * 0.12, h * 0.3)
          ..lineTo(w * 0.88, h * 0.3)
          ..lineTo(w * 0.8, h * 0.5)
          ..lineTo(w * 0.2, h * 0.5)
          ..close()
          ..moveTo(w * 0.25, h * 0.5)
          ..lineTo(w * 0.25, h * 0.88)
          ..moveTo(w * 0.75, h * 0.5)
          ..lineTo(w * 0.75, h * 0.88);
      case InkBrushIconKind.road:
        path
          ..moveTo(w * 0.25, h * 0.88)
          ..lineTo(w * 0.42, h * 0.15)
          ..moveTo(w * 0.75, h * 0.88)
          ..lineTo(w * 0.58, h * 0.15)
          ..moveTo(w * 0.5, h * 0.7)
          ..lineTo(w * 0.5, h * 0.55);
      case InkBrushIconKind.gardenPath:
        path
          ..addOval(
            Rect.fromCenter(
              center: Offset(w * 0.3, h * 0.75),
              width: w * 0.22,
              height: h * 0.15,
            ),
          )
          ..addOval(
            Rect.fromCenter(
              center: Offset(w * 0.65, h * 0.5),
              width: w * 0.24,
              height: h * 0.16,
            ),
          )
          ..addOval(
            Rect.fromCenter(
              center: Offset(w * 0.38, h * 0.25),
              width: w * 0.20,
              height: h * 0.14,
            ),
          );
      case InkBrushIconKind.terrace:
        path
          ..moveTo(w * 0.15, h * 0.88)
          ..lineTo(w * 0.35, h * 0.3)
          ..lineTo(w * 0.85, h * 0.3)
          ..moveTo(w * 0.28, h * 0.58)
          ..lineTo(w * 0.85, h * 0.58);
      case InkBrushIconKind.wall:
        path
          ..moveTo(w * 0.15, h * 0.3)
          ..lineTo(w * 0.5, h * 0.2)
          ..lineTo(w * 0.85, h * 0.3)
          ..moveTo(w * 0.2, h * 0.3)
          ..lineTo(w * 0.2, h * 0.85)
          ..lineTo(w * 0.8, h * 0.85)
          ..lineTo(w * 0.8, h * 0.3);
      case InkBrushIconKind.bamboo:
        path
          ..moveTo(w * 0.35, h * 0.88)
          ..lineTo(w * 0.35, h * 0.15)
          ..moveTo(w * 0.65, h * 0.88)
          ..lineTo(w * 0.65, h * 0.25)
          ..moveTo(w * 0.28, h * 0.6)
          ..lineTo(w * 0.42, h * 0.6)
          ..moveTo(w * 0.58, h * 0.5)
          ..lineTo(w * 0.72, h * 0.5);
      case InkBrushIconKind.pine:
        path
          ..moveTo(w * 0.3, h * 0.88)
          ..quadraticBezierTo(w * 0.45, h * 0.5, w * 0.4, h * 0.2)
          ..moveTo(w * 0.2, h * 0.45)
          ..quadraticBezierTo(w * 0.5, h * 0.35, w * 0.8, h * 0.45)
          ..moveTo(w * 0.25, h * 0.25)
          ..quadraticBezierTo(w * 0.5, h * 0.18, w * 0.75, h * 0.25);
      case InkBrushIconKind.willow:
        path
          ..moveTo(w * 0.3, h * 0.88)
          ..quadraticBezierTo(w * 0.4, h * 0.4, w * 0.5, h * 0.2)
          ..moveTo(w * 0.5, h * 0.2)
          ..quadraticBezierTo(w * 0.3, h * 0.4, w * 0.2, h * 0.75)
          ..moveTo(w * 0.5, h * 0.2)
          ..quadraticBezierTo(w * 0.7, h * 0.4, w * 0.8, h * 0.75);
      case InkBrushIconKind.maple:
        path
          ..moveTo(w * 0.5, h * 0.88)
          ..lineTo(w * 0.5, h * 0.45)
          ..moveTo(w * 0.5, h * 0.45)
          ..lineTo(w * 0.25, h * 0.25)
          ..moveTo(w * 0.5, h * 0.45)
          ..lineTo(w * 0.5, h * 0.15)
          ..moveTo(w * 0.5, h * 0.45)
          ..lineTo(w * 0.75, h * 0.25);
      case InkBrushIconKind.rock:
        path
          ..moveTo(w * 0.15, h * 0.85)
          ..lineTo(w * 0.3, h * 0.4)
          ..lineTo(w * 0.65, h * 0.35)
          ..lineTo(w * 0.85, h * 0.6)
          ..lineTo(w * 0.85, h * 0.85)
          ..close()
          ..moveTo(w * 0.35, h * 0.55)
          ..lineTo(w * 0.7, h * 0.55);
      case InkBrushIconKind.shoroBell:
        path
          ..moveTo(w * 0.15, h * 0.35)
          ..lineTo(w * 0.5, h * 0.15)
          ..lineTo(w * 0.85, h * 0.35)
          ..moveTo(w * 0.25, h * 0.35)
          ..lineTo(w * 0.25, h * 0.85)
          ..moveTo(w * 0.75, h * 0.35)
          ..lineTo(w * 0.75, h * 0.85)
          ..moveTo(w * 0.42, h * 0.4)
          ..quadraticBezierTo(w * 0.5, h * 0.35, w * 0.58, h * 0.4)
          ..lineTo(w * 0.6, h * 0.65)
          ..lineTo(w * 0.4, h * 0.65)
          ..close();
      case InkBrushIconKind.karesansui:
        path
          ..addOval(
            Rect.fromCenter(
              center: Offset(w * 0.5, h * 0.5),
              width: w * 0.8,
              height: h * 0.5,
            ),
          )
          ..addOval(
            Rect.fromCenter(
              center: Offset(w * 0.5, h * 0.5),
              width: w * 0.45,
              height: h * 0.28,
            ),
          )
          ..addOval(
            Rect.fromCircle(center: Offset(w * 0.5, h * 0.5), radius: w * 0.08),
          );
      case InkBrushIconKind.stoneWell:
        path
          ..moveTo(w * 0.2, h * 0.35)
          ..lineTo(w * 0.5, h * 0.18)
          ..lineTo(w * 0.8, h * 0.35)
          ..moveTo(w * 0.28, h * 0.35)
          ..lineTo(w * 0.28, h * 0.85)
          ..moveTo(w * 0.72, h * 0.35)
          ..lineTo(w * 0.72, h * 0.85)
          ..addOval(
            Rect.fromCenter(
              center: Offset(w * 0.5, h * 0.75),
              width: w * 0.42,
              height: h * 0.18,
            ),
          );
      case InkBrushIconKind.toriiGate:
        path
          ..moveTo(w * 0.12, h * 0.25)
          ..quadraticBezierTo(w * 0.5, h * 0.18, w * 0.88, h * 0.25)
          ..moveTo(w * 0.2, h * 0.42)
          ..lineTo(w * 0.8, h * 0.42)
          ..moveTo(w * 0.3, h * 0.25)
          ..lineTo(w * 0.26, h * 0.88)
          ..moveTo(w * 0.7, h * 0.25)
          ..lineTo(w * 0.74, h * 0.88);
      case InkBrushIconKind.demolish:
        path
          ..moveTo(w * 0.25, h * 0.25)
          ..lineTo(w * 0.75, h * 0.75)
          ..moveTo(w * 0.75, h * 0.25)
          ..lineTo(w * 0.25, h * 0.75);
      case InkBrushIconKind.rotate:
        path
          ..addArc(Rect.fromLTWH(w * 0.2, h * 0.2, w * 0.6, h * 0.6), -0.5, 5)
          ..moveTo(w * 0.78, h * 0.25)
          ..lineTo(w * 0.85, h * 0.45)
          ..lineTo(w * 0.65, h * 0.45);
      case InkBrushIconKind.undo:
        path
          ..addArc(Rect.fromLTWH(w * 0.2, h * 0.2, w * 0.6, h * 0.6), 0.5, -4.8)
          ..moveTo(w * 0.22, h * 0.25)
          ..lineTo(w * 0.15, h * 0.45)
          ..lineTo(w * 0.35, h * 0.45);
    }

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant InkBrushIconPainter oldDelegate) =>
      oldDelegate.icon != icon || oldDelegate.color != color;
}

class _ToolCardSpec {
  const new({
    required this.title,
    required this.subtitle,
    required this.tool,
    required this.icon,
    this.isDestructive = false,
  });

  final String title;
  final String subtitle;
  final PlacementTool tool;
  final InkBrushIconKind icon;
  final bool isDestructive;
}

class _CategoryTabButton extends StatelessWidget {
  const new({
    required this.category,
    required this.icon,
    required this.isExpanded,
    required this.hasActiveTool,
    required this.onTap,
  });

  final HudToolCategory category;
  final InkBrushIconKind icon;
  final bool isExpanded;
  final bool hasActiveTool;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    const accent = ShukubaHud._amberAccent;
    final highlighted = isExpanded || hasActiveTool;
    return GestureDetector(
      onTap: onTap,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: isExpanded
              ? const Color(0x36DECBAE)
              : (hasActiveTool
                    ? accent.withValues(alpha: 0.16)
                    : const Color(0x18000000)),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: highlighted ? accent : ShukubaHud._borderStroke,
            width: highlighted ? 1.2 : 1.0,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              InkBrushIcon(
                icon: icon,
                color: highlighted ? accent : ShukubaHud._mutedSand,
                size: 14,
              ),
              const SizedBox(width: 5),
              Text(
                category.label,
                style: TextStyle(
                  color: highlighted
                      ? ShukubaHud._washiInk
                      : ShukubaHud._mutedSand,
                  fontSize: 11,
                  fontWeight: highlighted ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
              const SizedBox(width: 3),
              Icon(
                isExpanded ? Icons.arrow_drop_up : Icons.arrow_drop_down,
                size: 14,
                color: highlighted ? accent : ShukubaHud._mutedSand,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CityBuilderDock extends StatefulWidget {
  const new({
    required this.activeTool,
    required this.canUndo,
    required this.onSelectTool,
    required this.onUndo,
  });

  final PlacementTool activeTool;
  final bool canUndo;
  final ValueChanged<PlacementTool> onSelectTool;
  final VoidCallback onUndo;

  static const List<_ToolCardSpec> _dwellingsAndShops = [
    _ToolCardSpec(
      title: 'Townhouse',
      subtitle: 'Machiya · 4 styles',
      tool: StampStructureTool(kind: StructureKind.machiya),
      icon: InkBrushIconKind.machiya,
    ),
    _ToolCardSpec(
      title: 'Teahouse',
      subtitle: 'Chaya · 3 styles',
      tool: StampStructureTool(kind: StructureKind.chaya),
      icon: InkBrushIconKind.chaya,
    ),
    _ToolCardSpec(
      title: 'Storehouse',
      subtitle: 'Kura · 3 styles',
      tool: StampStructureTool(kind: StructureKind.kura),
      icon: InkBrushIconKind.kura,
    ),
    _ToolCardSpec(
      title: 'Farmhouse',
      subtitle: 'Minka · 4 styles',
      tool: StampStructureTool(kind: StructureKind.minka),
      icon: InkBrushIconKind.minka,
    ),
    _ToolCardSpec(
      title: 'Market Stall',
      subtitle: 'Yatai · 4 styles',
      tool: StampStructureTool(kind: StructureKind.marketStall),
      icon: InkBrushIconKind.marketStall,
    ),
  ];

  static const List<_ToolCardSpec> _roadsAndWalls = [
    _ToolCardSpec(
      title: 'Road',
      subtitle: 'Dirt & stone',
      tool: DrawLaneTool(),
      icon: InkBrushIconKind.road,
    ),
    _ToolCardSpec(
      title: 'Garden Path',
      subtitle: 'Stepping stones',
      tool: DrawLaneTool(style: RoadStyle.gardenPath, widthMeters: 1.75),
      icon: InkBrushIconKind.gardenPath,
    ),
    _ToolCardSpec(
      title: 'Stone Terrace',
      subtitle: 'Retaining wall',
      tool: BuildTerraceTool(),
      icon: InkBrushIconKind.terrace,
    ),
    _ToolCardSpec(
      title: 'Courtyard Wall',
      subtitle: 'Tiled Hei',
      tool: BuildWallTool(),
      icon: InkBrushIconKind.wall,
    ),
  ];

  static const List<_ToolCardSpec> _treesAndRocks = [
    _ToolCardSpec(
      title: 'Bamboo Grove',
      subtitle: 'Take culms',
      tool: StampStructureTool(kind: StructureKind.bambooGrove),
      icon: InkBrushIconKind.bamboo,
    ),
    _ToolCardSpec(
      title: 'Black Pine',
      subtitle: 'Gnarled Matsu',
      tool: StampStructureTool(kind: StructureKind.pineTree),
      icon: InkBrushIconKind.pine,
    ),
    _ToolCardSpec(
      title: 'Weeping Willow',
      subtitle: 'Yanagi fronds',
      tool: StampStructureTool(kind: StructureKind.weepingWillow),
      icon: InkBrushIconKind.willow,
    ),
    _ToolCardSpec(
      title: 'Maple & Rocks',
      subtitle: 'Momiji',
      tool: StampStructureTool(kind: StructureKind.mapleCluster),
      icon: InkBrushIconKind.maple,
    ),
    _ToolCardSpec(
      title: 'Rock Outcrop',
      subtitle: 'Layered Iwa',
      tool: StampStructureTool(kind: StructureKind.rockOutcrop),
      icon: InkBrushIconKind.rock,
    ),
  ];

  static const List<_ToolCardSpec> _shrinesAndCourtyards = [
    _ToolCardSpec(
      title: 'Bell Pavilion',
      subtitle: 'Shōrō bonshō',
      tool: StampStructureTool(kind: StructureKind.shoroBell),
      icon: InkBrushIconKind.shoroBell,
    ),
    _ToolCardSpec(
      title: 'Zen Gravel Court',
      subtitle: 'Karesansui',
      tool: StampStructureTool(kind: StructureKind.karesansuiGarden),
      icon: InkBrushIconKind.karesansui,
    ),
    _ToolCardSpec(
      title: 'Courtyard Well',
      subtitle: 'Stone Ido',
      tool: StampStructureTool(kind: StructureKind.stoneWell),
      icon: InkBrushIconKind.stoneWell,
    ),
    _ToolCardSpec(
      title: 'Lantern Gate',
      subtitle: 'Torii arch',
      tool: StampStructureTool(kind: StructureKind.toriiGate),
      icon: InkBrushIconKind.toriiGate,
    ),
  ];

  static List<_ToolCardSpec> _cardsFor(HudToolCategory category) {
    return switch (category) {
      HudToolCategory.dwellingsAndShops => _dwellingsAndShops,
      HudToolCategory.roadsAndWalls => _roadsAndWalls,
      HudToolCategory.treesAndRocks => _treesAndRocks,
      HudToolCategory.shrinesAndCourtyards => _shrinesAndCourtyards,
    };
  }

  @override
  State<_CityBuilderDock> createState() => _CityBuilderDockState();
}

class _CityBuilderDockState extends State<_CityBuilderDock> {
  HudToolCategory? _openCategory;

  @override
  void initState() {
    super.initState();
    _openCategory = widget.activeTool.hudCategory;
  }

  @override
  void didUpdateWidget(covariant _CityBuilderDock oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_sameToolSelection(oldWidget.activeTool, widget.activeTool)) {
      return;
    }
    if (widget.activeTool is ExploreTool) {
      _openCategory = null;
    } else if (widget.activeTool.hudCategory case final nextCat?) {
      _openCategory = nextCat;
    }
  }

  static bool _sameToolSelection(PlacementTool a, PlacementTool b) {
    return switch ((a, b)) {
      (
        StampStructureTool(kind: final ka),
        StampStructureTool(kind: final kb),
      ) =>
        ka == kb,
      (DrawLaneTool(style: final sa), DrawLaneTool(style: final sb)) =>
        sa == sb,
      _ => a.runtimeType == b.runtimeType,
    };
  }

  void _toggleCategory(HudToolCategory category) {
    setState(() {
      _openCategory = _openCategory == category ? null : category;
    });
  }

  bool _matches(PlacementTool candidate) =>
      _sameToolSelection(widget.activeTool, candidate);

  @override
  Widget build(BuildContext context) {
    final activeCat = widget.activeTool.hudCategory;
    final openCat = _openCategory;
    const demolishSpec = _ToolCardSpec(
      title: 'Demolish',
      subtitle: 'Remove [Del]',
      tool: DemolishTool(),
      icon: InkBrushIconKind.demolish,
      isDestructive: true,
    );

    return DecoratedBox(
      decoration: BoxDecoration(
        color: ShukubaHud._lacquerBg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: ShukubaHud._borderStroke),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (openCat != null) ...[
              Wrap(
                spacing: 6,
                runSpacing: 6,
                alignment: WrapAlignment.center,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  for (final spec in _CityBuilderDock._cardsFor(openCat))
                    _ToolCardButton(
                      spec: spec,
                      active: _matches(spec.tool),
                      onTap: () => widget.onSelectTool(spec.tool),
                    ),
                ],
              ),
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 6),
                child: Divider(height: 1, color: ShukubaHud._borderStroke),
              ),
            ],
            Wrap(
              spacing: 6,
              runSpacing: 6,
              alignment: WrapAlignment.center,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                _CategoryTabButton(
                  category: HudToolCategory.dwellingsAndShops,
                  icon: InkBrushIconKind.dwellingsTab,
                  isExpanded: openCat == HudToolCategory.dwellingsAndShops,
                  hasActiveTool: activeCat == HudToolCategory.dwellingsAndShops,
                  onTap: () =>
                      _toggleCategory(HudToolCategory.dwellingsAndShops),
                ),
                _CategoryTabButton(
                  category: HudToolCategory.roadsAndWalls,
                  icon: InkBrushIconKind.roadsTab,
                  isExpanded: openCat == HudToolCategory.roadsAndWalls,
                  hasActiveTool: activeCat == HudToolCategory.roadsAndWalls,
                  onTap: () => _toggleCategory(HudToolCategory.roadsAndWalls),
                ),
                _CategoryTabButton(
                  category: HudToolCategory.treesAndRocks,
                  icon: InkBrushIconKind.natureTab,
                  isExpanded: openCat == HudToolCategory.treesAndRocks,
                  hasActiveTool: activeCat == HudToolCategory.treesAndRocks,
                  onTap: () => _toggleCategory(HudToolCategory.treesAndRocks),
                ),
                _CategoryTabButton(
                  category: HudToolCategory.shrinesAndCourtyards,
                  icon: InkBrushIconKind.shrinesTab,
                  isExpanded: openCat == HudToolCategory.shrinesAndCourtyards,
                  hasActiveTool:
                      activeCat == HudToolCategory.shrinesAndCourtyards,
                  onTap: () =>
                      _toggleCategory(HudToolCategory.shrinesAndCourtyards),
                ),
                const _DockDivider(),
                _ToolCardButton(
                  spec: demolishSpec,
                  active: _matches(demolishSpec.tool),
                  onTap: () => widget.onSelectTool(demolishSpec.tool),
                ),
                Opacity(
                  opacity: widget.canUndo ? 1.0 : 0.42,
                  child: _ActionChip(
                    label: 'Undo [Z]',
                    active: false,
                    accent: ShukubaHud._mutedSand,
                    onTap: widget.canUndo ? widget.onUndo : () {},
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _DockDivider extends StatelessWidget {
  const new();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      height: 28,
      child: VerticalDivider(
        width: 8,
        thickness: 1,
        color: ShukubaHud._borderStroke,
      ),
    );
  }
}

class _ToolCardButton extends StatelessWidget {
  const new({required this.spec, required this.active, required this.onTap});

  final _ToolCardSpec spec;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final accent = spec.isDestructive
        ? ShukubaHud._vermilionAccent
        : ShukubaHud._amberAccent;
    return GestureDetector(
      onTap: onTap,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: active
              ? accent.withValues(alpha: 0.24)
              : const Color(0x22000000),
          borderRadius: BorderRadius.circular(7),
          border: Border.all(
            color: active ? accent : ShukubaHud._borderStroke,
            width: active ? 1.3 : 1.0,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3.5),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              InkBrushIcon(
                icon: spec.icon,
                color: active ? accent : ShukubaHud._mutedSand,
              ),
              const SizedBox(width: 6),
              Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    spec.title,
                    style: TextStyle(
                      color: active
                          ? ShukubaHud._washiInk
                          : ShukubaHud._mutedSand,
                      fontSize: 10.5,
                      fontWeight: active ? FontWeight.w700 : FontWeight.w600,
                    ),
                  ),
                  Text(
                    spec.subtitle,
                    style: TextStyle(
                      color: active
                          ? accent
                          : ShukubaHud._mutedSand.withValues(alpha: 0.72),
                      fontSize: 9,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ActionChip extends StatelessWidget {
  const new({
    required this.label,
    required this.active,
    required this.accent,
    required this.onTap,
  });

  final String label;
  final bool active;
  final Color accent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: active ? accent.withValues(alpha: 0.24) : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: active ? accent : ShukubaHud._borderStroke),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
          child: Text(
            label,
            style: TextStyle(
              color: active ? ShukubaHud._washiInk : ShukubaHud._mutedSand,
              fontSize: 11,
              fontWeight: active ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }
}
