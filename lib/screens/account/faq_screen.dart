import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';

import 'package:communal_mobile/core/widgets/space.dart';
import 'package:communal_mobile/screens/account/widgets/faq_category_section.dart';

class FaqScreen extends StatefulWidget {
  const FaqScreen({super.key});

  @override
  State<FaqScreen> createState() => _FaqScreenState();
}

class _FaqScreenState extends State<FaqScreen> {
  final TextEditingController _searchController = TextEditingController();
  int _selectedTab = 0;

  final List<String> _tabs = [
    'Account',
    'Payments',
    'Loans',
    'Cooperative',
    'Security',
  ];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark.copyWith(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light,
      ),
      child: Scaffold(
        backgroundColor: Colors.grey.shade50,
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          systemOverlayStyle: SystemUiOverlayStyle.dark,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.black),
            onPressed: () => context.pop(),
          ),
          title: Text(
            'Frequently Asked Questions',
            style: TextStyle(
              fontSize: 19.sp,
              fontWeight: FontWeight.w700,
              color: Colors.black,
            ),
          ),
          centerTitle: true,
        ),
        body: Column(
          children: [
            _buildCategoryTabs(),
            vSpace(16),
            _buildSearchBar(),
            vSpace(16),
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    FaqCategorySection(
                      title: 'Account & Profile',
                      questions: [
                        FaqQuestion(
                          question: 'How do I upgrade my account tier?',
                          answer:
                              'To upgrade your account tier, go to Account Settings > Account Limits. Complete the required verifications for the tier you want to upgrade to.',
                        ),
                        FaqQuestion(
                          question: 'How do I update my profile information?',
                          answer:
                              'Navigate to Account Settings > My Profile and tap on Edit Profile. You can update your personal information, address, and other details.',
                        ),
                        FaqQuestion(
                          question: 'What documents do I need for verification?',
                          answer:
                              'For Tier 2, you need BVN and NIN. For Tier 3, you need to complete Tier 2, upload a valid ID, and provide address verification.',
                        ),
                        FaqQuestion(
                          question: 'Can I have multiple cooperatives?',
                          answer:
                              'Yes, you can join multiple cooperatives. Each cooperative has its own settings and contributions that you can manage separately.',
                        ),
                      ],
                    ),
                    vSpace(12),
                    FaqCategorySection(
                      title: 'Loans & Borrowing',
                      questions: [
                        FaqQuestion(
                          question: 'What loan amounts can I access?',
                          answer:
                              'Loan amounts depend on your account tier, creditworthiness, and the cooperative\'s policies. Check the Loans section for available offers.',
                        ),
                        FaqQuestion(
                          question: 'How long does loan approval take?',
                          answer:
                              'Loan approval typically takes 24-48 hours after submission of all required documents and guarantor information.',
                        ),
                        FaqQuestion(
                          question: 'What are the interest rates?',
                          answer:
                              'Interest rates vary based on loan amount, duration, and your credit profile. Check individual loan offers for specific rates.',
                        ),
                        FaqQuestion(
                          question: 'Can I repay my loan early?',
                          answer:
                              'Yes, you can repay your loan early. Early repayment may qualify you for reduced interest. Check your loan details for more information.',
                        ),
                      ],
                    ),
                    vSpace(12),
                    FaqCategorySection(
                      title: 'Communities & Cooperatives',
                      questions: [
                        FaqQuestion(
                          question: 'How do I join a community?',
                          answer:
                              'Browse available communities in the Community section, select one that interests you, and submit a join request. Wait for approval from the community admin.',
                        ),
                        FaqQuestion(
                          question: 'What is a cooperative wallet?',
                          answer:
                              'A cooperative wallet is a shared financial pool managed by the cooperative for contributions, loans, and other financial activities.',
                        ),
                        FaqQuestion(
                          question: 'How do I switch between cooperatives?',
                          answer:
                              'You can switch between cooperatives from the Community section. Each cooperative maintains separate settings and financial records.',
                        ),
                        FaqQuestion(
                          question: 'Can I create my own community?',
                          answer:
                              'Yes, you can create your own community. Navigate to the Community section and select "Create Community" to get started.',
                        ),
                      ],
                    ),
                    vSpace(12),
                    FaqCategorySection(
                      title: 'Payments & Transactions',
                      questions: [
                        FaqQuestion(
                          question: 'How do I make a transfer?',
                          answer:
                              'Go to the Wallet or Transactions section, select Transfer, enter the recipient details and amount, then confirm the transaction.',
                        ),
                        FaqQuestion(
                          question: 'What are the transaction limits?',
                          answer:
                              'Limits depend on your verification tier (Tier 1 after BVN and account number, Tier 2 after ID verification). Exact amounts are shown under Account > Account limits and may be updated by Communal.',
                        ),
                        FaqQuestion(
                          question: 'Are there transaction fees?',
                          answer:
                              'Transaction fees vary by transaction type. Check the fee schedule in Account Settings > Account Limits for detailed information.',
                        ),
                        FaqQuestion(
                          question: 'How do I track my obligations?',
                          answer:
                              'Navigate to the Obligations section to view all your financial obligations, payment schedules, and payment history.',
                        ),
                      ],
                    ),
                    vSpace(12),
                    FaqCategorySection(
                      title: 'Security & Privacy',
                      questions: [
                        FaqQuestion(
                          question: 'How do I change my transaction PIN?',
                          answer:
                              'Go to Account Settings > Security Settings, select Change PIN, verify your identity, and set a new PIN.',
                        ),
                        FaqQuestion(
                          question: 'What is biometric authentication?',
                          answer:
                              'Biometric authentication uses your fingerprint or face ID to securely access your account. Enable it in Security Settings.',
                        ),
                        FaqQuestion(
                          question: 'How do I secure my account?',
                          answer:
                              'Use a strong PIN, enable biometric authentication, never share your credentials, and enable two-factor authentication if available.',
                        ),
                        FaqQuestion(
                          question: 'What should I do if I suspect fraud?',
                          answer:
                              'Immediately freeze your account from Account Settings, change your PIN, and contact support at support@bullioncrib.com or use the Report Scam feature.',
                        ),
                      ],
                    ),
                    vSpace(32),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryTabs() {
    return Container(
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
            fontSize: 17.sp,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            color: isSelected ? const Color(0xFF7434FF) : Colors.grey.shade600,
          ),
        ),
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16.w),
      child: Container(
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
        child: TextField(
          controller: _searchController,
          decoration: InputDecoration(
            hintText: 'Search for help...',
            hintStyle: TextStyle(
              fontSize: 15.sp,
              color: Colors.grey.shade500,
            ),
            prefixIcon: Icon(
              Icons.search,
              color: Colors.grey.shade400,
              size: 20.sp,
            ),
            border: InputBorder.none,
            contentPadding: EdgeInsets.symmetric(
              horizontal: 16.w,
              vertical: 14.h,
            ),
          ),
        ),
      ),
    );
  }
}

class FaqQuestion {
  final String question;
  final String answer;

  FaqQuestion({required this.question, required this.answer});
}

