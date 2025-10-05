import 'package:flutter/material.dart';

class OnboardingIndicator extends StatelessWidget {
  final int currentIndex;
  final int total;

  const OnboardingIndicator({super.key, required this.currentIndex, required this.total});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(
        total,
        (index) => Container(
          margin: const EdgeInsets.symmetric(horizontal: 5),
          width: 20,
          height: 5,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(5),
            color: index == currentIndex
                ? Theme.of(context).primaryColor
                : Theme.of(context).secondaryHeaderColor,
          ),
        ),
      ),
    );
  }
}
