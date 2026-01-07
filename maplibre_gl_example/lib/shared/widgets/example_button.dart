import 'package:flutter/material.dart';

/// A styled button component for map examples with Material 3 design
class ExampleButton extends StatelessWidget {
  /// Button label text
  final String label;

  /// Callback when button is pressed
  final VoidCallback? onPressed;

  /// Button style variant
  final ExampleButtonStyle style;

  /// Optional icon
  final IconData? icon;

  const ExampleButton({
    super.key,
    required this.label,
    this.onPressed,
    this.style = ExampleButtonStyle.filled,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    switch (style) {
      case ExampleButtonStyle.filled:
        return icon != null
            ? FilledButton.icon(
                onPressed: onPressed,
                icon: Icon(icon),
                label: Text(label),
              )
            : FilledButton(
                onPressed: onPressed,
                child: Text(label),
              );

      case ExampleButtonStyle.tonal:
        return icon != null
            ? FilledButton.tonalIcon(
                onPressed: onPressed,
                icon: Icon(icon),
                label: Text(label),
              )
            : FilledButton.tonal(
                onPressed: onPressed,
                child: Text(label),
              );

      case ExampleButtonStyle.outlined:
        return icon != null
            ? OutlinedButton.icon(
                onPressed: onPressed,
                icon: Icon(icon),
                label: Text(label),
              )
            : OutlinedButton(
                onPressed: onPressed,
                child: Text(label),
              );

      case ExampleButtonStyle.text:
        return icon != null
            ? TextButton.icon(
                onPressed: onPressed,
                icon: Icon(icon),
                label: Text(label),
              )
            : TextButton(
                onPressed: onPressed,
                child: Text(label),
              );

      case ExampleButtonStyle.destructive:
        return icon != null
            ? FilledButton.tonalIcon(
                onPressed: onPressed,
                icon: Icon(icon),
                label: Text(label),
                style: FilledButton.styleFrom(
                  backgroundColor: theme.colorScheme.errorContainer,
                  foregroundColor: theme.colorScheme.onErrorContainer,
                ),
              )
            : FilledButton.tonal(
                onPressed: onPressed,
                style: FilledButton.styleFrom(
                  backgroundColor: theme.colorScheme.errorContainer,
                  foregroundColor: theme.colorScheme.onErrorContainer,
                ),
                child: Text(label),
              );
    }
  }
}

/// Button style variants
enum ExampleButtonStyle {
  /// Filled button (primary action)
  filled,

  /// Tonal button (secondary action)
  tonal,

  /// Outlined button (tertiary action)
  outlined,

  /// Text button (low emphasis)
  text,

  /// Destructive action (remove, delete, clear)
  destructive,
}

/// A group of buttons with a label
class ControlGroup extends StatelessWidget {
  /// Group title/label
  final String title;

  /// Buttons in this group
  final List<Widget> children;

  /// Whether to show as a vertical list. Defaults to false (horizontal wrap).
  final bool vertical;

  /// Whether to wrap the group in a Card. Defaults to true.
  final bool wrapInCard;

  const ControlGroup({
    super.key,
    required this.title,
    required this.children,
    this.vertical = false,
    this.wrapInCard = true,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (wrapInCard) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: SizedBox(width: double.infinity, child: _buildContent(theme)),
        ),
      );
    }
    return _buildContent(theme);
  }

  Widget _buildContent(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            title,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w600,
              color: theme.colorScheme.primary,
            ),
          ),
        ),
        if (vertical)
          Padding(
            padding: const EdgeInsets.only(left: 4.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: children,
            ),
          )
        else
          Wrap(
            spacing: 8.0,
            runSpacing: 8.0,
            children: children,
          ),
      ],
    );
  }
}

/// A segmented button group for mutually exclusive options
class ExampleSegmentedButton<T> extends StatelessWidget {
  /// Available options
  final List<ExampleSegment<T>> segments;

  /// Currently selected value
  final T selected;

  /// Callback when selection changes
  final ValueChanged<T> onSelectionChanged;

  const ExampleSegmentedButton({
    super.key,
    required this.segments,
    required this.selected,
    required this.onSelectionChanged,
  });

  @override
  Widget build(BuildContext context) {
    return SegmentedButton<T>(
      segments: segments
          .map((segment) => ButtonSegment<T>(
                value: segment.value,
                label: Text(segment.label),
                icon: segment.icon != null ? Icon(segment.icon) : null,
              ))
          .toList(),
      selected: {selected},
      onSelectionChanged: (Set<T> newSelection) {
        if (newSelection.isNotEmpty) {
          onSelectionChanged(newSelection.first);
        }
      },
    );
  }
}

/// A segment for ExampleSegmentedButton
class ExampleSegment<T> {
  final T value;
  final String label;
  final IconData? icon;

  const ExampleSegment({
    required this.value,
    required this.label,
    this.icon,
  });
}

/// A toggle switch with label
class ExampleSwitch extends StatelessWidget {
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  const ExampleSwitch({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return SwitchListTile(
      title: Text(label),
      value: value,
      onChanged: onChanged,
      contentPadding: EdgeInsets.zero,
    );
  }
}

/// An info card to display status or information
class InfoCard extends StatelessWidget {
  final String title;
  final String? subtitle;
  final IconData? icon;
  final Color? color;

  const InfoCard({
    super.key,
    required this.title,
    this.subtitle,
    this.icon,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cardColor = color ?? theme.colorScheme.secondaryContainer;
    final textColor = color != null
        ? ThemeData.estimateBrightnessForColor(color!) == Brightness.light
            ? Colors.black87
            : Colors.white
        : theme.colorScheme.onSecondaryContainer;

    return Card(
      color: cardColor,
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Row(
          children: [
            if (icon != null) ...[
              Icon(icon, color: textColor),
              const SizedBox(width: 12),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: textColor,
                    ),
                  ),
                  if (subtitle != null)
                    Text(
                      subtitle!,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: textColor.withValues(alpha: 0.8),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
