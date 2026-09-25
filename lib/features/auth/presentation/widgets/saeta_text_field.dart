import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class SaetaTextField extends StatefulWidget {
  const SaetaTextField({
    super.key,
    required this.label,
    required this.prefixIcon,
    this.controller,
    this.keyboardType,
    this.obscureText = false,
    this.readOnly = false,
    this.isLoading = false,
    this.validator,
    this.textInputAction,
    this.onFieldSubmitted,
    this.inputFormatters,
  });

  final String label;
  final IconData prefixIcon;
  final TextEditingController? controller;
  final TextInputType? keyboardType;
  final bool obscureText;
  final bool readOnly;
  final bool isLoading;
  final String? Function(String?)? validator;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onFieldSubmitted;
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

    return TextFormField(
      controller: widget.controller,
      keyboardType: widget.keyboardType,
      obscureText: _obscure,
      readOnly: widget.readOnly,
      textInputAction: widget.textInputAction,
      onFieldSubmitted: widget.onFieldSubmitted,
      validator: widget.validator,
      inputFormatters: widget.inputFormatters,
      decoration: InputDecoration(
        labelText: widget.label,
        border: const OutlineInputBorder(),
        prefixIcon: Icon(widget.prefixIcon),
        suffixIcon: suffix,
        filled: widget.readOnly,
        fillColor: widget.readOnly
            ? Theme.of(context).colorScheme.surfaceContainerHighest
            : null,
      ),
    );
  }
}
