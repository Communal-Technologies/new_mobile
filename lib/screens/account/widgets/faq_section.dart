import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import 'package:communal_mobile/core/widgets/space.dart';

class FaqSection extends StatefulWidget {
  const FaqSection({super.key});

  @override
  State<FaqSection> createState() => _FaqSectionState();
}

class _FaqSectionState extends State<FaqSection> {
  int _selectedTab = 0;
  final Map<int, List<FaqItem>> _faqsByTab = {
    0: [
      FaqItem(
        question: 'What is Communal HQ?',
        answer: 'Communal HQ is a cooperative management platform that helps communities manage their financial activities, contributions, and loans efficiently.',
      ),
      FaqItem(
        question: 'Is Bullion Crib safe and secure?',
        answer: 'Yes, Bullion Crib uses bank-level encryption and security measures to protect your data and transactions.',
      ),
      FaqItem(
        question: 'What are the benefits of using Bullion Crib?',
        answer: 'Bullion Crib offers easy loan management, transparent contributions, community networking, and secure financial transactions.',
      ),
      FaqItem(
        question: 'How do I contact customer support?',
        answer: 'You can contact customer support via email at support@bullioncrib.com, call us at +234 (0) 800 123 4567, or use the Live Chat feature.',
      ),
    ],
    1: [
      FaqItem(
        question: 'How do I make a payment?',
        answer: 'You can make payments through the app using your linked bank account or wallet.',
      ),
    ],
    2: [
      FaqItem(
        question: 'How do I apply for a loan?',
        answer: 'Navigate to the Loans section, select a loan offer, and follow the application process.',
      ),
    ],
    3: [
      FaqItem(
        question: 'How do I join a cooperative?',
        answer: 'Browse available cooperatives in the Community section and submit a join request.',
      ),
    ],
    4: [
      FaqItem(
        question: 'How do I secure my account?',
        answer: 'Enable two-factor authentication, set a strong PIN, and never share your login credentials.',
      ),
    ],
  };

  final List<String> _tabs = ['Account', 'Payments', 'Loans', 'Cooperative', 'Security'];

  @override
  Widget build(BuildContext context) {
    final currentFaqs = _faqsByTab[_selectedTab] ?? [];

    return Column(
      children: [
        Container(
          color: Colors.white,
          padding: EdgeInsets.symmetric(vertical: 12.h),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: EdgeInsets.symmetric(horizontal: 16.w),
            child: Row(
              children: List.generate(
                _tabs.length,
                (index) => _buildTab(index),
              ),
            ),
          ),
        ),
        vSpace(12),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 16.w),
          child: Column(
            children: currentFaqs.map((faq) => _FaqItemWidget(faq: faq)).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildTab(int index) {
    final isSelected = _selectedTab == index;
    return GestureDetector(
      onTap: () => setState(() => _selectedTab = index),
      child: Container(
        margin: EdgeInsets.only(right: 12.w),
        padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 10.h),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: isSelected ? const Color(0xFF7434FF) : Colors.transparent,
              width: 2,
            ),
          ),
        ),
        child: Text(
          _tabs[index],
          style: TextStyle(
            fontSize: 15.sp,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            color: isSelected ? const Color(0xFF7434FF) : Colors.grey.shade600,
          ),
        ),
      ),
    );
  }
}

class FaqItem {
  final String question;
  final String answer;

  FaqItem({required this.question, required this.answer});
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
        color: Colors.white,
        borderRadius: BorderRadius.circular(12.r),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.shade200,
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
                        fontSize: 14.sp,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF0F1D40),
                      ),
                    ),
                  ),
                  Icon(
                    _isExpanded
                        ? Icons.keyboard_arrow_up
                        : Icons.keyboard_arrow_down,
                    color: Colors.grey.shade600,
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
                  fontSize: 13.sp,
                  color: Colors.grey.shade700,
                  height: 1.5,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

