/// gzip compression is not available on browser
List<int> compressBody(List<int> body, Map<String, String> headers) => body;

/// gzip compression is not available on browser
Sink<List<int>> compressInSink(
        Sink<List<int>> sink, Map<String, String> headers) =>
    sink;
