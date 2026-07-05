import 'package:flutter/material.dart';
import '../localization/app_localizations.dart';

/// Reusable localized form validators.
class Validators {
  Validators._();

  static String? required(String? value, BuildContext context,
      {String? label}) {
    if (value == null || value.trim().isEmpty) {
      return label != null
          ? '$label ${context.loc.validationRequired.toLowerCase()}'
          : context.loc.validationRequired;
    }
    return null;
  }

  static String? email(String? value, BuildContext context) {
    if (value == null || value.trim().isEmpty) {
      return context.loc.validationRequired;
    }
    final RegExp regex = RegExp(r'^[\w\.\-+]+@[\w\-]+(\.[\w\-]+)+$');
    if (!regex.hasMatch(value.trim())) {
      return context.loc.validationEmail;
    }
    return null;
  }

  static String? password(String? value, BuildContext context) {
    if (value == null || value.isEmpty) {
      return context.loc.validationRequired;
    }
    if (value.length < 6) {
      return context.loc.validationPassword;
    }
    return null;
  }

  static String? confirmPassword(
      String? value, String original, BuildContext context) {
    if (value == null || value.isEmpty) {
      return context.loc.validationRequired;
    }
    if (value != original) {
      return context.loc.validationConfirmPassword;
    }
    return null;
  }

  static String? phone(String? value, BuildContext context) {
    if (value == null || value.trim().isEmpty) {
      return context.loc.validationRequired;
    }
    final RegExp regex = RegExp(r'^[+\d][\d\s\-]{6,}$');
    if (!regex.hasMatch(value.trim())) {
      return context.loc.validationPhone;
    }
    return null;
  }

  static String? positiveNumber(String? value, BuildContext context,
      {required String label}) {
    if (value == null || value.trim().isEmpty) {
      return null;
    }
    final double? n = double.tryParse(value.trim());
    if (n == null || n < 0) {
      return '$label: ${context.loc.validationPositiveNumber.toLowerCase()}';
    }
    return null;
  }
}
