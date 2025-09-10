// lib/services/api_service.dart
//

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:http_parser/http_parser.dart' show MediaType;


class ApiService {
  // ====== Construction ======
  ApiService._(this._dio);

  final Dio _dio;

  // Env base URL (falls back to Android emulator localhost)
  static final String _defaultBaseUrl =
      const String.fromEnvironment('BASE_URL', defaultValue: 'http://10.0.2.2:5000');

  // Token storage (in-memory by default). You can plug your own persistence.
  String? _accessToken;
  String? _refreshToken;

  /// Optional hooks to persist tokens (e.g., to secure storage)
  Future<String?> Function()? loadAccessToken;
  Future<String?> Function()? loadRefreshToken;
  Future<void> Function(String? access, String? refresh)? saveTokens;

  // Prevent multiple parallel refreshes
  Completer<bool>? _refreshing;

  static Future<ApiService> create({
    String? baseUrl,
    Future<String?> Function()? loadAccessToken,
    Future<String?> Function()? loadRefreshToken,
    Future<void> Function(String? access, String? refresh)? saveTokens,
    Duration connectTimeout = const Duration(seconds: 15),
    Duration receiveTimeout = const Duration(seconds: 20),
    Duration sendTimeout = const Duration(seconds: 20),
    bool enableLoggingInDebug = true,
  }) async {
    final dio = Dio(BaseOptions(
      baseUrl: baseUrl ?? _defaultBaseUrl,
      connectTimeout: connectTimeout,
      receiveTimeout: receiveTimeout,
      sendTimeout: sendTimeout,
      headers: {'Accept': 'application/json'},
    ));

    final api = ApiService._(dio)
      ..loadAccessToken = loadAccessToken
      ..loadRefreshToken = loadRefreshToken
      ..saveTokens = saveTokens;

    // Attach interceptors
    dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        // lazy-load tokens on first request if hooks provided
        api._accessToken ??= await api.loadAccessToken?.call();
        api._refreshToken ??= await api.loadRefreshToken?.call();
        if (api._accessToken != null && api._accessToken!.isNotEmpty) {
          options.headers['Authorization'] = 'Bearer ${api._accessToken}';
        }
        handler.next(options);
      },
      onError: (e, handler) async {
        // Only attempt refresh on 401, if we have a refresh token, and not already refreshing this call
        final isUnauthorized = e.response?.statusCode == 401;
        final reqPath = e.requestOptions.path;
        final isRefreshCall = reqPath.contains('/api/auth/refresh');
        final hasRefresh = (api._refreshToken ?? '').isNotEmpty;

        if (isUnauthorized && hasRefresh && !isRefreshCall) {
          final refreshed = await api._tryRefreshToken();
          if (refreshed) {
            // Retry original request with new access token
            final RequestOptions ro = e.requestOptions;
            final opts = Options(
              method: ro.method,
              headers: {
                ...ro.headers,
                if (api._accessToken != null) 'Authorization': 'Bearer ${api._accessToken}',
              },
              responseType: ro.responseType,
              contentType: ro.contentType,
              listFormat: ro.listFormat,
              followRedirects: ro.followRedirects,
              receiveDataWhenStatusError: ro.receiveDataWhenStatusError,
              validateStatus: ro.validateStatus,
            );
            try {
              final response = await api._dio.request(
                ro.path,
                data: ro.data,
                queryParameters: ro.queryParameters,
                options: opts,
                cancelToken: ro.cancelToken,
                onReceiveProgress: ro.onReceiveProgress,
                onSendProgress: ro.onSendProgress,
              );
              return handler.resolve(response);
            } catch (err) {
              // fall through to original error
            }
          }
        }
        handler.next(e);
      },
    ));

    // Optional console logging (good for dev)
    assert(() {
      if (enableLoggingInDebug) {
        dio.interceptors.add(LogInterceptor(
          requestBody: true,
          responseBody: true,
        ));
      }
      return true;
    }());

    return api;
  }

  Future<void> setTokens({String? access, String? refresh}) async {
    _accessToken = access;
    _refreshToken = refresh;
    await saveTokens?.call(access, refresh);
  }

  Future<bool> _tryRefreshToken() async {
    // Guard: if a refresh is underway, await it
    if (_refreshing != null) {
      return _refreshing!.future;
    }
    _refreshing = Completer<bool>();
    try {
      // Ensure we have latest persisted refresh
      _refreshToken ??= await loadRefreshToken?.call();
      if (_refreshToken == null || _refreshToken!.isEmpty) {
        _refreshing!.complete(false);
        _refreshing = null;
        return false;
      }

      final res = await _dio.post(
        '/api/auth/refresh',
        options: Options(
          headers: {'Authorization': 'Bearer $_refreshToken'},
        ),
      );
      final newAccess = (res.data as Map)['access_token'] as String?;
      if (newAccess == null || newAccess.isEmpty) {
        await setTokens(access: null, refresh: null);
        _refreshing!.complete(false);
        _refreshing = null;
        return false;
      }
      _accessToken = newAccess;
      // Keep old refresh (server returns only access here)
      await saveTokens?.call(_accessToken, _refreshToken);
      _refreshing!.complete(true);
      _refreshing = null;
      return true;
    } catch (_) {
      await setTokens(access: null, refresh: null);
      _refreshing!.complete(false);
      _refreshing = null;
      return false;
    }
  }

  // ====== Helpers ======
  T _map<T>(Response res) => res.data as T;

// Multipart from File
Future<FormData> _fileForm(
  String fieldName,
  File file, {
  String? filename,
  String? contentType,
}) async {
  final fname = filename ?? file.path.split(Platform.pathSeparator).last;
  return FormData.fromMap({
    fieldName: await MultipartFile.fromFile(
      file.path,
      filename: fname,
      // FIX: use MediaType instead of HeadersContentType
      contentType: contentType != null ? MediaType.parse(contentType) : null,
    ),
  });
}


  // ====== AUTH ======
  Future<Map<String, dynamic>> register({required String name, required String email, required String password}) async {
    final res = await _dio.post('/api/auth/register', data: {
      'name': name,
      'email': email,
      'password': password,
    });
    final map = _map<Map<String, dynamic>>(res);
    await setTokens(access: map['access_token'], refresh: map['refresh_token']);
    return map;
    // map['user'] contains {id,name,email,role,is_active,created_at}
  }

  Future<Map<String, dynamic>> login({required String email, required String password}) async {
    final res = await _dio.post('/api/auth/login', data: {
      'email': email,
      'password': password,
    });
    final map = _map<Map<String, dynamic>>(res);
    await setTokens(access: map['access_token'], refresh: map['refresh_token']);
    return map;
  }

  Future<Map<String, dynamic>> me() async {
    final res = await _dio.get('/api/auth/me');
    return _map<Map<String, dynamic>>(res); // { user: {...} }
  }

  Future<Map<String, dynamic>> requestPasswordReset(String email) async {
    final res = await _dio.post('/api/auth/password/request-reset', data: {'email': email});
    return _map<Map<String, dynamic>>(res); // { ok: true }
  }

  Future<Map<String, dynamic>> resetPassword({required String token, required String newPassword}) async {
    final res = await _dio.post('/api/auth/password/reset', data: {
      'token': token,
      'password': newPassword,
    });
    return _map<Map<String, dynamic>>(res); // { ok: true }
  }

  // ====== CATALOG / DISCOVERY ======
  Future<Map<String, dynamic>> getCategories() async {
    final res = await _dio.get('/api/categories');
    return _map<Map<String, dynamic>>(res); // { items: [...] }
  }

  Future<Map<String, dynamic>> getAttributes() async {
    final res = await _dio.get('/api/attributes');
    return _map<Map<String, dynamic>>(res); // { skin_types:[], concerns:[] }
  }

  Future<Map<String, dynamic>> getProducts({
    String? q,
    String? category,
    String? itemType,
    String? concern,
    String? skinType,
    int page = 1,
    int perPage = 20,
    String sort = '-created_at',
  }) async {
    final res = await _dio.get('/api/products', queryParameters: {
      if (q != null && q.isNotEmpty) 'q': q,
      if (category != null && category.isNotEmpty) 'category': category,
      if (itemType != null && itemType.isNotEmpty) 'item_type': itemType,
      if (concern != null && concern.isNotEmpty) 'concern': concern,
      if (skinType != null && skinType.isNotEmpty) 'skin_type': skinType,
      'page': page,
      'per_page': perPage,
      'sort': sort,
    });
    return _map<Map<String, dynamic>>(res);
  }

  Future<Map<String, dynamic>> getProductDetail(String idOrSlug) async {
    final res = await _dio.get('/api/products/$idOrSlug');
    return _map<Map<String, dynamic>>(res);
  }

  Future<Map<String, dynamic>> getRelatedProducts(String productId) async {
    final res = await _dio.get('/api/products/$productId/related');
    return _map<Map<String, dynamic>>(res); // { items: [...] }
  }

  Future<Map<String, dynamic>> searchProducts(String q) async {
    final res = await _dio.get('/api/search', queryParameters: {'q': q});
    return _map<Map<String, dynamic>>(res); // { items: [...] }
  }

  Future<Map<String, dynamic>> getHomeSections() async {
    final res = await _dio.get('/api/home');
    return _map<Map<String, dynamic>>(res); // { new_arrivals, top_rated, budget_picks }
  }

  // ====== REVIEWS ======
  Future<Map<String, dynamic>> getReviews(String productId) async {
    final res = await _dio.get('/api/products/$productId/reviews');
    return _map<Map<String, dynamic>>(res);
  }

  Future<Map<String, dynamic>> createReview(String productId, {required int rating, String? title, String? body}) async {
    final res = await _dio.post('/api/products/$productId/reviews', data: {
      'rating': rating,
      if (title != null) 'title': title,
      if (body != null) 'body': body,
    });
    return _map<Map<String, dynamic>>(res); // { id: ... }
  }

  Future<Map<String, dynamic>> deleteReview(String reviewId) async {
    final res = await _dio.delete('/api/reviews/$reviewId');
    return _map<Map<String, dynamic>>(res); // { ok: true }
  }

  // ====== WISHLIST ======
  Future<Map<String, dynamic>> getWishlist() async {
    final res = await _dio.get('/api/wishlist');
    return _map<Map<String, dynamic>>(res);
  }

  Future<Map<String, dynamic>> addToWishlist(String productId) async {
    final res = await _dio.post('/api/wishlist/$productId');
    return _map<Map<String, dynamic>>(res); // { ok: true }
  }

  Future<Map<String, dynamic>> removeFromWishlist(String productId) async {
    final res = await _dio.delete('/api/wishlist/$productId');
    return _map<Map<String, dynamic>>(res); // { ok: true }
  }

  // ====== ADDRESSES ======
  Future<Map<String, dynamic>> getAddresses() async {
    final res = await _dio.get('/api/addresses');
    return _map<Map<String, dynamic>>(res); // { items: [...] }
  }

  Future<Map<String, dynamic>> createAddress(Map<String, dynamic> address) async {
    final res = await _dio.post('/api/addresses', data: address);
    return _map<Map<String, dynamic>>(res); // address object
  }

  Future<Map<String, dynamic>> updateAddress(String id, Map<String, dynamic> address) async {
    final res = await _dio.put('/api/addresses/$id', data: address);
    return _map<Map<String, dynamic>>(res); // { ok: true }
  }

  Future<Map<String, dynamic>> deleteAddress(String id) async {
    final res = await _dio.delete('/api/addresses/$id');
    return _map<Map<String, dynamic>>(res); // { ok: true }
  }

  // ====== CART & CHECKOUT ======
  Future<Map<String, dynamic>> getCart() async {
    final res = await _dio.get('/api/cart');
    return _map<Map<String, dynamic>>(res); // { items, pricing }
  }

  Future<Map<String, dynamic>> addToCart({required String productId, int qty = 1}) async {
    final res = await _dio.post('/api/cart', data: {'product_id': productId, 'qty': qty});
    return _map<Map<String, dynamic>>(res); // { ok: true }
  }

  Future<Map<String, dynamic>> updateCartItem({required String productId, required int qty}) async {
    final res = await _dio.put('/api/cart/items/$productId', data: {'qty': qty});
    return _map<Map<String, dynamic>>(res); // { ok: true }
  }

  Future<Map<String, dynamic>> deleteCartItem(String productId) async {
    final res = await _dio.delete('/api/cart/items/$productId');
    return _map<Map<String, dynamic>>(res); // { ok: true }
  }

  Future<Map<String, dynamic>> clearCart() async {
    final res = await _dio.post('/api/cart/clear');
    return _map<Map<String, dynamic>>(res); // { ok: true }
  }

  Future<Map<String, dynamic>> priceCartItems(List<Map<String, dynamic>> items) async {
    final res = await _dio.post('/api/cart/price', data: {'items': items});
    return _map<Map<String, dynamic>>(res); // pricing object
  }

  Future<Map<String, dynamic>> checkout({
    List<Map<String, dynamic>>? items, // If null and JWT available, server uses saved cart
    required String email,
    String? name,
    Map<String, dynamic>? shippingAddress,
    String paymentMethod = 'cod',
  }) async {
    final res = await _dio.post('/api/checkout', data: {
      if (items != null) 'items': items,
      'email': email,
      if (name != null) 'name': name,
      if (shippingAddress != null) 'shipping_address': shippingAddress,
      'payment_method': paymentMethod,
    });
    return _map<Map<String, dynamic>>(res); // { order_id, order_no, status }
  }

  Future<Map<String, dynamic>> createPaymentIntent(double amount) async {
    final res = await _dio.post('/api/payments/create-intent', data: {'amount': amount});
    return _map<Map<String, dynamic>>(res); // { client_secret, amount }
  }

  // ====== ORDERS ======
  Future<Map<String, dynamic>> getOrders() async {
    final res = await _dio.get('/api/orders');
    return _map<Map<String, dynamic>>(res); // { items: [...] }
  }

  Future<Map<String, dynamic>> getOrderDetail(String orderId) async {
    final res = await _dio.get('/api/orders/$orderId');
    return _map<Map<String, dynamic>>(res); // full order
  }

  Future<Map<String, dynamic>> cancelOrder(String orderId) async {
    final res = await _dio.post('/api/orders/$orderId/cancel');
    return _map<Map<String, dynamic>>(res); // { ok: true }
  }

  // ====== AI: Face Analysis & Recs ======
  Future<Map<String, dynamic>> getAiProfile() async {
    final res = await _dio.get('/api/ai/profile');
    return _map<Map<String, dynamic>>(res); // { has_profile, profile? }
  }

  Future<Map<String, dynamic>> deleteAiProfile() async {
    final res = await _dio.delete('/api/ai/profile');
    return _map<Map<String, dynamic>>(res); // { ok: true }
  }

  /// Analyze via image file (multipart)
  Future<Map<String, dynamic>> analyzeFaceFile(File imageFile) async {
    final form = await _fileForm('file', imageFile);
    final res = await _dio.post('/api/ai/analyze', data: form);
    return _map<Map<String, dynamic>>(res); // { saved, image_path, image_url, result, merged }
  }

  /// Analyze via base64 (JSON)
  Future<Map<String, dynamic>> analyzeFaceBase64(String base64Image) async {
    final res = await _dio.post('/api/ai/analyze', data: {'image_base64': base64Image});
    return _map<Map<String, dynamic>>(res);
  }

  Future<Map<String, dynamic>> getRecommendations({
    String? skinType,
    List<String>? concerns,
  }) async {
    final qp = <String, dynamic>{};
    if (skinType != null && skinType.isNotEmpty) qp['skin_type'] = skinType;
    if (concerns != null && concerns.isNotEmpty) qp['concerns'] = concerns.join(',');
    final res = await _dio.get('/api/recommendations', queryParameters: qp);
    return _map<Map<String, dynamic>>(res);
  }
}
