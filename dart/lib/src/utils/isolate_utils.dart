import '_io_get_isolate_name.dart'
    if (dart.library.html) '_web_get_isolate_name.dart' as isolate_getter;

String? getIsolateName() => isolate_getter.getIsolateName();
