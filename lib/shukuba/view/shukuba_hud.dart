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

  static const Color _lacquerBg = Color(0xCC141316);
  static const Color _washiInk = Color(0xFFF2E8D5);
  static const Color _mutedSand = Color(0xFFB9AC96);
  static const Color _amberAccent = Color(0xFFE59A46);
  static const Color _jadeSight = Color(0xFF39C494);
  static const Color _borderStroke = Color(0x44D6C5A9);

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final rig = controller.timeOfDay;
        final graph = controller.graph;
        final visionActive =
            controller.effectiveVision != MagistrateVisionState.hidden;
        final strokeCount = controller.strokePoints.length;

        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                SizedBox(
                  width: double.infinity,
                  child: Wrap(
                    spacing: 12,
                    runSpacing: 10,
                    alignment: WrapAlignment.spaceBetween,
                    children: [
                      _WardPlaque(
                        structureCount: graph.structures.length,
                        lanternSpanCount: graph.lanternSpans.length,
                        scaleLabel: rig.scale.label,
                        onSelectPreset: onSelectPreset,
                      ),
                      _AtmospherePanel(
                        rig: rig,
                        visionActive: visionActive,
                        onChangedTime: controller.setTimeOfDay,
                        onToggleVision: controller.toggleMagistrateEye,
                      ),
                    ],
                  ),
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (strokeCount > 0)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: _StrokeBanner(
                          pointCount: strokeCount,
                          canCommit: strokeCount >= 2,
                          onCommit: controller.commitActiveStroke,
                          onCancel: controller.cancelActiveStroke,
                        ),
                      ),
                    _PaletteBar(
                      activeTool: controller.activeTool,
                      onSelectTool: controller.selectTool,
                      onRotateStamp: controller.rotateStampYaw,
                    ),
                  ],
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
    required this.lanternSpanCount,
    required this.scaleLabel,
    required this.onSelectPreset,
  });

  final int structureCount;
  final int lanternSpanCount;
  final String scaleLabel;
  final ValueChanged<CameraPreset> onSelectPreset;

  @override
  Widget build(BuildContext context) {
    const presets = [
      ('1 Dusk', CameraPreset.duskOverview),
      ('2 Market', CameraPreset.nightMarket),
      ('3 Watch', CameraPreset.magistrateWatchtower),
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
              'KAGE NO MACHI',
              style: TextStyle(
                color: ShukubaHud._washiInk,
                fontSize: 13,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.8,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              '$structureCount structures · $lanternSpanCount lantern spans · '
              '$scaleLabel',
              style: const TextStyle(
                color: ShukubaHud._mutedSand,
                fontSize: 11,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final (label, preset) in presets)
                  Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: _CompactChip(
                      label: label,
                      active: false,
                      accent: ShukubaHud._amberAccent,
                      onTap: () => onSelectPreset(preset),
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

class _AtmospherePanel extends StatelessWidget {
  const new({
    required this.rig,
    required this.visionActive,
    required this.onChangedTime,
    required this.onToggleVision,
  });

  final TimeOfDayRig rig;
  final bool visionActive;
  final ValueChanged<double> onChangedTime;
  final VoidCallback onToggleVision;

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
                  Icons.brightness_4,
                  size: 14,
                  color: rig.celestialHudColor,
                ),
                const SizedBox(width: 6),
                Text(
                  phaseLabel,
                  style: const TextStyle(
                    color: ShukubaHud._washiInk,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(width: 10),
                _CompactChip(
                  label: "Magistrate's Eye [Tab]",
                  active: visionActive,
                  accent: ShukubaHud._jadeSight,
                  onTap: onToggleVision,
                ),
              ],
            ),
            SizedBox(
              width: 240,
              height: 28,
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
          ],
        ),
      ),
    );
  }
}

class _StrokeBanner extends StatelessWidget {
  const new({
    required this.pointCount,
    required this.canCommit,
    required this.onCommit,
    required this.onCancel,
  });

  final int pointCount;
  final bool canCommit;
  final VoidCallback onCommit;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: ShukubaHud._lacquerBg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: ShukubaHud._amberAccent),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '$pointCount stroke anchor${pointCount == 1 ? '' : 's'} placed',
              style: const TextStyle(color: ShukubaHud._washiInk, fontSize: 11),
            ),
            const SizedBox(width: 10),
            if (canCommit)
              _CompactChip(
                label: 'Build [Enter]',
                active: true,
                accent: ShukubaHud._amberAccent,
                onTap: onCommit,
              ),
            const SizedBox(width: 6),
            _CompactChip(
              label: 'Cancel [Esc]',
              active: false,
              accent: ShukubaHud._mutedSand,
              onTap: onCancel,
            ),
          ],
        ),
      ),
    );
  }
}

class _PaletteBar extends StatelessWidget {
  const new({
    required this.activeTool,
    required this.onSelectTool,
    required this.onRotateStamp,
  });

  final PlacementTool activeTool;
  final ValueChanged<PlacementTool> onSelectTool;
  final VoidCallback onRotateStamp;

  static const List<(String, PlacementTool)> _entries = [
    ('Machiya', StampStructureTool(kind: StructureKind.machiya)),
    ('Stall', StampStructureTool(kind: StructureKind.marketStall)),
    ('Yagura', StampStructureTool(kind: StructureKind.yaguraTower)),
    ('Dirt Lane', DrawLaneTool()),
    ('Terrace', BuildTerraceTool()),
    ('Maple', StampStructureTool(kind: StructureKind.mapleCluster)),
    ('Bamboo', StampStructureTool(kind: StructureKind.bambooGrove)),
    ('Watch', InspectWatchTool()),
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
          children: [
            for (final (label, tool) in _entries)
              _CompactChip(
                label: label,
                active: _matches(tool),
                accent: tool is InspectWatchTool
                    ? ShukubaHud._jadeSight
                    : ShukubaHud._amberAccent,
                onTap: () => onSelectTool(tool),
              ),
            if (isStamp)
              _CompactChip(
                label: 'Rotate [R]',
                active: false,
                accent: ShukubaHud._mutedSand,
                onTap: onRotateStamp,
              ),
          ],
        ),
      ),
    );
  }
}

class _CompactChip extends StatelessWidget {
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
