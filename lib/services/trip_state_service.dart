import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class TripStateService {
  static const String _userKey = "omni_user_profile";
  static const String _tripKey = "omni_active_trip";
  static const String _vaultPlacesKey = "omni_vault_bookmarked_places";
  static const String _currencyKey = "omni_selected_currency";

  // ==========================================
  // CURRENCY PREFERENCE
  // ==========================================
  static Future<String> getSelectedCurrency() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_currencyKey) ?? "INR";
    } catch (_) {
      return "INR";
    }
  }

  static Future<void> setSelectedCurrency(String currencyCode) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_currencyKey, currencyCode);
    } catch (_) {}
  }

  // ==========================================
  // USER PROFILE
  // ==========================================
  static Future<Map<String, dynamic>> getUserProfile() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_userKey);
      if (raw != null && raw.isNotEmpty) {
        return jsonDecode(raw);
      }
    } catch (_) {}
    return {
      "name": "Leslie",
      "home_city": "Mumbai",
      "emergency_contact": "+91 98200 12345",
    };
  }

  static Future<void> saveUserProfile(Map<String, dynamic> user) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_userKey, jsonEncode(user));
    } catch (_) {}
  }

  // ==========================================
  // ACTIVE TRIP & ITINERARY
  // ==========================================
  static Future<Map<String, dynamic>> getActiveTrip({
    String? fallbackCity,
    String? fallbackState,
    String? fallbackCountry,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_tripKey);
      if (raw != null && raw.isNotEmpty) {
        return _purgeExpiredItinerary(jsonDecode(raw));
      }
    } catch (_) {}

    final city = fallbackCity ?? "Tokyo";
    final state = fallbackState ?? "Kanto";
    final country = fallbackCountry ?? "Japan";

    return _buildDefaultTripForCity(city, state, country);
  }

  static Future<void> saveActiveTrip(Map<String, dynamic> trip) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_tripKey, jsonEncode(trip));
    } catch (_) {}
  }

  /// Dynamically updates the active dashboard destination and regional transit when GPS or Explorer changes
  static Future<void> syncActiveCityAndTransit({
    required String city,
    required String state,
    required String country,
  }) async {
    try {
      final currentTrip = await getActiveTrip(
        fallbackCity: city,
        fallbackState: state,
        fallbackCountry: country,
      );

      final currentDest = currentTrip["destination"] as Map<String, dynamic>?;
      final currentCity = (currentDest?["city"] ?? "").toString().toLowerCase();

      if (currentCity == city.toLowerCase()) return;

      currentTrip["destination"] = {
        "city": city,
        "state": state,
        "country": country,
        "weather": {"temp": "28°C", "condition": "Pleasant"},
      };

      currentTrip["transit"] = _resolveRegionalTransit(city, country);
      currentTrip["stay"] = {
        "hotel_name": "Verified Stay in $city",
        "check_in": "2:00 PM",
      };

      await saveActiveTrip(currentTrip);
    } catch (_) {}
  }

  static Map<String, dynamic> _resolveRegionalTransit(String city, String country) {
    final lower = "$city $country".toLowerCase();

    if (lower.contains("jaipur")) {
      return {
        "mode": "TRAIN",
        "title": "Ajmer Vande Bharat Express",
        "carrier_no": "20978",
        "departure_time": "06:10 AM",
        "seat_info": "Coach C2, 18 (CNF)",
        "live_status": "Scheduled • Platform 1 (JP)",
      };
    } else if (lower.contains("delhi")) {
      return {
        "mode": "TRAIN",
        "title": "Vande Bharat Express",
        "carrier_no": "22436",
        "departure_time": "06:00 AM",
        "seat_info": "Coach C4, 32 (CNF)",
        "live_status": "On-Time • Platform 16 (NDLS)",
      };
    } else if (lower.contains("mumbai") || lower.contains("vasai") || lower.contains("virar")) {
      return {
        "mode": "TRAIN",
        "title": "Mumbai Tejas Rajdhani Express",
        "carrier_no": "12952",
        "departure_time": "05:00 PM",
        "seat_info": "Coach B3, 24 (CNF)",
        "live_status": "Scheduled • Platform 3 (BCT)",
      };
    } else if (lower.contains("japan") || lower.contains("tokyo")) {
      return {
        "mode": "BULLET_TRAIN",
        "title": "Tokaido Shinkansen (Nozomi)",
        "carrier_no": "SHIN-71",
        "departure_time": "08:30 AM",
        "seat_info": "Car 5, Seat 12A",
        "live_status": "On-Time • Track 14",
      };
    } else if (lower.contains("europe") || lower.contains("france") || lower.contains("london")) {
      return {
        "mode": "HIGH_SPEED_RAIL",
        "title": "Eurostar Express",
        "carrier_no": "ESTAR-9014",
        "departure_time": "10:24 AM",
        "seat_info": "Coach 7, Seat 44",
        "live_status": "Boarding • Gate 5",
      };
    }

    return {
      "mode": "TRANSIT",
      "title": "City Express Intercity",
      "carrier_no": "EXP-101",
      "departure_time": "09:00 AM",
      "seat_info": "Confirmed Ticket",
      "live_status": "Scheduled",
    };
  }

  static Map<String, dynamic> _buildDefaultTripForCity(String city, String state, String country) {
    return {
      "origin": {"city": "Mumbai", "country": "India"},
      "destination": {
        "city": city,
        "state": state,
        "country": country,
        "weather": {"temp": "28°C", "condition": "Pleasant"},
      },
      "transit": _resolveRegionalTransit(city, country),
      "stay": {
        "hotel_name": "Boutique Heritage Residency $city",
        "check_in": "2:00 PM",
      },
      "today_itinerary": <Map<String, dynamic>>[],
    };
  }

  static Future<void> addItineraryItem(
    String spotTitle,
    String category,
    String timeSlot, {
    DateTime? scheduledDateTime,
  }) async {
    final trip = await getActiveTrip();
    final List<dynamic> list = trip["today_itinerary"] ?? [];

    list.add({
      "id": "ITIN-${DateTime.now().millisecondsSinceEpoch}",
      "spot_title": spotTitle,
      "category": category,
      "time_slot": timeSlot,
      "is_completed": false,
      "scheduled_iso": scheduledDateTime?.toIso8601String(),
    });

    trip["today_itinerary"] = list;
    await saveActiveTrip(trip);
  }

  static Future<void> toggleItineraryItem(String itemId) async {
    final trip = await getActiveTrip();
    final List<dynamic> list = trip["today_itinerary"] ?? [];

    for (var item in list) {
      if (item["id"] == itemId) {
        item["is_completed"] = !(item["is_completed"] ?? false);
        break;
      }
    }

    trip["today_itinerary"] = list;
    await saveActiveTrip(trip);
  }

  static Map<String, dynamic> _purgeExpiredItinerary(Map<String, dynamic> trip) {
    final now = DateTime.now();
    final List<dynamic> list = trip["today_itinerary"] ?? [];

    final activeItems = list.where((item) {
      final iso = item["scheduled_iso"] as String?;
      if (iso == null || iso.isEmpty) return true;
      try {
        final scheduledTime = DateTime.parse(iso);
        return scheduledTime.isAfter(now);
      } catch (_) {
        return true;
      }
    }).toList();

    trip["today_itinerary"] = activeItems;
    return trip;
  }

  // ==========================================
  // VAULT BOOKMARKS SYNCHRONIZATION
  // ==========================================
  static Future<List<Map<String, dynamic>>> getVaultBookmarks() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_vaultPlacesKey);
      if (raw != null && raw.isNotEmpty) {
        final List<dynamic> decoded = jsonDecode(raw);
        return decoded.map((e) => Map<String, dynamic>.from(e)).toList();
      }
    } catch (_) {}
    return [];
  }

  static Future<void> saveVaultBookmark(Map<String, dynamic> place) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final current = await getVaultBookmarks();
      current.removeWhere((e) => e["name"] == place["name"]);
      current.insert(0, place);
      await prefs.setString(_vaultPlacesKey, jsonEncode(current));
    } catch (_) {}
  }

  static Future<void> deleteVaultBookmark(String id) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final current = await getVaultBookmarks();
      current.removeWhere((e) => e["id"] == id);
      await prefs.setString(_vaultPlacesKey, jsonEncode(current));
    } catch (_) {}
  }
}