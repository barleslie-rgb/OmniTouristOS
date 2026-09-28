import 'dart:async';
import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/trip_state_service.dart';
import '../services/passport_service.dart';
import '../services/expense_service.dart';
import '../widgets/metallic_embossed_button.dart';

class MyTripScreen extends StatefulWidget {
  final String language;
  final String backendUrl;
  final Function(int targetIndex)? onNavigateTab;
  final Function(String city, String state, String country)? onCityChange;
  final VoidCallback? onOpenDrawer;
  final Function(String lang)? onLanguageChanged;

  const MyTripScreen({
    Key? key,
    required this.language,
    this.backendUrl = "https://omni-backend-pk28.onrender.com",
    this.onNavigateTab,
    this.onCityChange,
    this.onOpenDrawer,
    this.onLanguageChanged,
  }) : super(key: key);

  @override
  State<MyTripScreen> createState() => _MyTripScreenState();
}

class _MyTripScreenState extends State<MyTripScreen> {
  Map<String, dynamic> _user = {};
  Map<String, dynamic> _trip = {};
  List<TripExpense> _recentExpenses = [];
  double _todaySpendSum = 0.0;

  bool _isLoading = true;
  Timer? _clockTimer;
  DateTime _currentClock = DateTime.now();

  String _travelMode = "Home";
  String _liveTemperature = "29°C";
  bool _isNight = false;
  bool _isFetchingWeather = false;
  bool _isGuest = false;

  Position? _lastKnownPosition;
  bool _isExploration = false;
  String _currentLiveCity = "Vasai-Virar";

  final List<Map<String, String>> _availableLanguages = [
    {"code": "EN", "name": "English", "native": "English", "flag": "🇬🇧"},
    {"code": "HI", "name": "Hindi", "native": "हिन्दी", "flag": "🇮🇳"},
    {"code": "MR", "name": "Marathi", "native": "मराठी", "flag": "🇮🇳"},
    {"code": "GU", "name": "Gujarati", "native": "ગુજરાતી", "flag": "🇮🇳"},
    {"code": "BN", "name": "Bengali", "native": "বাংলা", "flag": "🇮🇳"},
    {"code": "TA", "name": "Tamil", "native": "தமிழ்", "flag": "🇮🇳"},
    {"code": "TE", "name": "Telugu", "native": "తెలుగు", "flag": "🇮🇳"},
    {"code": "KN", "name": "Kannada", "native": "ಕನ್ನಡ", "flag": "🇮🇳"},
    {"code": "ML", "name": "Malayalam", "native": "മലയാളം", "flag": "🇮🇳"},
    {"code": "PA", "name": "Punjabi", "native": "ਪੰਜਾਬੀ", "flag": "🇮🇳"},
    {"code": "OR", "name": "Odia", "native": "ଓଡ଼ିଆ", "flag": "🇮🇳"},
    {"code": "AR", "name": "Arabic", "native": "العربية", "flag": "🇦🇪"},
    {"code": "FA", "name": "Persian", "native": "فارسی", "flag": "🇮🇷"},
    {"code": "UR", "name": "Urdu", "native": "اردو", "flag": "🇵🇰"},
    {"code": "FR", "name": "French", "native": "Français", "flag": "🇫🇷"},
    {"code": "DE", "name": "German", "native": "Deutsch", "flag": "🇩🇪"},
    {"code": "ES", "name": "Spanish", "native": "Español", "flag": "🇪🇸"},
    {"code": "IT", "name": "Italian", "native": "Italiano", "flag": "🇮🇹"},
    {"code": "RU", "name": "Russian", "native": "Русский", "flag": "🇷🇺"},
    {"code": "JA", "name": "Japanese", "native": "日本語", "flag": "🇯🇵"},
    {"code": "ZH", "name": "Chinese", "native": "简体中文", "flag": "🇨🇳"},
  ];

  static const Map<String, Map<String, String>> _dict = {
    "English": {
      "greeting_morning": "Good Morning, {name}!",
      "greeting_afternoon": "Good Afternoon, {name}!",
      "greeting_evening": "Good Evening, {name}!",
      "ready_to_explore": "Ready to explore today?",
      "guest_default": "Leslie",
      "action_translate": "Translate\n& Lens",
      "action_spends": "Log Daily\nSpend",
      "action_ar": "AR\nRadar",
      "action_passport": "Passport\nStamps",
      "no_activities": "No upcoming activities",
      "scheduled_plans": "scheduled plans today",
      "add_plans_sub": "Add your plans, tickets or reminders.",
      "add_activity_btn": "+ Activity",
      "emergency_header": "Emergency Lifelines",
      "emergency_sub": "Direct facility responders & helpline directory",
      "hospital": "Hospital / Casualty",
      "police": "Police Station",
      "fire_station": "Fire & Rescue",
      "chemist": "24h Chemist",
      "explore_tools": "Explore & Tools",
      "tool_destination": "Destinations\n& Sights",
      "tool_railway": "Railway\nTransit",
      "tool_chat": "Guide\nChat",
      "tool_vault": "Family\nVault",
      "tool_gems": "Community\nGems",
      "tool_scanner": "Paper Pilot\nScanner",
      "tool_converter": "Converter\nStudio",
      "tool_more": "More\nFeatures",
    },
    "Marathi": {
      "greeting_morning": "शुभ सकाळ, {name}!",
      "greeting_afternoon": "शुभ दुपार, {name}!",
      "greeting_evening": "शुभ संध्याकाळ, {name}!",
      "ready_to_explore": "आज फिरण्याची तयारी झाली का?",
      "guest_default": "लेस्ली",
      "action_translate": "भाषांतर\nव लेन्स",
      "action_spends": "खर्च\nनोंदवा",
      "action_ar": "दिशादर्शक\nकम्पास",
      "action_passport": "पर्यटन\nशिक्के",
      "no_activities": "कोणतीही आगामी योजना नाही",
      "scheduled_plans": "नियोजित योजना आज",
      "add_plans_sub": "तुमच्या सहलीच्या योजना व स्मरणपत्रे जोडा.",
      "add_activity_btn": "+ कृती जोडा",
      "emergency_header": "तातडीच्या आपत्कालीन सेवा",
      "emergency_sub": "स्थानिक मदत केंद्र व थेट दूरध्वनी",
      "hospital": "रुग्णालय / आपत्कालीन",
      "police": "पोलीस ठाणे",
      "fire_station": "अग्निशामक केंद्र",
      "chemist": "२४ तास मेडिकल",
      "explore_tools": "अन्वेषण आणि साधने",
      "tool_destination": "पर्यटन स्थळे\nमार्गदर्शक",
      "tool_railway": "रेल्वे\nमाहिती",
      "tool_chat": "पर्यटन\nसंवाद",
      "tool_vault": "कौटुंबिक\nतिजोरी",
      "tool_gems": "स्थानिक\nरत्ने",
      "tool_scanner": "पेपर पायलट\nस्कॅनर",
      "tool_converter": "कन्व्हर्टर\nस्टुडिओ",
      "tool_more": "इतर\nसुविधा",
    },
    "Hindi": {
      "greeting_morning": "सुप्रभात, {name}!",
      "greeting_afternoon": "शुभ दोपहर, {name}!",
      "greeting_evening": "शुभ संध्या, {name}!",
      "ready_to_explore": "क्या आप आज घूमने के लिए तैयार हैं?",
      "guest_default": "लेस्ली",
      "action_translate": "अनुवाद\nव लेंस",
      "action_spends": "खर्च\nदर्ज करें",
      "action_ar": "दिशा\nरडार",
      "action_passport": "पासपोर्ट\nमुहर",
      "no_activities": "कोई आगामी योजना नहीं",
      "scheduled_plans": "निर्धारित योजनाएं आज",
      "add_plans_sub": "अपनी योजनाएं, टिकट या रिमाइंडर जोड़ें।",
      "add_activity_btn": "+ गतिविधि",
      "emergency_header": "आपातकालीन हेल्पलाइन",
      "emergency_sub": "स्थानीय सहायता केंद्र व आपातकालीन नंबर",
      "hospital": "अस्पताल / इमरजेंसी",
      "police": "पुलिस स्टेशन",
      "fire_station": "दमकल केंद्र",
      "chemist": "24 घंटे मेडिकल",
      "explore_tools": "एक्सप्लोर और टूल्स",
      "tool_destination": "गंतव्य\nखोजें",
      "tool_railway": "रेलवे\nट्रांजिट",
      "tool_chat": "गाइड\nचैट",
      "tool_vault": "फैमिली\nवॉल्ट",
      "tool_gems": "लोकल\nस्थान",
      "tool_scanner": "पेपर पायलट\nस्कॅनर",
      "tool_converter": "कन्वर्टर\nस्टूडियो",
      "tool_more": "अन्य\nसुविधाएं",
    }
  };

  String _t(String key) {
    final lang = widget.language.trim();
    if (_dict.containsKey(lang) && _dict[lang]!.containsKey(key)) {
      return _dict[lang]![key]!;
    }
    return _dict["English"]![key] ?? key;
  }

  static const List<String> _weekdays = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"];
  static const List<String> _months = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"];

  String _formatNativeDate(DateTime dt) {
    return "${_weekdays[dt.weekday - 1]}, ${dt.day} ${_months[dt.month - 1]}";
  }

  String _formatNativeTime(int hour, int minute) {
    final period = hour >= 12 ? "PM" : "AM";
    final h = hour % 12 == 0 ? 12 : hour % 12;
    final m = minute.toString().padLeft(2, '0');
    return "${h.toString().padLeft(2, '0')}:$m $period";
  }

  final Map<String, Map<String, dynamic>> _hubCatalog = {
    "vasai-virar": {
      "city": "Vasai-Virar",
      "state": "Maharashtra",
      "country": "India",
      "image": "assets/images/dashboard_fort.png",
      "fallback_image": "https://images.unsplash.com/photo-1590050752117-238cb0fb12b1?auto=format&fit=crop&w=1200&q=80",
      "lat": 19.38,
      "lon": 72.83,
    },
    "virar": {
      "city": "Virar",
      "state": "Maharashtra",
      "country": "India",
      "image": "https://images.unsplash.com/photo-1561361066-613d52d91986?auto=format&fit=crop&w=1200&q=80",
      "fallback_image": "https://images.unsplash.com/photo-1590050752117-238cb0fb12b1?auto=format&fit=crop&w=1200&q=80",
      "lat": 19.4678,
      "lon": 72.8056,
    },
    "mumbai": {
      "city": "Mumbai",
      "state": "Maharashtra",
      "country": "India",
      "image": "https://images.unsplash.com/photo-1570168007204-dfb528c6958f?auto=format&fit=crop&w=1200&q=80",
      "fallback_image": "https://images.unsplash.com/photo-1570168007204-dfb528c6958f?auto=format&fit=crop&w=1200&q=80",
      "lat": 18.9220,
      "lon": 72.8347,
    },
    "tokyo": {
      "city": "Tokyo",
      "state": "Kanto",
      "country": "Japan",
      "image": "https://images.unsplash.com/photo-1503899036084-c55cdd92da26?auto=format&fit=crop&w=1200&q=80",
      "fallback_image": "https://images.unsplash.com/photo-1503899036084-c55cdd92da26?auto=format&fit=crop&w=1200&q=80",
      "lat": 35.6762,
      "lon": 139.6503,
    },
    "dubai": {
      "city": "Dubai",
      "state": "Dubai",
      "country": "United Arab Emirates",
      "image": "https://images.unsplash.com/photo-1512453979798-5ea266f8880c?auto=format&fit=crop&w=1200&q=80",
      "fallback_image": "https://images.unsplash.com/photo-1512453979798-5ea266f8880c?auto=format&fit=crop&w=1200&q=80",
      "lat": 25.2048,
      "lon": 55.2708,
    },
    "singapore": {
      "city": "Singapore",
      "state": "Central",
      "country": "Singapore",
      "image": "https://images.unsplash.com/photo-1525625293386-3f8f99389edd?auto=format&fit=crop&w=1200&q=80",
      "fallback_image": "https://images.unsplash.com/photo-1525625293386-3f8f99389edd?auto=format&fit=crop&w=1200&q=80",
      "lat": 1.3521,
      "lon": 103.8198,
    },
    "paris": {
      "city": "Paris",
      "state": "Île-de-France",
      "country": "France",
      "image": "https://images.unsplash.com/photo-1502602898657-3e91760cbb34?auto=format&fit=crop&w=1200&q=80",
      "fallback_image": "https://images.unsplash.com/photo-1502602898657-3e91760cbb34?auto=format&fit=crop&w=1200&q=80",
      "lat": 48.8566,
      "lon": 2.3522,
    },
  };

  Map<String, dynamic> _resolveDestinationDetails(String rawInput) {
    final clean = rawInput.trim().toLowerCase();
    for (final entry in _hubCatalog.entries) {
      if (clean == entry.key || clean.contains(entry.key) || entry.key.contains(clean)) {
        return entry.value;
      }
    }
    final titleFormatted = rawInput.trim().isEmpty ? "Vasai-Virar" : rawInput.trim();
    return {
      "city": titleFormatted,
      "state": "Regional Hub",
      "country": "Active Location",
      "image": "https://images.unsplash.com/photo-1488646953014-85cb44e25828?auto=format&fit=crop&w=1200&q=80",
      "fallback_image": "https://images.unsplash.com/photo-1488646953014-85cb44e25828?auto=format&fit=crop&w=1200&q=80",
      "lat": 19.38,
      "lon": 72.83,
    };
  }

  Map<String, Map<String, String>> _getHyperlocalLifelines(String city, String country) {
    final cleanCity = city.toLowerCase().trim();
    final cleanCountry = country.toLowerCase().trim();

    if (cleanCity == "virar" || (cleanCity.contains("virar") && !cleanCity.contains("vasai"))) {
      return {
        "hospital": {
          "title": _t("hospital"),
          "phone": "0250-2502300",
          "sub": "Sanjeevani Hospital & Critical Care (Virar West)",
        },
        "police": {
          "title": _t("police"),
          "phone": "0250-2522333",
          "sub": "Virar Police Station (Near Station Road)",
        },
        "fire": {
          "title": _t("fire_station"),
          "phone": "0250-2503333",
          "sub": "VVCMC Virar Sub-Fire Station (Bolinj)",
        },
        "pharmacy": {
          "title": _t("chemist"),
          "phone": "0250-2501234",
          "sub": "Royal 24h Medical Store (Virar West Station)",
        },
        "ambulance": {
          "title": "Ambulance (108)",
          "phone": "07350632424",
          "sub": "Virar Emergency ICU Ambulance Fleet",
        },
        "women": {
          "title": "Women Cell",
          "phone": "1091",
          "sub": "MBVV Police Women Safety Cell (Virar Division)",
        },
      };
    } else if (cleanCity.contains("mumbai") && !cleanCity.contains("vasai")) {
      return {
        "hospital": {
          "title": _t("hospital"),
          "phone": "022-26751000",
          "sub": "Lilavati Hospital & Research Centre (Bandra)",
        },
        "police": {
          "title": _t("police"),
          "phone": "022-22620826",
          "sub": "Mumbai Police Control Room / Azad Maidan",
        },
        "fire": {
          "title": _t("fire_station"),
          "phone": "022-23076111",
          "sub": "Mumbai Fire Brigade Byculla HQ Control",
        },
        "pharmacy": {
          "title": _t("chemist"),
          "phone": "022-24128888",
          "sub": "Noble 24 Hrs Emergency Medical Chemist",
        },
        "ambulance": {
          "title": "Ambulance (108)",
          "phone": "108",
          "sub": "Maharashtra Govt 24h Emergency Response",
        },
        "women": {
          "title": "Women Helpline",
          "phone": "103",
          "sub": "Mumbai Police Dedicated Women & Child Cell",
        },
      };
    } else if (cleanCountry.contains("japan") || cleanCity.contains("tokyo")) {
      return {
        "hospital": {
          "title": _t("hospital"),
          "phone": "03-5285-8181",
          "sub": "Himawari English Medical Info / St. Luke's Hospital",
        },
        "police": {
          "title": _t("police"),
          "phone": "03-3501-0110",
          "sub": "Tokyo Metropolitan Police Dept English Desk (110)",
        },
        "fire": {
          "title": _t("fire_station"),
          "phone": "119",
          "sub": "Tokyo Fire Department Rescue Command (119)",
        },
        "pharmacy": {
          "title": _t("chemist"),
          "phone": "03-3342-0109",
          "sub": "HAC 24h Drug Pharmacy (Shinjuku Station)",
        },
        "tourist_hotline": {
          "title": "JNTO Tourist Help",
          "phone": "050-3816-2786",
          "sub": "Japan National Tourism 24h English Assistance",
        },
      };
    } else if (cleanCountry.contains("emirates") || cleanCity.contains("dubai")) {
      return {
        "hospital": {
          "title": _t("hospital"),
          "phone": "04-2195000",
          "sub": "Rashid Hospital Trauma & Emergency Center",
        },
        "police": {
          "title": _t("police"),
          "phone": "04-6099999",
          "sub": "Dubai Police General HQ Emergency Desk (999)",
        },
        "fire": {
          "title": _t("fire_station"),
          "phone": "04-7052000",
          "sub": "Dubai Civil Defence Fire Unit (997)",
        },
        "pharmacy": {
          "title": _t("chemist"),
          "phone": "800-342",
          "sub": "DHA 24/7 Triage & Emergency Chemist Network",
        },
        "tourist_police": {
          "title": "Tourist Security",
          "phone": "901",
          "sub": "Dubai Tourist Police Safety Assistance Line",
        },
      };
    }

    // Default Domestic Standard: Vasai-Virar
    return {
      "hospital": {
        "title": _t("hospital"),
        "phone": "0250-2324200",
        "sub": "Cardinal Gracias Memorial Hospital (Vasai West)",
      },
      "police": {
        "title": _t("police"),
        "phone": "0250-2327011",
        "sub": "Manikpur / Vasai Police Station",
      },
      "fire": {
        "title": _t("fire_station"),
        "phone": "0250-2334258",
        "sub": "VVCMC Fire Control Station (Navghar)",
      },
      "pharmacy": {
        "title": _t("chemist"),
        "phone": "07428094028",
        "sub": "Ozone 24 Hrs Emergency Pharmacy (Vasai)",
      },
      "ambulance": {
        "title": "Ambulance (108)",
        "phone": "07350632424",
        "sub": "24h ICU Ambulance Fleet (Vasai Road)",
      },
      "women": {
        "title": "Women Cell",
        "phone": "1091",
        "sub": "MBVV Police Women Safety Cell (Vasai)",
      },
    };
  }

  @override
  void initState() {
    super.initState();
    _loadState();
    _checkLocationAndStamps();

    _clockTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) {
        setState(() {
          _currentClock = DateTime.now();
          _isNight = _currentClock.hour >= 19 || _currentClock.hour < 6;
        });
        if (_currentClock.second == 0 && _currentClock.minute % 15 == 0) {
          _fetchLiveWeather();
          _checkLocationAndStamps();
        }
      }
    });
  }

  @override
  void dispose() {
    _clockTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final supaUser = Supabase.instance.client.auth.currentUser;
      final isGuest = supaUser != null ? false : (prefs.getBool('omni_is_guest_mode') ?? false);
      final isExploration = await TripStateService.isExplorationMode();
      final cachedLive = await TripStateService.getCachedLiveLocation();

      Map<String, dynamic> user = {};
      Map<String, dynamic> trip = {};
      List<TripExpense> expenses = [];

      try {
        user = await TripStateService.getUserProfile().timeout(const Duration(milliseconds: 1500));
      } catch (_) {
        user = {"name": "Leslie", "email": "barleslie@gmail.com"};
      }

      try {
        trip = await TripStateService.getActiveTrip().timeout(const Duration(milliseconds: 1500));
      } catch (_) {
        trip = {
          "destination": {"city": "Vasai-Virar", "state": "Maharashtra", "country": "India"},
          "today_itinerary": []
        };
      }

      final destData = trip["destination"] as Map<String, dynamic>? ?? {};
      final String rawCity = (destData["city"] ?? "Vasai-Virar").toString();
      final resolved = _resolveDestinationDetails(rawCity);

      trip["destination"] = {
        "city": resolved["city"],
        "state": resolved["state"],
        "country": resolved["country"],
      };

      try {
        expenses = await ExpenseService.loadExpenses().timeout(const Duration(milliseconds: 1500));
      } catch (_) {
        expenses = [];
      }

      final now = DateTime.now();
      final double todaySum = expenses
          .where((e) => e.createdAt.year == now.year && e.createdAt.month == now.month && e.createdAt.day == now.day)
          .fold(0.0, (acc, cur) => acc + cur.amountLocal);

      if (mounted) {
        setState(() {
          _user = user;
          _trip = trip;
          _isGuest = isGuest;
          _isExploration = isExploration;
          _currentLiveCity = cachedLive["city"] ?? "Vasai-Virar";
          _recentExpenses = expenses.take(3).toList();
          _todaySpendSum = todaySum;
          _isNight = _currentClock.hour >= 19 || _currentClock.hour < 6;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _user = {"name": "Leslie", "email": "barleslie@gmail.com"};
          _trip = {
            "destination": {"city": "Vasai-Virar", "state": "Maharashtra", "country": "India"},
            "today_itinerary": []
          };
          _recentExpenses = [];
          _todaySpendSum = 0.0;
        });
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
        _fetchLiveWeather();
      }
    }
  }

  Future<void> _checkLocationAndStamps() async {
    try {
      final hasPermission = await Geolocator.checkPermission();
      if (hasPermission == LocationPermission.denied ||
          hasPermission == LocationPermission.deniedForever) {
        return;
      }

      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.medium,
        timeLimit: const Duration(seconds: 4),
      );

      if (!mounted) return;
      setState(() => _lastKnownPosition = pos);

      final resolvedGps = await TripStateService.resolveGpsLocation(
        latitude: pos.latitude,
        longitude: pos.longitude,
      );

      if (resolvedGps != null && mounted) {
        setState(() => _currentLiveCity = resolvedGps["city"]!);

        if (!_isExploration) {
          final liveCity = resolvedGps["city"]!;
          final liveState = resolvedGps["state"]!;
          final liveCountry = resolvedGps["country"]!;

          if (widget.onCityChange != null) {
            widget.onCityChange!(liveCity, liveState, liveCountry);
          }

          setState(() {
            _trip["destination"] = {
              "city": liveCity,
              "state": liveState,
              "country": liveCountry,
            };
          });

          await TripStateService.syncActiveCityAndTransit(
            city: liveCity,
            state: liveState,
            country: liveCountry,
          );
          _fetchLiveWeather();
        }
      }

      final unlocked = await PassportService.evaluateProximity(pos);
      if (unlocked != null && mounted) {
        _showCelebrationModal(unlocked);
      }
    } catch (_) {}
  }

  Future<void> _returnToLiveGps() async {
    HapticFeedback.selectionClick();
    await TripStateService.setExplorationMode(false);
    setState(() => _isExploration = false);

    if (_lastKnownPosition != null) {
      final resolved = await TripStateService.resolveGpsLocation(
        latitude: _lastKnownPosition!.latitude,
        longitude: _lastKnownPosition!.longitude,
        force: true,
      );
      if (resolved != null && mounted) {
        final c = resolved["city"]!;
        final s = resolved["state"]!;
        final co = resolved["country"]!;

        if (widget.onCityChange != null) widget.onCityChange!(c, s, co);
        setState(() {
          _trip["destination"] = {"city": c, "state": s, "country": co};
          _currentLiveCity = c;
        });
        await TripStateService.syncActiveCityAndTransit(city: c, state: s, country: co);
        _fetchLiveWeather();
      }
    } else {
      _checkLocationAndStamps();
    }
  }

  void _showCelebrationModal(PassportStamp stamp) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        backgroundColor: Colors.white,
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Color(stamp.colorHex).withOpacity(0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.stars_rounded, size: 54, color: Color(stamp.colorHex)),
            ),
            const SizedBox(height: 14),
            const Text(
              "🎉 Passport Stamp Unlocked!",
              textAlign: TextAlign.center,
              style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: Color(0xFF0F172A)),
            ),
            const SizedBox(height: 6),
            Text(
              "You arrived at ${stamp.name} in ${stamp.city}.",
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 13, color: Color(0xFF475569)),
            ),
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              height: 44,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Color(stamp.colorHex),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () {
                  Navigator.pop(ctx);
                  _openPassportModal(context);
                },
                child: const Text("View in Stamp Book", style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getResolvedDisplayName() {
    try {
      final supaUser = Supabase.instance.client.auth.currentUser;
      if (supaUser != null) {
        final meta = supaUser.userMetadata;
        if (meta != null) {
          final String? fullName = meta['full_name']?.toString() ?? meta['name']?.toString();
          if (fullName != null && fullName.trim().isNotEmpty) {
            return fullName.trim().split(' ').first;
          }
        }
        if (supaUser.email != null && supaUser.email!.contains('@')) {
          final emailPrefix = supaUser.email!.split('@').first;
          if (emailPrefix.isNotEmpty) {
            return emailPrefix[0].toUpperCase() + emailPrefix.substring(1);
          }
        }
      }
    } catch (_) {}

    if (_isGuest) return _t("guest_default");

    if (_user["name"] != null && _user["name"].toString().trim().isNotEmpty) {
      return _user["name"].toString().trim().split(' ').first;
    }
    return "Leslie";
  }

  String _getGreeting() {
    final hour = _currentClock.hour;
    final name = _getResolvedDisplayName();
    String rawTemplate = hour < 12 ? _t("greeting_morning") : (hour < 17 ? _t("greeting_afternoon") : _t("greeting_evening"));
    return rawTemplate.replaceAll("{name}", name);
  }

  Future<void> _fetchLiveWeather() async {
    if (_isFetchingWeather) return;
    _isFetchingWeather = true;

    try {
      final dest = _trip["destination"] ?? {};
      final String currentCityRaw = (dest["city"] ?? "Vasai-Virar").toString();
      final resolved = _resolveDestinationDetails(currentCityRaw);

      final double lat = (resolved["lat"] as num?)?.toDouble() ?? 19.38;
      final double lon = (resolved["lon"] as num?)?.toDouble() ?? 72.83;

      final url = Uri.parse("https://api.open-meteo.com/v1/forecast?latitude=$lat&longitude=$lon&current=temperature_2m");
      final res = await http.get(url).timeout(const Duration(seconds: 4));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (data["current"] != null && data["current"]["temperature_2m"] != null) {
          final tempVal = (data["current"]["temperature_2m"] as num).round();
          if (mounted) setState(() => _liveTemperature = "$tempVal°C");
        }
      }
    } catch (_) {
      if (_liveTemperature == "--°C") setState(() => _liveTemperature = "29°C");
    } finally {
      if (mounted) setState(() => _isFetchingWeather = false);
    }
  }

  void _showCityPickerDialog() {
    final dest = _trip["destination"] ?? {};
    final String currentCity = (dest["city"] ?? "Vasai-Virar").toString();
    final ctrl = TextEditingController(text: currentCity);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text("Switch Active Destination", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            InkWell(
              onTap: () {
                Navigator.pop(ctx);
                _returnToLiveGps();
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFBFDBFE)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.my_location_rounded, color: Color(0xFF2563EB), size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        "📍 Use My Current Location ($_currentLiveCity)",
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5, color: Color(0xFF1E40AF)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              "Or explore another city manually:",
              style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: ctrl,
              decoration: InputDecoration(
                labelText: "City Name",
                hintText: "e.g., Vasai-Virar, Virar, Mumbai, Tokyo, Dubai",
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                prefixIcon: const Icon(Icons.location_city_rounded, color: Color(0xFF2563EB)),
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: ["Vasai-Virar", "Virar", "Mumbai", "Tokyo", "Dubai", "Singapore", "Paris"].map((c) {
                return ActionChip(
                  label: Text(c, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                  onPressed: () => ctrl.text = c,
                );
              }).toList(),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("CANCEL")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2563EB), foregroundColor: Colors.white),
            onPressed: () async {
              final newCity = ctrl.text.trim();
              if (newCity.isNotEmpty) {
                final resolved = _resolveDestinationDetails(newCity);
                final updatedCity = resolved["city"] as String;
                final updatedState = resolved["state"] as String;
                final updatedCountry = resolved["country"] as String;

                await TripStateService.setExplorationMode(true);
                setState(() => _isExploration = true);

                if (widget.onCityChange != null) {
                  widget.onCityChange!(updatedCity, updatedState, updatedCountry);
                }
                setState(() {
                  _trip["destination"] = {
                    "city": updatedCity,
                    "state": updatedState,
                    "country": updatedCountry,
                  };
                });
                await TripStateService.syncActiveCityAndTransit(
                  city: updatedCity,
                  state: updatedState,
                  country: updatedCountry,
                );
                Navigator.pop(ctx);
                _fetchLiveWeather();
              }
            },
            child: const Text("EXPLORE"),
          ),
        ],
      ),
    );
  }

  void _showLanguagePickerModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => SizedBox(
        height: MediaQuery.of(context).size.height * 0.72,
        child: Column(
          children: [
            Container(
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFFCBD5E1),
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Row(
                children: [
                  const Icon(Icons.language_rounded, color: Color(0xFF2563EB), size: 22),
                  const SizedBox(width: 8),
                  const Text(
                    "Select App Language",
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEFF6FF),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      "${_availableLanguages.length} Languages",
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF2563EB)),
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                itemCount: _availableLanguages.length,
                separatorBuilder: (_, __) => const Divider(height: 1, color: Color(0xFFF1F5F9)),
                itemBuilder: (context, index) {
                  final lang = _availableLanguages[index];
                  final isSelected = widget.language == lang["name"];
                  return ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    leading: Text(lang["flag"]!, style: const TextStyle(fontSize: 24)),
                    title: Text(
                      "${lang['native']} (${lang['name']})",
                      style: TextStyle(
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                        color: isSelected ? const Color(0xFF2563EB) : const Color(0xFF1E293B),
                      ),
                    ),
                    trailing: isSelected
                        ? const Icon(Icons.check_circle_rounded, color: Color(0xFF2563EB), size: 20)
                        : null,
                    onTap: () {
                      Navigator.pop(ctx);
                      if (widget.onLanguageChanged != null) {
                        widget.onLanguageChanged!(lang["name"]!);
                      }
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _callNumber(String phone) async {
    final clean = phone.replaceAll(RegExp(r'[^0-9+]'), '');
    final uri = Uri.parse("tel:$clean");
    try {
      if (await canLaunchUrl(uri)) await launchUrl(uri);
    } catch (_) {}
  }

  void _showAllLifelinesModal(BuildContext context, String cityName, Map<String, Map<String, String>> lifelines) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        height: MediaQuery.of(context).size.height * 0.78,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            Container(
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              width: 40,
              height: 5,
              decoration: BoxDecoration(color: const Color(0xFFCBD5E1), borderRadius: BorderRadius.circular(10)),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(color: const Color(0xFFDC2626).withOpacity(0.12), shape: BoxShape.circle),
                    child: const Icon(Icons.shield_rounded, color: Color(0xFFDC2626), size: 22),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text("$cityName ${_t("emergency_header")}", style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: Color(0xFF0F172A))),
                        Text(_t("emergency_sub"), style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: Color(0xFFF1F5F9)),
            Expanded(
              child: ListView(
                padding: EdgeInsets.fromLTRB(20, 16, 20, 24 + MediaQuery.of(context).padding.bottom),
                children: lifelines.entries.map((entry) {
                  final key = entry.key;
                  final data = entry.value;
                  IconData icon = Icons.shield_rounded;
                  Color color = const Color(0xFFDC2626);

                  if (key == "hospital" || key == "ambulance") {
                    icon = Icons.local_hospital_rounded;
                    color = const Color(0xFFE11D48);
                  } else if (key == "police") {
                    icon = Icons.local_police_rounded;
                    color = const Color(0xFF0284C7);
                  } else if (key == "fire") {
                    icon = Icons.fire_truck_rounded;
                    color = const Color(0xFFEA580C);
                  } else if (key == "pharmacy") {
                    icon = Icons.medication_rounded;
                    color = const Color(0xFF059669);
                  } else if (key == "women") {
                    icon = Icons.security_rounded;
                    color = const Color(0xFF9333EA);
                  }

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _buildModalRow(icon, color, data["title"] ?? key, data),
                  );
                }).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildModalRow(IconData icon, Color color, String label, Map<String, String> data) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(color: color.withOpacity(0.12), shape: BoxShape.circle),
          child: Icon(icon, size: 20, color: color),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: color)),
              Text(data["sub"] ?? data["title"]!, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: Color(0xFF1E293B)), maxLines: 1, overflow: TextOverflow.ellipsis),
            ],
          ),
        ),
        const SizedBox(width: 8),
        ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: color,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
          onPressed: () => _callNumber(data["phone"]!),
          icon: const Icon(Icons.call_rounded, size: 14),
          label: Text(data["phone"]!, style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }

  Widget _buildHeroBackdrop(String assetPath, String fallbackUrl) {
    if (assetPath.startsWith("assets/")) {
      return Image.asset(
        assetPath,
        fit: BoxFit.cover,
        alignment: Alignment.center,
        errorBuilder: (_, __, ___) => Image.network(fallbackUrl, fit: BoxFit.cover, alignment: Alignment.center),
      );
    }
    return Image.network(
      assetPath,
      fit: BoxFit.cover,
      alignment: Alignment.center,
      errorBuilder: (_, __, ___) => Image.network(fallbackUrl, fit: BoxFit.cover, alignment: Alignment.center),
    );
  }

  Widget _buildGlassPill({required Widget child, EdgeInsetsGeometry? padding}) {
    return Container(
      padding: padding ?? const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.32),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.22), width: 1),
      ),
      child: child,
    );
  }

  // FIXED & FULLY IMPLEMENTED: Opens AR Radar / Guide Chat Camera View
  void _openArRadar() {
    HapticFeedback.mediumImpact();
    if (widget.onNavigateTab != null) {
      widget.onNavigateTab!(3); // Routes to Guide Chat / AR Companion
    }
  }

  // FIXED & FULLY IMPLEMENTED: Interactive Activity Planner Modal
  void _showAddActivityModal(BuildContext context) {
    HapticFeedback.selectionClick();
    final titleCtrl = TextEditingController();
    final timeCtrl = TextEditingController(text: "10:00 AM");

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) {
          final bottomPadding = MediaQuery.of(ctx).viewInsets.bottom;
          return Padding(
            padding: EdgeInsets.fromLTRB(20, 14, 20, bottomPadding + 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(color: const Color(0xFFCBD5E1), borderRadius: BorderRadius.circular(4)),
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      "Add Scheduled Activity",
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: Color(0xFF0F172A)),
                    ),
                    IconButton(icon: const Icon(Icons.close_rounded, size: 20), onPressed: () => Navigator.pop(ctx)),
                  ],
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: titleCtrl,
                  autofocus: true,
                  decoration: InputDecoration(
                    labelText: "Activity / Plan Name",
                    hintText: "e.g., Visit Bassein Fort, Train boarding",
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    isDense: true,
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: timeCtrl,
                  decoration: InputDecoration(
                    labelText: "Time",
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    isDense: true,
                  ),
                ),
                const SizedBox(height: 16),
                MetallicEmbossedButton(
                  label: "Save Activity",
                  icon: Icons.event_available_rounded,
                  variant: MetallicVariant.cobaltBlue,
                  isFullWidth: true,
                  height: 46,
                  onPressed: () async {
                    final title = titleCtrl.text.trim();
                    if (title.isNotEmpty) {
                      HapticFeedback.mediumImpact();
                      final itinerary = List<Map<String, dynamic>>.from(_trip["today_itinerary"] ?? []);
                      itinerary.add({
                        "time": timeCtrl.text.trim(),
                        "title": title,
                        "completed": false,
                      });
                      setState(() {
                        _trip["today_itinerary"] = itinerary;
                      });
                      await TripStateService.saveActiveTrip(_trip);
                      Navigator.pop(ctx);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(backgroundColor: Color(0xFF16A34A), content: Text("✓ Activity added successfully!")),
                      );
                    }
                  },
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  // FIXED & FULLY IMPLEMENTED: Passport Stamps Modal with Real Unlock Mapping
  void _openPassportModal(BuildContext context) async {
    List<PassportStamp> stamps = await PassportService.getStamps(currentPosition: _lastKnownPosition);
    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) {
          int unlockedCount = stamps.where((s) => s.isUnlocked).length;
          return SizedBox(
            height: MediaQuery.of(context).size.height * 0.82,
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(color: const Color(0xFFCBD5E1), borderRadius: BorderRadius.circular(4)),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.verified_rounded, color: Color(0xFF2563EB), size: 24),
                          const SizedBox(width: 8),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text("Travel Passport & Stamps", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 17, color: Color(0xFF0F172A))),
                              Text("$unlockedCount of ${stamps.length} Heritage Stamps Collected", style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B))),
                            ],
                          ),
                        ],
                      ),
                      IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx)),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: ListView.builder(
                      itemCount: stamps.length,
                      itemBuilder: (context, index) {
                        final stamp = stamps[index];
                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: stamp.isUnlocked ? Color(stamp.colorHex).withOpacity(0.06) : const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: stamp.isUnlocked ? Color(stamp.colorHex).withOpacity(0.3) : const Color(0xFFE2E8F0),
                              width: 1,
                            ),
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: stamp.isUnlocked ? Color(stamp.colorHex) : Colors.grey.shade400,
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  stamp.isUnlocked ? Icons.star_rounded : Icons.lock_rounded,
                                  color: Colors.white,
                                  size: 22,
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      stamp.name,
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                        color: stamp.isUnlocked ? const Color(0xFF0F172A) : Colors.grey.shade600,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      stamp.city,
                                      style: TextStyle(fontSize: 11.5, color: Colors.grey.shade600),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      "📍 ${stamp.city}",
                                      style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: stamp.isUnlocked ? Color(stamp.colorHex) : Colors.grey),
                                    ),
                                  ],
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: stamp.isUnlocked ? const Color(0xFFDCFCE7) : Colors.grey.shade200,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  stamp.isUnlocked ? "Unlocked" : "Locked",
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: stamp.isUnlocked ? const Color(0xFF16A34A) : Colors.grey.shade700,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  void _showQuickAddSpendModal(BuildContext context) {
    HapticFeedback.selectionClick();
    final titleCtrl = TextEditingController();
    final amountCtrl = TextEditingController();
    String selectedCategory = 'Food & Dining';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) {
          final bottomPadding = MediaQuery.of(ctx).viewInsets.bottom;
          return Padding(
            padding: EdgeInsets.fromLTRB(20, 14, 20, bottomPadding + 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(color: const Color(0xFFCBD5E1), borderRadius: BorderRadius.circular(4)),
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      "Quick Log Spend",
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: Color(0xFF0F172A)),
                    ),
                    IconButton(icon: const Icon(Icons.close_rounded, size: 20), onPressed: () => Navigator.pop(ctx)),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: TextField(
                        controller: amountCtrl,
                        keyboardType: TextInputType.number,
                        autofocus: true,
                        decoration: InputDecoration(
                          labelText: "Amount (₹)",
                          prefixText: "₹ ",
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                          isDense: true,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      flex: 3,
                      child: TextField(
                        controller: titleCtrl,
                        decoration: InputDecoration(
                          labelText: "What was it for?",
                          hintText: "e.g. Chai, Rickshaw",
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                          isDense: true,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                MetallicEmbossedButton(
                  label: "Record Spend",
                  icon: Icons.check_circle_rounded,
                  variant: MetallicVariant.emeraldGreen,
                  isFullWidth: true,
                  height: 46,
                  onPressed: () async {
                    final val = double.tryParse(amountCtrl.text.trim()) ?? 0.0;
                    if (val > 0) {
                      HapticFeedback.mediumImpact();
                      final homeCurr = await ExpenseService.getHomeCurrency();
                      final newExpense = TripExpense(
                        id: DateTime.now().millisecondsSinceEpoch.toString(),
                        title: titleCtrl.text.trim().isEmpty ? selectedCategory : titleCtrl.text.trim(),
                        category: selectedCategory,
                        amountLocal: val,
                        currencyLocal: 'INR',
                        amountHome: ExpenseService.convertFromInr(val, homeCurr),
                        currencyHome: homeCurr,
                        paymentMethod: 'Cash',
                        splitCount: 1,
                        createdAt: DateTime.now(),
                      );
                      await ExpenseService.addExpense(newExpense);
                      Navigator.pop(ctx);
                      _loadState();
                    }
                  },
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Color(0xFFF8FAFC),
        body: Center(child: CircularProgressIndicator(color: Color(0xFF2563EB))),
      );
    }

    final dest = _trip["destination"] ?? {};
    final String currentCityRaw = (dest["city"] ?? "Vasai-Virar").toString();
    final resolved = _resolveDestinationDetails(currentCityRaw);

    final String activeCity = resolved["city"]!;
    final String activeState = resolved["state"]!;
    final String activeCountry = resolved["country"]!;
    final String imagePath = resolved["image"]!;
    final String fallbackUrl = resolved["fallback_image"]!;

    final itinerary = List<Map<String, dynamic>>.from(_trip["today_itinerary"] ?? []);
    final lifelines = _getHyperlocalLifelines(activeCity, activeCountry);

    final dateString = _formatNativeDate(_currentClock);
    final timeString = _formatNativeTime(_currentClock.hour, _currentClock.minute);

    final currentMatch = _availableLanguages.firstWhere(
      (l) => l["name"] == widget.language,
      orElse: () => _availableLanguages.first,
    );
    final String currentCode = currentMatch["code"] ?? "EN";

    final topInset = MediaQuery.of(context).padding.top;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: Stack(
        children: [
          RefreshIndicator(
            onRefresh: () async {
              await _loadState();
              await _checkLocationAndStamps();
            },
            color: const Color(0xFF2563EB),
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: EdgeInsets.zero,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizedBox(
                    height: 380,
                    width: double.infinity,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        _buildHeroBackdrop(imagePath, fallbackUrl),
                        Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                Colors.black.withOpacity(0.55),
                                Colors.black.withOpacity(0.10),
                                Colors.black.withOpacity(0.85),
                              ],
                              stops: const [0.0, 0.40, 1.0],
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                            ),
                          ),
                        ),
                        Padding(
                          padding: EdgeInsets.fromLTRB(16, topInset + 8, 16, 20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  _buildGlassPill(
                                    padding: const EdgeInsets.all(8),
                                    child: InkWell(
                                      onTap: widget.onOpenDrawer,
                                      child: const Icon(Icons.menu_rounded, color: Colors.white, size: 22),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: InkWell(
                                      onTap: _showCityPickerDialog,
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Flexible(
                                                child: Text(
                                                  activeCity,
                                                  style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900),
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                              ),
                                              const SizedBox(width: 4),
                                              Icon(
                                                _isExploration ? Icons.explore_rounded : Icons.near_me_rounded,
                                                color: _isExploration ? const Color(0xFFFBBF24) : Colors.white,
                                                size: 14,
                                              ),
                                            ],
                                          ),
                                          Text(
                                            _isExploration
                                                ? "$activeState, $activeCountry • Exploring"
                                                : "$activeState, $activeCountry • Live GPS",
                                            style: TextStyle(
                                              color: _isExploration ? const Color(0xFFFDE68A) : Colors.white70,
                                              fontSize: 11.5,
                                              fontWeight: FontWeight.w600,
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                  _buildGlassPill(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          _isNight ? Icons.nightlight_round : Icons.wb_sunny_rounded,
                                          size: 15,
                                          color: _isNight ? const Color(0xFF93C5FD) : const Color(0xFFFBBF24),
                                        ),
                                        const SizedBox(width: 4),
                                        Text(_liveTemperature, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  InkWell(
                                    onTap: _showLanguagePickerModal,
                                    borderRadius: BorderRadius.circular(20),
                                    child: _buildGlassPill(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const Icon(Icons.language_rounded, size: 14, color: Colors.white),
                                          const SizedBox(width: 4),
                                          Text(
                                            currentCode,
                                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
                                          ),
                                          const Icon(Icons.keyboard_arrow_down_rounded, size: 16, color: Colors.white),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),

                              if (_isExploration) ...[
                                const SizedBox(height: 10),
                                InkWell(
                                  onTap: _returnToLiveGps,
                                  borderRadius: BorderRadius.circular(20),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF2563EB).withOpacity(0.90),
                                      borderRadius: BorderRadius.circular(20),
                                      border: Border.all(color: Colors.white.withOpacity(0.3), width: 1),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(Icons.gps_fixed_rounded, color: Colors.white, size: 12),
                                        const SizedBox(width: 6),
                                        Text(
                                          "Return to Live GPS ($_currentLiveCity)",
                                          style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],

                              const Spacer(),

                              Text(
                                _travelMode == "Transit" ? "Live Transit Cockpit" : _getGreeting(),
                                style: const TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w900, letterSpacing: -0.5),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                _t("ready_to_explore"),
                                style: const TextStyle(color: Colors.white70, fontSize: 14, fontWeight: FontWeight.w500),
                              ),
                              const SizedBox(height: 12),
                              _buildGlassPill(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.access_time_rounded, size: 13, color: Color(0xFF93C5FD)),
                                    const SizedBox(width: 6),
                                    Text("$dateString • $timeString", style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  Transform.translate(
                    offset: const Offset(0, -18),
                    child: Container(
                      decoration: const BoxDecoration(
                        color: Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                      ),
                      padding: const EdgeInsets.only(top: 14),
                      child: Column(
                        children: [
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(3),
                                  decoration: BoxDecoration(color: const Color(0xFFE2E8F0), borderRadius: BorderRadius.circular(20)),
                                  child: Row(
                                    children: [
                                      GestureDetector(
                                        onTap: () => setState(() => _travelMode = "Home"),
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                                          decoration: BoxDecoration(
                                            color: _travelMode == "Home" ? Colors.white : Colors.transparent,
                                            borderRadius: BorderRadius.circular(16),
                                            boxShadow: _travelMode == "Home" ? [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 4, offset: const Offset(0, 1))] : null,
                                          ),
                                          child: Row(
                                            children: [
                                              Icon(Icons.home_rounded, size: 14, color: _travelMode == "Home" ? const Color(0xFF2563EB) : const Color(0xFF64748B)),
                                              const SizedBox(width: 4),
                                              Text("Home Base", style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: _travelMode == "Home" ? const Color(0xFF0F172A) : const Color(0xFF64748B))),
                                            ],
                                          ),
                                        ),
                                      ),
                                      GestureDetector(
                                        onTap: () => setState(() => _travelMode = "Transit"),
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                                          decoration: BoxDecoration(
                                            color: _travelMode == "Transit" ? const Color(0xFF2563EB) : Colors.transparent,
                                            borderRadius: BorderRadius.circular(16),
                                            boxShadow: _travelMode == "Transit" ? [BoxShadow(color: const Color(0xFF2563EB).withOpacity(0.3), blurRadius: 4, offset: const Offset(0, 1))] : null,
                                          ),
                                          child: Row(
                                            children: [
                                              Icon(Icons.near_me_rounded, size: 14, color: _travelMode == "Transit" ? Colors.white : const Color(0xFF64748B)),
                                              const SizedBox(width: 4),
                                              Text("On Transit", style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: _travelMode == "Transit" ? Colors.white : const Color(0xFF64748B))),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Row(
                                  children: [
                                    Icon(
                                      _isExploration ? Icons.explore_outlined : Icons.check_circle_rounded,
                                      size: 13,
                                      color: _isExploration ? const Color(0xFFD97706) : const Color(0xFF16A34A),
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      _isExploration ? "Exploration Mode" : "Live GPS Mode",
                                      style: TextStyle(
                                        fontSize: 10.5,
                                        fontWeight: FontWeight.bold,
                                        color: _isExploration ? const Color(0xFFB45309) : const Color(0xFF16A34A),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 12),

                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: InkWell(
                              onTap: () {
                                if (widget.onNavigateTab != null) {
                                  widget.onNavigateTab!(5);
                                }
                              },
                              borderRadius: BorderRadius.circular(16),
                              child: Container(
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    colors: [Color(0xFF0F172A), Color(0xFF1E3A8A)],
                                  ),
                                  borderRadius: BorderRadius.circular(16),
                                  boxShadow: [
                                    BoxShadow(color: const Color(0xFF1E3A8A).withOpacity(0.25), blurRadius: 8, offset: const Offset(0, 3)),
                                  ],
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(color: Colors.white.withOpacity(0.18), shape: BoxShape.circle),
                                      child: const Icon(Icons.train_rounded, color: Colors.white, size: 22),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: const [
                                          Text(
                                            "Indian Railways Transit Hub",
                                            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13.5),
                                          ),
                                          Text(
                                            "Live Train Status • PNR • IRCTC Booking Direct",
                                            style: TextStyle(color: Colors.white70, fontSize: 11),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const Icon(Icons.arrow_forward_ios_rounded, color: Colors.white, size: 14),
                                  ],
                                ),
                              ),
                            ),
                          ),

                          const SizedBox(height: 14),

                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: Row(
                              children: [
                                _buildTopActionTile(
                                  icon: Icons.translate_rounded,
                                  label: _t("action_translate"),
                                  iconColor: const Color(0xFF2563EB),
                                  onTap: () {
                                    if (widget.onNavigateTab != null) widget.onNavigateTab!(4);
                                  },
                                ),
                                const SizedBox(width: 10),
                                _buildTopActionTile(
                                  icon: Icons.receipt_long_rounded,
                                  label: _t("action_spends"),
                                  iconColor: const Color(0xFF16A34A),
                                  onTap: () => _showQuickAddSpendModal(context),
                                ),
                                const SizedBox(width: 10),
                                _buildTopActionTile(
                                  icon: Icons.radar_rounded,
                                  label: _t("action_ar"),
                                  iconColor: const Color(0xFF0284C7),
                                  onTap: _openArRadar, // FIXED: Now opens AR Radar / Guide Chat
                                ),
                                const SizedBox(width: 10),
                                _buildTopActionTile(
                                  icon: Icons.card_membership_rounded,
                                  label: _t("action_passport"),
                                  iconColor: const Color(0xFF9333EA),
                                  onTap: () => _openPassportModal(context), // FIXED: Now opens populated passport stamp book
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 14),

                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF0FDF4),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: const Color(0xFFBBF7D0)),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(color: const Color(0xFFDCFCE7), borderRadius: BorderRadius.circular(10)),
                                    child: const Icon(Icons.calendar_today_rounded, color: Color(0xFF16A34A), size: 20),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          itinerary.isEmpty ? _t("no_activities") : "${itinerary.length} ${_t("scheduled_plans")}",
                                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(_t("add_plans_sub"), style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B))),
                                      ],
                                    ),
                                  ),
                                  MetallicEmbossedButton(
                                    label: _t("add_activity_btn"),
                                    variant: MetallicVariant.cobaltBlue,
                                    height: 36,
                                    fontSize: 11.5,
                                    onPressed: () => _showAddActivityModal(context), // FIXED: Now opens activity creator
                                  ),
                                ],
                              ),
                            ),
                          ),

                          const SizedBox(height: 14),

                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: const Color(0xFFE2E8F0)),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Row(
                                        children: [
                                          const Icon(Icons.account_balance_wallet_rounded, size: 18, color: Color(0xFF2563EB)),
                                          const SizedBox(width: 8),
                                          const Text("Recent Spends", style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800, color: Color(0xFF0F172A))),
                                          const SizedBox(width: 6),
                                          Text("(Today: ₹${_todaySpendSum.toStringAsFixed(0)})", style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: Color(0xFF64748B))),
                                        ],
                                      ),
                                      GestureDetector(
                                        onTap: () {
                                          if (widget.onNavigateTab != null) widget.onNavigateTab!(13);
                                        },
                                        child: const Text("View Ledger →", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF2563EB))),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),

                          const SizedBox(height: 18),

                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: Text(_t("explore_tools"), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Color(0xFF0F172A))),
                          ),

                          const SizedBox(height: 12),

                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: GridView.count(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              crossAxisCount: 4,
                              mainAxisSpacing: 10,
                              crossAxisSpacing: 10,
                              childAspectRatio: 0.82,
                              children: [
                                _buildToolGridTile(
                                  icon: Icons.explore_rounded,
                                  iconColor: const Color(0xFF2563EB),
                                  bgTint: const Color(0xFFEFF6FF),
                                  label: _t("tool_destination"),
                                  onTap: () {
                                    if (widget.onNavigateTab != null) widget.onNavigateTab!(2);
                                  },
                                ),
                                _buildToolGridTile(
                                  icon: Icons.train_rounded,
                                  iconColor: const Color(0xFF059669),
                                  bgTint: const Color(0xFFECFDF5),
                                  label: _t("tool_railway"),
                                  onTap: () {
                                    if (widget.onNavigateTab != null) widget.onNavigateTab!(5);
                                  },
                                ),
                                _buildToolGridTile(
                                  icon: Icons.support_agent_rounded,
                                  iconColor: const Color(0xFF9333EA),
                                  bgTint: const Color(0xFFFAF5FF),
                                  label: _t("tool_chat"),
                                  onTap: () {
                                    if (widget.onNavigateTab != null) widget.onNavigateTab!(3);
                                  },
                                ),
                                _buildToolGridTile(
                                  icon: Icons.folder_special_rounded,
                                  iconColor: const Color(0xFFEA580C),
                                  bgTint: const Color(0xFFFFF7ED),
                                  label: _t("tool_vault"),
                                  onTap: () {
                                    if (widget.onNavigateTab != null) widget.onNavigateTab!(6);
                                  },
                                ),
                                _buildToolGridTile(
                                  icon: Icons.star_rounded,
                                  iconColor: const Color(0xFFE11D48),
                                  bgTint: const Color(0xFFFFF1F2),
                                  label: _t("tool_gems"),
                                  onTap: () {
                                    if (widget.onNavigateTab != null) widget.onNavigateTab!(7);
                                  },
                                ),
                                _buildToolGridTile(
                                  icon: Icons.document_scanner_rounded,
                                  iconColor: const Color(0xFF0D9488),
                                  bgTint: const Color(0xFFF0FDFA),
                                  label: _t("tool_scanner"),
                                  onTap: () {
                                    if (widget.onNavigateTab != null) widget.onNavigateTab!(1);
                                  },
                                ),
                                _buildToolGridTile(
                                  icon: Icons.currency_exchange_rounded,
                                  iconColor: const Color(0xFF7C3AED),
                                  bgTint: const Color(0xFFF5F3FF),
                                  label: _t("tool_converter"),
                                  onTap: () {
                                    if (widget.onNavigateTab != null) widget.onNavigateTab!(8);
                                  },
                                ),
                                _buildToolGridTile(
                                  icon: Icons.grid_view_rounded,
                                  iconColor: const Color(0xFF475569),
                                  bgTint: const Color(0xFFF8FAFC),
                                  label: _t("tool_more"),
                                  onTap: () {
                                    if (widget.onOpenDrawer != null) {
                                      widget.onOpenDrawer!();
                                    }
                                  },
                                ),
                              ],
                            ),
                          ),

                          SizedBox(height: 40 + MediaQuery.of(context).padding.bottom),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Edge-Docked SOS Tab
          Positioned(
            right: -2,
            top: MediaQuery.of(context).size.height * 0.44,
            child: GestureDetector(
              onTap: () => _showAllLifelinesModal(context, activeCity, lifelines),
              child: Container(
                padding: const EdgeInsets.fromLTRB(10, 10, 8, 10),
                decoration: BoxDecoration(
                  color: const Color(0xFFDC2626),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(16),
                    bottomLeft: Radius.circular(16),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFDC2626).withOpacity(0.35),
                      blurRadius: 8,
                      offset: const Offset(-2, 2),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: const [
                    Icon(Icons.shield_rounded, color: Colors.white, size: 18),
                    SizedBox(height: 4),
                    RotatedBox(
                      quarterTurns: 3,
                      child: Text(
                        "SOS",
                        style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopActionTile({
    required IconData icon,
    required String label,
    required Color iconColor,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE2E8F0)),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 6, offset: const Offset(0, 2))],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: iconColor, size: 24),
              const SizedBox(height: 6),
              Text(label, textAlign: TextAlign.center, style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: Color(0xFF1E293B), height: 1.15)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildToolGridTile({
    required IconData icon,
    required Color iconColor,
    required Color bgTint,
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFF1F5F9)),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 6, offset: const Offset(0, 2))],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: bgTint, shape: BoxShape.circle), child: Icon(icon, size: 20, color: iconColor)),
            const SizedBox(height: 5),
            Text(label, textAlign: TextAlign.center, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Color(0xFF334155), height: 1.15)),
          ],
        ),
      ),
    );
  }
}