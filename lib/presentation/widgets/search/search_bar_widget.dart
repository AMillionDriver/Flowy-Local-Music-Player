import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';

class SearchBarWidget extends StatefulWidget {
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;
  final String initialValue;
  final List<String> suggestions;
  final ValueChanged<String>? onSuggestionTap;

  const SearchBarWidget({
    super.key,
    required this.onChanged,
    required this.onClear,
    this.initialValue = '',
    this.suggestions = const [],
    this.onSuggestionTap,
  });

  @override
  State<SearchBarWidget> createState() => _SearchBarWidgetState();
}

class _SearchBarWidgetState extends State<SearchBarWidget> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialValue);
  }

  @override
  void didUpdateWidget(covariant SearchBarWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialValue != _controller.text) {
      _controller.text = widget.initialValue;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          height: 46,
          decoration: BoxDecoration(
            color: AppColors.surfaceContainerHigh.withValues(alpha: 0.85),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: AppColors.outlineVariant.withValues(alpha: 0.3),
              width: 0.8,
            ),
          ),
          child: Row(
            children: [
              const SizedBox(width: 14),
              const Icon(
                Icons.search,
                color: AppColors.primary,
                size: 20,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: _controller,
                  onChanged: widget.onChanged,
                  style: AppTypography.bodyMd,
                  cursorColor: AppColors.primary,
                  decoration: InputDecoration(
                    border: InputBorder.none,
                    isDense: true,
                    hintText: 'Cari lagu, artis, atau album...',
                    hintStyle: AppTypography.bodyMd.copyWith(
                      color: AppColors.outline,
                    ),
                  ),
                ),
              ),
              if (_controller.text.isNotEmpty)
                IconButton(
                  icon: const Icon(Icons.close, size: 18),
                  color: AppColors.outline,
                  tooltip: 'Hapus Pencarian',
                  onPressed: () {
                    _controller.clear();
                    widget.onClear();
                  },
                )
              else
                IconButton(
                  icon: const Icon(Icons.mic_none, size: 20),
                  color: AppColors.outline,
                  tooltip: 'Pencarian Suara',
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Pencarian suara aktif'),
                        duration: Duration(seconds: 1),
                      ),
                    );
                  },
                ),
              const SizedBox(width: 4),
            ],
          ),
        ),

        // Interactive Suggestion Chips ala Fuse Search ("Mungkin maksud Anda...")
        if (widget.suggestions.isNotEmpty && _controller.text.trim().isNotEmpty) ...[
          const SizedBox(height: 8),
          SizedBox(
            height: 28,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: widget.suggestions.length,
              separatorBuilder: (_, _) => const SizedBox(width: 6),
              itemBuilder: (context, index) {
                final sug = widget.suggestions[index];
                return InkWell(
                  borderRadius: BorderRadius.circular(14),
                  onTap: () {
                    _controller.text = sug;
                    widget.onChanged(sug);
                    widget.onSuggestionTap?.call(sug);
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.primaryContainer.withValues(alpha: 0.35),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: AppColors.primary.withValues(alpha: 0.4),
                        width: 0.8,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.auto_awesome,
                          size: 12,
                          color: AppColors.primaryFixed,
                        ),
                        const SizedBox(width: 5),
                        Text(
                          sug,
                          style: AppTypography.labelSm.copyWith(
                            color: AppColors.primaryFixed,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ],
    );
  }
}
