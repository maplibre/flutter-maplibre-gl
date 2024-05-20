import 'package:flutter/material.dart';

abstract class ExamplePage extends StatelessWidget {
  const ExamplePage(
    this.leading,
    this.title, {
    this.needsLocationPermission = true,
    super.key,
  });

  final Widget leading;
  final String title;
  final bool needsLocationPermission;
}
