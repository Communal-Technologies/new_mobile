import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import 'package:communal_mobile/core/widgets/space.dart';
import 'package:communal_mobile/screens/account/faq_screen.dart';

class FaqCategorySection extends StatelessWidget {
  const FaqCategorySection({
    super.key,
    required this.title,
    required this.questions,
  });

  final String title;
  final List<FaqQuestion> questions;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(16.r),
          topRight: Radius.circular(16.r),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: EdgeInsets.all(16.w),
            decoration: BoxDecoration(
              color: const Color(0xFF7434FF).withOpacity(0.1),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(16.r),
                topRight: Radius.circular(16.r),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 32.w,
                  height: 32.w,
                  decoration: BoxDecoration(
                    color: const Color(0xFF7434FF),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      '?',
                      style: TextStyle(
                        fontSize: 18.sp,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
                hSpace(12),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      fontSize: 16.sp,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF0F1D40),
                    ),
                  ),
                ),
              ],
            ),
          ),
          ...questions.map((faq) => _FaqQuestionItem(question: faq)),
        ],
      ),
    );
  }
}

class _FaqQuestionItem extends StatefulWidget {
  const _FaqQuestionItem({required this.question});

  final FaqQuestion question;

  @override
  State<_FaqQuestionItem> createState() => _FaqQuestionItemState();
}

class _FaqQuestionItemState extends State<_FaqQuestionItem> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Divider(
          height: 1,
          thickness: 1,
          color: Colors.grey.shade200,
        ),
        InkWell(
          onTap: () => setState(() => _isExpanded = !_isExpanded),
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 16.h),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    widget.question.question,
                    style: TextStyle(
                      fontSize: 14.sp,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF0F1D40),
                    ),
                  ),
                ),
                hSpace(12),
                Icon(
                  _isExpanded
                      ? Icons.keyboard_arrow_up
                      : Icons.chevron_right,
                  color: Colors.grey.shade600,
                  size: 20.sp,
                ),
              ],
            ),
          ),
        ),
        if (_isExpanded)
          Container(
            padding: EdgeInsets.fromLTRB(16.w, 0, 16.w, 16.h),
            child: Text(
              widget.question.answer,
              style: TextStyle(
                fontSize: 13.sp,
                color: Colors.grey.shade700,
                height: 1.5,
              ),
            ),
          ),
      ],
    );
  }
}

