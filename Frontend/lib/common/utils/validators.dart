// lib/common/utils/validators.dart
//


import 'package:flutter/material.dart';

/// Signature of a text validator used in compose().
typedef Validator = String? Function(String? value);

class Validators {
  Validators._();

  // ---------------------------------------------------------------------------
  // Composition helpers
  // ---------------------------------------------------------------------------

  /// Compose multiple validators and return the first error, if any.
  static FormFieldValidator<String> compose(List<Validator> validators) {
    return (String? value) {
      for (final v in validators) {
        final String? err = v(value);
        if (err != null) return err;
      }
      return null;
    };
  }

  /// Utility to run validators directly on a value.
  static String? run(String? value, List<Validator> validators) =>
      compose(validators)(value);

  // ---------------------------------------------------------------------------
  // Core text validators
  // ---------------------------------------------------------------------------

  /// Field must be non-empty after trimming.
  static Validator required({String message = 'This field is required.'}) {
    return (String? value) {
      if (value == null || value.trim().isEmpty) {
        return message;
      }
      return null;
    };
  }

  /// Validate email with a simple regex (client-side convenience).
  static Validator email({String message = 'Enter a valid email address.'}) {
    final RegExp _re =
        RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]{2,}$', caseSensitive: false);
    return (String? value) {
      final v = (value ?? '').trim();
      if (v.isEmpty) return null; // allow empty; chain with required() if needed
      return _re.hasMatch(v) ? null : message;
    };
  }

  /// Minimum length (counts characters).
  static Validator minLength(int min, {String? message}) {
    return (String? value) {
      final v = value ?? '';
      if (v.isEmpty) return null; // allow empty; use required() to force
      return v.length < min ? (message ?? 'Minimum $min characters.') : null;
    };
  }

  /// Maximum length.
  static Validator maxLength(int max, {String? message}) {
    return (String? value) {
      final v = value ?? '';
      if (v.length > max) {
        return message ?? 'Maximum $max characters.';
      }
      return null;
    };
  }

  /// Only letters, numbers, spaces (useful for names).
  static Validator alnumSpace({String? message}) {
    final re = RegExp(r'^[A-Za-z0-9 ]+$');
    return (String? value) {
      final v = (value ?? '').trim();
      if (v.isEmpty) return null;
      return re.hasMatch(v)
          ? null
          : (message ?? 'Only letters, numbers, and spaces are allowed.');
    };
  }

  /// Basic phone validator (digits, spaces, +, -, parentheses).
  static Validator phone({String? message}) {
    final re = RegExp(r'^[0-9+\-\s()]{7,}$');
    return (String? value) {
      final v = (value ?? '').trim();
      if (v.isEmpty) return null;
      return re.hasMatch(v)
          ? null
          : (message ?? 'Enter a valid phone number.');
    };
  }

  /// Postal code (alphanumeric 3–10).
  static Validator postalCode({String? message}) {
    final re = RegExp(r'^[A-Za-z0-9\- ]{3,10}$');
    return (String? value) {
      final v = (value ?? '').trim();
      if (v.isEmpty) return null;
      return re.hasMatch(v)
          ? null
          : (message ?? 'Enter a valid postal code.');
    };
  }

  // ---------------------------------------------------------------------------
  // Password helpers
  // ---------------------------------------------------------------------------

  /// Simple password strength: min length, must include at least one letter and one digit.
  static Validator passwordStrong({
    int minLength = 8,
    bool requireLetter = true,
    bool requireDigit = true,
    String? message,
  }) {
    final reLetter = RegExp(r'[A-Za-z]');
    final reDigit = RegExp(r'\d');
    return (String? value) {
      final v = value ?? '';
      if (v.isEmpty) return null; // allow empty; pair with required()
      if (v.length < minLength) {
        return message ?? 'Use at least $minLength characters.';
      }
      if (requireLetter && !reLetter.hasMatch(v)) {
        return message ?? 'Include at least one letter.';
      }
      if (requireDigit && !reDigit.hasMatch(v)) {
        return message ?? 'Include at least one number.';
      }
      return null;
    };
  }

  /// Match against another controller's text (e.g., confirm password).
  static Validator matchController(
    TextEditingController other, {
    String message = 'Does not match.',
  }) {
    return (String? value) {
      final v = value ?? '';
      return v == other.text ? null : message;
    };
  }

  /// Match against a provided string value.
  static Validator matchValue(
    String otherValue, {
    String message = 'Does not match.',
  }) {
    return (String? value) {
      final v = value ?? '';
      return v == otherValue ? null : message;
    };
  }

  // ---------------------------------------------------------------------------
  // Numeric & price validators
  // ---------------------------------------------------------------------------

  /// Accepts integers or decimals; optional min/max bounds.
  static Validator number({
    double? min,
    double? max,
    String invalidMessage = 'Enter a valid number.',
    String? minMessage,
    String? maxMessage,
  }) {
    return (String? value) {
      final v = (value ?? '').trim();
      if (v.isEmpty) return null;
      final parsed = double.tryParse(v.replaceAll(',', ''));
      if (parsed == null) return invalidMessage;
      if (min != null && parsed < min) {
        return minMessage ?? 'Must be ≥ $min.';
      }
      if (max != null && parsed > max) {
        return maxMessage ?? 'Must be ≤ $max.';
      }
      return null;
    };
  }

  /// Price validator: non-negative number with up to 2 decimals by default.
  static Validator price({
    int decimals = 2,
    bool allowZero = true,
    String invalidMessage = 'Enter a valid amount.',
    String? negativeMessage,
    String? zeroMessage,
  }) {
    final re = RegExp(r'^\d+(\.\d+)?$');
    return (String? value) {
      final v = (value ?? '').trim();
      if (v.isEmpty) return null;
      if (!re.hasMatch(v)) return invalidMessage;
      final parsed = double.tryParse(v);
      if (parsed == null) return invalidMessage;
      if (parsed < 0) return negativeMessage ?? 'Amount cannot be negative.';
      if (!allowZero && parsed == 0) {
        return zeroMessage ?? 'Amount must be greater than zero.';
      }
      // Decimal places check
      final dot = v.indexOf('.');
      if (dot >= 0) {
        final frac = v.substring(dot + 1);
        if (frac.length > decimals) {
          return 'Use up to $decimals decimal places.';
        }
      }
      return null;
    };
  }

  // ---------------------------------------------------------------------------
  // Address validators (simple client hints)
  // ---------------------------------------------------------------------------

  static Validator name({String message = 'Enter a valid name.'}) {
    // Letters, numbers, spaces, some punctuation.
    final re = RegExp(r"^[A-Za-z0-9 ,.'-]{2,}$");
    return (String? value) {
      final v = (value ?? '').trim();
      if (v.isEmpty) return null;
      return re.hasMatch(v) ? null : message;
    };
  }

  static Validator nonEmptyLine({String message = 'Enter a valid address line.'}) {
    return (String? value) {
      final v = (value ?? '').trim();
      if (v.isEmpty) return null;
      return v.length >= 3 ? null : message;
    };
  }

  static Validator city({String message = 'Enter a valid city.'}) {
    final re = RegExp(r'^[A-Za-z .\-]{2,}$');
    return (String? value) {
      final v = (value ?? '').trim();
      if (v.isEmpty) return null;
      return re.hasMatch(v) ? null : message;
    };
  }

  static Validator region({String message = 'Enter a valid region/state.'}) {
    final re = RegExp(r'^[A-Za-z .\-]{2,}$');
    return (String? value) {
      final v = (value ?? '').trim();
      if (v.isEmpty) return null;
      return re.hasMatch(v) ? null : message;
    };
  }

  // ---------------------------------------------------------------------------
  // Boolean / checkbox
  // ---------------------------------------------------------------------------

  /// Checkbox must be true (e.g., accept Terms).
  static FormFieldValidator<bool> mustBeTrue({
    String message = 'Please accept to continue.',
  }) {
    return (bool? v) => (v ?? false) ? null : message;
  }

  // ---------------------------------------------------------------------------
  // Misc
  // ---------------------------------------------------------------------------

  /// If you get a server-side error string for a specific field,
  /// use this validator first in compose([]) to show it once.
  static Validator serverError(String? error) {
    bool consumed = false;
    return (String? value) {
      if (consumed || error == null || error.trim().isEmpty) return null;
      consumed = true;
      return error;
    };
  }
}
