import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Public URLs of the sibling apps, used in invitations and "view on
/// marketplace" links.
///
/// Set at build time:
///   --dart-define=VENDOR_APP_URL=https://vendor.example.com
///   --dart-define=USER_APP_URL=https://example.com
/// and overridable from Settings → Links (saved on this device), so a new
/// deployment does not need a rebuild of the console.
class AppLinks {
  AppLinks._();

  static const _vendorDefault = String.fromEnvironment('VENDOR_APP_URL');
  static const _userDefault = String.fromEnvironment('USER_APP_URL');
  static const _vendorKey = 'admin_link_vendor_app';
  static const _userKey = 'admin_link_user_app';

  static final ValueNotifier<String> vendorApp = ValueNotifier(_vendorDefault);
  static final ValueNotifier<String> userApp = ValueNotifier(_userDefault);

  static Future<void> restore() async {
    final p = await SharedPreferences.getInstance();
    vendorApp.value = p.getString(_vendorKey) ?? _vendorDefault;
    userApp.value = p.getString(_userKey) ?? _userDefault;
  }

  static Future<void> save({required String vendor, required String user}) async {
    final p = await SharedPreferences.getInstance();
    vendorApp.value = _clean(vendor);
    userApp.value = _clean(user);
    await p.setString(_vendorKey, vendorApp.value);
    await p.setString(_userKey, userApp.value);
  }

  static String _clean(String s) {
    var v = s.trim();
    if (v.isNotEmpty && !v.startsWith('http')) v = 'https://$v';
    while (v.endsWith('/')) {
      v = v.substring(0, v.length - 1);
    }
    return v;
  }
}
