import 'dart:async';

import 'package:flutter/material.dart';
import 'package:communal_mobile/core/utils/system_ui_style.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';

import 'package:communal_mobile/core/widgets/space.dart';
import 'package:communal_mobile/data/models/support_models.dart';
import 'package:communal_mobile/data/repositories/support_repository.dart';
import 'package:communal_mobile/injection.dart';
import 'package:communal_mobile/screens/account/widgets/faq_category_section.dart';

/// The FAQ catalogue, read from the support knowledge base.
///
/// It used to be four hardcoded lists in this file. They are now rows in
/// `sup_kb_articles` — the same rows the assistant answers from and the website
/// FAQ shows — so an answer edited in the admin console changes here on the next
/// open, and the app can no longer tell a member something the bot contradicts.
/// The audience is resolved from the token, so a signed-in member sees the
/// member-only answers as well as the public ones.
class FaqScreen extends StatefulWidget {
  const FaqScreen({super.key, this.initialQuery = ''});

  /// Pre-filled search, used by the Help & Support search bar so typing there
  /// lands on results rather than on an unfiltered catalogue.
  final String initialQuery;

  @override
  State<FaqScreen> createState() => _FaqScreenState();
}

class _FaqScreenState extends State<FaqScreen> {
  final TextEditingController _searchController = TextEditingController();

  Timer? _debounce;
  List<String> _categories = const [];
  List<KbArticle> _articles = const [];
  String _selectedCategory = '';
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _searchController.text = widget.initialQuery;
    unawaited(_load());
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  SupportRepository get _repo => getIt<SupportRepository>();

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      // Only categories that actually have a published article for this reader,
      // so a tab never opens onto nothing.
      final categories = _categories.isEmpty
          ? await _repo.knowledgeBaseCategories()
          : _categories;
      final articles = await _repo.knowledgeBase(
        query: _searchController.text,
        // A search runs across the whole base: narrowing it to the open tab
        // hides the answer the member is looking for.
        category: _searchController.text.trim().isEmpty ? _selectedCategory : '',
      );
      if (!mounted) return;
      setState(() {
        _categories = categories;
        _articles = articles;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  void _onSearchChanged(String _) {
    // Rebuild now so the clear button appears with the first keystroke; the
    // query itself waits for the debounce.
    setState(() {});
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () => unawaited(_load()));
  }

  void _selectCategory(String category) {
    if (_selectedCategory == category) return;
    setState(() => _selectedCategory = category);
    unawaited(_load());
  }

  /// Opens a conversation instead. Reachable from the empty state and from the
  /// bottom of the list: a catalogue with no answer in it is exactly when a
  /// member needs the assistant, and making them navigate back to find it is how
  /// the question goes unasked.
  void _askInstead() {
    context.pushNamed(
      'support-chat',
      extra: <String, dynamic>{
        'category': _selectedCategory.isEmpty
            ? SupportCategory.general
            : _selectedCategory,
        'categoryTitle': 'Help',
        if (_searchController.text.trim().isNotEmpty)
          'openingMessage': _searchController.text.trim(),
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: systemOverlayForTheme(theme),
      child: Scaffold(
        backgroundColor: theme.scaffoldBackgroundColor,
        appBar: AppBar(
          backgroundColor: theme.cardColor,
          elevation: 0,
          // Status-bar overlay must follow the active theme, otherwise
          // dark icons render invisibly on the dark scaffold.
          systemOverlayStyle: systemOverlayForTheme(theme),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => context.pop(),
          ),
          title: Text(
            'Frequently Asked Questions',
            style: TextStyle(
              fontSize: 19.sp,
              fontWeight: FontWeight.w700,
              color: theme.colorScheme.onSurface,
            ),
          ),
          centerTitle: true,
        ),
        body: Column(
          children: [
            if (_categories.isNotEmpty) _buildCategoryTabs(),
            vSpace(16),
            _buildSearchBar(),
            vSpace(16),
            Expanded(child: _buildBody(theme)),
          ],
        ),
      ),
    );
  }

  Widget _buildBody(ThemeData theme) {
    if (_loading && _articles.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null && _articles.isEmpty) {
      return _buildMessageState(
        theme,
        icon: Icons.cloud_off,
        title: 'We could not load the answers',
        body: _error!,
        actionLabel: 'Try again',
        onAction: () => unawaited(_load()),
      );
    }
    if (_articles.isEmpty) {
      return _buildMessageState(
        theme,
        icon: Icons.help_outline,
        title: _searchController.text.trim().isEmpty
            ? 'Nothing published here yet'
            : 'No answer matches that',
        body: 'Ask us directly — the assistant answers the common questions '
            'straight away and passes anything else to a person.',
        actionLabel: 'Ask us',
        onAction: _askInstead,
      );
    }

    final grouped = <String, List<KbArticle>>{};
    for (final article in _articles) {
      grouped.putIfAbsent(article.category, () => []).add(article);
    }

    return RefreshIndicator(
      onRefresh: _load,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: Column(
          children: [
            for (final entry in grouped.entries) ...[
              FaqCategorySection(
                title: supportCategoryLabel(entry.key),
                questions: entry.value
                    .map((a) => FaqQuestion(question: a.question, answer: a.answer))
                    .toList(),
              ),
              vSpace(12),
            ],
            vSpace(4),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 16.w),
              child: TextButton.icon(
                onPressed: _askInstead,
                icon: Icon(Icons.support_agent, size: 18.sp),
                label: Text(
                  'Still stuck? Ask us',
                  style: TextStyle(fontSize: 17.sp, fontWeight: FontWeight.w600),
                ),
                style: TextButton.styleFrom(
                  foregroundColor: const Color(0xFF7434FF),
                ),
              ),
            ),
            vSpace(32),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageState(
    ThemeData theme, {
    required IconData icon,
    required String title,
    required String body,
    required String actionLabel,
    required VoidCallback onAction,
  }) {
    return Center(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 32.w),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 44.sp,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.3),
            ),
            vSpace(12),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 19.sp,
                fontWeight: FontWeight.w700,
                color: theme.colorScheme.onSurface,
              ),
            ),
            vSpace(8),
            Text(
              body,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 17.sp,
                height: 1.5,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
            vSpace(16),
            ElevatedButton(
              onPressed: onAction,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF7434FF),
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 12.h),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12.r),
                ),
              ),
              child: Text(actionLabel, style: TextStyle(fontSize: 17.sp)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryTabs() {
    final theme = Theme.of(context);
    return Container(
      // Tab strip bar reads from the live theme so it flips with the
      // dark/light toggle. Was hardcoded `Colors.white` which rendered
      // as a bright stripe on the dark scaffold.
      color: theme.cardColor,
      padding: EdgeInsets.symmetric(vertical: 12.h),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.symmetric(horizontal: 16.w),
        child: Row(
          children: [
            _buildTab('', 'All'),
            for (final category in _categories)
              _buildTab(category, supportCategoryLabel(category)),
          ],
        ),
      ),
    );
  }

  Widget _buildTab(String category, String label) {
    final theme = Theme.of(context);
    final isSelected = _selectedCategory == category;
    return GestureDetector(
      onTap: () => _selectCategory(category),
      child: Container(
        margin: EdgeInsets.only(right: 12.w),
        padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 10.h),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: isSelected ? theme.primaryColor : Colors.transparent,
              width: 2,
            ),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 19.sp,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            color: isSelected
                ? theme.primaryColor
                : theme.colorScheme.onSurface.withValues(alpha: 0.6),
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
        child: TextField(
          controller: _searchController,
          onChanged: _onSearchChanged,
          textInputAction: TextInputAction.search,
          onSubmitted: (_) => unawaited(_load()),
          decoration: InputDecoration(
            hintText: 'Search for help...',
            hintStyle: TextStyle(
              fontSize: 17.sp,
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
            ),
            prefixIcon: Icon(
              Icons.search,
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4),
              size: 20.sp,
            ),
            suffixIcon: _searchController.text.isEmpty
                ? null
                : IconButton(
                    icon: Icon(Icons.close, size: 18.sp),
                    onPressed: () {
                      _searchController.clear();
                      unawaited(_load());
                    },
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
