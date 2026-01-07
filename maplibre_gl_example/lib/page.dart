import 'package:flutter/material.dart';

/// Category for organizing examples
enum ExampleCategory {
  basics('Basics', Icons.map),
  camera('Camera', Icons.videocam),
  interaction('Interaction', Icons.touch_app),
  annotations('Annotations', Icons.location_on),
  layers('Layers & Sources', Icons.layers),
  advanced('Advanced', Icons.science);

  const ExampleCategory(this.label, this.icon);

  final String label;
  final IconData icon;
}

abstract class ExamplePage extends StatelessWidget {
  const ExamplePage(
    this.leading,
    this.title, {
    this.needsLocationPermission = true,
    this.category = ExampleCategory.basics,
    super.key,
  });

  final Widget leading;
  final String title;
  final bool needsLocationPermission;
  final ExampleCategory category;
}
