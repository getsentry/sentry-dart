import 'package:logging/logging.dart';

void main() async {
  final log = Logger('MyAwesomeLogger');

  log.info('a breadcrumb!');

  try {
    throw Exception();
  } catch (error, stackTrace) {
    log.severe('an error!', error, stackTrace);
  }
}
