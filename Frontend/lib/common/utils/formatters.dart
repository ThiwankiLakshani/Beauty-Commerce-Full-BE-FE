// lib/common/utils/formatters.dart
//


import 'dart:math';
import 'package:flutter/material.dart';

import '../../app/app_constants.dart';

class Formatters {
  Formatters._();

  // ---------------------------------------------------------------------------
  // Number & Currency
  // ---------------------------------------------------------------------------

  /// Returns a formatted price string like "LKR 1,234.56".
  static String price(
    num? value, {
    String? currency, // e.g. 'LKR', 'USD'
    String? symbolOverride, // e.g. 'Rs' or '₨'
    int fractionDigits = 2,
  }) {
    final v = (value ?? 0).toDouble();
    final c = currency ?? AppInfo.defaultCurrency;
    final prefix = symbolOverride ?? _currencyPrefix(c);
    return '$prefix ${_numberWithGrouping(v, fractionDigits: fractionDigits)}';
  }

  /// Returns a compact currency string, e.g. "LKR 1.2K", "LKR 3.4M".
  static String compactCurrency(
    num? value, {
    String? currency,
    String? symbolOverride,
    int fractionDigits = 1,
  }) {
    final v = (value ?? 0).toDouble();
    final c = currency ?? AppInfo.defaultCurrency;
    final prefix = symbolOverride ?? _currencyPrefix(c);
    return '$prefix ${_compactNumber(v, fractionDigits: fractionDigits)}';
  }

  /// Formats a plain number with thousand separators (e.g., "12,345").
  static String number(
    num? value, {
    int fractionDigits = 0,
  }) {
    final v = (value ?? 0).toDouble();
    return _numberWithGrouping(v, fractionDigits: fractionDigits);
  }

  /// Formats a percent, e.g., 0.125 => "12.5%".
  static String percent(
    num? value, {
    int fractionDigits = 1,
  }) {
    final v = (value ?? 0).toDouble() * 100.0;
    return '${_numberWithGrouping(v, fractionDigits: fractionDigits)}%';
  }

  // ---------------------------------------------------------------------------
  // Date & Time
  // ---------------------------------------------------------------------------

  /// Formats as "YYYY-MM-DD".
  static String dateYMD(DateTime? dt) {
    if (dt == null) return '-';
    final y = dt.year.toString().padLeft(4, '0');
    final m = dt.month.toString().padLeft(2, '0');
    final d = dt.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
    // Example: 2025-09-06
  }

  /// Formats as "YYYY-MM-DD HH:MM".
  static String dateTimeShort(DateTime? dt) {
    if (dt == null) return '-';
    final date = dateYMD(dt);
    final hh = dt.hour.toString().padLeft(2, '0');
    final mm = dt.minute.toString().padLeft(2, '0');
    return '$date $hh:$mm';
    // Example: 2025-09-06 14:03
  }

  /// Returns "just now", "2m", "3h", "5d", "2w", "3mo", "1y".
  static String timeAgo(DateTime? time, {DateTime? now}) {
    if (time == null) return '-';
    final n = now ?? DateTime.now();
    Duration diff = n.difference(time);
    if (diff.inSeconds <= 15) return 'just now';
    if (diff.inMinutes < 1) return '${diff.inSeconds}s';
    if (diff.inHours < 1) return '${diff.inMinutes}m';
    if (diff.inDays < 1) return '${diff.inHours}h';
    if (diff.inDays < 7) return '${diff.inDays}d';

    final weeks = diff.inDays ~/ 7;
    if (weeks < 5) return '${weeks}w';

    final months = diff.inDays ~/ 30;
    if (months < 12) return '${months}mo';

    final years = diff.inDays ~/ 365;
    return '${years}y';
  }

  // ---------------------------------------------------------------------------
  // Text Helpers
  // ---------------------------------------------------------------------------

  /// Capitalizes each word: "hello world" -> "Hello World".
  static String titleCase(String input) {
    final lower = input.toLowerCase().replaceAll('_', ' ');
    final words = lower.split(RegExp(r'\s+')).where((w) => w.isNotEmpty);
    return words
        .map((w) => w[0].toUpperCase() + (w.length > 1 ? w.substring(1) : ''))
        .join(' ');
  }

  /// Truncates with ellipsis if longer than [max].
  static String truncate(String? text, {int max = 80, String ellipsis = '…'}) {
    final t = text ?? '';
    if (t.length <= max) return t;
    if (max <= 1) return ellipsis;
    return t.substring(0, max - 1) + ellipsis;
  }

  /// Masks an email showing first 1-3 chars of local part and domain.
  /// "john.doe@example.com" -> "jo***@example.com"
  static String maskEmail(String? email) {
    final e = (email ?? '').trim();
    final at = e.indexOf('@');
    if (at <= 0) return e.isEmpty ? '-' : e;
    final local = e.substring(0, at);
    final domain = e.substring(at);
    final shown = local.length <= 3 ? local : local.substring(0, 3);
    return '$shown***$domain';
  }

  /// Masks a phone number keeping last 4 digits.
  /// "0771234567" -> "***-***-4567"
  static String maskPhone(String? phone) {
    final p = (phone ?? '').replaceAll(RegExp(r'\s+'), '');
    if (p.isEmpty) return '-';
    final last4 = p.length >= 4 ? p.substring(p.length - 4) : p;
    return '***-***-$last4';
  }

  /// Joins non-empty strings with a separator.
  static String joinNonEmpty(Iterable<String?> items, {String sep = ', '}) {
    return items.where((e) => (e ?? '').trim().isNotEmpty).map((e) => e!.trim()).join(sep);
  }

  /// Normalizes order status to a readable label (e.g., "paid", "processing").
  static String orderStatusLabel(String? status) {
    final s = (status ?? '').trim().toLowerCase();
    switch (s) {
      case 'paid':
        return 'Paid';
      case 'processing':
        return 'Processing';
      case 'shipped':
        return 'Shipped';
      case 'completed':
        return 'Completed';
      case 'pending':
        return 'Pending';
      case 'canceled':
      case 'cancelled':
        return 'Canceled';
      case 'refunded':
        return 'Refunded';
      default:
        return titleCase(s.isEmpty ? 'Unknown' : s);
    }
  }

  // ---------------------------------------------------------------------------
  // Internals
  // ---------------------------------------------------------------------------

  /// Very small currency map; returns a readable prefix for known codes.
  static String _currencyPrefix(String? code) {
    switch ((code ?? '').toUpperCase()) {
      case 'USD':
        return '\$';
      case 'EUR':
        return '€';
      case 'GBP':
        return '£';
      case 'JPY':
      case 'CNY':
        return '¥';
      case 'INR':
        return '₹';
      case 'KRW':
        return '₩';
      case 'VND':
        return '₫';
      case 'AUD':
        return 'A\$';
      case 'CAD':
        return 'C\$';
      case 'SGD':
        return 'S\$';
      case 'MYR':
        return 'RM';
      case 'LKR':
      default:
        // Default: show the code itself (matches backend "LKR 0.00" style).
        return (code ?? AppInfo.defaultCurrency).toUpperCase();
    }
  }

  /// Formats with thousands separators and fixed [fractionDigits].
  /// Handles negatives and NaN/Infinity gracefully.
  static String _numberWithGrouping(
    double value, {
    int fractionDigits = 0,
  }) {
    if (value.isNaN || value.isInfinite) return '0';
    final isNeg = value < 0;
    final abs = value.abs();

    String fixed = abs.toStringAsFixed(max(0, fractionDigits));
    String intPart;
    String fracPart = '';

    final dot = fixed.indexOf('.');
    if (dot >= 0) {
      intPart = fixed.substring(0, dot);
      fracPart = fixed.substring(dot + 1);
    } else {
      intPart = fixed;
    }

    final grouped = _groupThousands(intPart);
    final sign = isNeg ? '-' : '';
    return fracPart.isEmpty ? '$sign$grouped' : '$sign$grouped.$fracPart';
  }

  /// Adds commas every 3 digits from the right (simple en_US style).
  static String _groupThousands(String digits) {
    final buf = StringBuffer();
    int count = 0;
    for (int i = digits.length - 1; i >= 0; i--) {
      buf.write(digits[i]);
      count++;
      if (count == 3 && i != 0) {
        buf.write(',');
        count = 0;
      }
    }
    return buf.toString().split('').reversed.join();
  }

  /// Produces "1.2K", "3.4M", "5.6B" etc.
  static String _compactNumber(
    double value, {
    int fractionDigits = 1,
  }) {
    if (value.isNaN || value.isInfinite) return '0';
    final isNeg = value < 0;
    double abs = value.abs();

    String unit = '';
    if (abs >= 1e12) {
      abs /= 1e12;
      unit = 'T';
    } else if (abs >= 1e9) {
      abs /= 1e9;
      unit = 'B';
    } else if (abs >= 1e6) {
      abs /= 1e6;
      unit = 'M';
    } else if (abs >= 1e3) {
      abs /= 1e3;
      unit = 'K';
    }

    final numStr = _trimTrailingZeros(abs.toStringAsFixed(fractionDigits));
    return '${isNeg ? '-' : ''}$numStr$unit';
  }

  static String _trimTrailingZeros(String s) {
    if (!s.contains('.')) return s;
    s = s.replaceFirst(RegExp(r'\.?0+$'), '');
    return s;
  }
}
