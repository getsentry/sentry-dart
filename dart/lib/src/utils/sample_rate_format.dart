// ignore: dangling_library_doc_comments
/// Code ported & adapted from `intl` package
/// https://pub.dev/packages/intl
///
/// License:
///
/// Copyright 2013, the Dart project authors.
///
/// Redistribution and use in source and binary forms, with or without
/// modification, are permitted provided that the following conditions are
/// met:
///
///     * Redistributions of source code must retain the above copyright
///       notice, this list of conditions and the following disclaimer.
///     * Redistributions in binary form must reproduce the above
///       copyright notice, this list of conditions and the following
///       disclaimer in the documentation and/or other materials provided
///       with the distribution.
///     * Neither the name of Google LLC nor the names of its
///       contributors may be used to endorse or promote products derived
///       from this software without specific prior written permission.
///
/// THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
/// "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
/// LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR
/// A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT
/// OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
/// SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT
/// LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
/// DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY
/// THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
/// (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
/// OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

import 'dart:math';

import 'package:meta/meta.dart';

@internal
class SampleRateFormat {
  int _minimumIntegerDigits;
  int _maximumFractionDigits;
  int _minimumFractionDigits;

  /// The difference between our zero and '0'.
  ///
  /// In other words, a constant _localeZero - _zero. Initialized when
  /// the locale is set.
  final int _zeroOffset;

  /// Caches the symbols
  final _NumberSymbols _symbols;

  /// Transient internal state in which to build up the result of the format
  /// operation. We can have this be just an instance variable because Dart is
  /// single-threaded and unless we do an asynchronous operation in the process
  /// of formatting then there will only ever be one number being formatted
  /// at a time. In languages with threads we'd need to pass this on the stack.
  final StringBuffer _buffer = StringBuffer();

  factory SampleRateFormat() {
    var symbols = _NumberSymbols(
      DECIMAL_SEP: '.',
      ZERO_DIGIT: '0',
    );
    var localeZero = symbols.ZERO_DIGIT.codeUnitAt(0);
    var zeroOffset = localeZero - '0'.codeUnitAt(0);

    return SampleRateFormat._(
      symbols,
      zeroOffset,
    );
  }

  SampleRateFormat._(this._symbols, this._zeroOffset)
      : _minimumIntegerDigits = 1,
        _maximumFractionDigits = 16,
        _minimumFractionDigits = 0;

  /// Format the sample rate
  String format(dynamic sampleRate) {
    try {
      if (_isNaN(sampleRate)) return '0';
      if (_isSmallerZero(sampleRate)) {
        sampleRate = 0;
      }
      if (_isLargerOne(sampleRate)) {
        sampleRate = 1;
      }
      _formatFixed(sampleRate.abs());

      var result = _buffer.toString();
      _buffer.clear();
      return result;
    } catch (_) {
      _buffer.clear();
      return '0';
    }
  }

  /// Used to test if we have exceeded integer limits.
  static final _maxInt = 1 is double ? pow(2, 52) : 1.0e300.floor();
  static final _maxDigits = (log(_maxInt) / log(10)).ceil();

  bool _isNaN(number) => number is num ? number.isNaN : false;
  bool _isSmallerZero(number) => number is num ? number < 0 : false;
  bool _isLargerOne(number) => number is num ? number > 1 : false;

  /// Format the basic number portion, including the fractional digits.
  void _formatFixed(dynamic number) {
    dynamic integerPart;
    int fractionPart;
    int extraIntegerDigits;
    var fractionDigits = _maximumFractionDigits;
    var minFractionDigits = _minimumFractionDigits;

    var power = 0;
    int digitMultiplier;

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

    power = pow(10, fractionDigits) as int;
    digitMultiplier = power;

    // Multiply out to the number of decimal places and the percent, then
    // round. For fixed-size integer types this should always be zero, so
    // multiplying is OK.
    var remainingDigits = _round(fraction * digitMultiplier).toInt();

    if (remainingDigits >= digitMultiplier) {
      // Overflow into the main digits: 0.99 => 1.00
      integerPart++;
      remainingDigits -= digitMultiplier;
    } else if (_numberOfIntegerDigits(remainingDigits) >
        _numberOfIntegerDigits(_floor(fraction * digitMultiplier).toInt())) {
      // Fraction has been rounded (0.0996 -> 0.1).
      fraction = remainingDigits / digitMultiplier;
    }

    // Separate out the extra integer parts from the fraction part.
    extraIntegerDigits = remainingDigits ~/ power;
    fractionPart = remainingDigits % power;

    var integerDigits = _integerDigits(integerPart, extraIntegerDigits);
    var digitLength = integerDigits.length;
    var fractionPresent =
        fractionDigits > 0 && (minFractionDigits > 0 || fractionPart > 0);

    if (_hasIntegerDigits(integerDigits)) {
      // Add the padding digits to the regular digits so that we get grouping.
      var padding = '0' * (_minimumIntegerDigits - digitLength);
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
  static int _numberOfIntegerDigits(dynamic number) {
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

  /// Compute the raw integer digits which will then be printed with
  /// grouping and translated to localized digits.
  String _integerDigits(integerPart, extraIntegerDigits) {
    // If the integer part is larger than the maximum integer size
    // (2^52 on Javascript, 2^63 on the VM) it will lose precision,
    // so pad out the rest of it with zeros.
    var paddingDigits = '';
    if (integerPart is num && integerPart > _maxInt) {
      var howManyDigitsTooBig =
          (log(integerPart) / log(10)).ceil() - _maxDigits;
      num divisor = pow(10, howManyDigitsTooBig).round();
      // pow() produces 0 if the result is too large for a 64-bit int.
      // If that happens, use a floating point divisor instead.
      if (divisor == 0) divisor = pow(10.0, howManyDigitsTooBig);
      paddingDigits = '0' * howManyDigitsTooBig.toInt();
      integerPart = (integerPart / divisor).truncate();
    }

    var extra = extraIntegerDigits == 0 ? '' : extraIntegerDigits.toString();
    var intDigits = _mainIntegerDigits(integerPart);
    var paddedExtra = intDigits.isEmpty ? extra : extra.padLeft(0, '0');
    return '$intDigits$paddedExtra$paddingDigits';
  }

  /// The digit string of the integer part. This is the empty string if the
  /// integer part is zero and otherwise is the toString() of the integer
  /// part, stripping off any minus sign.
  String _mainIntegerDigits(integer) {
    if (integer == 0) return '';
    var digits = integer.toString();
    // If we have a fixed-length int representation, it can have a negative
    // number whose negation is also negative, e.g. 2^-63 in 64-bit.
    // Remove the minus sign.
    return digits.startsWith('-') ? digits.substring(1) : digits;
  }

  /// Format the part after the decimal place in a fixed point number.
  void _formatFractionPart(String fractionPart, int minDigits) {
    var fractionLength = fractionPart.length;
    while (fractionPart.codeUnitAt(fractionLength - 1) == '0'.codeUnitAt(0) &&
        fractionLength > minDigits + 1) {
      fractionLength--;
    }
    for (var i = 1; i < fractionLength; i++) {
      _addDigit(fractionPart.codeUnitAt(i));
    }
  }

  /// Print the decimal separator if appropriate.
  void _decimalSeparator(bool fractionPresent) {
    if (fractionPresent) {
      _add(_symbols.DECIMAL_SEP);
    }
  }

  /// Return true if we have a main integer part which is printable, either
  /// because we have digits left of the decimal point (this may include digits
  /// which have been moved left because of percent or permille formatting),
  /// or because the minimum number of printable digits is greater than 1.
  bool _hasIntegerDigits(String digits) =>
      digits.isNotEmpty || _minimumIntegerDigits > 0;

  /// A group of methods that provide support for writing digits and other
  /// required characters into [_buffer] easily.
  void _add(String x) {
    _buffer.write(x);
  }

  void _addZero() {
    _buffer.write(_symbols.ZERO_DIGIT);
  }

  void _addDigit(int x) {
    _buffer.writeCharCode(x + _zeroOffset);
  }
}

// Suppress naming issues as changes would be breaking.
// ignore_for_file: non_constant_identifier_names
class _NumberSymbols {
  final String DECIMAL_SEP, ZERO_DIGIT;

  const _NumberSymbols({required this.DECIMAL_SEP, required this.ZERO_DIGIT});
}
