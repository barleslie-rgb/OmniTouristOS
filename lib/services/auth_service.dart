import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user_profile.dart';

class AuthService {
  static final SupabaseClient _supabase = Supabase.instance.client;
  static const String _guestKey = 'omni_is_guest_mode';

  // Get current logged-in user
  static User? get currentUser => _supabase.auth.currentUser;

  // Stream auth state changes
  static Stream<AuthState> get authStateChanges => _supabase.auth.onAuthStateChange;

  // Guest Mode Check & State
  static Future<bool> isGuest() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_guestKey) ?? false;
  }

  static Future<void> setGuestMode(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_guestKey, value);
  }

  // -------------------------------------------------------------
  // 1. GOOGLE 1-TAP OAUTH SIGN-IN
  // -------------------------------------------------------------
 static Future<bool> signInWithGoogle() async {
    try {
      // Clear guest mode ahead of launching the browser flow
      await setGuestMode(false);

      final success = await _supabase.auth.signInWithOAuth(
        OAuthProvider.google,
        redirectTo: kIsWeb ? null : 'io.supabase.touristos://login-callback',
      );
      return success;
    } catch (e) {
      debugPrint("GOOGLE SIGN-IN ERROR: $e");
      rethrow;
    }
  }

  // -------------------------------------------------------------
  // 2. EMAIL & PASSWORD: SIGN IN EXISTING USER
  // -------------------------------------------------------------
  static Future<UserProfile?> signInWithPassword({
    required String email,
    required String password,
  }) async {
    final res = await _supabase.auth.signInWithPassword(
      email: email.trim(),
      password: password.trim(),
    );

    if (res.user != null) {
      await setGuestMode(false);
      return await syncOrCreateUserProfile(res.user!);
    }
    return null;
  }

  // -------------------------------------------------------------
  // 3. EMAIL & PASSWORD: CREATE NEW ACCOUNT
  // -------------------------------------------------------------
  static Future<UserProfile?> signUpWithPassword({
    required String email,
    required String password,
    String? fullName,
  }) async {
    final res = await _supabase.auth.signUp(
      email: email.trim(),
      password: password.trim(),
      data: fullName != null && fullName.trim().isNotEmpty
          ? {'full_name': fullName.trim(), 'name': fullName.trim()}
          : null,
    );

    if (res.user != null) {
      await setGuestMode(false);
      return await syncOrCreateUserProfile(res.user!);
    }
    return null;
  }

  // -------------------------------------------------------------
  // 4. SYNC OR AUTO-PROVISION 30-DAY TRIAL PROFILE
  // -------------------------------------------------------------
  static Future<UserProfile> syncOrCreateUserProfile(User user) async {
    final email = user.email ?? "";
    final isMaster = email.toLowerCase().trim() == UserProfile.masterAdminEmail.toLowerCase().trim();

    try {
      final data = await _supabase
          .from('user_profiles')
          .select()
          .eq('id', user.id)
          .maybeSingle();

      if (data != null) {
        return UserProfile.fromJson(data);
      }

      // First time login -> create 30-day trial record
      final newProfile = UserProfile(
        id: user.id,
        email: email,
        role: isMaster ? "admin" : "user",
        createdAt: DateTime.now(),
        trialEndsAt: DateTime.now().add(const Duration(days: 30)),
        isPremium: isMaster,
        isBanned: false,
      );

      await _supabase.from('user_profiles').insert(newProfile.toJson());
      return newProfile;
    } catch (_) {
      // Offline fallback: ensures the app operates smoothly without crash
      return UserProfile(
        id: user.id,
        email: email,
        role: isMaster ? "admin" : "user",
        createdAt: DateTime.now(),
        trialEndsAt: DateTime.now().add(const Duration(days: 30)),
        isPremium: isMaster,
        isBanned: false,
      );
    }
  }

  // -------------------------------------------------------------
  // 5. CHECK BAN STATUS
  // -------------------------------------------------------------
  static Future<bool> isUserBanned(String userId) async {
    if (currentUser?.email?.toLowerCase().trim() == UserProfile.masterAdminEmail.toLowerCase().trim()) {
      return false; // Master owner is permanently immune
    }

    try {
      final res = await _supabase
          .from('user_profiles')
          .select('is_banned')
          .eq('id', userId)
          .single();
      return res['is_banned'] ?? false;
    } catch (_) {
      return false;
    }
  }

  // -------------------------------------------------------------
  // 6. SIGN OUT
  // -------------------------------------------------------------
  static Future<void> signOut() async {
    await setGuestMode(false);
    await _supabase.auth.signOut();
  }
}