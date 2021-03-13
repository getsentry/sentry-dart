import 'package:sentry/sentry.dart';
import 'package:test/test.dart';

void main() {
  test('copyWith keeps unchanged', () {
    final data = _generate();

    final copy = data.copyWith();

    expect(data.toJson(), copy.toJson());
  });

  test('copyWith takes new values', () {
    final data = _generate();

    final copy = data.copyWith(
      id: 'id1',
      username: 'username1',
      email: 'email1',
      ipAddress: 'ipAddress1',
      extras: {'key1': 'value1'},
    );

    expect('id1', copy.id);
    expect('username1', copy.username);
    expect('email1', copy.email);
    expect('ipAddress1', copy.ipAddress);
    expect({'key1': 'value1'}, copy.extras);
  });
}

SentryUser _generate() => SentryUser(
      id: 'id',
      username: 'username',
      email: 'email',
      ipAddress: 'ipAddress',
      extras: {'key': 'value'},
    );
