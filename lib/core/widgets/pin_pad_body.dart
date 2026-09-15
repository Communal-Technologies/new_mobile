import 'package:flutter/material.dart';

/// The body of a screen that asks for the transaction PIN: its content at the top
/// and the keypad centred in whatever height is left below it, so a tall phone
/// does not leave the pad sitting high with an empty band underneath. It scrolls
/// only when the content and the pad together do not fit.
class PinPadBody extends StatelessWidget {
  const PinPadBody({
    super.key,
    required this.header,
    required this.pad,
    this.footer = const [],
    this.padding = EdgeInsets.zero,
  });

  final List<Widget> header;
  final Widget pad;
  final List<Widget> footer;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        padding: padding,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            minHeight: (constraints.maxHeight - padding.vertical)
                .clamp(0.0, double.infinity),
          ),
          child: IntrinsicHeight(
            child: Column(
              children: [
                ...header,
                Expanded(child: Center(child: pad)),
                ...footer,
              ],
            ),
          ),
        ),
      ),
    );
  }
}
