// widgets/crm_text_field.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_theme.dart';

class CrmTextField extends StatefulWidget {
  final String label;
  final String? hint;
  final IconData? prefixIcon;
  final IconData? suffixIcon;
  final bool isPassword;
  final TextEditingController? controller;
  final String? Function(String?)? validator;
  final TextInputType keyboardType;
  final TextInputAction textInputAction;
  final int? maxLines;
  final bool enabled;
  final String? initialValue;
  final void Function(String)? onChanged;
  final void Function()? onTap;
  final bool readOnly;
  final FocusNode? focusNode;
  final Color? fillColor;
  final ValueChanged<String>? onFieldSubmitted; // 👈 ADDED
  final int? maxLength; // 👈 ADDED
  final List<TextInputFormatter>? inputFormatters; // 👈 ADDED

  const CrmTextField({
    super.key,
    required this.label,
    this.hint,
    this.prefixIcon,
    this.suffixIcon,
    this.isPassword = false,
    this.controller,
    this.validator,
    this.keyboardType = TextInputType.text,
    this.textInputAction = TextInputAction.next,
    this.maxLines = 1,
    this.enabled = true,
    this.initialValue,
    this.onChanged,
    this.onTap,
    this.readOnly = false,
    this.focusNode,
    this.fillColor,
    this.onFieldSubmitted, // 👈 ADDED
    this.maxLength, // 👈 ADDED
    this.inputFormatters, // 👈 ADDED
  });

  @override
  State<CrmTextField> createState() => _CrmTextFieldState();
}

class _CrmTextFieldState extends State<CrmTextField> {
  bool _obscure = true;
  late TextEditingController _controller;
  bool _hasInitialValue = false;

  @override
  void initState() {
    super.initState();
    // If controller is provided, use it; otherwise create one
    if (widget.controller != null) {
      _controller = widget.controller!;
    } else {
      _controller = TextEditingController(text: widget.initialValue);
      if (widget.initialValue != null && widget.initialValue!.isNotEmpty) {
        _hasInitialValue = true;
      }
    }
  }

  @override
  void didUpdateWidget(CrmTextField oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Update controller if widget.controller changes
    if (widget.controller != null && widget.controller != oldWidget.controller) {
      _controller = widget.controller!;
    }
  }

  @override
  void dispose() {
    // Only dispose if we created the controller
    if (widget.controller == null) {
      _controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Label with optional required indicator
        Row(
          children: [
            Text(
              widget.label,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: AppColors.textPrimary,
              ),
            ),
            if (widget.validator != null) ...[
              const SizedBox(width: 4),
              const Text(
                '*',
                style: TextStyle(
                  color: Colors.red,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 6),
        TextFormField(
          controller: _controller,
          focusNode: widget.focusNode,
          obscureText: widget.isPassword && _obscure,
          keyboardType: widget.keyboardType,
          textInputAction: widget.textInputAction,
          validator: widget.validator,
          maxLines: widget.maxLines,
          enabled: widget.enabled,
          readOnly: widget.readOnly,
          onChanged: widget.onChanged,
          onTap: widget.onTap,
          onFieldSubmitted: widget.onFieldSubmitted, // 👈 ADDED
          maxLength: widget.maxLength, // 👈 ADDED
          inputFormatters: widget.inputFormatters ?? 
              (widget.maxLength != null 
                  ? [LengthLimitingTextInputFormatter(widget.maxLength)] 
                  : null), // 👈 ADDED
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontSize: 15,
            fontWeight: FontWeight.w500,
          ),
          decoration: InputDecoration(
            hintText: widget.hint,
            hintStyle: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 14,
            ),
            prefixIcon: widget.prefixIcon != null
                ? Icon(
                    widget.prefixIcon,
                    color: AppColors.textSecondary,
                    size: 20,
                  )
                : null,
            suffixIcon: widget.isPassword
                ? IconButton(
                    icon: Icon(
                      _obscure 
                          ? Icons.visibility_off_outlined 
                          : Icons.visibility_outlined,
                      color: AppColors.textSecondary,
                      size: 20,
                    ),
                    onPressed: widget.enabled
                        ? () => setState(() => _obscure = !_obscure)
                        : null,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  )
                : (widget.suffixIcon != null
                    ? Icon(
                        widget.suffixIcon,
                        color: AppColors.textSecondary,
                        size: 20,
                      )
                    : null),
            // 👇 ADDED: counter text style for maxLength
            counterText: widget.maxLength != null ? null : '',
            counterStyle: const TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: AppColors.border),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: AppColors.border),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: AppColors.primary, width: 2),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Colors.red, width: 1.5),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Colors.red, width: 2),
            ),
            disabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(
                color: AppColors.textSecondary.withOpacity(0.3),
              ),
            ),
            filled: true,
            fillColor: widget.fillColor ?? Colors.white,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 14,
            ),
            errorStyle: const TextStyle(
              fontSize: 12,
              color: Colors.red,
            ),
          ),
        ),
      ],
    );
  }
}