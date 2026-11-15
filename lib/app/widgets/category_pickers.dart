import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app_sizes.dart';
import 'app_widgets.dart';

/// Returned by [showIconPickerSheet] when the user picks "Automatic".
const automaticIcon = '';

/// Grid of category icons in groups, tinted with [color]. Returns the chosen
/// icon key, [automaticIcon], or null when dismissed.
Future<String?> showIconPickerSheet(
  BuildContext context, {
  required Color color,
  String? selected,
  IconData? automatic,
}) => showModalBottomSheet<String>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  builder: (sheetContext) {
    final theme = Theme.of(sheetContext);
    final tint = readableCategoryColor(color, theme.brightness);

    Widget cell(String key, IconData icon, String label) {
      final isSelected = key == (selected ?? automaticIcon);
      return Semantics(
        button: true,
        selected: isSelected,
        label: label,
        child: InkWell(
          borderRadius: BorderRadius.circular(RadiusSize.medium),
          onTap: () => Navigator.of(sheetContext).pop(key),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            decoration: BoxDecoration(
              color: tint.withValues(alpha: isSelected ? .22 : .10),
              borderRadius: BorderRadius.circular(RadiusSize.medium),
              border: Border.all(
                color: isSelected ? tint : Colors.transparent,
                width: 2,
              ),
            ),
            child: Icon(icon, color: tint, size: IconSize.large),
          ),
        ),
      );
    }

    SliverGrid grid(List<Widget> cells) => SliverGrid.count(
      crossAxisCount: 6,
      mainAxisSpacing: SpaceSize.small,
      crossAxisSpacing: SpaceSize.small,
      children: cells,
    );

    Widget header(String title) => SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          0,
          SpaceSize.large,
          0,
          SpaceSize.small,
        ),
        child: Text(title, style: theme.textTheme.titleSmall),
      ),
    );

    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(sheetContext).height * .8,
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: SpaceSize.gutter),
        child: CustomScrollView(
          shrinkWrap: true,
          slivers: [
            SliverToBoxAdapter(
              child: Text('Choose an icon', style: theme.textTheme.titleLarge),
            ),
            header('Automatic (from the name)'),
            grid([
              cell(
                automaticIcon,
                automatic ?? Icons.auto_awesome_outlined,
                'Automatic',
              ),
            ]),
            for (final group in categoryIconGroups.entries) ...[
              header(group.key),
              grid([
                for (final e in group.value.entries)
                  cell(e.key, e.value, e.key.replaceAll('_', ' ')),
              ]),
            ],
            const SliverToBoxAdapter(child: SizedBox(height: SpaceSize.huge)),
          ],
        ),
      ),
    );
  },
);

/// Full color picker: saturation/brightness panel, hue slider, hex entry and
/// quick swatches. Any color can be chosen. Returns null when dismissed.
Future<Color?> showColorPickerSheet(
  BuildContext context, {
  required Color initial,
  IconData? icon,
}) => showAppSheet<Color>(
  context,
  builder: (_) => _ColorPickerSheet(initial: initial, icon: icon),
);

class _ColorPickerSheet extends StatefulWidget {
  const _ColorPickerSheet({required this.initial, this.icon});
  final Color initial;
  final IconData? icon;

  @override
  State<_ColorPickerSheet> createState() => _ColorPickerSheetState();
}

class _ColorPickerSheetState extends State<_ColorPickerSheet> {
  late HSVColor hsv = HSVColor.fromColor(widget.initial);
  late final TextEditingController hex = TextEditingController(
    text: colorToHex(widget.initial).substring(1),
  );

  @override
  void dispose() {
    hex.dispose();
    super.dispose();
  }

  void _set(HSVColor value, {bool updateText = true}) {
    setState(() => hsv = value);
    if (updateText) {
      hex.value = TextEditingValue(
        text: colorToHex(value.toColor()).substring(1),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = hsv.toColor();
    final shown = readableCategoryColor(color, theme.brightness);
    return SheetScaffold(
      title: 'Tag color',
      subtitle: 'Pick any color. It is used for this category everywhere.',
      primaryLabel: 'Use this color',
      onPrimary: () => Navigator.of(context).pop(color),
      children: [
        Row(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: shown.withValues(
                  alpha: theme.brightness == Brightness.dark ? .22 : .14,
                ),
                borderRadius: BorderRadius.circular(17),
              ),
              child: Icon(
                widget.icon ?? Icons.sell_outlined,
                color: shown,
                size: 28,
              ),
            ),
            const SizedBox(width: SpaceSize.medium),
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
                border: Border.all(color: theme.colorScheme.outlineVariant),
              ),
            ),
            const SizedBox(width: SpaceSize.medium),
            Expanded(
              child: TextField(
                controller: hex,
                maxLength: 6,
                textCapitalization: TextCapitalization.characters,
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp('[0-9a-fA-F]')),
                ],
                style: theme.textTheme.titleMedium?.copyWith(
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
                decoration: const InputDecoration(
                  labelText: 'Hex',
                  prefixText: '# ',
                  counterText: '',
                ),
                onChanged: (text) {
                  final parsed = colorFromHex(text);
                  if (parsed != null) {
                    _set(HSVColor.fromColor(parsed), updateText: false);
                  }
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: SpaceSize.large),
        _SaturationValuePanel(hsv: hsv, onChanged: _set),
        const SizedBox(height: SpaceSize.large),
        _HueSlider(hsv: hsv, onChanged: _set),
        const SizedBox(height: SpaceSize.large),
        Wrap(
          spacing: SpaceSize.small,
          runSpacing: SpaceSize.small,
          children: [
            for (final swatch in categorySwatches)
              Semantics(
                button: true,
                label: 'Color ${colorToHex(swatch)}',
                child: InkResponse(
                  onTap: () => _set(HSVColor.fromColor(swatch)),
                  radius: 22,
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: swatch,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: colorToHex(swatch) == colorToHex(color)
                            ? theme.colorScheme.onSurface
                            : Colors.transparent,
                        width: 2.5,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: SpaceSize.large),
      ],
    );
  }
}

/// Square where x = saturation and y = brightness for the current hue.
class _SaturationValuePanel extends StatelessWidget {
  const _SaturationValuePanel({required this.hsv, required this.onChanged});
  final HSVColor hsv;
  final ValueChanged<HSVColor> onChanged;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      const height = 180.0;
      final width = constraints.maxWidth;
      void update(Offset p) => onChanged(
        hsv
            .withSaturation((p.dx / width).clamp(0.0, 1.0))
            .withValue(1 - (p.dy / height).clamp(0.0, 1.0)),
      );
      final hue = HSVColor.fromAHSV(1, hsv.hue, 1, 1).toColor();
      return Semantics(
        label: 'Saturation and brightness',
        child: GestureDetector(
          onTapDown: (d) => update(d.localPosition),
          // Separate axis recognizers win against the sheet's own scrolling
          // and drag-to-close, so dragging in the panel picks a color.
          onVerticalDragStart: (d) => update(d.localPosition),
          onVerticalDragUpdate: (d) => update(d.localPosition),
          onHorizontalDragStart: (d) => update(d.localPosition),
          onHorizontalDragUpdate: (d) => update(d.localPosition),
          child: SizedBox(
            height: height,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(RadiusSize.medium),
              child: Stack(
                children: [
                  Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(colors: [Colors.white, hue]),
                      ),
                    ),
                  ),
                  const Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [Colors.transparent, Colors.black],
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    left: hsv.saturation * width - 12,
                    top: (1 - hsv.value) * height - 12,
                    child: _Thumb(color: hsv.toColor()),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    },
  );
}

/// Rainbow slider choosing the hue.
class _HueSlider extends StatelessWidget {
  const _HueSlider({required this.hsv, required this.onChanged});
  final HSVColor hsv;
  final ValueChanged<HSVColor> onChanged;

  static final _rainbow = [
    for (var h = 0; h <= 360; h += 60)
      HSVColor.fromAHSV(1, h.toDouble() % 360, 1, 1).toColor(),
  ];

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final width = constraints.maxWidth;
      void update(Offset p) =>
          onChanged(hsv.withHue((p.dx / width).clamp(0.0, 1.0) * 359.9));
      return Semantics(
        label: 'Hue',
        slider: true,
        value: '${hsv.hue.round()} degrees',
        child: GestureDetector(
          onTapDown: (d) => update(d.localPosition),
          onHorizontalDragStart: (d) => update(d.localPosition),
          onHorizontalDragUpdate: (d) => update(d.localPosition),
          child: SizedBox(
            height: 32,
            child: Stack(
              alignment: Alignment.centerLeft,
              children: [
                Container(
                  height: 20,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    gradient: LinearGradient(colors: _rainbow),
                  ),
                ),
                Positioned(
                  left: hsv.hue / 360 * width - 12,
                  child: _Thumb(
                    color: HSVColor.fromAHSV(1, hsv.hue, 1, 1).toColor(),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
}

class _Thumb extends StatelessWidget {
  const _Thumb({required this.color});
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    width: 24,
    height: 24,
    decoration: BoxDecoration(
      color: color,
      shape: BoxShape.circle,
      border: Border.all(color: Colors.white, width: 3),
      boxShadow: const [BoxShadow(color: Color(0x55000000), blurRadius: 4)],
    ),
  );
}
