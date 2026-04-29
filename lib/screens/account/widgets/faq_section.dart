import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

/// Compact "popular questions" preview used inside the Help & Support
/// screen. The full tabbed FAQ catalog lives on `FaqScreen` — having
/// tabs here too is redundant (the user already has a "See more" CTA
/// next to this section that opens that screen). We just show the
/// most-asked items so the help surface stays scannable.
class FaqSection extends StatelessWidget {
  const FaqSection({super.key});

  static const List<FaqItem> _popularFaqs = [
    FaqItem(
      question: 'What is Communal?',
      answer:
          'Communal is a cooperative management platform that helps communities manage their financial activities, contributions, and loans efficiently.',
    ),
    FaqItem(
      question: 'Is Communal safe and secure?',
      answer:
          'Yes — Communal uses bank-level encryption and biometric / PIN protection to keep your data and transactions safe.',
    ),
    FaqItem(
      question: 'How do I contact customer support?',
      answer:
          'Email support@bullioncrib.com, call +234 (0) 800 123 4567, or open Live Chat below.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16.w),
      child: Column(
        children:
            _popularFaqs.map((faq) => _FaqItemWidget(faq: faq)).toList(),
      ),
    );
  }
}

class FaqItem {
  final String question;
  final String answer;

  const FaqItem({required this.question, required this.answer});
}

class _FaqItemWidget extends StatefulWidget {
  const _FaqItemWidget({required this.faq});

  final FaqItem faq;

  @override
  State<_FaqItemWidget> createState() => _FaqItemWidgetState();
}

class _FaqItemWidgetState extends State<_FaqItemWidget> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.only(bottom: 8.h),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(12.r),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).dividerColor,
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          InkWell(
            onTap: () => setState(() => _isExpanded = !_isExpanded),
            child: Padding(
              padding: EdgeInsets.all(16.w),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      widget.faq.question,
                      style: TextStyle(
                        fontSize: 15.sp,
                        fontWeight: FontWeight.w600,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                  ),
                  Icon(
                    _isExpanded
                        ? Icons.keyboard_arrow_up
                        : Icons.keyboard_arrow_down,
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                ],
              ),
            ),
          ),
          if (_isExpanded)
            Padding(
              padding: EdgeInsets.fromLTRB(16.w, 0, 16.w, 16.h),
              child: Text(
                widget.faq.answer,
                style: TextStyle(
                  fontSize: 15.sp,
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                  height: 1.5,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

