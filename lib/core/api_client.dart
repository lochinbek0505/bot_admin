import 'package:dio/dio.dart';

class ApiClient {
  final Dio dio;
  String _baseUrl;
  String? _apiKey;

  ApiClient({required String baseUrl, String? apiKey})
      : _baseUrl = baseUrl,
        _apiKey = apiKey,
        dio = Dio(
          BaseOptions(
            baseUrl: baseUrl,
            connectTimeout: const Duration(seconds: 15),
            receiveTimeout: const Duration(seconds: 20),
            responseType: ResponseType.json,
          ),
        ) {
    dio.interceptors.add(_AuthInterceptor(() => _apiKey));
    dio.interceptors.add(LogInterceptor(
      requestHeader: true,
      requestBody: true,
      responseHeader: true,
      responseBody: false,
    ));
  }

  void updateBaseUrl(String baseUrl) {
    _baseUrl = baseUrl;
    dio.options.baseUrl = baseUrl;
  }

  void updateApiKey(String? apiKey) {
    _apiKey = (apiKey ?? '').trim().isEmpty ? null : apiKey!.trim();
  }

  /// Servis qatlamida ham foydalanish uchun
  String? get currentApiKey => _apiKey;

  String toFullUrl(String p) {
    if (p.isEmpty) return p;
    if (p.startsWith('http://') || p.startsWith('https://')) return p;
    return '$_baseUrl$p';
  }
}

class _AuthInterceptor extends Interceptor {
  final String? Function() _apiKeyProvider;
  _AuthInterceptor(this._apiKeyProvider);

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    final m = options.method.toUpperCase();
    final isRead = m == 'GET' || m == 'HEAD' || m == 'OPTIONS';

    // GET/HEAD/OPTIONS: custom header yubormaymiz (CORS preflight bo‘lmasin)
    options.headers.remove('X-API-Key');

    if (!isRead) {
      final key = _apiKeyProvider();
      if (key != null && key.isNotEmpty) {
        options.headers['X-API-Key'] = key;
      }
    }
    handler.next(options);
  }
}
