import 'package:communal_mobile/core/widgets/space.dart';
import 'package:communal_mobile/data/repositories/transfer_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';

/// Full bank list + search + featured carousel. Pops with selected [TransferBank].
class TransferExternalBankPickerScreen extends StatefulWidget {
  const TransferExternalBankPickerScreen({
    super.key,
    required this.banks,
    required this.featuredBanks,
  });

  final List<TransferBank> banks;
  final List<TransferBank> featuredBanks;

  @override
  State<TransferExternalBankPickerScreen> createState() =>
      _TransferExternalBankPickerScreenState();
}

class _TransferExternalBankPickerScreenState
    extends State<TransferExternalBankPickerScreen> {
  final _searchCtrl = TextEditingController();

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  List<TransferBank> get _filtered {
    final q = _searchCtrl.text.trim().toLowerCase();
    if (q.isEmpty) return widget.banks;
    return widget.banks
        .where(
          (b) =>
              b.name.toLowerCase().contains(q) ||
              b.nipCode.toLowerCase().contains(q),
        )
        .toList(growable: false);
  }

  Widget _logoTile({double size = 40}) {
    return CircleAvatar(
      radius: (size / 2).r,
      backgroundColor: const Color(0xFFE8E8F0),
      child: Icon(
        Icons.account_balance,
        size: (size * 0.45).sp,
        color: const Color(0xFF0F1D40),
      ),
    );
  }

  Widget _bankRow(TransferBank b, {bool compact = false}) {
    return InkWell(
      onTap: () => context.pop(b),
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: 14.w,
          vertical: compact ? 10.h : 11.h,
        ),
        child: Row(
          children: [
            _logoTile(size: compact ? 40 : 44),
            SizedBox(width: 12.w),
            Expanded(
                child: Text(
                b.name,
                style: TextStyle(
                  fontSize: compact ? 15.sp : 16.sp,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF0F1D40),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final featured = widget.featuredBanks.take(10).toList(growable: false);
    final showFeatured =
        featured.isNotEmpty && _searchCtrl.text.trim().isEmpty;

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(8.w, 4.h, 8.w, 0),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back_ios_new, size: 20),
                    onPressed: () => context.pop(),
                  ),
                  Expanded(
                    child: Text(
                      'Choose Recipient Bank',
                      style: TextStyle(
                        fontSize: 22.sp,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF0F1D40),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(16.w, 12.h, 16.w, 8.h),
              child: TextField(
                controller: _searchCtrl,
                onChanged: (_) => setState(() {}),
                style: TextStyle(fontSize: 17.sp, color: Colors.black87),
                decoration: InputDecoration(
                  hintText: 'Search banks',
                  hintStyle: TextStyle(fontSize: 17.sp, color: Colors.grey.shade500),
                  prefixIcon: Icon(Icons.search, color: Colors.grey.shade600, size: 24.sp),
                  filled: true,
                  fillColor: Colors.white,
                  contentPadding:
                      EdgeInsets.symmetric(horizontal: 12.w, vertical: 14.h),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12.r),
                    borderSide: BorderSide(color: Colors.grey.shade300),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12.r),
                    borderSide: BorderSide(color: Colors.grey.shade300),
                  ),
                ),
              ),
            ),
            Expanded(
              child: ListView(
                padding: EdgeInsets.fromLTRB(16.w, 8.h, 16.w, 24.h),
                children: [
                  if (showFeatured) ...[
                    Text(
                      'Featured Banks',
                      style: TextStyle(
                        fontSize: 17.sp,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF0F1D40),
                      ),
                    ),
                    vSpace(10),
                    Container(
                      width: double.infinity,
                      padding: EdgeInsets.fromLTRB(8.w, 8.h, 8.w, 10.h),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12.r),
                        border: Border.all(color: const Color(0xFFE7E7E7)),
                      ),
                      child: SizedBox(
                        height: 108.h,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount: featured.length,
                          separatorBuilder: (_, __) => SizedBox(width: 14.w),
                          itemBuilder: (context, i) {
                            final b = featured[i];
                            return InkWell(
                              onTap: () => context.pop(b),
                              borderRadius: BorderRadius.circular(10.r),
                              child: SizedBox(
                                width: 96.w,
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    _logoTile(size: 46),
                                    vSpace(8),
                                    Text(
                                      b.name,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        fontSize: 15.sp,
                                        fontWeight: FontWeight.w600,
                                        height: 1.25,
                                        color: const Color(0xFF0F1D40),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                    vSpace(16),
                  ],
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12.r),
                      border: Border.all(color: const Color(0xFFE7E7E7)),
                    ),
                    child: Column(
                      children: [
                        for (final b in _filtered) _bankRow(b),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
