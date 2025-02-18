import 'package:platform/platform.dart';

import '_io_platform.dart' if (dart.library.js_interop) '_web_platform.dart'
    as platform;

const Platform instance = platform.instance;
