import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:communal_mobile/core/widgets/space.dart';
import 'package:communal_mobile/screens/loans/data/sample_guarantors.dart';

class GuarantorSelector extends StatefulWidget {
  const GuarantorSelector({
    super.key,
    required this.label,
    required this.selectedGuarantor,
    required this.availableGuarantors,
    required this.excludedGuarantorIds,
    required this.onChanged,
  });

  final String label;
  final Guarantor? selectedGuarantor;
  final List<Guarantor> availableGuarantors;
  final List<String> excludedGuarantorIds;
  final Function(Guarantor?) onChanged;

  @override
  State<GuarantorSelector> createState() => _GuarantorSelectorState();
}

class _GuarantorSelectorState extends State<GuarantorSelector> {
  bool _isExpanded = false;

  List<Guarantor> get _filteredGuarantors {
    return widget.availableGuarantors
        .where((g) => !widget.excludedGuarantorIds.contains(g.id))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.label,
          style: TextStyle(
            fontSize: 16.sp,
            fontWeight: FontWeight.w700,
            color: const Color(0xFF0F1D40),
          ),
        ),
        vSpace(12),
        GestureDetector(
          onTap: () {
            setState(() {
              _isExpanded = !_isExpanded;
            });
          },
          child: Container(
            padding: EdgeInsets.all(16.w),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12.r),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: Row(
              children: [
                Expanded(
                  child: widget.selectedGuarantor != null
                      ? Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.selectedGuarantor!.name,
                              style: TextStyle(
                                fontSize: 15.sp,
                                fontWeight: FontWeight.w700,
                                color: const Color(0xFF0F1D40),
                              ),
                            ),
                            vSpace(4),
                            Text(
                              widget.selectedGuarantor!.displayInfo,
                              style: TextStyle(
                                fontSize: 13.sp,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ],
                        )
                      : Text(
                          'Select guarantor',
                          style: TextStyle(
                            fontSize: 15.sp,
                            color: Colors.grey.shade400,
                          ),
                        ),
                ),
                Icon(
                  _isExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                  color: Colors.grey.shade600,
                ),
              ],
            ),
          ),
        ),
        if (_isExpanded) ...[
          vSpace(8),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12.r),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: Column(
              children: [
                for (int i = 0; i < _filteredGuarantors.length; i++) ...[
                  _buildGuarantorOption(_filteredGuarantors[i]),
                  if (i < _filteredGuarantors.length - 1)
                    Divider(height: 1, color: Colors.grey.shade200),
                ],
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildGuarantorOption(Guarantor guarantor) {
    final isSelected = widget.selectedGuarantor?.id == guarantor.id;

    return InkWell(
      onTap: () {
        widget.onChanged(isSelected ? null : guarantor);
        setState(() {
          _isExpanded = false;
        });
      },
      child: Container(
        padding: EdgeInsets.all(16.w),
        color: isSelected ? const Color(0xFFF3E5F5) : Colors.transparent,
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    guarantor.name,
                    style: TextStyle(
                      fontSize: 15.sp,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF0F1D40),
                    ),
                  ),
                  vSpace(4),
                  Text(
                    guarantor.displayInfo,
                    style: TextStyle(
                      fontSize: 13.sp,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),
            if (isSelected)
              Icon(
                Icons.check_circle,
                color: const Color(0xFF7434FF),
                size: 24.sp,
              ),
          ],
        ),
      ),
    );
  }
}

