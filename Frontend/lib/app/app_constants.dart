// lib/app/app_constants.dart

import 'package:flutter/material.dart';

/// Prevent instantiation by exposing only static members.
class AppConstants {
  AppConstants._();
}

/// Basic app information and branding.
class AppInfo {
  AppInfo._();

  static const String appName = 'Beauty Commerce';
  static const String version = '1.0.0';
  static const String companyName = 'Beauty Commerce Ltd.';
  static const String supportEmail = 'support@example.com';
  static const String defaultCurrency = 'LKR';

  /// Matches the seed value used in AppTheme.
  static const Color brandSeedColor = Color(0xFF66CC99);
}

/// Build / environment flags.
class BuildFlags {
  BuildFlags._();

  /// True for profile/release, false for debug.
  static const bool isProduction = bool.fromEnvironment('dart.vm.product');

  /// Toggle feature-gated UI as you develop.
  static const bool enableAiFeatures = true; // AI Analyze/Profile
  static const bool enableMockPayments = true; // /api/payments/create-intent is mocked
}

/// API-related constants.
class Api {
  Api._();

  /// Key used with --dart-define to inject a base URL at runtime.
  /// Example:
  ///   flutter run --dart-define=BASE_URL=http://10.0.2.2:5000
  static const String envBaseUrlKey = 'BASE_URL';

  /// Sensible local defaults (choose based on your target during development).
  static const String defaultBaseUrlAndroidEmulator = 'http://10.0.2.2:5000';
  static const String defaultBaseUrlIosSimulator = 'http://127.0.0.1:5000';

  /// Authorization header name.
  static const String authHeader = 'Authorization';
  static const String bearerPrefix = 'Bearer ';

  // ---------------- Endpoints (paths only) ----------------

  // Auth
  static const String authRegister = '/api/auth/register';
  static const String authLogin = '/api/auth/login';
  static const String authRefresh = '/api/auth/refresh';
  static const String authMe = '/api/auth/me';
  static const String authPasswordRequest = '/api/auth/password/request-reset';
  static const String authPasswordReset = '/api/auth/password/reset';

  // Catalog / Discovery
  static const String categories = '/api/categories';
  static const String attributes = '/api/attributes';
  static const String products = '/api/products'; // + '/:idOrSlug'
  static const String search = '/api/search';
  static const String home = '/api/home';

  // Reviews
  static const String productReviews = '/api/products'; // + '/:productId/reviews'
  static const String reviewById = '/api/reviews'; // + '/:reviewId'

  // Wishlist
  static const String wishlist = '/api/wishlist'; // GET list
  static const String wishlistItem = '/api/wishlist'; // + '/:productId' (POST/DELETE)

  // Addresses
  static const String addresses = '/api/addresses'; // list/create
  static const String addressById = '/api/addresses'; // + '/:id' (PUT/DELETE)

  // Cart & Checkout
  static const String cart = '/api/cart';
  static const String cartItems = '/api/cart/items'; // + '/:productId' (PUT/DELETE)
  static const String cartClear = '/api/cart/clear';
  static const String cartPrice = '/api/cart/price';
  static const String checkout = '/api/checkout';
  static const String paymentIntent = '/api/payments/create-intent';

  // Orders
  static const String orders = '/api/orders'; // list
  static const String orderById = '/api/orders'; // + '/:orderId'
  static const String orderCancel = '/api/orders'; // + '/:orderId/cancel'

  // AI
  static const String aiProfile = '/api/ai/profile';
  static const String aiAnalyze = '/api/ai/analyze';
  static const String recommendations = '/api/recommendations';

  // --- Auth (Password reset) ---
  static const String authPasswordRequestReset = '/api/auth/password/request-reset';
}

/// Default networking values for HTTP clients.
class NetworkDefaults {
  NetworkDefaults._();

  static const Duration connectTimeout = Duration(seconds: 15);
  static const Duration receiveTimeout = Duration(seconds: 20);
  static const Duration sendTimeout = Duration(seconds: 20);

  static const Map<String, String> defaultHeaders = <String, String>{
    'Accept': 'application/json',
  };

  /// Pagination defaults (server caps per_page at 100).
  static const int defaultPage = 1;
  static const int defaultPageSize = 20;
  static const int maxPageSize = 100;
}

/// Route path names used by the app router.
///
/// Keep these centralized to avoid string typos.
class Routes {
  Routes._();

  // Auth flow
  static const String login = '/login';
  static const String register = '/register';
  static const String forgot = '/forgot';
  static const String reset = '/reset';

  // Tabs / main
  static const String home = '/home';
  static const String categories = '/categories';
  static const String categoryListing = '/category/:id';
  static const String discover = '/discover';
  static const String search = '/search';
  static const String searchResults = '/search/results';
  static const String recommendations = '/recommendations';
  static const String cart = '/cart';
  static const String account = '/account';

  // Product flow
  static const String productDetail = '/product/:idOrSlug';

  // Checkout
  static const String checkoutAddress = '/checkout/address';
  static const String checkoutAddressNew = '/checkout/address/new';
  static const String checkoutAddressEdit = '/checkout/address/:id/edit';
  static const String checkoutReview = '/checkout/review';
  static const String checkoutPayment = '/checkout/payment';
  static const String checkoutConfirm = '/checkout/confirm';
  static const String checkoutSuccess = '/checkout/success';

  // Account subroutes
  static const String orders = '/orders';
  static const String orderDetail = '/orders/:id';
  static const String wishlist = '/wishlist';
  static const String addresses = '/addresses';
  static const String addressesNew = '/addresses/new';
  static const String addressesEdit = '/addresses/:id/edit';
  static const String settings = '/settings';

  // AI (hub + subroutes)
  static const String ai = '/ai';              // <-- added for AI hub
  static const String aiAnalyze = '/ai/analyze';
  static const String aiProfile = '/ai/profile';
}

/// Keys for local/secure storage.
class StorageKeys {
  StorageKeys._();

  // Auth
  static const String accessToken = 'auth.access_token';
  static const String refreshToken = 'auth.refresh_token';
  static const String user = 'auth.user'; // serialized user

  // Preferences
  static const String themeMode = 'prefs.theme_mode'; // system/light/dark
  static const String languageCode = 'prefs.language_code';
  static const String notificationsEnabled = 'prefs.notifications_enabled';

  // UX
  static const String searchHistory = 'ux.search_history';
  static const String seenOnboarding = 'ux.seen_onboarding';

  // Cart (optional client cache)
  static const String cartCache = 'cart.cache';
}

/// UI constants shared across widgets.
class UI {
  UI._();

  // Dimensions
  static const double cornerRadius = 14.0; // match Theme radius
  static const double cardRadius = 14.0;
  static const double bottomSheetTopRadius = 24.0;

  // Spacing
  static const double spacingXS = 6.0;
  static const double spacingS = 10.0;
  static const double spacingM = 14.0;
  static const double spacingL = 18.0;
  static const double spacingXL = 24.0;

  // Durations
  static const Duration animFast = Duration(milliseconds: 150);
  static const Duration anim = Duration(milliseconds: 250);
  static const Duration animSlow = Duration(milliseconds: 350);

  // Elevation presets (Material 3 often uses 0; keep for special cases)
  static const double elevationNone = 0.0;
  static const double elevation1 = 1.0;
  static const double elevation2 = 2.0;

  // Icon defaults (for nav bars, placeholders, etc.)
  static const IconData iconHome = Icons.home_rounded;
  static const IconData iconCategories = Icons.category_rounded;
  static const IconData iconDiscover = Icons.search_rounded;
  static const IconData iconCart = Icons.shopping_cart_rounded;
  static const IconData iconAccount = Icons.person_rounded;
  static const IconData iconAi = Icons.auto_awesome; // <-- handy for AI tab
}

/// Common regular expressions.
class Regex {
  Regex._();

  /// Basic email validation (client-side convenience).
  static final RegExp email =
      RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]{2,}$', caseSensitive: false);

  /// Digits only (e.g., postal codes).
  static final RegExp digitsOnly = RegExp(r'^\d+$');
}
