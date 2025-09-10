// lib/app/app_router.dart


import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'app_constants.dart';

// Settings
import '../features/account/screens/settings_screen.dart';

// AUTH
import '../features/auth/login/screens/login_screen.dart';
import '../features/auth/register/screens/register_screen.dart';
import '../features/auth/forgot_password/screens/password_request_screen.dart';
import '../features/auth/forgot_password/screens/password_reset_screen.dart';

// HOME & CATEGORIES
import '../features/home/screens/home_screen.dart';
import '../features/categories/screens/categories_screen.dart';
import '../features/categories/screens/category_listing_screen.dart';

// PRODUCT
import '../features/product/screens/product_detail_screen.dart';

// CART & CHECKOUT
import '../features/cart/screens/cart_screen.dart';
import '../features/cart/screens/order_review_screen.dart';
import '../features/cart/screens/payment_method_screen.dart';
import '../features/cart/screens/order_confirm_screen.dart';
import '../features/cart/screens/order_success_screen.dart';

// ACCOUNT / ORDERS / WISHLIST / ADDRESSES / SETTINGS
import '../features/account/screens/account_home_screen.dart';
import '../features/orders/screens/orders_list_screen.dart';
import '../features/orders/screens/order_detail_screen.dart';
import '../features/wishlist/screens/wishlist_screen.dart';
import '../features/addresses/screens/addresses_list_screen.dart';
import '../features/addresses/screens/address_edit_screen.dart';

// AI (NO ALIASES — import normally)
import '../features/ai/screens/ai_analyze_screen.dart';
import '../features/ai/screens/ai_profile_screen.dart';


import 'package:beauty_commerce_app/app/theme_controller.dart';

/// Lightweight auth state the router listens to.
class _AuthState extends ChangeNotifier {
  String? _accessToken;

  String? get accessToken => _accessToken;
  bool get isLoggedIn => (_accessToken != null && _accessToken!.isNotEmpty);

  void setToken(String? token) {
    final normalized = token?.trim();
    _accessToken = (normalized == null || normalized.isEmpty) ? null : normalized;
    notifyListeners();
  }
}

class AppRouter {
  AppRouter._();

  static final _auth = _AuthState();

  /// Call after login/logout
  static void setAccessToken(String? token) => _auth.setToken(token);

  /// Read current token
  static String? get accessToken => _auth.accessToken;

  static final GlobalKey<NavigatorState> _rootKey =
      GlobalKey<NavigatorState>(debugLabel: 'root');

  /// Paths that require auth
  static const List<String> _protectedPrefixes = <String>[
    Routes.cart,
    '/checkout',
    Routes.account,
    Routes.orders,
    Routes.wishlist,
    Routes.addresses,
    Routes.settings,
    Routes.ai,
    Routes.aiAnalyze,
    Routes.aiProfile,
  ];

  static bool _needsAuth(String location) {
    final loc = Uri.parse(location).path;
    for (final p in _protectedPrefixes) {
      if (loc == p || loc.startsWith('$p/')) return true;
    }
    return false;
  }

  static bool _isAuthPage(String location) {
    final loc = Uri.parse(location).path;
    return loc == Routes.login ||
        loc == Routes.register ||
        loc == Routes.forgot ||
        loc == Routes.reset;
  }

  static final GoRouter router = GoRouter(
    navigatorKey: _rootKey,
    initialLocation: Routes.login,
    refreshListenable: _auth,

    // Centralized redirects based on auth state
    redirect: (context, state) {
      final loggedIn = _auth.isLoggedIn;
      final goingToAuth = _isAuthPage(state.matchedLocation);
      final needsAuth = _needsAuth(state.matchedLocation);

      if (!loggedIn && needsAuth) return Routes.login;
      if (loggedIn && goingToAuth) return Routes.home;
      if (state.matchedLocation == '/') {
        return loggedIn ? Routes.home : Routes.login;
      }
      return null;
    },

    routes: <RouteBase>[
      // Root redirect
      GoRoute(path: '/', redirect: (ctx, st) => Routes.login),

      // -------------------- Auth Flow --------------------
      GoRoute(
        path: Routes.login,
        name: 'login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: Routes.register,
        name: 'register',
        builder: (context, state) => const RegisterScreen(),
      ),
      GoRoute(
        path: Routes.forgot,
        name: 'forgot',
        builder: (context, state) => const PasswordRequestScreen(),
      ),
      GoRoute(
        path: Routes.reset,
        name: 'reset',
        builder: (context, state) => const PasswordResetScreen(),
      ),

      // -------------------- Global Detail Routes (no auth needed) ----
      GoRoute(
        path: Routes.productDetail, // '/product/:idOrSlug'
        name: 'product_detail',
        builder: (context, state) {
          final id = state.pathParameters['idOrSlug'] ?? '';
          return ProductDetailScreen(
            idOrSlug: id,
            accessToken: accessToken ?? '',
          );
        },
      ),
      GoRoute(
        path: Routes.categoryListing, // '/category/:id'
        name: 'category_listing',
        builder: (context, state) {
          final id = state.pathParameters['id'] ?? '';
          return CategoryListingScreen(categoryId: id);
        },
      ),

      // Keep /categories accessible by deep link (not in tab bar).
      GoRoute(
        path: Routes.categories,
        name: 'categories',
        builder: (context, state) => const CategoriesScreen(),
      ),

      // -------------------- Main 4-Tab Shell ------------------------
      // Order MUST match BottomNavigationBar items: Home, AI, Cart, Account
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            _MainScaffold(navigationShell: navigationShell),
        branches: <StatefulShellBranch>[
          // 0) Home
          StatefulShellBranch(
            routes: <RouteBase>[
              GoRoute(
                path: Routes.home,
                name: 'home',
                builder: (context, state) => const HomeScreen(),
              ),
            ],
          ),

          // 1) AI (protected) — Profile hub + Analyze
          StatefulShellBranch(
            routes: <RouteBase>[
              GoRoute(
                path: Routes.ai, // '/ai'
                name: 'ai',
                builder: (context, state) => AiProfileScreen(
                  accessToken: accessToken ?? '',
                  onOpenAnalyze: () => context.pushNamed('ai_analyze'),
                  onRequireLogin: () => context.goNamed('login'),
                ),
              ),
              GoRoute(
                path: Routes.aiAnalyze, // '/ai/analyze'
                name: 'ai_analyze',
                builder: (context, state) =>
                    AiAnalyzeScreen(accessToken: accessToken ?? ''),
              ),
              GoRoute(
                path: Routes.aiProfile, // '/ai/profile'
                name: 'ai_profile',
                builder: (context, state) => AiProfileScreen(
                  accessToken: accessToken ?? '',
                  onOpenAnalyze: () => context.pushNamed('ai_analyze'),
                  onRequireLogin: () => context.goNamed('login'),
                ),
              ),
            ],
          ),

          // 2) Cart & Checkout (protected) — tab pushes cart without switching index
          StatefulShellBranch(
            routes: <RouteBase>[
              GoRoute(
                path: Routes.cart,
                name: 'cart',
                builder: (context, state) =>
                    CartScreen(accessToken: accessToken ?? ''),
              ),
              GoRoute(
                path: Routes.checkoutAddress, // '/checkout/address'
                name: 'checkout_address',
                builder: (context, state) =>
                    AddressesListScreen(accessToken: accessToken ?? ''),
              ),
              GoRoute(
                path: Routes.checkoutAddressNew, // '/checkout/address/new'
                name: 'checkout_address_new',
                builder: (context, state) =>
                    AddressEditScreen(accessToken: accessToken ?? ''),
              ),
              GoRoute(
                path: Routes.checkoutAddressEdit, // '/checkout/address/:id/edit'
                name: 'checkout_address_edit',
                builder: (context, state) {
                  final id = state.pathParameters['id'] ?? '';
                  return AddressEditScreen(
                    accessToken: accessToken ?? '',
                    addressId: id,
                  );
                },
              ),
              GoRoute(
                path: Routes.checkoutReview,
                name: 'checkout_review',
                builder: (context, state) =>
                    OrderReviewScreen(accessToken: accessToken ?? ''),
              ),
              GoRoute(
                path: Routes.checkoutPayment,
                name: 'checkout_payment',
                builder: (context, state) =>
                    PaymentMethodScreen(accessToken: accessToken ?? ''),
              ),
              GoRoute(
                path: Routes.checkoutConfirm,
                name: 'checkout_confirm',
                builder: (context, state) =>
                    OrderConfirmScreen(accessToken: accessToken ?? ''),
              ),
              GoRoute(
                path: Routes.checkoutSuccess,
                name: 'checkout_success',
                builder: (context, state) {
                  final orderNo = state.uri.queryParameters['orderNo'] ?? '';
                  return OrderSuccessScreen(orderNo: orderNo);
                },
              ),
            ],
          ),

          // 3) Account Area (protected)
          StatefulShellBranch(
            routes: <RouteBase>[
              GoRoute(
                path: Routes.account,
                name: 'account',
                builder: (context, state) =>
                    AccountHomeScreen(accessToken: accessToken ?? ''),
              ),
              GoRoute(
                path: Routes.orders,
                name: 'orders',
                builder: (context, state) =>
                    OrdersListScreen(accessToken: accessToken ?? ''),
              ),
              GoRoute(
                path: Routes.orderDetail,
                name: 'order_detail',
                builder: (context, state) {
                  final id = state.pathParameters['id'] ?? '';
                  return OrderDetailScreen(
                    orderId: id,
                    accessToken: accessToken ?? '',
                  );
                },
              ),
              GoRoute(
                path: Routes.wishlist,
                name: 'wishlist',
                builder: (context, state) =>
                    WishlistScreen(accessToken: accessToken ?? ''),
              ),
              GoRoute(
                path: Routes.addresses,
                name: 'addresses',
                builder: (context, state) =>
                    AddressesListScreen(accessToken: accessToken ?? ''),
              ),
              GoRoute(
                path: Routes.addressesNew,
                name: 'addresses_new',
                builder: (context, state) =>
                    AddressEditScreen(accessToken: accessToken ?? ''),
              ),
              GoRoute(
                path: Routes.addressesEdit,
                name: 'addresses_edit',
                builder: (context, state) {
                  final id = state.pathParameters['id'] ?? '';
                  return AddressEditScreen(
                    accessToken: accessToken ?? '',
                    addressId: id,
                  );
                },
              ),
              GoRoute(
                path: Routes.settings,
                name: 'settings',
                builder: (context, state) => SettingsScreen(
                  accessToken: accessToken, // optional, used by "Delete AI profile"
                  initialThemeMode: ThemeController.instance.mode,
                  onThemeModeChanged: ThemeController.instance.setMode,
                  // (You can also pass the notify toggles here if you later persist them)
                ),
              ),

            ],
          ),
        ],
      ),
    ],

    errorBuilder: (context, state) => Scaffold(
      appBar: AppBar(title: const Text('404 Not Found')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            state.uri.toString(),
            textAlign: TextAlign.center,
          ),
        ),
      ),
    ),
  );
}

// -----------------------------------------------------------------------------
// Main Scaffold with BottomNavigationBar (4 tabs)
// -----------------------------------------------------------------------------
class _MainScaffold extends StatelessWidget {
  const _MainScaffold({required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  // Matches the Cart branch index above (Home 0, AI 1, Cart 2, Account 3)
  static const int _cartTabIndex = 2;

  void _onTap(BuildContext context, int index) {
    if (index == _cartTabIndex) {
      context.pushNamed('cart'); // push cart without changing tab
      return;
    }
    navigationShell.goBranch(
      index,
      initialLocation: index == navigationShell.currentIndex,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: navigationShell.currentIndex,
        onTap: (i) => _onTap(context, i),
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(icon: Icon(UI.iconHome), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(UI.iconAi), label: 'AI'),
          BottomNavigationBarItem(icon: Icon(UI.iconCart), label: 'Cart'),
          BottomNavigationBarItem(icon: Icon(UI.iconAccount), label: 'Account'),
        ],
      ),
    );
  }
}
