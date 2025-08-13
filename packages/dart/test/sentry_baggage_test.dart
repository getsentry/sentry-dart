import 'package:sentry/src/sentry_baggage.dart';
import 'package:test/test.dart';

void main() {
  group('$SentryBaggage', () {
    test('reads from header string with spaces', () {
      final headers =
          'userId =  alice   ,  serverNode = DF%2028,isProduction=false';
      final baggage = SentryBaggage.fromHeader(headers);

      expect(baggage.get('userId'), 'alice');
      expect(baggage.get('serverNode'), 'DF 28');
      expect(baggage.get('isProduction'), 'false');

      expect(baggage.toHeaderString(),
          'userId=alice,serverNode=DF%2028,isProduction=false');
    });

    test('decodes and encodes the headers', () {
      final headers =
          'user%2Bid=alice,server%2Bnode=DF%2028,is%2Bproduction=false';
      final baggage = SentryBaggage.fromHeader(headers);

      expect(baggage.get('user+id'), 'alice');
      expect(baggage.get('server+node'), 'DF 28');
      expect(baggage.get('is+production'), 'false');

      expect(baggage.toHeaderString(),
          'user%2Bid=alice,server%2Bnode=DF%2028,is%2Bproduction=false');
    });

    test('reads from header list', () {
      final headers = [
        'userId =   alice',
        'serverNode = DF%2028, isProduction = false'
      ];
      final baggage = SentryBaggage.fromHeaderList(headers);

      expect(baggage.get('userId'), 'alice');
      expect(baggage.get('serverNode'), 'DF 28');
      expect(baggage.get('isProduction'), 'false');

      expect(baggage.toHeaderString(),
          'userId=alice,serverNode=DF%2028,isProduction=false');
    });

    test('reads from empty string', () {
      final baggage = SentryBaggage.fromHeader('');

      expect(baggage.toHeaderString(), isEmpty);
    });

    test('reads from blank string', () {
      final baggage = SentryBaggage.fromHeader('  ');

      expect(baggage.toHeaderString(), isEmpty);
    });

    test('drops large values when above the limit', () {
      final buffer = StringBuffer();
      for (int i = 0; i < 1000; i++) {
        // 10 chars each loop
        buffer.write('largeValue');
      }

      // max is 8192
      expect(buffer.length > 8192, isTrue);
      final largeValue = buffer.toString();

      final baggage = SentryBaggage.fromHeader(
          'smallValue=remains,largeValue=$largeValue,otherValue=kept');

      expect(baggage.get('smallValue'), 'remains');
      expect(baggage.get('otherValue'), 'kept');
      expect(baggage.get('largeValue'), largeValue);

      expect(baggage.toHeaderString(), 'smallValue=remains,otherValue=kept');
    });

    test('drops items when above the list member limit', () {
      final buffer = StringBuffer();
      final match = StringBuffer();
      for (int i = 1; i <= 65; i++) {
        final value = '$i=$i,';
        buffer.write(value);
        // max is 64
        if (i <= 64) {
          match.write(value);
        }
      }
      final baggage = SentryBaggage.fromHeader(buffer.toString());

      expect(baggage.toHeaderString(),
          match.toString().substring(0, match.length - 1));
    });
  });
}
