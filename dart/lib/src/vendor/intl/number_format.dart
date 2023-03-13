import 'dart:math';

import 'number_symbols.dart';

// ignore_for_file: constant_identifier_names

/// Provides the ability to format a number in a locale-specific way.
///
/// The format is specified as a pattern using a subset of the ICU formatting
/// patterns.
///
/// - `0` A single digit
/// - `#` A single digit, omitted if the value is zero
/// - `.` Decimal separator
/// - `-` Minus sign
/// - `,` Grouping separator
/// - `E` Separates mantissa and expontent
/// - `+` - Before an exponent, to say it should be prefixed with a plus sign.
/// - `%` - In prefix or suffix, multiply by 100 and show as percentage
/// - `‰ (\u2030)` In prefix or suffix, multiply by 1000 and show as per mille
/// - `¤ (\u00A4)` Currency sign, replaced by currency name
/// - `'` Used to quote special characters
/// - `;` Used to separate the positive and negative patterns (if both present)
///
/// For example,
///
///       var f = NumberFormat("###.0#", "en_US");
///       print(f.format(12.345));
///           ==> 12.34
///
/// If the locale is not specified, it will default to the current locale. If
/// the format is not specified it will print in a basic format with at least
/// one integer digit and three fraction digits.
///
/// There are also standard patterns available via the special constructors.
/// e.g.
///
///       var percent = NumberFormat.percentPattern("ar");
///       var eurosInUSFormat = NumberFormat.currency(locale: "en_US",
///           symbol: "€");
///
/// There are several such constructors available, though some of them are
/// limited. For example, at the moment, scientificPattern prints only as
/// equivalent to "#E0" and does not take into account significant digits.
class NumberFormat {

  /// Set to true if the format has explicitly set the grouping size.
  final bool _decimalSeparatorAlwaysShown;

  int maximumIntegerDigits;
  int minimumIntegerDigits;

  bool _explicitMaximumFractionDigits = false;
  int _maximumFractionDigits;
  int get maximumFractionDigits => _maximumFractionDigits;
  set maximumFractionDigits(int x) {
    significantDigitsInUse = false;
    _explicitMaximumFractionDigits = true;
    _maximumFractionDigits = x;
    _minimumFractionDigits = min(_minimumFractionDigits, x);
  }

  bool _explicitMinimumFractionDigits = false;
  int _minimumFractionDigits;
  int get minimumFractionDigits => _minimumFractionDigits;
  set minimumFractionDigits(int x) {
    significantDigitsInUse = false;
    _explicitMinimumFractionDigits = true;
    _minimumFractionDigits = x;
    _maximumFractionDigits = max(_maximumFractionDigits, x);
  }

  int minimumExponentDigits;

  int? _maximumSignificantDigits;
  int? get maximumSignificantDigits => _maximumSignificantDigits;
  set maximumSignificantDigits(int? x) {
    _maximumSignificantDigits = x;
    if (x != null && _minimumSignificantDigits != null) {
      _minimumSignificantDigits = min(_minimumSignificantDigits!, x);
    }
    significantDigitsInUse = true;
  }

  /// Whether minimumSignificantDigits should cause trailing 0 in fraction part.
  ///
  /// Ex: with 2 significant digits:
  /// 0.999 => "1.0" (strict) or "1" (non-strict).
  bool minimumSignificantDigitsStrict = false;

  int? _minimumSignificantDigits;
  int? get minimumSignificantDigits => _minimumSignificantDigits;
  set minimumSignificantDigits(int? x) {
    _minimumSignificantDigits = x;
    if (x != null && _maximumSignificantDigits != null) {
      _maximumSignificantDigits = max(_maximumSignificantDigits!, x);
    }
    significantDigitsInUse = true;
    minimumSignificantDigitsStrict = x != null;
  }

  ///  How many significant digits should we print.
  ///
  ///  Note that if significantDigitsInUse is the default false, this
  ///  will be ignored.
  @Deprecated('Use maximumSignificantDigits / minimumSignificantDigits')
  int? get significantDigits => _minimumSignificantDigits;

  set significantDigits(int? x) {
    minimumSignificantDigits = x;
    maximumSignificantDigits = x;
  }

  bool significantDigitsInUse = false;

  /// For percent and permille, what are we multiplying by in order to
  /// get the printed value, e.g. 100 for percent.
  final int multiplier;

  /// How many digits are there in the [multiplier].
  final int _multiplierDigits;

  /// Caches the symbols used for our locale.
  final NumberSymbols _symbols;

  /// The number of decimal places to use when formatting.
  ///
  /// If this is not explicitly specified in the constructor, then for
  /// currencies we use the default value for the currency if the name is given,
  /// otherwise we use the value from the pattern for the locale.
  ///
  /// So, for example,
  ///       NumberFormat.currency(name: 'USD', decimalDigits: 7)
  /// will format with 7 decimal digits, because that's what we asked for. But
  ///       NumberFormat.currency(locale: 'en_US', name: 'JPY')
  /// will format with zero, because that's the default for JPY, and the
  /// currency's default takes priority over the locale's default.
  ///       NumberFormat.currency(locale: 'en_US')
  /// will format with two, which is the default for that locale.
  ///
  final int? decimalDigits;

  /// Transient internal state in which to build up the result of the format
  /// operation. We can have this be just an instance variable because Dart is
  /// single-threaded and unless we do an asynchronous operation in the process
  /// of formatting then there will only ever be one number being formatted
  /// at a time. In languages with threads we'd need to pass this on the stack.
  final StringBuffer _buffer = StringBuffer();

  /// Create a number format that prints using [newPattern] as it applies in
  /// [locale].
  factory NumberFormat([String? locale]) =>
      NumberFormat._forPattern(locale);

  /// Create a number format that prints in a pattern we get from
  /// the [getPattern] function using the locale [locale].
  ///
  /// The [currencySymbol] can either be specified directly, or we can pass a
  /// function [computeCurrencySymbol] that will compute it later, given other
  /// information, typically the verified locale.
  factory NumberFormat._forPattern(String? locale) {
    var symbols = NumberSymbols(
        NAME: "en",
        DECIMAL_SEP: '.',
        GROUP_SEP: ',',
        PERCENT: '%',
        ZERO_DIGIT: '0',
        PLUS_SIGN: '+',
        MINUS_SIGN: '-',
        EXP_SYMBOL: 'E',
        PERMILL: '\u2030',
        INFINITY: '\u221E',
        NAN: 'NaN',
        DECIMAL_PATTERN: '#,##0.###',
        SCIENTIFIC_PATTERN: '#E0',
        PERCENT_PATTERN: '#,##0%',
        CURRENCY_PATTERN: '\u00A4#,##0.00',
        DEF_CURRENCY_CODE: 'USD');
    var localeZero = symbols.ZERO_DIGIT.codeUnitAt(0);
    var zeroOffset = localeZero - '0'.codeUnitAt(0);

    return NumberFormat._(
        localeZero,
        symbols,
        zeroOffset);
  }

  NumberFormat._(
      this.localeZero,
      this._symbols,
      this._zeroOffset)
      : multiplier = 1,
        _multiplierDigits = 0,
        minimumExponentDigits = 0,
        maximumIntegerDigits = 40,
        minimumIntegerDigits = 1,
        _maximumFractionDigits = 16,
        _minimumFractionDigits = 0,
        _decimalSeparatorAlwaysShown = false,
        decimalDigits = null;

  /// Return the symbols which are used in our locale. Cache them to avoid
  /// repeated lookup.
  NumberSymbols get symbols => _symbols;

  /// Format [number] according to our pattern and return the formatted string.
  String format(dynamic number) {
    if (_isNaN(number)) return symbols.NAN;

    _formatFixed(number.abs());

    var result = _buffer.toString();
    _buffer.clear();
    return result;
  }

  /// Used to test if we have exceeded integer limits.
  // TODO(alanknight): Do we have a MaxInt constant we could use instead?
  static final _maxInt = 1 is double ? pow(2, 52) : 1.0e300.floor();
  static final _maxDigits = (log(_maxInt) / log(10)).ceil();

  /// Helpers to check numbers that don't conform to the [num] interface,
  /// e.g. Int64
  bool _isInfinite(number) => number is num ? number.isInfinite : false;
  bool _isNaN(number) => number is num ? number.isNaN : false;

  /// Helper to get the floor of a number which might not be num. This should
  /// only ever be called with an argument which is positive, or whose abs()
  ///  is negative. The second case is the maximum negative value on a
  ///  fixed-length integer. Since they are integers, they are also their own
  ///  floor.
  dynamic _floor(dynamic number) {
    if (number.isNegative && !number.abs().isNegative) {
      throw ArgumentError(
          'Internal error: expected positive number, got $number');
    }
    return (number is num) ? number.floor() : number ~/ 1;
  }

  /// Helper to round a number which might not be num.
  dynamic _round(dynamic number) {
    if (number is num) {
      if (number.isInfinite) {
        return _maxInt;
      } else {
        return number.round();
      }
    } else if (number.remainder(1) == 0) {
      // Not a normal number, but int-like, e.g. Int64
      return number;
    } else {
      // TODO(alanknight): Do this more efficiently. If IntX had floor and
      // round we could avoid this.
      var basic = _floor(number);
      var fraction = (number - basic).toDouble().round();
      return fraction == 0 ? number : number + fraction;
    }
  }

  // Return the number of digits left of the decimal place in [number].
  static int numberOfIntegerDigits(dynamic number) {
    var simpleNumber = (number.toDouble() as double).abs();
    // It's unfortunate that we have to do this, but we get precision errors
    // that affect the result if we use logs, e.g. 1000000
    if (simpleNumber < 10) return 1;
    if (simpleNumber < 100) return 2;
    if (simpleNumber < 1000) return 3;
    if (simpleNumber < 10000) return 4;
    if (simpleNumber < 100000) return 5;
    if (simpleNumber < 1000000) return 6;
    if (simpleNumber < 10000000) return 7;
    if (simpleNumber < 100000000) return 8;
    if (simpleNumber < 1000000000) return 9;
    if (simpleNumber < 10000000000) return 10;
    if (simpleNumber < 100000000000) return 11;
    if (simpleNumber < 1000000000000) return 12;
    if (simpleNumber < 10000000000000) return 13;
    if (simpleNumber < 100000000000000) return 14;
    if (simpleNumber < 1000000000000000) return 15;
    if (simpleNumber < 10000000000000000) return 16;
    if (simpleNumber < 100000000000000000) return 17;
    if (simpleNumber < 1000000000000000000) return 18;
    return 19;
  }

  /// Whether to use SignificantDigits unconditionally for fraction digits.
  bool _useDefaultSignificantDigits() => true;

  /// How many digits after the decimal place should we display, given that
  /// by default, [fractionDigits] should be used, and there are up to
  /// [expectedSignificantDigits] left to display in the fractional part..
  int _adjustFractionDigits(int fractionDigits, expectedSignificantDigits) {
    if (_useDefaultSignificantDigits()) return fractionDigits;
    // If we are printing a currency significant digits would have us only print
    // some of the decimal digits, use all of them. So $12.30, not $12.3
    if (expectedSignificantDigits > 0) {
      return decimalDigits!;
    } else {
      return min(fractionDigits, decimalDigits!);
    }
  }

  /// Format the basic number portion, including the fractional digits.
  void _formatFixed(dynamic number) {
    dynamic integerPart;
    int fractionPart;
    int extraIntegerDigits;
    var fractionDigits = maximumFractionDigits;
    var minFractionDigits = minimumFractionDigits;

    var power = 0;
    int digitMultiplier;

    if (_isInfinite(number)) {
      integerPart = number.toInt();
      extraIntegerDigits = 0;
      fractionPart = 0;
    } else {
      // We have three possible pieces. First, the basic integer part. If this
      // is a percent or permille, the additional 2 or 3 digits. Finally the
      // fractional part.
      // We avoid multiplying the number because it might overflow if we have
      // a fixed-size integer type, so we extract each of the three as an
      // integer pieces.
      integerPart = _floor(number);
      var fraction = number - integerPart;
      if (fraction.toInt() != 0) {
        // If the fractional part leftover is > 1, presumbly the number
        // was too big for a fixed-size integer, so leave it as whatever
        // it was - the obvious thing is a double.
        integerPart = number;
        fraction = 0;
      }

      /// If we have significant digits, compute the number of fraction
      /// digits based on that.
      void computeFractionDigits() {
        if (significantDigitsInUse) {
          var integerLength = number == 0
              ? 1
              : integerPart != 0
                  ? numberOfIntegerDigits(integerPart)
                  // We might need to add digits after decimal point.
                  : (log(fraction) / ln10).ceil();

          if (minimumSignificantDigits != null) {
            var remainingSignificantDigits =
                minimumSignificantDigits! - _multiplierDigits - integerLength;

            fractionDigits = max(0, remainingSignificantDigits);
            if (minimumSignificantDigitsStrict) {
              minFractionDigits = fractionDigits;
            }
            fractionDigits = _adjustFractionDigits(
                fractionDigits, remainingSignificantDigits);
          }

          if (maximumSignificantDigits != null) {
            if (maximumSignificantDigits! == 0) {
              // Stupid case: only '0' has no significant digits.
              integerPart = 0;
              fractionDigits = 0;
            } else if (maximumSignificantDigits! <
                integerLength + _multiplierDigits) {
              // We may have to round.
              var divideBy = pow(10, integerLength - maximumSignificantDigits!);
              if (maximumSignificantDigits! < integerLength) {
                integerPart = (integerPart / divideBy).round() * divideBy;
              }
              fraction = (fraction / divideBy).round() * divideBy;
              fractionDigits = 0;
            } else {
              fractionDigits =
                  maximumSignificantDigits! - integerLength - _multiplierDigits;
              fractionDigits =
                  _adjustFractionDigits(fractionDigits, fractionDigits);
            }
          }
          if (fractionDigits > maximumFractionDigits &&
              _explicitMaximumFractionDigits) {
            fractionDigits = min(fractionDigits, maximumFractionDigits);
          }
          if (fractionDigits < minimumFractionDigits &&
              _explicitMinimumFractionDigits) {
            fractionDigits = _minimumFractionDigits;
          }
        }
      }

      computeFractionDigits();

      power = pow(10, fractionDigits) as int;
      digitMultiplier = power * multiplier;

      // Multiply out to the number of decimal places and the percent, then
      // round. For fixed-size integer types this should always be zero, so
      // multiplying is OK.
      var remainingDigits = _round(fraction * digitMultiplier).toInt();

      var hasRounding = false;
      if (remainingDigits >= digitMultiplier) {
        // Overflow into the main digits: 0.99 => 1.00
        integerPart++;
        remainingDigits -= digitMultiplier;
        hasRounding = true;
      } else if (numberOfIntegerDigits(remainingDigits) >
          numberOfIntegerDigits(_floor(fraction * digitMultiplier).toInt())) {
        // Fraction has been rounded (0.0996 -> 0.1).
        fraction = remainingDigits / digitMultiplier;
        hasRounding = true;
      }
      if (hasRounding && significantDigitsInUse) {
        // We might have to recompute significant digits after fraction.
        // With 3 significant digits, "9.999" should be "10.0", not "10.00".
        computeFractionDigits();
      }

      // Separate out the extra integer parts from the fraction part.
      extraIntegerDigits = remainingDigits ~/ power;
      fractionPart = remainingDigits % power;
    }

    var integerDigits = _integerDigits(integerPart, extraIntegerDigits);
    var digitLength = integerDigits.length;
    var fractionPresent =
        fractionDigits > 0 && (minFractionDigits > 0 || fractionPart > 0);

    if (_hasIntegerDigits(integerDigits)) {
      // Add the padding digits to the regular digits so that we get grouping.
      var padding = '0' * (minimumIntegerDigits - digitLength);
      integerDigits = '$padding$integerDigits';
      digitLength = integerDigits.length;
      for (var i = 0; i < digitLength; i++) {
        _addDigit(integerDigits.codeUnitAt(i));
      }
    } else if (!fractionPresent) {
      // If neither fraction nor integer part exists, just print zero.
      _addZero();
    }

    _decimalSeparator(fractionPresent);
    if (fractionPresent) {
      _formatFractionPart((fractionPart + power).toString(), minFractionDigits);
    }
  }

  /// Compute the raw integer digits which will then be printed with
  /// grouping and translated to localized digits.
  String _integerDigits(integerPart, extraIntegerDigits) {
    // If the integer part is larger than the maximum integer size
    // (2^52 on Javascript, 2^63 on the VM) it will lose precision,
    // so pad out the rest of it with zeros.
    var paddingDigits = '';
    if (integerPart is num && integerPart > _maxInt) {
      var howManyDigitsTooBig = (log(integerPart) / _ln10).ceil() - _maxDigits;
      num divisor = pow(10, howManyDigitsTooBig).round();
      // pow() produces 0 if the result is too large for a 64-bit int.
      // If that happens, use a floating point divisor instead.
      if (divisor == 0) divisor = pow(10.0, howManyDigitsTooBig);
      paddingDigits = '0' * howManyDigitsTooBig.toInt();
      integerPart = (integerPart / divisor).truncate();
    }

    var extra = extraIntegerDigits == 0 ? '' : extraIntegerDigits.toString();
    var intDigits = _mainIntegerDigits(integerPart);
    var paddedExtra =
        intDigits.isEmpty ? extra : extra.padLeft(_multiplierDigits, '0');
    return '$intDigits$paddedExtra$paddingDigits';
  }

  /// The digit string of the integer part. This is the empty string if the
  /// integer part is zero and otherwise is the toString() of the integer
  /// part, stripping off any minus sign.
  String _mainIntegerDigits(integer) {
    if (integer == 0) return '';
    var digits = integer.toString();
    if (significantDigitsInUse &&
        maximumSignificantDigits != null &&
        digits.length > maximumSignificantDigits!) {
      digits = digits.substring(0, maximumSignificantDigits!) +
          ''.padLeft(digits.length - maximumSignificantDigits!, '0');
    }
    // If we have a fixed-length int representation, it can have a negative
    // number whose negation is also negative, e.g. 2^-63 in 64-bit.
    // Remove the minus sign.
    return digits.startsWith('-') ? digits.substring(1) : digits;
  }

  /// Format the part after the decimal place in a fixed point number.
  void _formatFractionPart(String fractionPart, int minDigits) {
    var fractionLength = fractionPart.length;
    while (fractionPart.codeUnitAt(fractionLength - 1) ==
            '0'.codeUnitAt(0) &&
        fractionLength > minDigits + 1) {
      fractionLength--;
    }
    for (var i = 1; i < fractionLength; i++) {
      _addDigit(fractionPart.codeUnitAt(i));
    }
  }

  /// Print the decimal separator if appropriate.
  void _decimalSeparator(bool fractionPresent) {
    if (_decimalSeparatorAlwaysShown || fractionPresent) {
      _add(symbols.DECIMAL_SEP);
    }
  }

  /// Return true if we have a main integer part which is printable, either
  /// because we have digits left of the decimal point (this may include digits
  /// which have been moved left because of percent or permille formatting),
  /// or because the minimum number of printable digits is greater than 1.
  bool _hasIntegerDigits(String digits) =>
      digits.isNotEmpty || minimumIntegerDigits > 0;

  /// A group of methods that provide support for writing digits and other
  /// required characters into [_buffer] easily.
  void _add(String x) {
    _buffer.write(x);
  }

  void _addZero() {
    _buffer.write(symbols.ZERO_DIGIT);
  }

  void _addDigit(int x) {
    _buffer.writeCharCode(x + _zeroOffset);
  }

  /// The code point for the locale's zero digit.
  ///
  ///  Initialized when the locale is set.
  final int localeZero;

  /// The difference between our zero and '0'.
  ///
  /// In other words, a constant _localeZero - _zero. Initialized when
  /// the locale is set.
  final int _zeroOffset;
}

final _ln10 = log(10);
