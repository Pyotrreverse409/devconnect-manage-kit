import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

class SearchField extends StatelessWidget {
  final String hintText;
  final ValueChanged<String> onChanged;
  final VoidCallback? onClear;
  final TextEditingController? controller;

  const SearchField({
    super.key,
    this.hintText = 'Search...',
    required this.onChanged,
    this.onClear,
    this.controller,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return SizedBox(
      height: 32,
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        style: TextStyle(
          fontSize: 13,
          color: isDark ? Colors.white : Colors.black87,
        ),
        decoration: InputDecoration(
          hintText: hintText,
          hintStyle: TextStyle(
            fontSize: 13,
            color: Colors.grey[500],
          ),
          prefixIcon: Icon(
            LucideIcons.search,
            size: 14,
            color: Colors.grey[500],
          ),
          prefixIconConstraints: const BoxConstraints(minWidth: 36),
          suffixIcon: onClear != null
              ? GestureDetector(
                  onTap: onClear,
                  child: Icon(
                    LucideIcons.x,
                    size: 14,
                    color: Colors.grey[500],
                  ),
                )
              : null,
          contentPadding: const EdgeInsets.symmetric(horizontal: 12),
          filled: true,
          fillColor: isDark
              ? const Color(0xFF21262D)
              : const Color(0xFFEEF0F2),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(
              color: theme.colorScheme.primary.withValues(alpha: 0.5),
              width: 1,
            ),
          ),
        ),
      ),
    );
  }
}
