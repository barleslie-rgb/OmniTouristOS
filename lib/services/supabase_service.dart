import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseService {
  static const String supabaseUrl = "https://jzkbhbnrzkekbjxumvom.supabase.co";
  static const String supabaseAnonKey =
      "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imp6a2JoYm5yemtla2JqeHVtdm9tIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODg3NTg0MDEsImV4cCI6MjEwNDMzNDQwMX0.7ZcXdc87S3szmbBNm66d9DMRAjUAe6rXda7zpOLaLq8";

  static bool _initialized = false;

  static const List<String> adminEmails = [
    "barleslie@gmail.com",
    "admin@touristos.app",
  ];

  static bool isUserAdmin(String? email) {
    if (email == null || email.isEmpty) return false;
    final clean = email.toLowerCase().trim();
    return adminEmails.any((admin) => clean == admin.toLowerCase().trim());
  }

  static Future<void> ensureInitialized() async {
    if (_initialized) return;
    try {
      final _ = Supabase.instance.client;
      _initialized = true;
    } catch (_) {
      await Supabase.initialize(
        url: supabaseUrl,
        anonKey: supabaseAnonKey,
      );
      _initialized = true;
    }
  }

  static SupabaseClient get client => Supabase.instance.client;

  // ==========================================
  // OMNIGUARD AUTONOMOUS MODERATION BOT
  // ==========================================
  static final RegExp _illegalRegex = RegExp(
    r'\b(drugs|narcotics|cocaine|weed|marijuana|ganja|charas|mdma|pills|escort|sex|weapons|firearm|ammo|hack|crypto|wire\s*transfer|hawala|t\.me\/|telegram\.me\/)\b',
    caseSensitive: false,
  );

  static final RegExp _spamRegex = RegExp(
    r'(https?:\/\/[^\s]+|bit\.ly\/[^\s]+|\+?91[0-9]{10})',
    caseSensitive: false,
  );

  static Future<Map<String, dynamic>> inspectWithOmniGuard({
    required String text,
    required String userId,
    required String userName,
    required String channelType,
  }) async {
    final cleanText = text.trim();

    if (_illegalRegex.hasMatch(cleanText)) {
      await _logViolation(
        userId: userId,
        userName: userName,
        channelType: channelType,
        originalText: cleanText,
        reason: "Illegal contraband / solicitation match",
        actionTaken: "instant_ban",
      );
      await banUser(userId, "Violated safety guidelines (Illegal content / illicit goods)");
      return {
        "allowed": false,
        "reason": "This message was blocked by OmniGuard for violating safety rules. Your account has been suspended.",
      };
    }

    if (_spamRegex.hasMatch(cleanText)) {
      await _logViolation(
        userId: userId,
        userName: userName,
        channelType: channelType,
        originalText: cleanText,
        reason: "External redirect trap / unverified link or raw phone drop",
        actionTaken: "quarantined",
      );
      return {
        "allowed": false,
        "reason": "Posting external links or unverified numbers is restricted to keep travelers safe.",
      };
    }

    return {"allowed": true};
  }

  static Future<void> _logViolation({
    required String userId,
    required String userName,
    required String channelType,
    required String originalText,
    required String reason,
    required String actionTaken,
  }) async {
    try {
      await ensureInitialized();
      await client.from('community_moderation_logs').insert({
        'violator_id': userId,
        'violator_name': userName,
        'channel_type': channelType,
        'original_message': originalText,
        'violation_reason': reason,
        'action_taken': actionTaken,
      });
    } catch (_) {}
  }

  // ==========================================
  // USER BANNING & UGC BLOCKING
  // ==========================================
  static Future<bool> isUserBanned(String userId) async {
    try {
      await ensureInitialized();
      final res = await client
          .from('user_profiles')
          .select('is_banned')
          .eq('id', userId)
          .maybeSingle();
      return res != null && res['is_banned'] == true;
    } catch (_) {
      return false;
    }
  }

  static Future<void> banUser(String userId, String reason) async {
    try {
      await ensureInitialized();
      await client.from('user_profiles').update({
        'is_banned': true,
        'banned_reason': reason,
      }).eq('id', userId);
    } catch (_) {}
  }

  static Future<void> blockUser(String blockerId, String blockedId) async {
    try {
      await ensureInitialized();
      await client.from('community_user_blocks').upsert({
        'blocker_id': blockerId,
        'blocked_id': blockedId,
      });
    } catch (_) {}
  }

  static Future<List<String>> getBlockedUserIds(String myId) async {
    try {
      await ensureInitialized();
      final res = await client
          .from('community_user_blocks')
          .select('blocked_id')
          .eq('blocker_id', myId);
      return (res as List).map((r) => r['blocked_id'].toString()).toList();
    } catch (_) {
      return [];
    }
  }

  // ==========================================
  // DIRECT 1-TO-1 MESSAGING
  // ==========================================
  static Stream<List<Map<String, dynamic>>> streamDirectMessages(String myId, String peerId) {
    return client
        .from('community_direct_messages')
        .stream(primaryKey: ['id'])
        .order('created_at', ascending: true);
  }

  static Future<bool> sendDirectMessage({
    required String senderId,
    required String senderName,
    required String receiverId,
    required String message,
  }) async {
    try {
      await ensureInitialized();
      await client.from('community_direct_messages').insert({
        'sender_id': senderId,
        'sender_name': senderName,
        'receiver_id': receiverId,
        'message': message.trim(),
      });
      return true;
    } catch (e) {
      debugPrint("Send DM error: $e");
      return false;
    }
  }

  // ==========================================
  // CORE PLACE HELPERS & ADDMETHOD (FOR CONTRIBUTE SCREEN)
  // ==========================================
  static Future<List<Map<String, dynamic>>> getPlacesForCity(String city) async {
    final prefs = await SharedPreferences.getInstance();
    final cacheKey = "offline_places_${city.toLowerCase().trim()}";

    try {
      await ensureInitialized();
      final response = await client
          .from('community_places')
          .select()
          .ilike('city', '%$city%')
          .order('upvotes', ascending: false)
          .order('created_at', ascending: false);

      final List<Map<String, dynamic>> places = List<Map<String, dynamic>>.from(response);
      await prefs.setString(cacheKey, jsonEncode(places));
      return places;
    } catch (e) {
      final cachedRaw = prefs.getString(cacheKey);
      if (cachedRaw != null && cachedRaw.isNotEmpty) {
        final List<dynamic> decoded = jsonDecode(cachedRaw);
        return decoded.map((e) => Map<String, dynamic>.from(e)).toList();
      }
      return [];
    }
  }

  /// Submits a newly discovered venue directly to Supabase
  static Future<bool> addPlace(Map<String, dynamic> placeData) async {
    try {
      await ensureInitialized();

      if ((placeData['maps_url'] ?? '').toString().isEmpty) {
        final name = placeData['name'] ?? '';
        final address = placeData['address'] ?? '';
        final city = placeData['city'] ?? '';
        placeData['maps_url'] =
            "https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent('$name, $address, $city')}";
      }

      await client.from('community_places').insert(placeData);

      final city = (placeData['city'] ?? '').toString();
      if (city.isNotEmpty) {
        await getPlacesForCity(city);
      }
      return true;
    } catch (e, st) {
      debugPrint("SUPABASE addPlace ERROR: $e");
      debugPrint("STACK TRACE: $st");
      return false;
    }
  }

  static Future<bool> upvotePlace(dynamic placeId, int currentUpvotes) async {
    final prefs = await SharedPreferences.getInstance();
    final votedKey = "voted_gem_${placeId.toString()}";
    if (prefs.getBool(votedKey) == true) return false;

    try {
      await ensureInitialized();
      await client.from('community_places').update({'upvotes': currentUpvotes + 1}).eq('id', placeId);
      await prefs.setBool(votedKey, true);
      return true;
    } catch (_) {
      return false;
    }
  }

  static Stream<List<Map<String, dynamic>>> streamPlaceMessages(String placeId) {
    return client
        .from('community_place_messages')
        .stream(primaryKey: ['id'])
        .eq('place_id', placeId)
        .order('created_at', ascending: true);
  }

  static Future<bool> postPlaceMessage({
    required String placeId,
    required String userId,
    required String userName,
    required String message,
  }) async {
    try {
      await ensureInitialized();
      await client.from('community_place_messages').insert({
        'place_id': placeId,
        'user_id': userId,
        'user_name': userName,
        'message': message.trim(),
      });
      return true;
    } catch (_) {
      return false;
    }
  }

  static Stream<List<Map<String, dynamic>>> streamCityPulse(String city) {
    return client
        .from('community_city_pulse')
        .stream(primaryKey: ['id'])
        .eq('city', city)
        .order('created_at', ascending: false);
  }

  static Future<bool> postCityPulse({
    required String city,
    required String userId,
    required String userName,
    required String content,
  }) async {
    try {
      await ensureInitialized();
      await client.from('community_city_pulse').insert({
        'city': city,
        'user_id': userId,
        'user_name': userName,
        'content': content.trim(),
      });
      return true;
    } catch (_) {
      return false;
    }
  }
}