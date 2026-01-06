import 'package:flutter/material.dart';

/// A reusable color picker widget that displays a modal bottom sheet
/// with a grid of color options
class ColorPickerModal {
  /// Shows a color picker modal and returns the selected color
  ///
  /// [context] - The build context
  /// [title] - Optional title for the picker (defaults to "Select Color")
  /// [currentColor] - The currently selected color (for highlighting)
  /// [colorFormat] - Whether to return hex string or Color object
  static Future<dynamic> show({
    required BuildContext context,
    String title = 'Select Color',
    Color? currentColor,
    ColorFormat colorFormat = ColorFormat.color,
  }) async {
    final colorOptions = _getDefaultColors();

    return showModalBottomSheet<dynamic>(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              title,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: colorOptions.entries.map((entry) {
                final color = entry.value;
                final isSelected = currentColor == color;

                return InkWell(
                  onTap: () {
                    final result = colorFormat == ColorFormat.hex
                        ? _colorToHex(color)
                        : color;
                    Navigator.pop(context, result);
                  },
                  child: Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      color: color,
                      border: Border.all(
                        color: isSelected ? Colors.blue : Colors.grey,
                        width: isSelected ? 3 : 2,
                      ),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: entry.key.isNotEmpty
                        ? Center(
                            child: Text(
                              entry.key,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: _getContrastColor(color),
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                shadows: const [
                                  Shadow(
                                    color: Colors.black45,
                                    blurRadius: 2,
                                  ),
                                ],
                              ),
                            ),
                          )
                        : null,
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  /// Shows a color picker and returns a hex color string
  static Future<String?> showForHex({
    required BuildContext context,
    String title = 'Select Color',
    String? currentHexColor,
  }) async {
    final currentColor =
        currentHexColor != null ? _hexToColor(currentHexColor) : null;

    return await show(
      context: context,
      title: title,
      currentColor: currentColor,
      colorFormat: ColorFormat.hex,
    );
  }

  /// Default color palette
  static Map<String, Color> _getDefaultColors() {
    return {
      'Red': const Color(0xFFE74C3C),
      'Blue': const Color(0xFF3498DB),
      'Green': const Color(0xFF2ECC71),
      'Yellow': const Color(0xFFF1C40F),
      'Purple': const Color(0xFF9B59B6),
      'Orange': const Color(0xFFE67E22),
      'Pink': const Color(0xFFEC7063),
      'Teal': const Color(0xFF1ABC9C),
      'Cyan': const Color(0xFF00BCD4),
      'Indigo': const Color(0xFF5C6BC0),
      'White': Colors.white,
      'Black': Colors.black,
    };
  }

  /// Converts a Color to hex string format (#RRGGBB)
  static String _colorToHex(Color color) {
    return '#${color.toARGB32().toRadixString(16).substring(2).toUpperCase()}';
  }

  /// Converts a hex string to Color
  static Color _hexToColor(String hex) {
    final hexCode = hex.replaceAll('#', '');
    return Color(int.parse(hexCode, radix: 16) + 0xFF000000);
  }

  /// Get contrasting color for text (white or black)
  static Color _getContrastColor(Color color) {
    final luminance =
        (0.299 * color.r + 0.587 * color.g + 0.114 * color.b) / 255;
    return luminance > 0.5 ? Colors.black : Colors.white;
  }
}

/// Format for the color picker return value
enum ColorFormat {
  /// Returns a Color object
  color,

  /// Returns a hex string (#RRGGBB)
  hex,
}

/// A simple widget that displays a color swatch with an optional border
class ColorSwatch extends StatelessWidget {
  final Color color;
  final double size;
  final bool isSelected;

  const ColorSwatch({
    super.key,
    required this.color,
    this.size = 48,
    this.isSelected = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color,
        border: Border.all(
          color: isSelected ? Colors.blue : Colors.grey,
          width: isSelected ? 3 : 1,
        ),
        borderRadius: BorderRadius.circular(4),
      ),
    );
  }
}
