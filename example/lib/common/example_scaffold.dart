import 'package:flutter/material.dart';
import 'package:maplibre_gl_example/main.dart';

class ExampleScaffold extends StatelessWidget {
  final ExamplePage page;
  final Widget body;
  final Widget? floatingActionButton;

  const ExampleScaffold({
    super.key,
    required this.page,
    required this.body,
    this.floatingActionButton,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(page.title)),
      floatingActionButton: floatingActionButton,
      body: body,
    );
  }
}
