import 'package:flutter/material.dart';

import '../theme/app_spacing.dart';

/// Komponen pembungkus responsif — memusatkan konten pada layar lebar (lebar maks 560),
/// menerapkan margin horizontal 24 px, dan menghormati SafeArea.
class ResponsiveBody extends StatelessWidget {
  final Widget child;
  final double maxWidth;
  final EdgeInsetsGeometry? padding;
  final bool useSafeArea;
  final AlignmentGeometry alignment;

  const ResponsiveBody({
    super.key,
    required this.child,
    this.maxWidth = 560,
    this.padding,
    this.useSafeArea = true,
    this.alignment = Alignment.topCenter,
  });

  @override
  Widget build(BuildContext context) {
    Widget content = Padding(
      padding: padding ?? const EdgeInsets.symmetric(horizontal: AppSpacing.pageMargin),
      child: child,
    );

    content = Align(
      alignment: alignment,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: SizedBox(
          width: double.infinity,
          height: double.infinity,
          child: content,
        ),
      ),
    );

    if (useSafeArea) {
      content = SafeArea(child: content);
    }

    return content;
  }
}
