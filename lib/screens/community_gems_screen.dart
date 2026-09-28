import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/supabase_service.dart';
import '../services/trip_state_service.dart';
import '../widgets/metallic_embossed_button.dart';
import 'contribute_place_screen.dart';

class CommunityGemsScreen extends StatefulWidget {
  final String activeCity;
  final String language;
  final String backendUrl;

  const CommunityGemsScreen({
    Key? key,
    required this.activeCity,
    this.language = "English",
    this.backendUrl = "https://omni-backend-pk28.onrender.com",
  }) : super(key: key);

  @override
  State<CommunityGemsScreen> createState() => _CommunityGemsScreenState();
}

class _CommunityGemsScreenState extends State<CommunityGemsScreen> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _places = [];
  String _currentHubCity = "";
  late String _activeLanguage;
  String _selectedCategory = "All";
  final TextEditingController _searchCtrl = TextEditingController();
  String _searchQuery = "";

  Position? _userPosition;
  Set<String> _upvotedGemIds = {};
  final Map<String, String> _translatedTips = {};
  final Set<String> _translatingPlaceIds = {};

  String? _currentUserId;
  String? _currentUserEmail;
  String _currentUserName = "Local Scout";
  bool _isAdmin = false;
  List<String> _blockedUserIds = [];

  RealtimeChannel? _presenceChannel;
  List<Map<String, dynamic>> _activeScouts = [];
  String? _remoteTypingUser;
  DateTime? _lastTypingTime;

  static const String _upvoteStorageKey = "omni_community_upvoted_ids";
  static const String _languagePrefKey = "omni_selected_ui_language";
  static const String _tosAcceptedKey = "omni_community_tos_accepted";
  static const List<String> _adminEmails = [
    "barleslie@gmail.com",
    "admin@touristos.app",
  ];

  final List<Map<String, dynamic>> _supportedLanguages = [
    {"code": "en", "name": "English", "native": "English"},
    {"code": "mr", "name": "Marathi", "native": "मराठी"},
    {"code": "hi", "name": "Hindi", "native": "हिंदी"},
    {"code": "gu", "name": "Gujarati", "native": "ગુજરાતી"},
    {"code": "ta", "name": "Tamil", "native": "தமிழ்"},
    {"code": "te", "name": "Telugu", "native": "తెలుగు"},
    {"code": "kn", "name": "Kannada", "native": "ಕನ್ನಡ"},
    {"code": "ml", "name": "Malayalam", "native": "മലയാളം"},
    {"code": "bn", "name": "Bengali", "native": "বাংলা"},
    {"code": "pa", "name": "Punjabi", "native": "ਪੰਜਾਬੀ"},
    {"code": "fr", "name": "French", "native": "Français"},
    {"code": "de", "name": "German", "native": "Deutsch"},
    {"code": "es", "name": "Spanish", "native": "Español"},
    {"code": "it", "name": "Italian", "native": "Italiano"},
    {"code": "pt", "name": "Portuguese", "native": "Português"},
    {"code": "ru", "name": "Russian", "native": "Русский"},
    {"code": "ar", "name": "Arabic", "native": "العربية"},
    {"code": "ur", "name": "Urdu", "native": "اردو"},
    {"code": "fa", "name": "Persian", "native": "فारसी"},
    {"code": "ja", "name": "Japanese", "native": "日本語"},
    {"code": "zh", "name": "Chinese", "native": "中文"},
    {"code": "th", "name": "Thai", "native": "ไทย"},
    {"code": "vi", "name": "Vietnamese", "native": "Tiếng Việt"},
    {"code": "id", "name": "Indonesian", "native": "Bahasa Indonesia"},
  ];

  final List<Map<String, dynamic>> _filterCategories = [
    {"label": "All", "icon": Icons.grid_view_rounded, "color": const Color(0xFF2563EB)},
    {"label": "Pharmacy / Chemist", "icon": Icons.medication_rounded, "color": const Color(0xFF16A34A)},
    {"label": "Barber & Salon", "icon": Icons.content_cut_rounded, "color": const Color(0xFF7C3AED)},
    {"label": "Kirana & Essentials", "icon": Icons.storefront_rounded, "color": const Color(0xFFD97706)},
    {"label": "Ice Cream & Dairy", "icon": Icons.icecream_rounded, "color": const Color(0xFFE11D48)},
    {"label": "Cold Storage & Meat", "icon": Icons.kitchen_rounded, "color": const Color(0xFF0284C7)},
    {"label": "Indo-Chinese & Snacks", "icon": Icons.ramen_dining_rounded, "color": const Color(0xFFEA580C)},
    {"label": "Chai & Quick Bites", "icon": Icons.coffee_rounded, "color": const Color(0xFFB45309)},
    {"label": "Bar & Restaurant", "icon": Icons.sports_bar_rounded, "color": const Color(0xFF4F46E5)},
    {"label": "Diner & Seafood", "icon": Icons.restaurant_rounded, "color": const Color(0xFF0D9488)},
    {"label": "Market, Bazaar & Mall", "icon": Icons.shopping_bag_rounded, "color": const Color(0xFFBE123C)},
    {"label": "Movie Cinema & Theater", "icon": Icons.movie_rounded, "color": const Color(0xFFDC2626)},
    {"label": "Picnic Spot & Landscape", "icon": Icons.park_rounded, "color": const Color(0xFF059669)},
    {"label": "Resort & Farmhouse", "icon": Icons.pool_rounded, "color": const Color(0xFF0891B2)},
    {"label": "Heritage & Sight", "icon": Icons.castle_rounded, "color": const Color(0xFF475569)},
  ];

  static const Map<String, Map<String, String>> _categoryTranslations = {
    "English": {
      "All": "All",
      "Pharmacy / Chemist": "Pharmacy / Chemist",
      "Barber & Salon": "Barber & Salon",
      "Kirana & Essentials": "Kirana & Essentials",
      "Ice Cream & Dairy": "Ice Cream & Dairy",
      "Cold Storage & Meat": "Cold Storage & Meat",
      "Indo-Chinese & Snacks": "Indo-Chinese & Snacks",
      "Chai & Quick Bites": "Chai & Quick Bites",
      "Bar & Restaurant": "Bar & Restaurant",
      "Diner & Seafood": "Diner & Seafood",
      "Market, Bazaar & Mall": "Market, Bazaar & Mall",
      "Movie Cinema & Theater": "Movie Cinema & Theater",
      "Picnic Spot & Landscape": "Picnic Spot & Landscape",
      "Resort & Farmhouse": "Resort & Farmhouse",
      "Heritage & Sight": "Heritage & Sight",
      "navigate_btn": "Navigate",
      "endorse_btn": "Endorse",
      "add_gem_btn": "+ Add Local Shop / Gem",
      "search_hint": "Search pharmacy, barber, chai, food spot...",
      "recommended_by": "Recommended by",
      "translate": "Translate",
      "show_original": "Show Original",
      "delete_gem": "Delete Listing",
      "edit_gem": "Edit Listing",
      "ask_locals": "Ask Locals",
    },
    "Marathi": {
      "All": "सर्व",
      "Pharmacy / Chemist": "औषधालय / केमिस्ट",
      "Barber & Salon": "सलून आणि ग्रूमिंग",
      "Kirana & Essentials": "किराणा व दैनंदिन वस्तू",
      "Ice Cream & Dairy": "आईस्क्रीम व डेअरी",
      "Cold Storage & Meat": "मटण, चिकन व मासे",
      "Indo-Chinese & Snacks": "इंडो-चायनीज व स्नॅक्स",
      "Chai & Quick Bites": "चहा आणि नाश्ता",
      "Bar & Restaurant": "रेस्टॉरंट व बार",
      "Diner & Seafood": "हॉटेल व सीफूड",
      "Market, Bazaar & Mall": "बाजार, भाजी मंडई व मॉल",
      "Movie Cinema & Theater": "सिनेमागृह व थिएटर",
      "Picnic Spot & Landscape": "पिकनिक व निसर्ग स्थळे",
      "Resort & Farmhouse": "रिसॉर्ट व फार्महाऊस",
      "Heritage & Sight": "ऐतिहासिक व पर्यटन स्थळे",
      "navigate_btn": "दिशा दाखवा",
      "endorse_btn": "शिफारस करा",
      "add_gem_btn": "+ नवीन दुकान / जागा जोडा",
      "search_hint": "केमिस्ट, सलून, चहा, खाऊ गल्ली शोधा...",
      "recommended_by": "द्वारे शिफारस",
      "translate": "भाषांतर करा",
      "show_original": "मूळ दाखवा",
      "delete_gem": "नोंद हटवा",
      "edit_gem": "माहिती बदला",
      "ask_locals": "स्थानिकांना विचारा",
    },
    "Hindi": {
      "All": "सभी",
      "Pharmacy / Chemist": "दवाइयां / केमिस्ट",
      "Barber & Salon": "सैलून और ग्रूमिंग",
      "Kirana & Essentials": "किराना और आवश्यक वस्तुएं",
      "Ice Cream & Dairy": "आइसक्रीम और डेयरी",
      "Cold Storage & Meat": "मटन, चिकन व मछली",
      "Indo-Chinese & Snacks": "इंडो-चाइनीज व स्नैक्स",
      "Chai & Quick Bites": "चाय और नाश्ता",
      "Bar & Restaurant": "रेस्तरां और बार",
      "Diner & Seafood": "डाइनर और सीफूड",
      "Market, Bazaar & Mall": "बाजार, सब्जी मंडी व मॉल",
      "Movie Cinema & Theater": "सिनेमाघर व थिएटर",
      "Picnic Spot & Landscape": "पिकनिक स्थल व प्रकृति",
      "Resort & Farmhouse": "रिसॉर्ट और फार्महाउस",
      "Heritage & Sight": "ऐतिहासिक व पर्यटन स्थल",
      "navigate_btn": "नेविगेट करें",
      "endorse_btn": "सिफारिश करें",
      "add_gem_btn": "+ नई दुकान / स्थान जोड़ें",
      "search_hint": "दवा दुकान, सैलून, चाय, भोजनालय खोजें...",
      "recommended_by": "द्वारा अनुशंसित",
      "translate": "अनुवाद करें",
      "show_original": "मूल देखें",
      "delete_gem": "स्थान हटाएं",
      "edit_gem": "जानकारी बदलें",
      "ask_locals": "स्थानीय लोगों से पूछें",
    }
  };

  @override
  void initState() {
    super.initState();
    _currentHubCity = widget.activeCity;
    _activeLanguage = widget.language.trim().isNotEmpty ? widget.language.trim() : "English";
    _initAuthAndPreferences();
    _fetchUserLocation();
    _loadPlacesForCity(_currentHubCity);
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _presenceChannel?.unsubscribe();
    super.dispose();
  }

  Future<void> _initAuthAndPreferences() async {
    try {
      final supaUser = Supabase.instance.client.auth.currentUser;
      if (supaUser != null) {
        _currentUserId = supaUser.id;
        _currentUserEmail = supaUser.email?.toLowerCase();
        _currentUserName = (supaUser.userMetadata?['full_name'] ?? _currentUserEmail?.split('@').first ?? "Local Scout").toString();
        _isAdmin = _currentUserEmail != null && _adminEmails.any((e) => _currentUserEmail!.contains(e));
      } else {
        _currentUserId = "guest_${DateTime.now().millisecondsSinceEpoch}";
      }

      if (_currentUserId != null) {
        _blockedUserIds = await SupabaseService.getBlockedUserIds(_currentUserId!);
      }
    } catch (_) {}

    try {
      final prefs = await SharedPreferences.getInstance();
      final savedLang = prefs.getString(_languagePrefKey);
      if (savedLang != null && savedLang.isNotEmpty) {
        if (mounted) setState(() => _activeLanguage = savedLang);
      }
      final list = prefs.getStringList(_upvoteStorageKey) ?? [];
      if (mounted) setState(() => _upvotedGemIds = list.toSet());
    } catch (_) {}

    _initPresenceChannel();
  }

  void _initPresenceChannel() {
    try {
      final cleanCity = _currentHubCity.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_').toLowerCase();
      _presenceChannel = Supabase.instance.client.channel('presence_$cleanCity');

      _presenceChannel!.onBroadcast(
        event: 'typing',
        callback: (payload) {
          final typer = payload['user_name']?.toString() ?? '';
          final typerId = payload['user_id']?.toString() ?? '';
          if (typerId != _currentUserId && typer.isNotEmpty) {
            if (mounted) {
              setState(() {
                _remoteTypingUser = typer;
                _lastTypingTime = DateTime.now();
              });
              Future.delayed(const Duration(seconds: 3), () {
                if (mounted && _lastTypingTime != null &&
                    DateTime.now().difference(_lastTypingTime!).inSeconds >= 3) {
                  setState(() => _remoteTypingUser = null);
                }
              });
            }
          }
        },
      );

      _presenceChannel!
          .onPresenceSync((_) {
            final dynamic rawState = _presenceChannel!.presenceState();
            final Map<String, Map<String, dynamic>> scoutsMap = {};

            void parsePresence(dynamic presence) {
              try {
                final payload = presence.payload;
                if (payload != null && payload['user_id'] != null) {
                  final uid = payload['user_id'].toString();
                  scoutsMap[uid] = {
                    'user_id': uid,
                    'user_name': (payload['user_name'] ?? 'Scout').toString(),
                  };
                }
              } catch (_) {}
            }

            if (rawState is List) {
              for (var presence in rawState) {
                parsePresence(presence);
              }
            } else if (rawState is Map) {
              for (var entry in rawState.entries) {
                if (entry.value is List) {
                  for (var presence in (entry.value as List)) {
                    parsePresence(presence);
                  }
                }
              }
            }

            if (mounted) {
              setState(() => _activeScouts = scoutsMap.values.toList());
            }
          })
          .subscribe((status, _) async {
            if (status == RealtimeSubscribeStatus.subscribed) {
              await _presenceChannel!.track({
                'user_id': _currentUserId,
                'user_name': _currentUserName,
                'online_at': DateTime.now().toIso8601String(),
              });
            }
          });
    } catch (_) {}
  }

  Future<bool> _ensureTosAccepted() async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(_tosAcceptedKey) == true) return true;

    final accepted = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: const [
            Icon(Icons.verified_user_rounded, color: Color(0xFF2563EB), size: 24),
            SizedBox(width: 8),
            Text("Community Safety Rules", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
          ],
        ),
        content: const Text(
          "To keep Omni TouristOS safe for travelers and locals:\n\n"
          "• No illicit goods, contraband, or unauthorized deals.\n"
          "• Zero tolerance for harassment, scams, or abuse.\n"
          "• Messages are supervised by OmniGuard AI and admins.\n\n"
          "Violators face immediate permanent account suspension.",
          style: TextStyle(fontSize: 13, color: Color(0xFF475569), height: 1.4),
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2563EB),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text("I Agree & Understand", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (accepted == true) {
      await prefs.setBool(_tosAcceptedKey, true);
      return true;
    }
    return false;
  }

  String _t(String englishKey) {
    if (_categoryTranslations.containsKey(_activeLanguage) &&
        _categoryTranslations[_activeLanguage]!.containsKey(englishKey)) {
      return _categoryTranslations[_activeLanguage]![englishKey]!;
    }
    if (_categoryTranslations["English"]!.containsKey(englishKey)) {
      return _categoryTranslations["English"]![englishKey]!;
    }
    return englishKey;
  }

  String _formatRelativeTime(dynamic rawTimestamp) {
    if (rawTimestamp == null) return "Just now";
    try {
      final parsed = DateTime.parse(rawTimestamp.toString()).toLocal();
      final diff = DateTime.now().difference(parsed);

      if (diff.inSeconds < 60) return "Just now";
      if (diff.inMinutes < 60) return "${diff.inMinutes}m ago";
      if (diff.inHours < 24) return "${diff.inHours}h ago";
      if (diff.inDays < 7) return "${diff.inDays}d ago";
      return "${parsed.day}/${parsed.month}";
    } catch (_) {
      return "Recently";
    }
  }

  void _showLanguageSelectorModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => SizedBox(
        height: MediaQuery.of(context).size.height * 0.75,
        child: Column(
          children: [
            Container(margin: const EdgeInsets.only(top: 12, bottom: 8), width: 44, height: 5, decoration: BoxDecoration(color: const Color(0xFFCBD5E1), borderRadius: BorderRadius.circular(10))),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 10),
              child: Row(
                children: const [
                  Icon(Icons.translate_rounded, color: Color(0xFF2563EB), size: 22),
                  SizedBox(width: 10),
                  Text("Select Community Language", style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: Color(0xFF0F172A))),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                itemCount: _supportedLanguages.length,
                separatorBuilder: (_, __) => const Divider(height: 1, color: Color(0xFFF1F5F9)),
                itemBuilder: (context, idx) {
                  final lang = _supportedLanguages[idx];
                  final name = lang["name"] as String;
                  final native = lang["native"] as String;
                  final isSelected = name.toLowerCase() == _activeLanguage.toLowerCase();

                  return ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    tileColor: isSelected ? const Color(0xFFEFF6FF) : null,
                    title: Text(native, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: isSelected ? const Color(0xFF1D4ED8) : const Color(0xFF1E293B))),
                    subtitle: Text(name, style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                    trailing: isSelected ? const Icon(Icons.check_circle_rounded, color: Color(0xFF2563EB)) : null,
                    onTap: () async {
                      Navigator.pop(ctx);
                      setState(() {
                        _activeLanguage = name;
                        _translatedTips.clear();
                      });
                      final prefs = await SharedPreferences.getInstance();
                      await prefs.setString(_languagePrefKey, name);
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

  Future<void> _fetchUserLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return;

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) return;
      }
      if (permission == LocationPermission.deniedForever) return;

      final lastPos = await Geolocator.getLastKnownPosition();
      if (lastPos != null && mounted) setState(() => _userPosition = lastPos);

      final livePos = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high, timeLimit: const Duration(seconds: 8));
      if (mounted) setState(() => _userPosition = livePos);
    } catch (_) {}
  }

  List<Map<String, dynamic>> _deduplicatePlaces(List<Map<String, dynamic>> rawList) {
    final Map<String, Map<String, dynamic>> map = {};

    for (var item in rawList) {
      final name = (item['name'] ?? '').toString().toLowerCase().trim();
      final city = (item['city'] ?? '').toString().toLowerCase().trim();
      final key = "$name|$city";

      if (!map.containsKey(key)) {
        map[key] = item;
      } else {
        final existing = map[key]!;
        final existingUpvotes = (existing['upvotes'] as num?)?.toInt() ?? 0;
        final currentUpvotes = (item['upvotes'] as num?)?.toInt() ?? 0;
        final hasImage = (item['image_url'] ?? '').toString().isNotEmpty;

        if (hasImage || currentUpvotes > existingUpvotes) {
          map[key] = item;
        }
      }
    }
    return map.values.toList();
  }

  Future<void> _loadPlacesForCity(String city) async {
    setState(() => _isLoading = true);
    final data = await SupabaseService.getPlacesForCity(city);
    if (!mounted) return;

    if (data.isNotEmpty) {
      final clean = _deduplicatePlaces(data);
      setState(() {
        _places = clean;
        _isLoading = false;
      });
    } else {
      final generated = _generateGemsForCity(city);
      setState(() {
        _places = generated;
        _isLoading = false;
      });
    }
  }

  Future<void> _executeActiveSearch(String query) async {
    final q = query.trim();
    if (q.isEmpty) {
      _loadPlacesForCity(_currentHubCity);
      return;
    }

    setState(() {
      _isLoading = true;
      _searchQuery = q;
    });

    List<Map<String, dynamic>> results = [];

    try {
      await SupabaseService.ensureInitialized();
      final response = await SupabaseService.client
          .from('community_places')
          .select()
          .or('city.ilike.%$q%,name.ilike.%$q%,address.ilike.%$q%,category.ilike.%$q%')
          .order('upvotes', ascending: false);

      results = _deduplicatePlaces(List<Map<String, dynamic>>.from(response));
    } catch (e) {
      debugPrint("Supabase query notice: $e");
    }

    if (results.isEmpty) {
      results = _generateGemsForCity(q);
    }

    if (!mounted) return;
    setState(() {
      _places = results;
      _isLoading = false;
      if (results.isNotEmpty) {
        _currentHubCity = q[0].toUpperCase() + q.substring(1);
      }
    });
  }

  List<Map<String, dynamic>> _generateGemsForCity(String queryCity) {
    final cityName = queryCity.trim().isEmpty ? "Local Area" : (queryCity[0].toUpperCase() + queryCity.substring(1));
    final cleanCity = cityName.toLowerCase();

    double centerLat = 19.3556;
    double centerLon = 72.8256;

    if (cleanCity.contains("mumbai")) {
      centerLat = 18.9220;
      centerLon = 72.8347;
    } else if (cleanCity.contains("dubai")) {
      centerLat = 25.2048;
      centerLon = 55.2708;
    } else if (cleanCity.contains("delhi")) {
      centerLat = 28.6139;
      centerLon = 77.2090;
    } else if (_userPosition != null) {
      centerLat = _userPosition!.latitude;
      centerLon = _userPosition!.longitude;
    }

    final templates = [
      {
        "name": "$cityName 24x7 Apollo & Sanjivani Chemist",
        "category": "Pharmacy / Chemist",
        "address": "Opposite Central Transit Junction, Station Road, $cityName",
        "description": "24/7 all-night pharmacy stocking critical emergency medicines, surgical supplies, and instant delivery.",
        "contact_phone": "+91 98200 12345",
        "must_try_tip": "Open 24 hours including national holidays.",
        "tags": ["🕒 24 Hours", "💳 UPI Accepted", "🛵 Home Delivery"],
        "upvotes": 12,
      },
      {
        "name": "Classic Royal Mens Grooming & Hair Salon",
        "category": "Barber & Salon",
        "address": "Shop 4, Market Promenade, Near City Post, $cityName",
        "description": "Hygienic local salon offering precision fades, beard styling, facial massages, and quick walk-in service.",
        "contact_phone": "+91 98200 23456",
        "must_try_tip": "Try their herbal head massage with menthol cooling.",
        "tags": ["❄️ AC Seating", "💳 UPI Accepted", "💰 Budget Friendly"],
        "upvotes": 9,
      },
      {
        "name": "Shree Ganesh Kirana & Daily Provisions",
        "category": "Kirana & Essentials",
        "address": "Bazaar Main Gali, Near Old Clock Tower, $cityName",
        "description": "Trusted neighborhood store for fresh grains, cold-pressed oils, dairy essentials, and spices.",
        "contact_phone": "+91 98200 34567",
        "must_try_tip": "Home delivery within 30 minutes on phone order.",
        "tags": ["🛵 Home Delivery", "💳 UPI Accepted", "💰 Budget Friendly"],
        "upvotes": 14,
      },
      {
        "name": "Tapri Corner Masala Chai & Bun Maska",
        "category": "Chai & Quick Bites",
        "address": "Station Gate 2 Exit, Beside Auto Stand, $cityName",
        "description": "Piping hot ginger-cardamom cutting chai, crispy bun maska, samosas, and piping vada pavs.",
        "contact_phone": "",
        "must_try_tip": "Best cutting chai in the area, paired with hot onion bhajiyas.",
        "tags": ["🌿 Pure Veg", "💰 Budget Friendly", "💳 UPI Accepted"],
        "upvotes": 31,
      },
      {
        "name": "Coastal Spice Seafood Diner & Thali House",
        "category": "Diner & Seafood",
        "address": "Near Old Fishermen Wharf, Coastal Lane, $cityName",
        "description": "Authentic regional thalis, surmai fry, crab masala, and homestyle coconut curry.",
        "contact_phone": "+91 98200 89012",
        "must_try_tip": "Order the special executive fish thali with solkadhi.",
        "tags": ["❄️ AC Seating", "💳 UPI Accepted"],
        "upvotes": 28,
      },
    ];

    return templates.asMap().entries.map((entry) {
      final idx = entry.key;
      final t = entry.value;
      final offsetLat = ((idx * 7) % 15 - 7) * 0.0035;
      final offsetLon = ((idx * 11) % 15 - 7) * 0.0035;

      return {
        "id": "DYNAMIC-$idx-${t['name'].hashCode}",
        "name": t['name'],
        "category": t['category'],
        "address": t['address'],
        "city": cityName,
        "description": t['description'],
        "contact_phone": t['contact_phone'],
        "maps_url": "https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent("${t['name']}, $cityName")}",
        "contributor_name": "Verified Local Scout",
        "upvotes": t['upvotes'],
        "must_try_tip": t['must_try_tip'],
        "endorsement_tags": t['tags'],
        "latitude": centerLat + offsetLat,
        "longitude": centerLon + offsetLon,
      };
    }).toList();
  }

  String _calculateDistance(Map<String, dynamic> gem) {
    double uLat = _userPosition?.latitude ?? 19.3900;
    double uLon = _userPosition?.longitude ?? 72.8300;

    double? lat = double.tryParse(gem['latitude']?.toString() ?? "");
    double? lon = double.tryParse(gem['longitude']?.toString() ?? "");

    if (lat == null || lon == null || (lat == 0.0 && lon == 0.0)) {
      final textBlob = "${gem['name']} ${gem['address']} ${gem['city']}".toLowerCase();

      if (textBlob.contains("naigaon")) {
        lat = 19.3522;
        lon = 72.8519;
      } else if (textBlob.contains("babhola")) {
        lat = 19.3789;
        lon = 72.8214;
      } else if (textBlob.contains("vasai")) {
        lat = 19.3844;
        lon = 72.8300;
      } else if (textBlob.contains("virar")) {
        lat = 19.4678;
        lon = 72.8056;
      } else if (textBlob.contains("mumbai")) {
        lat = 18.9220;
        lon = 72.8347;
      } else if (textBlob.contains("dubai")) {
        lat = 25.2048;
        lon = 55.2708;
      } else {
        lat = uLat + 0.005;
        lon = uLon + 0.005;
      }
    }

    final distanceMeters = Geolocator.distanceBetween(uLat, uLon, lat, lon);

    if (distanceMeters < 1000) {
      return "📍 ${distanceMeters.round()}m away";
    } else {
      return "📍 ${(distanceMeters / 1000).toStringAsFixed(1)} km away";
    }
  }

  Future<void> _handleUpvote(Map<String, dynamic> gem) async {
    final placeId = gem['id']?.toString();
    if (placeId == null) return;

    if (_upvotedGemIds.contains(placeId)) {
      HapticFeedback.lightImpact();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(backgroundColor: Color(0xFF475569), duration: Duration(seconds: 2), content: Text("You have already endorsed and upvoted this spot.")),
      );
      return;
    }

    HapticFeedback.mediumImpact();
    final currentUpvotes = (gem['upvotes'] as num?)?.toInt() ?? 0;
    final newCount = currentUpvotes + 1;

    setState(() {
      gem['upvotes'] = newCount;
      _upvotedGemIds.add(placeId);
    });

    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_upvoteStorageKey, _upvotedGemIds.toList());
    await SupabaseService.upvotePlace(placeId, currentUpvotes);

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(backgroundColor: Color(0xFF16A34A), duration: Duration(seconds: 2), content: Text("✓ Recommendation verified & upvoted!")),
    );
  }

  void _showEditPlaceModal(Map<String, dynamic> gem) {
    final nameCtrl = TextEditingController(text: gem['name'] ?? "");
    final addressCtrl = TextEditingController(text: gem['address'] ?? "");
    final phoneCtrl = TextEditingController(text: gem['contact_phone'] ?? "");
    final tipCtrl = TextEditingController(text: gem['must_try_tip'] ?? "");
    String category = gem['category'] ?? "Pharmacy / Chemist";

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) {
        final bottomInset = MediaQuery.of(ctx).viewInsets.bottom;
        final systemNavInset = MediaQuery.of(ctx).padding.bottom;

        return StatefulBuilder(
          builder: (ctx, setModalState) => Container(
            padding: EdgeInsets.fromLTRB(20, 16, 20, bottomInset > 0 ? bottomInset + 16 : systemNavInset + 20),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: const Color(0xFFCBD5E1), borderRadius: BorderRadius.circular(10)))),
                  const SizedBox(height: 14),
                  Row(
                    children: const [
                      Icon(Icons.edit_note_rounded, color: Color(0xFF2563EB), size: 24),
                      SizedBox(width: 8),
                      Text("Edit Place Listing", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16.5, color: Color(0xFF0F172A))),
                    ],
                  ),
                  const SizedBox(height: 14),
                  const Text("Shop / Spot Name", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5, color: Color(0xFF334155))),
                  const SizedBox(height: 5),
                  TextField(
                    controller: nameCtrl,
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: const Color(0xFFF8FAFC),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text("Category", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5, color: Color(0xFF334155))),
                  const SizedBox(height: 5),
                  DropdownButtonFormField<String>(
                    value: _filterCategories.any((c) => c['label'] == category) && category != "All" ? category : "Pharmacy / Chemist",
                    isExpanded: true,
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: const Color(0xFFF8FAFC),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                    ),
                    items: _filterCategories.where((c) => c['label'] != 'All').map((c) => DropdownMenuItem(value: c['label'] as String, child: Text(c['label'] as String))).toList(),
                    onChanged: (val) => setModalState(() => category = val!),
                  ),
                  const SizedBox(height: 12),
                  const Text("Address / Neighborhood Street", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5, color: Color(0xFF334155))),
                  const SizedBox(height: 5),
                  TextField(
                    controller: addressCtrl,
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: const Color(0xFFF8FAFC),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text("Phone / WhatsApp Number", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5, color: Color(0xFF334155))),
                  const SizedBox(height: 5),
                  TextField(
                    controller: phoneCtrl,
                    keyboardType: TextInputType.phone,
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: const Color(0xFFF8FAFC),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text("Must-Try Tip / Highlight", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5, color: Color(0xFF334155))),
                  const SizedBox(height: 5),
                  TextField(
                    controller: tipCtrl,
                    maxLength: 100,
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: const Color(0xFFF8FAFC),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                    ),
                  ),
                  const SizedBox(height: 16),
                  MetallicEmbossedButton(
                    label: "SAVE LISTING UPDATES",
                    icon: Icons.check_circle_rounded,
                    variant: MetallicVariant.emeraldGreen,
                    height: 46,
                    fontSize: 12.5,
                    isFullWidth: true,
                    onPressed: () async {
                      final updatedName = nameCtrl.text.trim();
                      final updatedAddr = addressCtrl.text.trim();
                      final updatedPhone = phoneCtrl.text.trim();
                      final updatedTip = tipCtrl.text.trim();

                      if (updatedName.isEmpty || updatedAddr.isEmpty) return;

                      setState(() {
                        gem['name'] = updatedName;
                        gem['category'] = category;
                        gem['address'] = updatedAddr;
                        gem['contact_phone'] = updatedPhone;
                        gem['must_try_tip'] = updatedTip;
                      });

                      Navigator.pop(ctx);

                      try {
                        await SupabaseService.client.from('community_places').update({
                          'name': updatedName,
                          'category': category,
                          'address': updatedAddr,
                          'contact_phone': updatedPhone,
                          'must_try_tip': updatedTip,
                        }).eq('id', gem['id']);

                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(backgroundColor: Color(0xFF16A34A), content: Text("✓ Place details updated successfully!")),
                        );
                      } catch (e) {
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Failed to update: $e")));
                      }
                    },
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _deletePlaceListing(Map<String, dynamic> gem) async {
    final placeId = gem['id']?.toString();
    final placeName = gem['name'] ?? "Place";
    if (placeId == null || placeId.startsWith("DYNAMIC-")) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: const [
            Icon(Icons.delete_forever_rounded, color: Color(0xFFDC2626), size: 24),
            SizedBox(width: 8),
            Text("Delete Listing", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
          ],
        ),
        content: Text("Are you sure you want to permanently remove '$placeName' from Community Gems?", style: const TextStyle(fontSize: 13, color: Color(0xFF475569))),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("Cancel")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFDC2626), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text("Delete Permanently", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      HapticFeedback.heavyImpact();
      try {
        await SupabaseService.client.from('community_places').delete().eq('id', placeId);
        setState(() {
          _places.removeWhere((p) => p['id']?.toString() == placeId);
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(backgroundColor: const Color(0xFF16A34A), content: Text("✓ '$placeName' removed from community directory.")),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Failed to delete: $e")));
        }
      }
    }
  }

  void _openDirectChatModal({required String peerId, required String peerName}) {
    final TextEditingController dmCtrl = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) {
        final keyboardPadding = MediaQuery.of(ctx).viewInsets.bottom;
        final systemNavPadding = MediaQuery.of(ctx).padding.bottom;
        final effectiveBottom = keyboardPadding > 0 ? keyboardPadding + 8 : systemNavPadding + 14;

        return SizedBox(
          height: MediaQuery.of(context).size.height * 0.82,
          child: Padding(
            padding: EdgeInsets.fromLTRB(16, 12, 16, effectiveBottom),
            child: Column(
              children: [
                Container(width: 44, height: 4, decoration: BoxDecoration(color: const Color(0xFFCBD5E1), borderRadius: BorderRadius.circular(4))),
                const SizedBox(height: 12),
                Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: const Color(0xFF2563EB),
                      radius: 18,
                      child: Text(peerName.isNotEmpty ? peerName[0].toUpperCase() : "S", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(peerName, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15, color: Color(0xFF0F172A))),
                          const Text("🔒 Private 1-to-1 Travel Scout Chat", style: TextStyle(fontSize: 11, color: Color(0xFF16A34A), fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.block_rounded, color: Color(0xFFDC2626), size: 20),
                      tooltip: "Block User",
                      onPressed: () async {
                        await SupabaseService.blockUser(_currentUserId!, peerId);
                        setState(() => _blockedUserIds.add(peerId));
                        Navigator.pop(ctx);
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("✓ User blocked. Messages hidden.")));
                      },
                    ),
                    IconButton(icon: const Icon(Icons.close_rounded), onPressed: () => Navigator.pop(ctx)),
                  ],
                ),
                const Divider(height: 16),
                Expanded(
                  child: StreamBuilder<List<Map<String, dynamic>>>(
                    stream: SupabaseService.streamDirectMessages(_currentUserId!, peerId),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator(color: Color(0xFF2563EB)));
                      }
                      final allDms = snapshot.data ?? [];
                      final dms = allDms.where((m) {
                        final s = m['sender_id']?.toString();
                        final r = m['receiver_id']?.toString();
                        return (s == _currentUserId && r == peerId) || (s == peerId && r == _currentUserId);
                      }).toList();

                      if (dms.isEmpty) {
                        return Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: const [
                              Icon(Icons.lock_outline_rounded, size: 40, color: Color(0xFF94A3B8)),
                              SizedBox(height: 8),
                              Text("Start a private conversation", style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF475569))),
                              Text("Coordinate local meetups, routes, or food advice.", style: TextStyle(fontSize: 11.5, color: Color(0xFF94A3B8))),
                            ],
                          ),
                        );
                      }

                      return ListView.separated(
                        itemCount: dms.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (context, idx) {
                          final dm = dms[idx];
                          final isMe = dm['sender_id'] == _currentUserId;
                          final text = dm['message'] ?? "";
                          final createdAt = dm['created_at'];

                          return Align(
                            alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                            child: Container(
                              constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.82),
                              margin: const EdgeInsets.symmetric(horizontal: 4),
                              padding: const EdgeInsets.fromLTRB(12, 8, 12, 7),
                              decoration: BoxDecoration(
                                color: isMe ? const Color(0xFF1E40AF) : const Color(0xFFF1F5F9),
                                borderRadius: BorderRadius.only(
                                  topLeft: const Radius.circular(16),
                                  topRight: const Radius.circular(16),
                                  bottomLeft: Radius.circular(isMe ? 16 : 4),
                                  bottomRight: Radius.circular(isMe ? 4 : 16),
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.04),
                                    blurRadius: 3,
                                    offset: const Offset(0, 1),
                                  ),
                                ],
                              ),
                              child: Column(
                                crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    text,
                                    style: TextStyle(
                                      fontSize: 15.2,
                                      height: 1.35,
                                      fontWeight: FontWeight.w400,
                                      color: isMe ? Colors.white : const Color(0xFF111827),
                                    ),
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    _formatRelativeTime(createdAt),
                                    style: TextStyle(
                                      fontSize: 10.5,
                                      fontWeight: FontWeight.w500,
                                      color: isMe ? Colors.white70 : const Color(0xFF94A3B8),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: dmCtrl,
                        style: const TextStyle(fontSize: 15.0, color: Color(0xFF0F172A)),
                        decoration: InputDecoration(
                          hintText: "Type private message...",
                          hintStyle: const TextStyle(fontSize: 13.5, color: Color(0xFF94A3B8)),
                          filled: true,
                          fillColor: const Color(0xFFF8FAFC),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(Icons.send_rounded, color: Color(0xFF2563EB)),
                      onPressed: () async {
                        final txt = dmCtrl.text.trim();
                        if (txt.isEmpty) return;

                        if (!await _ensureTosAccepted()) return;

                        final verdict = await SupabaseService.inspectWithOmniGuard(
                          text: txt,
                          userId: _currentUserId!,
                          userName: _currentUserName,
                          channelType: "dm",
                        );

                        if (verdict['allowed'] != true) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(backgroundColor: const Color(0xFFDC2626), content: Text(verdict['reason'] ?? "Blocked")),
                          );
                          return;
                        }

                        dmCtrl.clear();
                        await SupabaseService.sendDirectMessage(
                          senderId: _currentUserId!,
                          senderName: _currentUserName,
                          receiverId: peerId,
                          message: txt,
                        );
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showScoutActionSheet(String scoutId, String scoutName) {
    if (scoutId == _currentUserId) return;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: CircleAvatar(backgroundColor: const Color(0xFF2563EB), child: Text(scoutName.isNotEmpty ? scoutName[0].toUpperCase() : 'S', style: const TextStyle(color: Colors.white))),
              title: Text(scoutName, style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: const Text("Active in this city hub", style: TextStyle(color: Color(0xFF16A34A), fontSize: 11.5, fontWeight: FontWeight.w600)),
            ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.forum_rounded, color: Color(0xFF2563EB)),
              title: const Text("Send 1-to-1 Private Message", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5)),
              onTap: () {
                Navigator.pop(ctx);
                _openDirectChatModal(peerId: scoutId, peerName: scoutName);
              },
            ),
            ListTile(
              leading: const Icon(Icons.block_rounded, color: Color(0xFFDC2626)),
              title: const Text("Block Scout", style: TextStyle(color: Color(0xFFDC2626), fontWeight: FontWeight.bold, fontSize: 13.5)),
              onTap: () async {
                await SupabaseService.blockUser(_currentUserId!, scoutId);
                setState(() => _blockedUserIds.add(scoutId));
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("✓ Scout blocked.")));
              },
            ),
            if (_isAdmin) ...[
              ListTile(
                leading: const Icon(Icons.gavel_rounded, color: Colors.black87),
                title: const Text("Admin: Ban User Account", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5)),
                onTap: () async {
                  await SupabaseService.banUser(scoutId, "Administrative safety ban");
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("✓ User account banned.")));
                },
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _showAskLocalsModal(Map<String, dynamic> gem) {
    final placeId = gem['id']?.toString() ?? "";
    final placeName = gem['name'] ?? "Local Spot";
    final placeCreatorId = (gem['created_by_user_id'] ?? '').toString();
    final TextEditingController msgCtrl = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setChatState) {
            final keyboardPadding = MediaQuery.of(ctx).viewInsets.bottom;
            final systemNavPadding = MediaQuery.of(ctx).padding.bottom;
            final effectiveBottomPadding = keyboardPadding > 0 ? keyboardPadding + 8 : systemNavPadding + 14;

            return SizedBox(
              height: MediaQuery.of(context).size.height * 0.80,
              child: Padding(
                padding: EdgeInsets.fromLTRB(16, 12, 16, effectiveBottomPadding),
                child: Column(
                  children: [
                    Container(width: 44, height: 4, decoration: BoxDecoration(color: const Color(0xFFCBD5E1), borderRadius: BorderRadius.circular(4))),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: const BoxDecoration(color: Color(0xFFEFF6FF), shape: BoxShape.circle),
                          child: const Icon(Icons.forum_rounded, color: Color(0xFF2563EB), size: 20),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text("Ask Locals: $placeName", style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15, color: Color(0xFF0F172A)), maxLines: 1, overflow: TextOverflow.ellipsis),
                              const Text("Live Q&A with scouts and neighborhood visitors", style: TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                            ],
                          ),
                        ),
                        IconButton(icon: const Icon(Icons.close_rounded), onPressed: () => Navigator.pop(ctx)),
                      ],
                    ),
                    const Divider(height: 16),
                    Expanded(
                      child: StreamBuilder<List<Map<String, dynamic>>>(
                        stream: SupabaseService.streamPlaceMessages(placeId),
                        builder: (context, snapshot) {
                          if (snapshot.connectionState == ConnectionState.waiting) {
                            return const Center(child: CircularProgressIndicator(color: Color(0xFF2563EB)));
                          }
                          final messages = snapshot.data ?? [];
                          final cleanMessages = messages.where((m) => !_blockedUserIds.contains(m['user_id']?.toString())).toList();

                          if (cleanMessages.isEmpty) {
                            return Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: const [
                                  Icon(Icons.chat_bubble_outline_rounded, size: 40, color: Color(0xFF94A3B8)),
                                  SizedBox(height: 8),
                                  Text("No questions yet for this place.", style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF475569))),
                                  Text("Be the first to ask about food, hours, or crowds!", style: TextStyle(fontSize: 11.5, color: Color(0xFF94A3B8))),
                                ],
                              ),
                            );
                          }
                          return ListView.separated(
                            itemCount: cleanMessages.length,
                            separatorBuilder: (_, __) => const SizedBox(height: 8),
                            itemBuilder: (context, idx) {
                              final msg = cleanMessages[idx];
                              final msgId = msg['id']?.toString() ?? "";
                              final msgUserId = msg['user_id']?.toString() ?? "";
                              final sender = msg['user_name'] ?? "Explorer";
                              final text = msg['message'] ?? "";
                              final createdAt = msg['created_at'];
                              final isMe = msgUserId == _currentUserId;
                              final canManageMsg = isMe || _isAdmin;

                              final isMsgAdmin = _isAdmin && isMe;
                              final isMsgCreator = placeCreatorId.isNotEmpty && msgUserId == placeCreatorId;

                              return Align(
                                alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                                child: InkWell(
                                  onLongPress: () {
                                    if (canManageMsg) {
                                      _showMsgManageSheet(msgId, text);
                                    } else {
                                      _showScoutActionSheet(msgUserId, sender);
                                    }
                                  },
                                  borderRadius: BorderRadius.circular(14),
                                  child: Container(
                                    constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.82),
                                    margin: const EdgeInsets.symmetric(horizontal: 4),
                                    padding: const EdgeInsets.fromLTRB(12, 8, 12, 7),
                                    decoration: BoxDecoration(
                                      color: isMe ? const Color(0xFF1E40AF) : const Color(0xFFF1F5F9),
                                      borderRadius: BorderRadius.only(
                                        topLeft: const Radius.circular(16),
                                        topRight: const Radius.circular(16),
                                        bottomLeft: Radius.circular(isMe ? 16 : 4),
                                        bottomRight: Radius.circular(isMe ? 4 : 16),
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withOpacity(0.04),
                                          blurRadius: 3,
                                          offset: const Offset(0, 1),
                                        ),
                                      ],
                                    ),
                                    child: Column(
                                      crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Text(
                                              sender,
                                              style: TextStyle(
                                                fontWeight: FontWeight.w700,
                                                fontSize: 12.0,
                                                color: isMe ? Colors.white70 : const Color(0xFF0D9488),
                                              ),
                                            ),
                                            if (isMsgAdmin) ...[
                                              const SizedBox(width: 4),
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                                decoration: BoxDecoration(color: const Color(0xFFFEF3C7), borderRadius: BorderRadius.circular(4)),
                                                child: const Text("🛡️ Admin", style: TextStyle(fontSize: 8.5, fontWeight: FontWeight.bold, color: Color(0xFF92400E))),
                                              ),
                                            ] else if (isMsgCreator) ...[
                                              const SizedBox(width: 4),
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                                decoration: BoxDecoration(color: const Color(0xFFDCFCE7), borderRadius: BorderRadius.circular(4)),
                                                child: const Text("👤 Contributor", style: TextStyle(fontSize: 8.5, fontWeight: FontWeight.bold, color: Color(0xFF166534))),
                                              ),
                                            ],
                                            const SizedBox(width: 6),
                                            Text(
                                              _formatRelativeTime(createdAt),
                                              style: TextStyle(fontSize: 9.5, color: isMe ? Colors.white54 : const Color(0xFF94A3B8)),
                                            ),
                                            if (canManageMsg) ...[
                                              const SizedBox(width: 4),
                                              Icon(Icons.more_horiz_rounded, size: 12, color: isMe ? Colors.white60 : Colors.black38),
                                            ],
                                          ],
                                        ),
                                        const SizedBox(height: 3),
                                        Text(
                                          text,
                                          style: TextStyle(
                                            fontSize: 15.0,
                                            height: 1.35,
                                            fontWeight: FontWeight.w400,
                                            color: isMe ? Colors.white : const Color(0xFF111827),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            },
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: msgCtrl,
                            style: const TextStyle(fontSize: 15.0, color: Color(0xFF0F172A)),
                            decoration: InputDecoration(
                              hintText: "Ask about timings, fresh items, waiting...",
                              hintStyle: const TextStyle(fontSize: 13.5, color: Color(0xFF94A3B8)),
                              filled: true,
                              fillColor: const Color(0xFFF8FAFC),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          icon: const Icon(Icons.send_rounded, color: Color(0xFF2563EB)),
                          onPressed: () async {
                            final txt = msgCtrl.text.trim();
                            if (txt.isEmpty) return;

                            if (!await _ensureTosAccepted()) return;

                            final verdict = await SupabaseService.inspectWithOmniGuard(
                              text: txt,
                              userId: _currentUserId!,
                              userName: _currentUserName,
                              channelType: "qa",
                            );

                            if (verdict['allowed'] != true) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(backgroundColor: const Color(0xFFDC2626), content: Text(verdict['reason'] ?? "Blocked")),
                              );
                              return;
                            }

                            msgCtrl.clear();
                            await SupabaseService.postPlaceMessage(
                              placeId: placeId,
                              userId: _currentUserId!,
                              userName: _currentUserName,
                              message: txt,
                            );
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showMsgManageSheet(String msgId, String oldText) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.edit_rounded, color: Color(0xFF2563EB)),
              title: const Text("Edit Message", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              onTap: () {
                Navigator.pop(ctx);
                _showEditMessageDialog(msgId, oldText);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline_rounded, color: Color(0xFFDC2626)),
              title: const Text("Delete Message", style: TextStyle(color: Color(0xFFDC2626), fontWeight: FontWeight.bold)),
              onTap: () async {
                Navigator.pop(ctx);
                await SupabaseService.client.from('community_place_messages').delete().eq('id', msgId);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showEditMessageDialog(String msgId, String oldText) {
    final editCtrl = TextEditingController(text: oldText);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text("Edit Question / Reply", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 15)),
        content: TextField(controller: editCtrl, decoration: const InputDecoration(border: OutlineInputBorder(), hintText: "Update message...")),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2563EB)),
            onPressed: () async {
              final newText = editCtrl.text.trim();
              if (newText.isNotEmpty) {
                await SupabaseService.client.from('community_place_messages').update({'message': newText}).eq('id', msgId);
              }
              Navigator.pop(ctx);
            },
            child: const Text("Save", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _openCityPulseRoom() {
    final TextEditingController pulseCtrl = TextEditingController();
    final ScrollController scrollCtrl = ScrollController();
    DateTime? lastBroadcastTyping;

    void broadcastTyping() {
      final now = DateTime.now();
      if (lastBroadcastTyping == null || now.difference(lastBroadcastTyping!).inSeconds > 2) {
        lastBroadcastTyping = now;
        _presenceChannel?.sendBroadcastMessage(
          event: 'typing',
          payload: {
            'user_id': _currentUserId,
            'user_name': _currentUserName,
          },
        );
      }
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            final keyboardPadding = MediaQuery.of(ctx).viewInsets.bottom;
            final systemNavPadding = MediaQuery.of(ctx).padding.bottom;
            final effectiveBottom = keyboardPadding > 0 ? keyboardPadding + 8 : systemNavPadding + 14;

            final displayScouts = List<Map<String, dynamic>>.from(_activeScouts);
            if (!displayScouts.any((s) => s['user_id'] == _currentUserId)) {
              displayScouts.insert(0, {'user_id': _currentUserId, 'user_name': '$_currentUserName (You)'});
            }

            return SizedBox(
              height: MediaQuery.of(context).size.height * 0.86,
              child: Padding(
                padding: EdgeInsets.fromLTRB(16, 12, 16, effectiveBottom),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 44,
                        height: 4,
                        decoration: BoxDecoration(color: const Color(0xFFCBD5E1), borderRadius: BorderRadius.circular(4)),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: const BoxDecoration(color: Color(0xFFFEF3C7), shape: BoxShape.circle),
                          child: const Icon(Icons.campaign_rounded, color: Color(0xFFD97706), size: 22),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "$_currentHubCity Community Pulse",
                                style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15.5, color: Color(0xFF0F172A)),
                              ),
                              Row(
                                children: [
                                  Container(width: 7, height: 7, decoration: const BoxDecoration(color: Color(0xFF16A34A), shape: BoxShape.circle)),
                                  const SizedBox(width: 5),
                                  Text(
                                    "${displayScouts.length} Active Now",
                                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF16A34A)),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        IconButton(icon: const Icon(Icons.close_rounded), onPressed: () => Navigator.pop(ctx)),
                      ],
                    ),

                    const SizedBox(height: 10),
                    SizedBox(
                      height: 32,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: displayScouts.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 6),
                        itemBuilder: (context, idx) {
                          final s = displayScouts[idx];
                          final sName = s['user_name'] ?? 'Scout';
                          final sId = s['user_id'] ?? '';
                          final isMe = sId == _currentUserId;

                          return InkWell(
                            onTap: isMe ? null : () => _showScoutActionSheet(sId, sName),
                            borderRadius: BorderRadius.circular(16),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                              decoration: BoxDecoration(
                                color: isMe ? const Color(0xFFF1F5F9) : const Color(0xFFEFF6FF),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: isMe ? const Color(0xFFCBD5E1) : const Color(0xFFBFDBFE)),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(width: 6, height: 6, decoration: const BoxDecoration(color: Color(0xFF16A34A), shape: BoxShape.circle)),
                                  const SizedBox(width: 5),
                                  Text(
                                    sName,
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: isMe ? const Color(0xFF475569) : const Color(0xFF1D4ED8),
                                    ),
                                  ),
                                  if (!isMe) ...[
                                    const SizedBox(width: 4),
                                    const Icon(Icons.touch_app_rounded, size: 11, color: Color(0xFF2563EB)),
                                  ],
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),

                    const Divider(height: 16),

                    Expanded(
                      child: StreamBuilder<List<Map<String, dynamic>>>(
                        stream: SupabaseService.streamCityPulse(_currentHubCity),
                        builder: (context, snapshot) {
                          if (snapshot.connectionState == ConnectionState.waiting) {
                            return const Center(child: CircularProgressIndicator(color: Color(0xFF2563EB)));
                          }
                          final list = snapshot.data ?? [];
                          final cleanList = list.where((m) => !_blockedUserIds.contains(m['user_id']?.toString())).toList();

                          if (cleanList.isEmpty) {
                            return Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: const [
                                  Icon(Icons.forum_outlined, size: 40, color: Color(0xFF94A3B8)),
                                  SizedBox(height: 8),
                                  Text("No updates yet in this city.", style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF475569))),
                                  Text("Say hi or ask about local traffic & spots!", style: TextStyle(fontSize: 11.5, color: Color(0xFF94A3B8))),
                                ],
                              ),
                            );
                          }

                          return ListView.separated(
                            controller: scrollCtrl,
                            itemCount: cleanList.length,
                            separatorBuilder: (_, __) => const SizedBox(height: 8),
                            itemBuilder: (context, idx) {
                              final item = cleanList[idx];
                              final sender = item['user_name'] ?? "Local Scout";
                              final senderId = item['user_id'] ?? "";
                              final content = item['content'] ?? "";
                              final createdAt = item['created_at'];
                              final isMe = senderId == _currentUserId;

                              return Align(
                                alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                                child: Container(
                                  constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.82),
                                  margin: const EdgeInsets.symmetric(horizontal: 4),
                                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 7),
                                  decoration: BoxDecoration(
                                    color: isMe ? const Color(0xFF1E40AF) : const Color(0xFFF1F5F9),
                                    borderRadius: BorderRadius.only(
                                      topLeft: const Radius.circular(16),
                                      topRight: const Radius.circular(16),
                                      bottomLeft: Radius.circular(isMe ? 16 : 4),
                                      bottomRight: Radius.circular(isMe ? 4 : 16),
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.04),
                                        blurRadius: 3,
                                        offset: const Offset(0, 1),
                                      ),
                                    ],
                                  ),
                                  child: Column(
                                    crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                                    children: [
                                      if (!isMe) ...[
                                        InkWell(
                                          onTap: () => _showScoutActionSheet(senderId, sender),
                                          child: Text(
                                            sender,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w700,
                                              fontSize: 12.5,
                                              color: Color(0xFF0D9488),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(height: 3),
                                      ],
                                      Text(
                                        content,
                                        style: TextStyle(
                                          fontSize: 15.2,
                                          height: 1.35,
                                          fontWeight: FontWeight.w400,
                                          color: isMe ? Colors.white : const Color(0xFF111827),
                                        ),
                                      ),
                                      const SizedBox(height: 3),
                                      Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text(
                                            _formatRelativeTime(createdAt),
                                            style: TextStyle(
                                              fontSize: 10.5,
                                              fontWeight: FontWeight.w500,
                                              color: isMe ? Colors.white70 : const Color(0xFF94A3B8),
                                            ),
                                          ),
                                          if (isMe) ...[
                                            const SizedBox(width: 4),
                                            const Icon(Icons.done_all_rounded, size: 13, color: Colors.white70),
                                          ],
                                          if (_isAdmin) ...[
                                            const SizedBox(width: 6),
                                            InkWell(
                                              onTap: () async {
                                                await SupabaseService.client.from('community_city_pulse').delete().eq('id', item['id']);
                                              },
                                              child: Icon(Icons.delete_outline_rounded, size: 14, color: isMe ? Colors.white70 : const Color(0xFFDC2626)),
                                            ),
                                          ],
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          );
                        },
                      ),
                    ),

                    if (_remoteTypingUser != null) ...[
                      Padding(
                        padding: const EdgeInsets.only(top: 4, bottom: 2, left: 4),
                        child: Row(
                          children: [
                            const SizedBox(
                              width: 10,
                              height: 10,
                              child: CircularProgressIndicator(strokeWidth: 1.5, color: Color(0xFF2563EB)),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              "$_remoteTypingUser is typing...",
                              style: const TextStyle(fontSize: 11, fontStyle: FontStyle.italic, color: Color(0xFF64748B)),
                            ),
                          ],
                        ),
                      ),
                    ],

                    const SizedBox(height: 6),

                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: pulseCtrl,
                            style: const TextStyle(fontSize: 15.0, color: Color(0xFF0F172A)),
                            onChanged: (val) {
                              if (val.trim().isNotEmpty) {
                                broadcastTyping();
                              }
                            },
                            decoration: InputDecoration(
                              hintText: "Post an update or tip (e.g. Ferry open till 7 PM...)",
                              hintStyle: const TextStyle(fontSize: 13.5, color: Color(0xFF94A3B8)),
                              filled: true,
                              fillColor: const Color(0xFFF8FAFC),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          icon: const Icon(Icons.send_rounded, color: Color(0xFF2563EB)),
                          onPressed: () async {
                            final txt = pulseCtrl.text.trim();
                            if (txt.isEmpty) return;

                            if (!await _ensureTosAccepted()) return;

                            final verdict = await SupabaseService.inspectWithOmniGuard(
                              text: txt,
                              userId: _currentUserId!,
                              userName: _currentUserName,
                              channelType: "pulse",
                            );

                            if (verdict['allowed'] != true) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(backgroundColor: const Color(0xFFDC2626), content: Text(verdict['reason'] ?? "Blocked")),
                              );
                              return;
                            }

                            HapticFeedback.lightImpact();
                            pulseCtrl.clear();
                            await SupabaseService.postCityPulse(
                              city: _currentHubCity,
                              userId: _currentUserId!,
                              userName: _currentUserName,
                              content: txt,
                            );

                            if (scrollCtrl.hasClients) {
                              scrollCtrl.animateTo(
                                0.0,
                                duration: const Duration(milliseconds: 300),
                                curve: Curves.easeOut,
                              );
                            }
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _translateTipInline(String placeId, String originalText) async {
    if (_translatingPlaceIds.contains(placeId)) return;

    if (_translatedTips.containsKey(placeId)) {
      setState(() => _translatedTips.remove(placeId));
      return;
    }

    setState(() => _translatingPlaceIds.add(placeId));

    try {
      final cleanUrl = widget.backendUrl.replaceAll(RegExp(r'/+$'), '');
      final res = await http.post(
        Uri.parse("$cleanUrl/api/v1/chat"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "message": "Translate this local place review accurately into $_activeLanguage. Output the translation only without commentary: \"$originalText\"",
          "target_language": _activeLanguage,
        }),
      ).timeout(const Duration(seconds: 6));

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final translated = (data["reply"] ?? data["answer"] ?? "").toString().trim().replaceAll('"', '');
        if (translated.isNotEmpty && mounted) {
          setState(() {
            _translatedTips[placeId] = translated;
          });
        }
      }
    } catch (_) {} finally {
      if (mounted) setState(() => _translatingPlaceIds.remove(placeId));
    }
  }

  void _bookmarkToMyTrip(Map<String, dynamic> gem) async {
    HapticFeedback.mediumImpact();
    final name = gem['name'] ?? "Local Spot";
    final category = gem['category'] ?? "Community Gem";
    final addr = gem['address'] ?? _currentHubCity;

    await TripStateService.addItineraryItem(
      name,
      category,
      "Community Gem • $addr",
      scheduledDateTime: DateTime.now().add(const Duration(hours: 3)),
    );

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(backgroundColor: const Color(0xFF16A34A), content: Text("✓ Added '$name' to your Home Dashboard Schedule!"), duration: const Duration(seconds: 2)),
      );
    }
  }

  void _showEndorseSheet(Map<String, dynamic> gem) {
    final availableTags = [
      "🕒 24 Hours",
      "💳 UPI Accepted",
      "🛵 Home Delivery",
      "❄️ AC Seating",
      "🌿 Pure Veg",
      "💰 Budget Friendly",
      "🅿️ Parking Available",
      "📶 Free Wi-Fi",
    ];

    List<String> currentTags = [];
    if (gem['endorsement_tags'] is List) {
      currentTags = List<String>.from(gem['endorsement_tags']);
    }

    final selectedTags = Set<String>.from(currentTags);
    final tipController = TextEditingController(text: gem['must_try_tip'] ?? "");

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) {
          final bottomInset = MediaQuery.of(ctx).viewInsets.bottom;
          final systemNavInset = MediaQuery.of(ctx).padding.bottom;

          return Container(
            padding: EdgeInsets.fromLTRB(20, 16, 20, bottomInset > 0 ? bottomInset + 16 : systemNavInset + 20),
            decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: const Color(0xFFCBD5E1), borderRadius: BorderRadius.circular(10)))),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      const Icon(Icons.verified_rounded, color: Color(0xFF2563EB), size: 22),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          "${_t("endorse_btn")} ${gem['name']}",
                          style: const TextStyle(fontSize: 16.5, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  const Text("Tap highlights to assist community travelers:", style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: availableTags.map((tag) {
                      final isSelected = selectedTags.contains(tag);
                      return FilterChip(
                        label: Text(tag, style: TextStyle(fontSize: 12, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
                        selected: isSelected,
                        selectedColor: const Color(0xFFDBEAFE),
                        checkmarkColor: const Color(0xFF2563EB),
                        labelStyle: TextStyle(color: isSelected ? const Color(0xFF1E40AF) : const Color(0xFF334155)),
                        onSelected: (val) {
                          setSheetState(() {
                            if (val) {
                              selectedTags.add(tag);
                            } else {
                              selectedTags.remove(tag);
                            }
                          });
                        },
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 16),
                  const Text("Quick Tip / Must-Try (Max 100 chars)", style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: Color(0xFF334155))),
                  const SizedBox(height: 6),
                  TextField(
                    controller: tipController,
                    maxLength: 100,
                    decoration: InputDecoration(
                      hintText: "e.g. Try the special seafood thali or 24/7 night counter",
                      hintStyle: const TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
                      filled: true,
                      fillColor: const Color(0xFFF8FAFC),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    ),
                  ),
                  const SizedBox(height: 12),
                  MetallicEmbossedButton(
                    label: _t("endorse_btn").toUpperCase(),
                    icon: Icons.star_rounded,
                    variant: MetallicVariant.emeraldGreen,
                    height: 44,
                    fontSize: 12.5,
                    isFullWidth: true,
                    onPressed: () async {
                      final updatedTags = selectedTags.toList();
                      final updatedTip = tipController.text.trim();
                      final placeId = gem['id']?.toString();

                      int currentUpvotes = (gem['upvotes'] as num?)?.toInt() ?? 0;
                      if (placeId != null && !_upvotedGemIds.contains(placeId)) {
                        currentUpvotes += 1;
                        _upvotedGemIds.add(placeId);
                        final prefs = await SharedPreferences.getInstance();
                        await prefs.setStringList(_upvoteStorageKey, _upvotedGemIds.toList());
                      }

                      setState(() {
                        gem['endorsement_tags'] = updatedTags;
                        if (updatedTip.isNotEmpty) {
                          gem['must_try_tip'] = updatedTip;
                        }
                        gem['upvotes'] = currentUpvotes;
                      });

                      Navigator.pop(ctx);

                      try {
                        await SupabaseService.client
                            .from('community_places')
                            .update({
                              'endorsement_tags': updatedTags,
                              'must_try_tip': updatedTip,
                              'upvotes': currentUpvotes,
                            })
                            .eq('id', gem['id']);
                      } catch (_) {}

                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(backgroundColor: Color(0xFF16A34A), content: Text("✓ Endorsement recorded!")),
                      );
                    },
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _launchMaps(String customUrl, String placeName, dynamic rawLat, dynamic rawLon) async {
    HapticFeedback.mediumImpact();
    double? lat = double.tryParse(rawLat?.toString() ?? "");
    double? lon = double.tryParse(rawLon?.toString() ?? "");

    final Uri mapUri;
    if (lat != null && lon != null && lat != 0.0 && lon != 0.0) {
      mapUri = Uri.parse("google.navigation:q=$lat,$lon&mode=d");
    } else if (customUrl.isNotEmpty && customUrl.startsWith("http")) {
      mapUri = Uri.parse(customUrl);
    } else {
      mapUri = Uri.parse("https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent('$placeName, $_currentHubCity')}");
    }

    try {
      if (!await launchUrl(mapUri, mode: LaunchMode.externalApplication)) {
        await launchUrl(mapUri, mode: LaunchMode.platformDefault);
      }
    } catch (_) {
      final fallbackWeb = Uri.parse("https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent('$placeName, $_currentHubCity')}");
      await launchUrl(fallbackWeb, mode: LaunchMode.inAppBrowserView);
    }
  }

  Future<void> _callPhone(String phone) async {
    final clean = phone.replaceAll(RegExp(r'[^0-9+]'), '');
    if (clean.isEmpty) return;
    final uri = Uri.parse("tel:$clean");
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {}
  }

  Future<void> _launchWhatsApp(String phone, String placeName) async {
    HapticFeedback.lightImpact();
    String clean = phone.replaceAll(RegExp(r'[^0-9]'), '');
    if (clean.isEmpty) return;

    if (clean.length == 10) {
      clean = "91$clean";
    }

    final message = "Hello $placeName, inquiring via Omni TouristOS.";
    final appUri = Uri.parse("whatsapp://send?phone=$clean&text=${Uri.encodeComponent(message)}");
    final webUri = Uri.parse("https://wa.me/$clean?text=${Uri.encodeComponent(message)}");

    try {
      if (!await launchUrl(appUri, mode: LaunchMode.externalApplication)) {
        await launchUrl(webUri, mode: LaunchMode.externalApplication);
      }
    } catch (_) {
      await launchUrl(webUri, mode: LaunchMode.inAppBrowserView);
    }
  }

  List<Map<String, dynamic>> get _filteredPlaces {
    return _places.where((p) {
      final matchesCategory = _selectedCategory == "All" || p['category'] == _selectedCategory;

      final q = _searchQuery.toLowerCase().trim();
      if (q.isEmpty) return matchesCategory;

      final name = (p['name'] ?? '').toString().toLowerCase();
      final address = (p['address'] ?? '').toString().toLowerCase();
      final desc = (p['description'] ?? '').toString().toLowerCase();
      final cat = (p['category'] ?? '').toString().toLowerCase();
      final city = (p['city'] ?? '').toString().toLowerCase();
      final tip = (p['must_try_tip'] ?? '').toString().toLowerCase();

      return matchesCategory &&
          (name.contains(q) || address.contains(q) || desc.contains(q) || cat.contains(q) || city.contains(q) || tip.contains(q));
    }).toList();
  }

  IconData _getCategoryIcon(String category) {
    final match = _filterCategories.firstWhere(
      (c) => (c["label"] as String).toLowerCase() == category.toLowerCase(),
      orElse: () => {"icon": Icons.place_rounded},
    );
    return match["icon"] as IconData;
  }

  Color _getCategoryColor(String category) {
    final match = _filterCategories.firstWhere(
      (c) => (c["label"] as String).toLowerCase() == category.toLowerCase(),
      orElse: () => {"color": const Color(0xFF2563EB)},
    );
    return match["color"] as Color;
  }

  Widget _buildCleanHeaderBar() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 4, 16, 6),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 6, offset: const Offset(0, 2)),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(color: const Color(0xFFEFF6FF), borderRadius: BorderRadius.circular(10)),
            child: const Icon(Icons.location_on_rounded, color: Color(0xFF2563EB), size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "$_currentHubCity Hub",
                  style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14.5, color: Color(0xFF0F172A)),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  "${_places.length} Verified Spots • 🟢 ${_activeScouts.length + 1} Scouts Online",
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF16A34A)),
                ),
              ],
            ),
          ),
          InkWell(
            onTap: _openCityPulseRoom,
            borderRadius: BorderRadius.circular(8),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF3C7),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFFDE68A)),
              ),
              child: Row(
                children: const [
                  Icon(Icons.forum_rounded, color: Color(0xFFD97706), size: 13),
                  SizedBox(width: 4),
                  Text("Pulse", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF92400E))),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).padding.bottom;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: const Color(0xFFF8FAFC),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Color(0xFF0F172A), size: 24),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          "Community Gems",
          style: TextStyle(fontWeight: FontWeight.w900, fontSize: 17, color: Color(0xFF0F172A)),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 6),
            child: InkWell(
              onTap: _openCityPulseRoom,
              borderRadius: BorderRadius.circular(16),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF3C7),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFFDE68A)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Stack(
                      alignment: Alignment.topRight,
                      children: [
                        const Icon(Icons.campaign_rounded, color: Color(0xFFD97706), size: 16),
                        Container(width: 6, height: 6, decoration: const BoxDecoration(color: Color(0xFF16A34A), shape: BoxShape.circle)),
                      ],
                    ),
                    const SizedBox(width: 4),
                    const Text("Pulse", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11.5, color: Color(0xFF92400E))),
                  ],
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: InkWell(
              onTap: _showLanguageSelectorModal,
              borderRadius: BorderRadius.circular(16),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFBFDBFE)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.language_rounded, color: Color(0xFF2563EB), size: 14),
                    const SizedBox(width: 4),
                    Text(_activeLanguage, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Color(0xFF1E40AF))),
                    const Icon(Icons.arrow_drop_down, color: Color(0xFF2563EB), size: 14),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: Container(
        padding: EdgeInsets.fromLTRB(16, 8, 16, bottomInset > 0 ? bottomInset + 8 : 14),
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
        ),
        child: MetallicEmbossedButton(
          label: _t("add_gem_btn").toUpperCase(),
          icon: Icons.add_business_rounded,
          variant: MetallicVariant.cobaltBlue,
          height: 46,
          fontSize: 12.5,
          isFullWidth: true,
          onPressed: () async {
            final result = await Navigator.push(
              context,
              MaterialPageRoute(builder: (ctx) => ContributePlaceScreen(activeCity: _currentHubCity)),
            );
            if (result == true) _loadPlacesForCity(_currentHubCity);
          },
        ),
      ),
      body: Column(
        children: [
          _buildCleanHeaderBar(),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 6),
            child: TextField(
              controller: _searchCtrl,
              textInputAction: TextInputAction.search,
              onSubmitted: _executeActiveSearch,
              decoration: InputDecoration(
                hintText: _t("search_hint"),
                hintStyle: const TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
                prefixIcon: IconButton(
                  icon: const Icon(Icons.search_rounded, color: Color(0xFF2563EB), size: 22),
                  onPressed: () => _executeActiveSearch(_searchCtrl.text),
                ),
                suffixIcon: _searchCtrl.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear_rounded, size: 18, color: Colors.grey),
                        onPressed: () {
                          _searchCtrl.clear();
                          _executeActiveSearch("");
                        },
                      )
                    : null,
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(vertical: 10),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
              ),
            ),
          ),
          SizedBox(
            height: 44,
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              scrollDirection: Axis.horizontal,
              itemCount: _filterCategories.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final item = _filterCategories[index];
                final rawLabel = item["label"] as String;
                final localizedLabel = _t(rawLabel);
                final icon = item["icon"] as IconData;
                final isSelected = rawLabel == _selectedCategory;

                return ChoiceChip(
                  avatar: Icon(icon, size: 15, color: isSelected ? Colors.white : item["color"] as Color),
                  label: Text(
                    localizedLabel,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                      color: isSelected ? Colors.white : const Color(0xFF334155),
                    ),
                  ),
                  selected: isSelected,
                  selectedColor: const Color(0xFF2563EB),
                  backgroundColor: Colors.white,
                  side: BorderSide(color: isSelected ? const Color(0xFF2563EB) : const Color(0xFFCBD5E1)),
                  onSelected: (selected) {
                    if (selected) setState(() => _selectedCategory = rawLabel);
                  },
                );
              },
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: Color(0xFF2563EB)))
                : _filteredPlaces.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.storefront_outlined, size: 52, color: Colors.grey.shade400),
                              const SizedBox(height: 12),
                              Text(
                                _searchQuery.isNotEmpty ? "No matching spots found for '$_searchQuery'" : "No neighborhood spots listed yet in $_currentHubCity",
                                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF475569)),
                              ),
                              const SizedBox(height: 6),
                              const Text("Be the first to list a barber, chemist, or food stall!", textAlign: TextAlign.center, style: TextStyle(fontSize: 12.5, color: Color(0xFF94A3B8))),
                            ],
                          ),
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: () async {
                          await _fetchUserLocation();
                          await _loadPlacesForCity(_currentHubCity);
                        },
                        color: const Color(0xFF2563EB),
                        child: ListView.separated(
                          padding: const EdgeInsets.fromLTRB(16, 6, 16, 24),
                          itemCount: _filteredPlaces.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 12),
                          itemBuilder: (context, index) {
                            final gem = _filteredPlaces[index];
                            final idStr = (gem['id'] ?? '').toString();
                            final name = gem['name'] ?? 'Local Spot';
                            final category = gem['category'] ?? 'General';
                            final address = gem['address'] ?? '';
                            final city = gem['city'] ?? _currentHubCity;
                            final description = gem['description'] ?? '';
                            final phone = (gem['contact_phone'] ?? '').toString().trim();
                            final mapsUrl = (gem['maps_url'] ?? '').toString().trim();
                            final contributor = gem['contributor_name'] ?? 'Local Resident';
                            final upvotes = (gem['upvotes'] as num?)?.toInt() ?? 0;
                            final originalTip = (gem['must_try_tip'] ?? '').toString().trim();
                            final imageUrl = gem['image_url'] as String?;
                            final lat = gem['latitude'];
                            final lon = gem['longitude'];
                            final createdBy = (gem['created_by_user_id'] ?? '').toString();

                            final hasVoted = _upvotedGemIds.contains(idStr);
                            final isTranslating = _translatingPlaceIds.contains(idStr);
                            final displayTip = _translatedTips[idStr] ?? originalTip;
                            final hasTranslated = _translatedTips.containsKey(idStr);

                            final bool canManage = _isAdmin ||
                                (_currentUserId != null &&
                                    _currentUserId!.isNotEmpty &&
                                    _currentUserId == createdBy);

                            List<String> tags = [];
                            if (gem['endorsement_tags'] is List) {
                              tags = List<String>.from(gem['endorsement_tags']);
                            }

                            final accentColor = _getCategoryColor(category);
                            final distanceStr = _calculateDistance(gem);

                            return Container(
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: const Color(0xFFE2E8F0)),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.02),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (imageUrl != null && imageUrl.isNotEmpty) ...[
                                    ClipRRect(
                                      borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                                      child: Image.network(
                                        imageUrl,
                                        height: 160,
                                        width: double.infinity,
                                        fit: BoxFit.cover,
                                        errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                                      ),
                                    ),
                                  ],
                                  Padding(
                                    padding: const EdgeInsets.all(16),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Container(
                                              padding: const EdgeInsets.all(10),
                                              decoration: BoxDecoration(
                                                color: accentColor.withOpacity(0.12),
                                                shape: BoxShape.circle,
                                              ),
                                              child: Icon(_getCategoryIcon(category), color: accentColor, size: 22),
                                            ),
                                            const SizedBox(width: 12),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    name,
                                                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
                                                  ),
                                                  const SizedBox(height: 4),
                                                  Wrap(
                                                    crossAxisAlignment: WrapCrossAlignment.center,
                                                    spacing: 6,
                                                    runSpacing: 4,
                                                    children: [
                                                      Container(
                                                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                                        decoration: BoxDecoration(color: accentColor.withOpacity(0.08), borderRadius: BorderRadius.circular(6)),
                                                        child: Text(
                                                          _t(category),
                                                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: accentColor),
                                                        ),
                                                      ),
                                                      Container(
                                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                        decoration: BoxDecoration(color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(6)),
                                                        child: Text(
                                                          city,
                                                          style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: Color(0xFF475569)),
                                                        ),
                                                      ),
                                                      if (distanceStr.isNotEmpty)
                                                        Container(
                                                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                                          decoration: BoxDecoration(
                                                            color: const Color(0xFFEFF6FF),
                                                            borderRadius: BorderRadius.circular(6),
                                                            border: Border.all(color: const Color(0xFFBFDBFE)),
                                                          ),
                                                          child: Text(
                                                            distanceStr,
                                                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF1D4ED8)),
                                                          ),
                                                        ),
                                                    ],
                                                  ),
                                                ],
                                              ),
                                            ),
                                            Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                InkWell(
                                                  borderRadius: BorderRadius.circular(20),
                                                  onTap: () => _handleUpvote(gem),
                                                  child: Container(
                                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                                    decoration: BoxDecoration(
                                                      color: hasVoted ? const Color(0xFF2563EB) : const Color(0xFFEFF6FF),
                                                      borderRadius: BorderRadius.circular(20),
                                                      border: Border.all(color: hasVoted ? const Color(0xFF1D4ED8) : const Color(0xFFBFDBFE)),
                                                    ),
                                                    child: Row(
                                                      mainAxisSize: MainAxisSize.min,
                                                      children: [
                                                        Icon(Icons.thumb_up_rounded, size: 13, color: hasVoted ? Colors.white : const Color(0xFF2563EB)),
                                                        const SizedBox(width: 5),
                                                        Text(
                                                          "$upvotes",
                                                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: hasVoted ? Colors.white : const Color(0xFF1E40AF)),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                ),
                                                if (canManage) ...[
                                                  const SizedBox(width: 4),
                                                  PopupMenuButton<String>(
                                                    padding: EdgeInsets.zero,
                                                    icon: const Icon(Icons.more_vert_rounded, size: 20, color: Color(0xFF64748B)),
                                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                                    onSelected: (val) {
                                                      if (val == 'edit') {
                                                        _showEditPlaceModal(gem);
                                                      } else if (val == 'delete') {
                                                        _deletePlaceListing(gem);
                                                      }
                                                    },
                                                    itemBuilder: (ctx) => [
                                                      PopupMenuItem(
                                                        value: 'edit',
                                                        child: Row(
                                                          children: [
                                                            const Icon(Icons.edit_rounded, color: Color(0xFF2563EB), size: 18),
                                                            const SizedBox(width: 8),
                                                            Text(_t("edit_gem"), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5)),
                                                          ],
                                                        ),
                                                      ),
                                                      PopupMenuItem(
                                                        value: 'delete',
                                                        child: Row(
                                                          children: [
                                                            const Icon(Icons.delete_outline_rounded, color: Color(0xFFDC2626), size: 18),
                                                            const SizedBox(width: 8),
                                                            Text(_t("delete_gem"), style: const TextStyle(color: Color(0xFFDC2626), fontWeight: FontWeight.bold, fontSize: 12.5)),
                                                          ],
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ],
                                              ],
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 10),
                                        Row(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            const Icon(Icons.location_on_rounded, size: 15, color: Color(0xFF64748B)),
                                            const SizedBox(width: 5),
                                            Expanded(
                                              child: Text(
                                                address,
                                                style: const TextStyle(fontSize: 12.5, color: Color(0xFF475569), fontWeight: FontWeight.w500),
                                              ),
                                            ),
                                          ],
                                        ),
                                        if (tags.isNotEmpty) ...[
                                          const SizedBox(height: 8),
                                          Wrap(
                                            spacing: 6,
                                            runSpacing: 4,
                                            children: tags.map((t) {
                                              return Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                                decoration: BoxDecoration(color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(6), border: Border.all(color: const Color(0xFFE2E8F0))),
                                                child: Text(t, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF334155))),
                                              );
                                            }).toList(),
                                          ),
                                        ],
                                        if (displayTip.isNotEmpty) ...[
                                          const SizedBox(height: 8),
                                          Container(
                                            width: double.infinity,
                                            padding: const EdgeInsets.all(10),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFFFEFCE8),
                                              borderRadius: BorderRadius.circular(10),
                                              border: Border.all(color: const Color(0xFFFEF08A)),
                                            ),
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Row(
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  children: [
                                                    const Text("💡 ", style: TextStyle(fontSize: 13)),
                                                    Expanded(
                                                      child: Text(
                                                        displayTip,
                                                        style: const TextStyle(fontSize: 12, color: Color(0xFF854D0E), fontWeight: FontWeight.w600, height: 1.35),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                                const SizedBox(height: 6),
                                                Align(
                                                  alignment: Alignment.centerRight,
                                                  child: InkWell(
                                                    onTap: isTranslating ? null : () => _translateTipInline(idStr, originalTip),
                                                    borderRadius: BorderRadius.circular(6),
                                                    child: Padding(
                                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                      child: Row(
                                                        mainAxisSize: MainAxisSize.min,
                                                        children: [
                                                          if (isTranslating)
                                                            const SizedBox(width: 10, height: 10, child: CircularProgressIndicator(strokeWidth: 1.5, color: Color(0xFFB45309)))
                                                          else
                                                            Icon(hasTranslated ? Icons.undo_rounded : Icons.translate_rounded, size: 12, color: const Color(0xFFB45309)),
                                                          const SizedBox(width: 4),
                                                          Text(
                                                            hasTranslated ? _t("show_original") : "${_t("translate")} ($_activeLanguage)",
                                                            style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: Color(0xFFB45309)),
                                                          ),
                                                        ],
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ] else if (description.isNotEmpty) ...[
                                          const SizedBox(height: 8),
                                          Container(
                                            width: double.infinity,
                                            padding: const EdgeInsets.all(9),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFFF8FAFC),
                                              borderRadius: BorderRadius.circular(8),
                                              border: Border.all(color: const Color(0xFFF1F5F9)),
                                            ),
                                            child: Text(
                                              "“ $description",
                                              style: const TextStyle(fontSize: 12, color: Color(0xFF334155), height: 1.3),
                                            ),
                                          ),
                                        ],
                                        const SizedBox(height: 10),
                                        Row(
                                          children: [
                                            const Icon(Icons.person_outline_rounded, size: 13, color: Color(0xFF94A3B8)),
                                            const SizedBox(width: 4),
                                            Text(
                                              "${_t("recommended_by")} $contributor",
                                              style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8), fontWeight: FontWeight.w500),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 12),
                                        const Divider(height: 1),
                                        const SizedBox(height: 12),
                                        Row(
                                          children: [
                                            if (phone.isNotEmpty) ...[
                                              InkWell(
                                                onTap: () => _callPhone(phone),
                                                borderRadius: BorderRadius.circular(10),
                                                child: Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
                                                  decoration: BoxDecoration(color: const Color(0xFFF0FDF4), border: Border.all(color: const Color(0xFFBBF7D0)), borderRadius: BorderRadius.circular(10)),
                                                  child: Row(
                                                    children: const [
                                                      Icon(Icons.call_rounded, size: 14, color: Color(0xFF16A34A)),
                                                      SizedBox(width: 3),
                                                      Text("Call", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF16A34A))),
                                                    ],
                                                  ),
                                                ),
                                              ),
                                              const SizedBox(width: 6),
                                              InkWell(
                                                onTap: () => _launchWhatsApp(phone, name),
                                                borderRadius: BorderRadius.circular(10),
                                                child: Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
                                                  decoration: BoxDecoration(color: const Color(0xFFECFDF5), border: Border.all(color: const Color(0xFFA7F3D0)), borderRadius: BorderRadius.circular(10)),
                                                  child: Row(
                                                    children: const [
                                                      Icon(Icons.chat_bubble_rounded, size: 13, color: Color(0xFF059669)),
                                                      SizedBox(width: 3),
                                                      Text("WhatsApp", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF059669))),
                                                    ],
                                                  ),
                                                ),
                                              ),
                                              const SizedBox(width: 6),
                                            ],
                                            InkWell(
                                              onTap: () => _showAskLocalsModal(gem),
                                              borderRadius: BorderRadius.circular(10),
                                              child: Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
                                                decoration: BoxDecoration(color: const Color(0xFFEFF6FF), border: Border.all(color: const Color(0xFFBFDBFE)), borderRadius: BorderRadius.circular(10)),
                                                child: Row(
                                                  children: [
                                                    const Icon(Icons.forum_rounded, size: 13, color: Color(0xFF2563EB)),
                                                    const SizedBox(width: 3),
                                                    Text(_t("ask_locals"), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF2563EB))),
                                                  ],
                                                ),
                                              ),
                                            ),
                                            const Spacer(),
                                            InkWell(
                                              onTap: () => _bookmarkToMyTrip(gem),
                                              borderRadius: BorderRadius.circular(10),
                                              child: Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
                                                decoration: BoxDecoration(color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(10), border: Border.all(color: const Color(0xFFCBD5E1))),
                                                child: Row(
                                                  children: const [
                                                    Icon(Icons.bookmark_add_rounded, color: Color(0xFF334155), size: 14),
                                                    SizedBox(width: 3),
                                                    Text("+ My Trip", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF334155))),
                                                  ],
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 10),
                                        Row(
                                          children: [
                                            Expanded(
                                              child: MetallicEmbossedButton(
                                                label: _t("endorse_btn").toUpperCase(),
                                                icon: Icons.star_rounded,
                                                variant: MetallicVariant.titaniumSilver,
                                                height: 40,
                                                fontSize: 11.5,
                                                onPressed: () => _showEndorseSheet(gem),
                                              ),
                                            ),
                                            const SizedBox(width: 10),
                                            Expanded(
                                              child: MetallicEmbossedButton(
                                                label: _t("navigate_btn").toUpperCase(),
                                                icon: Icons.navigation_rounded,
                                                variant: MetallicVariant.cobaltBlue,
                                                height: 40,
                                                fontSize: 11.5,
                                                onPressed: () => _launchMaps(mapsUrl, name, lat, lon),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }
}