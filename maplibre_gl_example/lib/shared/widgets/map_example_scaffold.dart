import 'package:flutter/material.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import '../constants.dart';

/// A reusable scaffold for map examples that provides a consistent layout:
/// - Map on top (50% of screen by default)
/// - Scrollable control panel below
/// - Automatic handling of responsive sizing
class MapExampleScaffold extends StatelessWidget {
  /// The MapLibre map widget
  final MapLibreMap map;

  /// Control widgets to display below the map
  final List<Widget> controls;

  /// Optional title for the example (shown in app bar if provided)
  final String? title;

  /// Map height ratio (0.0 to 1.0). Defaults to 0.5 (50% of screen)
  final double mapHeightRatio;

  /// Whether to show the app bar. Defaults to false.
  final bool showAppBar;

  /// Optional floating action button
  final Widget? floatingActionButton;

  /// Alignment of control buttons. Defaults to center.
  final WrapAlignment controlsAlignment;

  /// Padding around controls. Defaults to standard padding.
  final EdgeInsets? controlsPadding;

  /// Whether to wrap controls in a Card. Defaults to false.
  final bool wrapInCard;

  const MapExampleScaffold({
    super.key,
    required this.map,
    required this.controls,
    this.title,
    this.mapHeightRatio = ExampleConstants.mapHeightRatio,
    this.showAppBar = false,
    this.floatingActionButton,
    this.controlsAlignment = WrapAlignment.start,
    this.controlsPadding,
    this.wrapInCard = false,
  }) : assert(mapHeightRatio > 0.0 && mapHeightRatio <= 1.0,
            'mapHeightRatio must be between 0.0 and 1.0');

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final screenHeight = MediaQuery.of(context).size.height;
    final mapHeight = screenHeight * mapHeightRatio;

    final controlsWidget = _buildControls(theme);

    final body = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: mapHeight,
          child: map,
        ),
        Expanded(
          child: SingleChildScrollView(
            child: controlsWidget,
          ),
        ),
      ],
    );

    return Scaffold(
      appBar: showAppBar && title != null
          ? AppBar(
              title: Text(title!),
              elevation: 0,
            )
          : null,
      body: body,
      floatingActionButton: floatingActionButton,
    );
  }

  Widget _buildControls(ThemeData theme) {
    final padding = controlsPadding ??
        const EdgeInsets.all(ExampleConstants.paddingStandard);

    final wrappedControls = Wrap(
      runSpacing: ExampleConstants.buttonRunSpacing,
      alignment: controlsAlignment,
      children: controls,
    );

    if (wrapInCard) {
      return Padding(
        padding: padding,
        child: Card(
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(ExampleConstants.borderRadius),
          ),
          child: Padding(
            padding: const EdgeInsets.all(ExampleConstants.paddingStandard),
            child: wrappedControls,
          ),
        ),
      );
    }

    return Padding(
      padding: padding,
      child: wrappedControls,
    );
  }
}

/// A builder variant that accepts a child builder for more complex layouts
class MapExampleScaffoldBuilder extends StatelessWidget {
  /// The MapLibre map widget
  final MapLibreMap map;

  /// Builder for the control panel content
  final Widget Function(BuildContext context) controlsBuilder;

  /// Optional title for the example
  final String? title;

  /// Map height ratio (0.0 to 1.0). Defaults to 0.5 (50% of screen)
  final double mapHeightRatio;

  /// Whether to show the app bar. Defaults to false.
  final bool showAppBar;

  /// Optional floating action button
  final Widget? floatingActionButton;

  const MapExampleScaffoldBuilder({
    super.key,
    required this.map,
    required this.controlsBuilder,
    this.title,
    this.mapHeightRatio = ExampleConstants.mapHeightRatio,
    this.showAppBar = false,
    this.floatingActionButton,
  });

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final mapHeight = screenHeight * mapHeightRatio;

    final body = Column(
      children: [
        SizedBox(
          height: mapHeight,
          child: map,
        ),
        Expanded(
          child: SingleChildScrollView(
            child: controlsBuilder(context),
          ),
        ),
      ],
    );

    return Scaffold(
      appBar: showAppBar && title != null
          ? AppBar(
              title: Text(title!),
              elevation: 0,
            )
          : null,
      body: body,
      floatingActionButton: floatingActionButton,
    );
  }
}
