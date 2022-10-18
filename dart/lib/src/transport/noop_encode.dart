/// gzip compression is not available on browser
Sink<List<int>> compressInSink(
        Sink<List<int>> sink, Map<String, String> headers) =>
    sink;
