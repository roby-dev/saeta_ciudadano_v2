import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';

/// Login/register text field: a semibold 13px label rendered *above* the
/// input (not a Material floating [InputDecoration.labelText]), a 48-tall
/// radius-10 input (via [AppTheme]'s `inputDecorationTheme`), and an
/// optional show/hide eye icon for password fields.
class SaetaTextField extends StatefulWidget {
  const SaetaTextField({
    super.key,
    required this.label,
    this.prefixIcon,
    this.controller,
    this.keyboardType,
    this.obscureText = false,
    this.readOnly = false,
    this.isLoading = false,
    this.validator,
    this.textInputAction,
    this.onFieldSubmitted,
    this.onChanged,
    this.inputFormatters,
  });

  final String label;
  final IconData? prefixIcon;
  final TextEditingController? controller;
  final TextInputType? keyboardType;
  final bool obscureText;
  final bool readOnly;
  final bool isLoading;
  final String? Function(String?)? validator;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onFieldSubmitted;
  final ValueChanged<String>? onChanged;
  final List<TextInputFormatter>? inputFormatters;

  @override
  State<SaetaTextField> createState() => _SaetaTextFieldState();
}

class _SaetaTextFieldState extends State<SaetaTextField> {
  late bool _obscure;

  @override
  void initState() {
    super.initState();
    _obscure = widget.obscureText;
  }

  @override
  Widget build(BuildContext context) {
    Widget? suffix;
    if (widget.isLoading) {
      suffix = const Padding(
        padding: EdgeInsets.all(12),
        child: SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    } else if (widget.obscureText) {
      suffix = IconButton(
        icon: Icon(
          _obscure ? Icons.visibility_off : Icons.visibility,
        ),
        onPressed: () => setState(() => _obscure = !_obscure),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.label,
          style: const TextStyle(
            fontFamily: AppFonts.sans,
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: AppColors.heading,
          ),
        ),
        const SizedBox(height: 6),
        TextFormField(
          controller: widget.controller,
          keyboardType: widget.keyboardType,
          obscureText: _obscure,
          readOnly: widget.readOnly,
          textInputAction: widget.textInputAction,
          onFieldSubmitted: widget.onFieldSubmitted,
          onChanged: widget.onChanged,
          validator: widget.validator,
          inputFormatters: widget.inputFormatters,
          style: const TextStyle(fontFamily: AppFonts.sans, fontSize: 15),
          decoration: InputDecoration(
            prefixIcon:
                widget.prefixIcon != null ? Icon(widget.prefixIcon) : null,
            suffixIcon: suffix,
            filled: true,
            fillColor: widget.readOnly ? AppColors.background : null,
          ),
        ),
      ],
    );
  }
}
