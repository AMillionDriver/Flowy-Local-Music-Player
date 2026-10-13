import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../data/models/music_filter.dart';

class FilterChipsRow extends StatelessWidget {
  final List<MusicFilter> filters;
  final String activeFilterId;
  final ValueChanged<String> onFilterSelected;

  const FilterChipsRow({
    super.key,
    required this.filters,
    required this.activeFilterId,
    required this.onFilterSelected,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 36,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: filters.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final filter = filters[index];
          final isSelected = filter.id == activeFilterId;

          return Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(18),
              onTap: () => onFilterSelected(filter.id),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(horizontal: 14),
                decoration: BoxDecoration(
                  color: isSelected
                      ? AppColors.primaryContainer
                      : AppColors.surfaceContainerHigh.withValues(alpha: 0.85),
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: AppColors.primaryContainer.withValues(alpha: 0.4),
                            blurRadius: 12,
                            offset: const Offset(0, 2),
                          ),
                        ]
                      : null,
                ),
                alignment: Alignment.center,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (filter.icon != null) ...[
                      Icon(
                        filter.icon,
                        size: 15,
                        color: isSelected
                            ? AppColors.onPrimaryContainer
                            : AppColors.secondaryFixed,
                      ),
                      const SizedBox(width: 6),
                    ],
                    Text(
                      filter.label,
                      style: AppTypography.labelMd.copyWith(
                        color: isSelected
                            ? AppColors.onPrimaryContainer
                            : AppColors.secondaryFixed,
                        fontWeight:
                            isSelected ? FontWeight.w600 : FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
