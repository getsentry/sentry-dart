import 'package:http/http.dart';

class SentrySupabaseClient extends BaseClient {
  late final Client innerClient;

  SentrySupabaseClient({Client? client}) {
    innerClient = client ?? Client();
  }

  @override
  Future<StreamedResponse> send(BaseRequest request) {

    // TODO: Instrument the supabase request

    return innerClient.send(request);
  }
}
