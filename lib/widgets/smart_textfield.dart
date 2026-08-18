import 'package:flutter/material.dart';

class SmartTextField extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool obscureText;
  final TextEditingController controller;

  const SmartTextField({
    super.key,
    required this.label,
    required this.icon,
    required this.controller,
    this.obscureText = false,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,

      obscureText: obscureText,

      decoration: InputDecoration(
        labelText: label,

        prefixIcon: Icon(icon),
      ),
    );
  }
}