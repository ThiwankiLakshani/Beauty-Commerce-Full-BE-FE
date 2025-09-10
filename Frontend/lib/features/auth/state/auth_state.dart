import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

class AuthState extends ChangeNotifier {
  String? accessToken;
  String? refreshToken;
  Map<String, dynamic>? user;

  void setFromPayload(Map<String, dynamic> payload) {
    accessToken  = (payload['access_token'] as String?)?.trim();
    refreshToken = (payload['refresh_token'] as String?)?.trim();
    user         = payload['user'] is Map ? (payload['user'] as Map).cast<String, dynamic>() : null;
    notifyListeners();
  }

  void clear() {
    accessToken = null;
    refreshToken = null;
    user = null;
    notifyListeners();
  }

  bool get isSignedIn => (accessToken ?? '').isNotEmpty;
}

/// Inherited wrapper so widgets can read AuthState from the widget tree.
class AuthScope extends InheritedNotifier<AuthState> {
  const AuthScope({
    super.key,
    required AuthState notifier,
    required Widget child,
  }) : super(notifier: notifier, child: child);

  static AuthState of(BuildContext context, {bool listen = true}) {
    final scope = listen
        ? context.dependOnInheritedWidgetOfExactType<AuthScope>()
        : context.getElementForInheritedWidgetOfExactType<AuthScope>()?.widget as AuthScope?;
    if (scope == null || scope.notifier == null) {
      throw FlutterError('AuthScope not found. Wrap your app with AuthScope.');
    }
    return scope.notifier!;
  }

  @override
  bool updateShouldNotify(AuthScope old) => notifier != old.notifier;
}
