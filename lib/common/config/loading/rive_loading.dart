import 'package:flutter/material.dart';
// The builder below reports its own `RiveLoading` state, which collides with
// the widget declared here.
import 'package:rive/rive.dart' hide RiveLoading;

import '../models/loading_config.dart';

class RiveLoading extends StatefulWidget {
  final LoadingConfig loadingConfig;

  const RiveLoading(this.loadingConfig, {super.key});

  @override
  State<RiveLoading> createState() => _RiveLoadingState();
}

class _RiveLoadingState extends State<RiveLoading> {
  /// Owned by this state, so it is disposed with the widget.
  FileLoader? _fileLoader;

  @override
  void initState() {
    super.initState();
    final path = widget.loadingConfig.path;
    if (path == null || path.isEmpty) {
      return;
    }
    _fileLoader = path.startsWith('http')
        ? FileLoader.fromUrl(path, riveFactory: Factory.flutter)
        : FileLoader.fromAsset(path, riveFactory: Factory.flutter);
  }

  @override
  void dispose() {
    _fileLoader?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final fileLoader = _fileLoader;
    if (fileLoader == null) {
      return const SizedBox();
    }

    return Center(
      child: RiveWidgetBuilder(
        fileLoader: fileLoader,
        // A loading animation that fails to load should stay invisible rather
        // than replace the screen with an error box.
        onFailed: (_, __) {},
        builder: (context, state) => switch (state) {
          RiveLoaded() => RiveWidget(
              controller: state.controller,
              fit: Fit.contain,
            ),
          _ => const SizedBox(),
        },
      ),
    );
  }
}
