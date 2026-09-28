import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'auth_service.dart';

class PassportStamp {
  final String id;
  final String city;
  final String name;
  final String title;
  final double lat;
  final double lng;
  final double radiusMeters;
  final String iconCode;
  final int colorHex;
  final bool isUnlocked;
  final DateTime? unlockedAt;
  final double? distanceMeters;

  PassportStamp({
    required this.id,
    required this.city,
    required this.name,
    required this.title,
    required this.lat,
    required this.lng,
    required this.radiusMeters,
    required this.iconCode,
    required this.colorHex,
    this.isUnlocked = false,
    this.unlockedAt,
    this.distanceMeters,
  });

  PassportStamp copyWith({
    bool? isUnlocked,
    DateTime? unlockedAt,
    double? distanceMeters,
  }) {
    return PassportStamp(
      id: id,
      city: city,
      name: name,
      title: title,
      lat: lat,
      lng: lng,
      radiusMeters: radiusMeters,
      iconCode: iconCode,
      colorHex: colorHex,
      isUnlocked: isUnlocked ?? this.isUnlocked,
      unlockedAt: unlockedAt ?? this.unlockedAt,
      distanceMeters: distanceMeters ?? this.distanceMeters,
    );
  }
}

class PassportService {
  static const String _localStampsKey = "omni_unlocked_stamps_v1";

  // Pre-configured geofenced landmark registry
  static final List<PassportStamp> _landmarkRegistry = [
    PassportStamp(
      id: "stamp_vasai_fort",
      city: "Vasai-Virar",
      name: "Bassein Fort (Fort Vasai)",
      title: "Portuguese Citadel Heritage",
      lat: 19.3308,
      lng: 72.8149,
      radiusMeters: 450.0,
      iconCode: "fort",
      colorHex: 0xFF2563EB,
    ),
    PassportStamp(
      id: "stamp_jivdani",
      city: "Vasai-Virar",
      name: "Jivdani Mata Temple",
      title: "Hilltop Divine Sanctuary",
      lat: 19.4678,
      lng: 72.8256,
      radiusMeters: 400.0,
      iconCode: "temple",
      colorHex: 0xFFD97706,
    ),
    PassportStamp(
      id: "stamp_suruchi",
      city: "Vasai-Virar",
      name: "Suruchi Beach Promenade",
      title: "Casuarina Coastal Shoreline",
      lat: 19.3496,
      lng: 72.7842,
      radiusMeters: 500.0,
      iconCode: "beach",
      colorHex: 0xFF0284C7,
    ),
    PassportStamp(
      id: "stamp_gateway_mumbai",
      city: "Mumbai",
      name: "Gateway of India",
      title: "Colaba Waterfront Arch",
      lat: 18.9220,
      lng: 72.8347,
      radiusMeters: 350.0,
      iconCode: "monument",
      colorHex: 0xFF16A34A,
    ),
    PassportStamp(
      id: "stamp_csmt",
      city: "Mumbai",
      name: "Chhatrapati Shivaji Maharaj Terminus",
      title: "Victorian Gothic Railway Hub",
      lat: 18.9400,
      lng: 72.8354,
      radiusMeters: 300.0,
      iconCode: "train",
      colorHex: 0xFF9333EA,
    ),
    PassportStamp(
      id: "stamp_marine_drive",
      city: "Mumbai",
      name: "Marine Drive Promenade",
      title: "Queen's Necklace Bay",
      lat: 18.9432,
      lng: 72.8230,
      radiusMeters: 600.0,
      iconCode: "coast",
      colorHex: 0xFFEA580C,
    ),
  ];

  /// Loads all stamps, mapping unlock states from local disk & Supabase
  static Future<List<PassportStamp>> getStamps({Position? currentPosition}) async {
    final prefs = await SharedPreferences.getInstance();
    final Map<String, dynamic> unlockedMap = {};

    // 1. Read offline cache
    final localRaw = prefs.getString(_localStampsKey);
    if (localRaw != null && localRaw.isNotEmpty) {
      try {
        unlockedMap.addAll(jsonDecode(localRaw));
      } catch (_) {}
    }

    // 2. Fetch Supabase sync if signed in
    final user = AuthService.currentUser;
    if (user != null) {
      try {
        final res = await Supabase.instance.client
            .from('user_profiles')
            .select('unlocked_stamps')
            .eq('id', user.id)
            .maybeSingle();

        if (res != null && res['unlocked_stamps'] != null) {
          final cloudStamps = res['unlocked_stamps'];
          if (cloudStamps is Map) {
            cloudStamps.forEach((k, v) => unlockedMap[k.toString()] = v);
            await prefs.setString(_localStampsKey, jsonEncode(unlockedMap));
          }
        }
      } catch (e) {
        debugPrint("Cloud stamp fetch notice: $e");
      }
    }

    // 3. Map registry with unlock status & distance calculations
    return _landmarkRegistry.map((stamp) {
      final isUnlocked = unlockedMap.containsKey(stamp.id);
      DateTime? date;
      if (isUnlocked && unlockedMap[stamp.id] != null) {
        date = DateTime.tryParse(unlockedMap[stamp.id].toString());
      }

      double? dist;
      if (currentPosition != null) {
        dist = Geolocator.distanceBetween(
          currentPosition.latitude,
          currentPosition.longitude,
          stamp.lat,
          stamp.lng,
        );
      }

      return stamp.copyWith(
        isUnlocked: isUnlocked,
        unlockedAt: date,
        distanceMeters: dist,
      );
    }).toList();
  }

  /// Evaluates current GPS location against geofences.
  /// Returns the newly unlocked stamp if within radius, or null if already unlocked / out of range.
  static Future<PassportStamp?> evaluateProximity(Position position) async {
    final prefs = await SharedPreferences.getInstance();
    final Map<String, dynamic> unlockedMap = {};

    final localRaw = prefs.getString(_localStampsKey);
    if (localRaw != null && localRaw.isNotEmpty) {
      try {
        unlockedMap.addAll(jsonDecode(localRaw));
      } catch (_) {}
    }

    for (final stamp in _landmarkRegistry) {
      if (unlockedMap.containsKey(stamp.id)) continue;

      final double distance = Geolocator.distanceBetween(
        position.latitude,
        position.longitude,
        stamp.lat,
        stamp.lng,
      );

      if (distance <= stamp.radiusMeters) {
        final now = DateTime.now();
        unlockedMap[stamp.id] = now.toIso8601String();

        // 1. Save locally
        await prefs.setString(_localStampsKey, jsonEncode(unlockedMap));

        // 2. Sync to Supabase
        final user = AuthService.currentUser;
        if (user != null) {
          try {
            await Supabase.instance.client
                .from('user_profiles')
                .update({'unlocked_stamps': unlockedMap})
                .eq('id', user.id);
          } catch (e) {
            debugPrint("Supabase stamp sync err: $e");
          }
        }

        return stamp.copyWith(
          isUnlocked: true,
          unlockedAt: now,
          distanceMeters: distance,
        );
      }
    }

    return null;
  }
}