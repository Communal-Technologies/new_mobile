import 'package:flutter/material.dart';

class BottomSheetHandlebar extends StatelessWidget {
  const BottomSheetHandlebar({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        height: 6,
        width: 76.18,
        margin: const EdgeInsets.only(top: 8, bottom: 16),
        decoration: BoxDecoration(
          color: const Color(0xFFE2E2E2),
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    );
  }
}
