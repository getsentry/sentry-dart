import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:mockito/annotations.dart';
import 'package:sentry/sentry.dart';
import 'dart:async';

@GenerateMocks([
  Hub,
  FirebaseRemoteConfig,
  Stream,
  StreamSubscription,
])
void main() {}
