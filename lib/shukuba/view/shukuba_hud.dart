import 'package:flutter/material.dart' hide Matrix4;
import 'package:kage_no_machi/shukuba/model/shukuba_types.dart';
import 'package:kage_no_machi/shukuba/view/shukuba_controller.dart';

class ShukubaHud extends StatelessWidget {
  const new({
    required this.controller,
    required this.onSelectPreset,
    super.key,
  });

  final ShukubaController controller;
  final ValueChanged<CameraPreset> onSelectPreset;

  static const Color _lacquerBg = Color(0xD6121318);
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

        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                MouseRegion(
                  onEnter: (_) => controller.updateHoverPoint(null),
                  child: SizedBox(
                    width: double.infinity,
                    child: Wrap(
                      spacing: 12,
                      runSpacing: 10,
                      alignment: WrapAlignment.spaceBetween,
                      children: [
                        _WardPlaque(
                          structureCount: graph.structures.length,
                          wallCount: graph.walls.length,
                          lanternSpanCount: graph.lanternSpans.length,
                          onSelectPreset: onSelectPreset,
                        ),
                        _AtmospherePanel(
                          rig: rig,
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
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: _ToolGuidanceBar(
                          activeTool: controller.activeTool,
                          preview: controller.activePreview,
                          strokeCount: strokeCount,
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
                        onRotateStamp: controller.rotateStampYaw,
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

class _WardPlaque extends StatelessWidget {
  const new({
    required this.structureCount,
    required this.wallCount,
    required this.lanternSpanCount,
    required this.onSelectPreset,
  });

  final int structureCount;
  final int wallCount;
  final int lanternSpanCount;
  final ValueChanged<CameraPreset> onSelectPreset;

  @override
  Widget build(BuildContext context) {
    const presets = [
      ('1 Golden Dusk', CameraPreset.duskOverview),
      ('2 Night Market', CameraPreset.nightMarket),
      ('3 Gorge Crossing', CameraPreset.riverCrossing),
    ];
    return DecoratedBox(
      decoration: BoxDecoration(
        color: ShukubaHud._lacquerBg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: ShukubaHud._borderStroke),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'KAGE NO MACHI · EDO POST-TOWN',
              style: TextStyle(
                color: ShukubaHud._washiInk,
                fontSize: 12,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.5,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              '$structureCount buildings & trees · $wallCount walls · '
              '$lanternSpanCount lantern spans',
              style: const TextStyle(
                color: ShukubaHud._mutedSand,
                fontSize: 11,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final (label, preset) in presets)
                  _ActionChip(
                    label: label,
                    active: false,
                    accent: ShukubaHud._amberAccent,
                    onTap: () => onSelectPreset(preset),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _AtmospherePanel extends StatelessWidget {
  const new({required this.rig, required this.onChangedTime});

  final TimeOfDayRig rig;
  final ValueChanged<double> onChangedTime;

  @override
  Widget build(BuildContext context) {
    final phaseLabel = rig.isMoonlit ? 'Blue Hour Night' : 'Golden Dusk';
    return DecoratedBox(
      decoration: BoxDecoration(
        color: ShukubaHud._lacquerBg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: ShukubaHud._borderStroke),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  rig.isMoonlit ? Icons.nights_stay : Icons.wb_twilight,
                  size: 14,
                  color: rig.celestialHudColor,
                ),
                const SizedBox(width: 6),
                Text(
                  '$phaseLabel · ${rig.scale.label}',
                  style: const TextStyle(
                    color: ShukubaHud._washiInk,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            SizedBox(
              width: 230,
              height: 26,
              child: SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  trackHeight: 3,
                  thumbShape: const RoundSliderThumbShape(
                    enabledThumbRadius: 6,
                  ),
                  activeTrackColor: rig.celestialHudColor,
                  inactiveTrackColor: const Color(0x44F2E8D5),
                  thumbColor: ShukubaHud._washiInk,
                ),
                child: Slider(value: rig.value, onChanged: onChangedTime),
              ),
            ),
            const Text(
              'Right-drag or WASD pan · Scroll zoom · Q/E orbit',
              style: TextStyle(color: ShukubaHud._mutedSand, fontSize: 10),
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
    required this.onCommitStroke,
    required this.onCancelStroke,
    required this.onExitTool,
  });

  final PlacementTool activeTool;
  final BuildPreview preview;
  final int strokeCount;
  final VoidCallback onCommitStroke;
  final VoidCallback onCancelStroke;
  final VoidCallback onExitTool;

  String _describeGuidance() {
    switch (activeTool) {
      case ExploreTool():
        return 'Select any building, lane, wall, or tree below to start '
            'building · Drag to pan · Scroll to zoom · Q/E orbit';
      case StampStructureTool(:final kind):
        final spec = kind.spec;
        var spanHint = '';
        if (preview case StampGhostPreview(:final lanternSpans)) {
          if (lanternSpans.isNotEmpty) {
            final n = lanternSpans.length;
            spanHint = ' · +$n lantern string${n == 1 ? '' : 's'} ready';
          }
        }
        final snapNote = spec.straddlesRoad
            ? 'Straddles lanes automatically'
            : (spec.snapsToRoadTangent
                  ? 'Faces nearest lane automatically'
                  : 'Free garden placement');
        return '${spec.displayName} (${spec.edoSubtitle}) · '
            'Left-click to place · $snapNote$spanHint · [R] Rotate';
      case DrawLaneTool():
        return 'Cobble Lane (Kaidō path) · '
            'Click and drag on ground to paint a gravel & stepping-stone lane';
      case BuildTerraceTool():
        return 'Stone Terrace (Ishigaki retaining wall) · '
            'Click and drag to raise a fitted castle-stone platform';
      case BuildWallTool():
        return 'Courtyard Wall (Hei plaster & tile wall) · '
            'Click and drag to enclose compounds and gardens';
      case DemolishTool():
        if (preview case DemolishHoverPreview(:final candidate)) {
          return 'Demolish · Left-click to remove ${candidate.label} · '
              '[Z] Undo';
        }
        return 'Demolish · Hover any building, wall, terrace, or side lane '
            'and click to remove · [Z] Undo';
      case InspectWatchTool():
        return 'Town View';
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDemolish = activeTool is DemolishTool;
    final isToolActive = activeTool is! ExploreTool;
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
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
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
            else if (isToolActive)
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

class _ToolCardSpec {
  const new({
    required this.title,
    required this.subtitle,
    required this.tool,
    this.isDestructive = false,
  });

  final String title;
  final String subtitle;
  final PlacementTool tool;
  final bool isDestructive;
}

class _CityBuilderDock extends StatelessWidget {
  const new({
    required this.activeTool,
    required this.canUndo,
    required this.onSelectTool,
    required this.onRotateStamp,
    required this.onUndo,
  });

  final PlacementTool activeTool;
  final bool canUndo;
  final ValueChanged<PlacementTool> onSelectTool;
  final VoidCallback onRotateStamp;
  final VoidCallback onUndo;

  static const List<_ToolCardSpec> _buildings = [
    _ToolCardSpec(
      title: 'Townhouse',
      subtitle: 'Machiya',
      tool: StampStructureTool(kind: StructureKind.machiya),
    ),
    _ToolCardSpec(
      title: 'Teahouse',
      subtitle: 'Chaya inn',
      tool: StampStructureTool(kind: StructureKind.chaya),
    ),
    _ToolCardSpec(
      title: 'Storehouse',
      subtitle: 'White Kura',
      tool: StampStructureTool(kind: StructureKind.kura),
    ),
    _ToolCardSpec(
      title: 'Market Stall',
      subtitle: 'Yatai booth',
      tool: StampStructureTool(kind: StructureKind.marketStall),
    ),
    _ToolCardSpec(
      title: 'Lantern Gate',
      subtitle: 'Torii arch',
      tool: StampStructureTool(kind: StructureKind.toriiGate),
    ),
  ];

  static const List<_ToolCardSpec> _pathsAndWalls = [
    _ToolCardSpec(
      title: 'Cobble Lane',
      subtitle: 'Drag path',
      tool: DrawLaneTool(),
    ),
    _ToolCardSpec(
      title: 'Stone Terrace',
      subtitle: 'Drag wall',
      tool: BuildTerraceTool(),
    ),
    _ToolCardSpec(
      title: 'Courtyard Wall',
      subtitle: 'Tiled Hei',
      tool: BuildWallTool(),
    ),
  ];

  static const List<_ToolCardSpec> _nature = [
    _ToolCardSpec(
      title: 'Maple & Rocks',
      subtitle: 'Momiji',
      tool: StampStructureTool(kind: StructureKind.mapleCluster),
    ),
    _ToolCardSpec(
      title: 'Bamboo Grove',
      subtitle: 'Take culms',
      tool: StampStructureTool(kind: StructureKind.bambooGrove),
    ),
  ];

  bool _matches(PlacementTool candidate) {
    if (activeTool case StampStructureTool(kind: final a)) {
      if (candidate case StampStructureTool(kind: final b)) {
        return a == b;
      }
    }
    return activeTool.runtimeType == candidate.runtimeType;
  }

  @override
  Widget build(BuildContext context) {
    final isStamp = activeTool is StampStructureTool;
    const demolishSpec = _ToolCardSpec(
      title: 'Demolish',
      subtitle: 'Remove [Del]',
      tool: DemolishTool(),
      isDestructive: true,
    );

    return DecoratedBox(
      decoration: BoxDecoration(
        color: ShukubaHud._lacquerBg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: ShukubaHud._borderStroke),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        child: Wrap(
          spacing: 6,
          runSpacing: 6,
          alignment: WrapAlignment.center,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            for (final spec in _buildings)
              _ToolCardButton(
                spec: spec,
                active: _matches(spec.tool),
                onTap: () => onSelectTool(spec.tool),
              ),
            const _DockDivider(),
            for (final spec in _pathsAndWalls)
              _ToolCardButton(
                spec: spec,
                active: _matches(spec.tool),
                onTap: () => onSelectTool(spec.tool),
              ),
            const _DockDivider(),
            for (final spec in _nature)
              _ToolCardButton(
                spec: spec,
                active: _matches(spec.tool),
                onTap: () => onSelectTool(spec.tool),
              ),
            const _DockDivider(),
            if (isStamp)
              _ActionChip(
                label: 'Rotate [R]',
                active: false,
                accent: ShukubaHud._amberAccent,
                onTap: onRotateStamp,
              ),
            _ToolCardButton(
              spec: demolishSpec,
              active: _matches(demolishSpec.tool),
              onTap: () => onSelectTool(demolishSpec.tool),
            ),
            Opacity(
              opacity: canUndo ? 1.0 : 0.42,
              child: _ActionChip(
                label: 'Undo [Z]',
                active: false,
                accent: ShukubaHud._mutedSand,
                onTap: canUndo ? onUndo : () {},
              ),
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
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                spec.title,
                style: TextStyle(
                  color: active ? ShukubaHud._washiInk : ShukubaHud._mutedSand,
                  fontSize: 11,
                  fontWeight: active ? FontWeight.w700 : FontWeight.w600,
                ),
              ),
              Text(
                spec.subtitle,
                style: TextStyle(
                  color: active
                      ? accent
                      : ShukubaHud._mutedSand.withValues(alpha: 0.72),
                  fontSize: 9.5,
                ),
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
