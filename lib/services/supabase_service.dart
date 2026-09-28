import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseService {
  static const String supabaseUrl = "https://jzkbhbnrzkekbjxumvom.supabase.co";
  static const String supabaseAnonKey =
      "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imp6a2JoYm5yemtla2JqeHVtdm9tIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODg3NTg0MDEsImV4cCI6MjEwNDMzNDQwMX0.7ZcXdc87S3szmbBNm66d9DMRAjUAe6rXda7zpOLaLq8";

  static bool _initialized = false;

  /// Ensures Supabase is initialized before executing any query
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

  /// Fetches places for the target city from Supabase and updates offline cache
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

      final List<Map<String, dynamic>> places =
          List<Map<String, dynamic>>.from(response);

      await prefs.setString(cacheKey, jsonEncode(places));
      return places;
    } catch (e) {
      debugPrint("SUPABASE FETCH ERROR: $e");
      final cachedRaw = prefs.getString(cacheKey);
      if (cachedRaw != null && cachedRaw.isNotEmpty) {
        final List<dynamic> decoded = jsonDecode(cachedRaw);
        return decoded.map((e) => Map<String, dynamic>.from(e)).toList();
      }
      return [];
    }
  }

  /// Submits a newly discovered local venue directly to Supabase via Map (Used by ContributePlaceScreen)
  static Future<bool> addPlace(Map<String, dynamic> placeData) async {
    try {
      await ensureInitialized();

      // Ensure maps_url fallback exists if not manually provided
      if ((placeData['maps_url'] ?? '').toString().isEmpty) {
        final name = placeData['name'] ?? '';
        final address = placeData['address'] ?? '';
        final city = placeData['city'] ?? '';
        placeData['maps_url'] =
            "https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent('$name, $address, $city')}";
      }

      await client.from('community_places').insert(placeData);

      // Refresh offline cache with new entry
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

  /// Submits a newly discovered local venue directly to Supabase via named parameters
  static Future<String?> contributePlace({
    required String name,
    required String category,
    required String city,
    required String address,
    String? phone,
    String? description,
    String? contributorName,
  }) async {
    try {
      await ensureInitialized();

      final mapsUrl =
          "https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent('$name, $address, $city')}";

      await client.from('community_places').insert({
        'name': name,
        'category': category,
        'city': city,
        'address': address,
        'contact_phone': phone ?? '',
        'description': description ?? '',
        'maps_url': mapsUrl,
        'contributor_name': contributorName ?? 'Local Explorer',
        'is_verified': true,
        'upvotes': 0,
      });

      // Refresh offline cache with new entry
      await getPlacesForCity(city);
      return null;
    } catch (e, st) {
      debugPrint("SUPABASE INSERT ERROR: $e");
      debugPrint("STACK TRACE: $st");
      return e.toString();
    }
  }

  /// Increments upvote count on Supabase and tracks locally in SharedPreferences
  static Future<bool> upvotePlace(dynamic placeId, int currentUpvotes) async {
    final prefs = await SharedPreferences.getInstance();
    final votedKey = "voted_gem_${placeId.toString()}";

    // Prevent duplicate upvotes from the same device
    if (prefs.getBool(votedKey) == true) {
      return false;
    }

    try {
      await ensureInitialized();
      await client
          .from('community_places')
          .update({'upvotes': currentUpvotes + 1})
          .eq('id', placeId);

      await prefs.setBool(votedKey, true);
      return true;
    } catch (e) {
      debugPrint("UPVOTE ERROR: $e");
      return false;
    }
  }
}