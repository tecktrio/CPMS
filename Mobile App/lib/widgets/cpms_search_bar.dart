import 'package:flutter/material.dart';

/// Standard rectangular search bar for CPMS platform.
/// Features a crisp rectangle layout (subtle 8px border radius),
/// clean 1px border, search icon, very light placeholder color (#CBD5E1),
/// and an interactive clear button.
class CpmsSearchBar extends StatelessWidget {
  final TextEditingController controller;
  final String hintText;
  final ValueChanged<String>? onChanged;
  final VoidCallback? onClear;
  final double height;
  final FocusNode? focusNode;
  final bool autofocus;
  final ValueChanged<String>? onSubmitted;
  final EdgeInsetsGeometry? margin;

  const CpmsSearchBar({
    super.key,
    required this.controller,
    this.hintText = 'Search...',
    this.onChanged,
    this.onClear,
    this.height = 46,
    this.focusNode,
    this.autofocus = false,
    this.onSubmitted,
    this.margin,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      margin: margin,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE2E8F0), width: 1.2),
        boxShadow: const [
          BoxShadow(
            color: Color(0x06000000),
            blurRadius: 4,
            offset: Offset(0, 1),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 14),
            child: Icon(
              Icons.search,
              color: Color(0xFF94A3B8),
              size: 20,
            ),
          ),
          Expanded(
            child: ValueListenableBuilder<TextEditingValue>(
              valueListenable: controller,
              builder: (context, value, _) {
                return TextField(
                  controller: controller,
                  focusNode: focusNode,
                  autofocus: autofocus,
                  onSubmitted: onSubmitted,
                  onChanged: onChanged,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF0F172A),
                  ),
                  decoration: InputDecoration(
                    hintText: hintText,
                    hintStyle: const TextStyle(
                      color: Color(0xFFCBD5E1), // very light placeholder color
                      fontSize: 13.5,
                      fontWeight: FontWeight.w400,
                    ),
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(vertical: 12),
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    errorBorder: InputBorder.none,
                    disabledBorder: InputBorder.none,
                    fillColor: Colors.transparent,
                    filled: false,
                  ),
                );
              },
            ),
          ),
          ValueListenableBuilder<TextEditingValue>(
            valueListenable: controller,
            builder: (context, value, _) {
              if (value.text.isEmpty) {
                return const SizedBox(width: 8);
              }
              return IconButton(
                icon: const Icon(
                  Icons.clear,
                  color: Color(0xFF94A3B8),
                  size: 18,
                ),
                splashRadius: 18,
                onPressed: () {
                  controller.clear();
                  if (onClear != null) {
                    onClear!();
                  } else if (onChanged != null) {
                    onChanged!('');
                  }
                },
              );
            },
          ),
        ],
      ),
    );
  }
}

