import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import 'package:communal_mobile/data/models/support_models.dart';
import 'package:communal_mobile/data/repositories/support_repository.dart';
import 'package:communal_mobile/injection.dart';

/// Compact "popular questions" preview used inside the Help & Support
/// screen. The full catalogue lives on `FaqScreen` — having tabs here too
/// is redundant (the user already has a "See more" CTA next to this
/// section that opens that screen). We just show the first few articles
/// so the help surface stays scannable.
///
/// The three questions here used to be hardcoded, and one of them told members
/// to email an address belonging to a different product. They are now the first
/// rows of the knowledge base, so they cannot drift from what the assistant and
/// the website say.
class FaqSection extends StatefulWidget {
  const FaqSection({super.key, this.limit = 3});

  final int limit;

  @override
  State<FaqSection> createState() => _FaqSectionState();
}

class _FaqSectionState extends State<FaqSection> {
  late Future<List<KbArticle>> _future;

  @override
  void initState() {
    super.initState();
    _future = getIt<SupportRepository>().knowledgeBase(limit: widget.limit);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16.w),
      child: FutureBuilder<List<KbArticle>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Column(
              children: List.generate(
                widget.limit,
                (_) => const _SkeletonRow(),
              ),
            );
          }
          final articles = snapshot.data ?? const <KbArticle>[];
          if (articles.isEmpty) {
            // Nothing published, or the desk is unreachable. Say so rather than
            // showing invented answers: the contact details and the assistant
            // are right below this section either way.
            return Text(
              'No published answers yet — ask us below and we will help.',
              style: TextStyle(
                fontSize: 17.sp,
                color:
                    Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
              ),
            );
          }
          return Column(
            children: articles
                .take(widget.limit)
                .map((article) => _FaqItemWidget(
                      faq: FaqItem(
                        question: article.question,
                        answer: article.answer,
                      ),
                    ))
                .toList(),
          );
        },
      ),
    );
  }
}

class _SkeletonRow extends StatelessWidget {
  const _SkeletonRow();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 54.h,
      margin: EdgeInsets.only(bottom: 8.h),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(12.r),
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
                        fontSize: 17.sp,
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
                  fontSize: 17.sp,
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
