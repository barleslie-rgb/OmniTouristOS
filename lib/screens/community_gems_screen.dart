import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/supabase_service.dart';
import '../services/trip_state_service.dart';
import '../widgets/metallic_embossed_button.dart';
import 'contribute_place_screen.dart';
import 'community_pulse_chat_screen.dart';

class CommunityGemsScreen extends StatefulWidget {
  final String activeCity;
  final String language;
  final String backendUrl;

  const CommunityGemsScreen({
    super.key,
    required this.activeCity,
    this.language = "English",
    this.backendUrl = "https://omni-backend-pk28.onrender.com",
  });

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
    {"code": "fa", "name": "Persian", "native": "فارسی"},
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
      "add_gem_btn": "+ Add Local Gem",
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
      "add_gem_btn": "+ नवीन रत्न / जागा जोडा",
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
      "add_gem_btn": "+ नया रत्न / स्थान जोड़ें",
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
          "• No illicit goods, contraband, or unauthorized promotions.\n"
          "• Zero tolerance for harassment, scams, or abuse.\n"
          "• Messages & notices are supervised by OmniGuard AI.\n\n"
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

  void _shareAppInvite() {
    HapticFeedback.selectionClick();
    final inviteMessage = "Join me on Omni TouristOS! We're discovering verified neighborhood gems 💎, live transit cockpits, and sharing real-time tips in $_currentHubCity Gem Chat:\nhttps://touristos.app/invite/${_currentUserId ?? 'scout'}";
    Share.share(inviteMessage, subject: "Invite to Omni TouristOS Gem Chat");
  }

  void _shareNoticeFlyer(Map<String, dynamic> gem) {
    HapticFeedback.selectionClick();
    final name = gem['name'] ?? 'Local Spot';
    final title = gem['daily_notice_title'] ?? "Today's Special";
    final content = gem['daily_notice_content'] ?? "";
    final tag = gem['daily_notice_tag'] ?? "Special";
    final address = gem['address'] ?? _currentHubCity;

    final flyerText = "📢 [$tag] TODAY AT $name ($address):\n\n"
        "✨ $title\n"
        "${content.isNotEmpty ? "$content\n\n" : "\n"}"
        "Shared via Omni TouristOS Community Gems 💎\n"
        "https://touristos.app/gem/${gem['id'] ?? ''}";

    Share.share(flyerText, subject: "Today's Special at $name");
  }

  void _showNoticeFlyerModal(Map<String, dynamic> gem, bool canManage) {
    HapticFeedback.mediumImpact();
    final name = gem['name'] ?? "Local Spot";
    final category = gem['category'] ?? "Spot";
    final title = gem['daily_notice_title'] ?? "Notice";
    final content = gem['daily_notice_content'] ?? "";
    final tag = gem['daily_notice_tag'] ?? "Special";
    final address = gem['address'] ?? _currentHubCity;
    final expiresIso = gem['daily_notice_expires_at']?.toString();

    String expiresText = "Active Today";
    if (expiresIso != null && expiresIso.isNotEmpty) {
      try {
        final exp = DateTime.parse(expiresIso).toLocal();
        final diff = exp.difference(DateTime.now());
        if (diff.inHours > 0) {
          expiresText = "Valid for next ${diff.inHours} hours";
        } else if (diff.inMinutes > 0) {
          expiresText = "Valid for next ${diff.inMinutes} mins";
        }
      } catch (_) {}
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.78,
          decoration: const BoxDecoration(
            color: Color(0xFF0F172A),
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: Column(
            children: [
              Container(
                margin: const EdgeInsets.only(top: 12, bottom: 8),
                width: 44,
                height: 4,
                decoration: BoxDecoration(color: const Color(0xFF334155), borderRadius: BorderRadius.circular(10)),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.close_rounded, color: Colors.white70),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E293B),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: const Color(0xFF334155)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.schedule_rounded, color: Color(0xFFFCD34D), size: 14),
                          const SizedBox(width: 5),
                          Text(expiresText, style: const TextStyle(fontSize: 11, color: Color(0xFFFCD34D), fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(24, 8, 24, 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF59E0B),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          tag.toUpperCase(),
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: Colors.black87),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                          height: 1.25,
                        ),
                      ),
                      const SizedBox(height: 14),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1E293B),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: const Color(0xFF334155)),
                        ),
                        child: Text(
                          content.isNotEmpty ? content : "Notice published by the spot team.",
                          style: const TextStyle(
                            fontSize: 15,
                            color: Color(0xFFE2E8F0),
                            height: 1.45,
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      Row(
                        children: [
                          const Icon(Icons.storefront_rounded, color: Color(0xFF38BDF8), size: 18),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              name,
                              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Padding(
                        padding: const EdgeInsets.only(left: 26),
                        child: Text(
                          "$category • $address",
                          style: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                decoration: const BoxDecoration(
                  color: Color(0xFF0F172A),
                  border: Border(top: BorderSide(color: Color(0xFF1E293B))),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    MetallicEmbossedButton(
                      label: "SHARE FLYER (WHATSAPP / MESSENGER) 📤",
                      icon: Icons.share_rounded,
                      variant: MetallicVariant.cobaltBlue,
                      height: 46,
                      fontSize: 12.5,
                      isFullWidth: true,
                      onPressed: () {
                        Navigator.pop(ctx);
                        _shareNoticeFlyer(gem);
                      },
                    ),
                    if (canManage) ...[
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(
                                foregroundColor: const Color(0xFFDC2626),
                                side: const BorderSide(color: Color(0xFFEF4444)),
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              icon: const Icon(Icons.delete_outline_rounded, size: 18),
                              label: const Text("Delete Notice", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                              onPressed: () async {
                                final placeId = gem['id']?.toString() ?? "";
                                setState(() {
                                  gem['daily_notice_title'] = null;
                                  gem['daily_notice_content'] = null;
                                  gem['daily_notice_tag'] = null;
                                });
                                Navigator.pop(ctx);
                                await SupabaseService.clearDailyNotice(placeId);
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text("✓ Notice removed from spot.")),
                                  );
                                }
                              },
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF2563EB),
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              icon: const Icon(Icons.edit_rounded, size: 18, color: Colors.white),
                              label: const Text("Edit Notice", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.white)),
                              onPressed: () {
                                Navigator.pop(ctx);
                                _showDailyNoticeModal(gem);
                              },
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
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

      final livePos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 8),
        ),
      );
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
    if (mounted) setState(() { _isLoading = true; });
    try {
      final cleanUrl = widget.backendUrl.replaceAll(RegExp(r'/+$'), '');
      final hasSearch = _searchQuery.trim().isNotEmpty;
      final endpoint = hasSearch
          ? '/api/v1/community/place-discovery/search'
          : '/api/v1/community/places/search';
      final searchParams = <String, String>{
        'city': city,
        'category': _selectedCategory == 'All' ? 'All' : _selectedCategory,
        'limit': hasSearch ? '20' : '50',
      };
      if (hasSearch) {
        searchParams['q'] = _searchQuery.trim();
      }
      if (_userPosition != null) {
        searchParams['lat'] = _userPosition!.latitude.toString();
        searchParams['lng'] = _userPosition!.longitude.toString();
      }
      final uri = Uri.parse('$cleanUrl$endpoint').replace(queryParameters: searchParams);
      final response = await http.get(uri).timeout(const Duration(seconds: 30));
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw Exception('Community search returned ${response.statusCode}');
      }
      final decoded = jsonDecode(response.body);
      if (decoded is Map && decoded['provider'] != null) {
        debugPrint('Community Gems provider: ${decoded['provider']}');
      }
      final rows = decoded is Map ? decoded['places'] : null;
      if (rows is! List) throw Exception('Invalid Community Gems response');
      final data = rows.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
      if (!mounted) return;
      setState(() { _places = _deduplicatePlaces(data); _isLoading = false; });
    } catch (e) {
      // Keep the community database useful if the unified backend is temporarily unavailable.
      try {
        final data = await SupabaseService.getPlacesForCity(city);
        if (!mounted) return;
        setState(() { _places = _deduplicatePlaces(data); _isLoading = false; });
      } catch (_) {
        if (mounted) setState(() { _places = []; _isLoading = false; });
      }
      debugPrint('Community Gems live search: $e');
    }
  }

  Future<void> _executeActiveSearch(String query) async {
    final q = query.trim();
    setState(() { _searchQuery = q; });
    await _loadPlacesForCity(_currentHubCity);
  }

  String _calculateDistance(Map<String, dynamic> gem) {
    if (_userPosition == null) return "📍 Finding GPS...";

    double uLat = _userPosition!.latitude;
    double uLon = _userPosition!.longitude;

    double? lat = double.tryParse(gem['latitude']?.toString() ?? "");
    double? lon = double.tryParse(gem['longitude']?.toString() ?? "");

    if (lat == null || lon == null || (lat == 0.0 && lon == 0.0)) {
      return "📍 Within Neighborhood";
    }

    final distanceMeters = Geolocator.distanceBetween(uLat, uLon, lat, lon);
    final distanceKm = distanceMeters / 1000.0;

    if (distanceKm > 100) {
      return "📍 ${distanceKm.toStringAsFixed(0)} km away";
    } else if (distanceMeters < 1000) {
      return "📍 ${distanceMeters.round()}m away";
    } else {
      return "📍 ${distanceKm.toStringAsFixed(1)} km away";
    }
  }

  Future<void> _handleGemEndorsement(Map<String, dynamic> gem) async {
    final placeId = gem['id']?.toString();
    if (placeId == null) return;

    if (_upvotedGemIds.contains(placeId)) {
      HapticFeedback.lightImpact();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(backgroundColor: Color(0xFF475569), duration: Duration(seconds: 2), content: Text("You have already awarded a Gem 💎 to this spot.")),
      );
      return;
    }

    HapticFeedback.mediumImpact();
    final currentGems = (gem['upvotes'] as num?)?.toInt() ?? 0;
    final newCount = currentGems + 1;

    setState(() {
      gem['upvotes'] = newCount;
      _upvotedGemIds.add(placeId);
    });

    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_upvoteStorageKey, _upvotedGemIds.toList());
    await SupabaseService.endorseGem(placeId, currentGems);

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(backgroundColor: Color(0xFF16A34A), duration: Duration(seconds: 2), content: Text("✓ Gem awarded! Spot verified by community 💎")),
    );
  }

  void _showDailyNoticeModal(Map<String, dynamic> gem) {
    HapticFeedback.selectionClick();
    final titleCtrl = TextEditingController(text: gem['daily_notice_title'] ?? "");
    final contentCtrl = TextEditingController(text: gem['daily_notice_content'] ?? "");
    String selectedTag = gem['daily_notice_tag'] ?? "Special";

    final tags = ["Special", "Chef Special", "Offer / Discount", "Notice", "Fresh Batch", "Available Today"];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) {
        final bottomInset = MediaQuery.of(ctx).viewInsets.bottom;
        return StatefulBuilder(
          builder: (ctx, setNoticeState) => Container(
            padding: EdgeInsets.fromLTRB(20, 16, 20, bottomInset + 20),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: const Color(0xFFCBD5E1), borderRadius: BorderRadius.circular(10)))),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      const Icon(Icons.campaign_rounded, color: Color(0xFFD97706), size: 24),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          "Today's Special & Notice Board",
                          style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16.5, color: Color(0xFF0F172A)),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text("Post daily specials, fresh batches, or temporary announcements for ${gem['name']}.", style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                  const SizedBox(height: 14),
                  const Text("Notice Tag", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5, color: Color(0xFF334155))),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    children: tags.map((t) {
                      final isSelected = selectedTag == t;
                      return ChoiceChip(
                        label: Text(t, style: TextStyle(fontSize: 11, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
                        selected: isSelected,
                        selectedColor: const Color(0xFFFEF3C7),
                        labelStyle: TextStyle(color: isSelected ? const Color(0xFF92400E) : const Color(0xFF334155)),
                        onSelected: (val) => setNoticeState(() => selectedTag = t),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 12),
                  const Text("Headline / Special Title", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5, color: Color(0xFF334155))),
                  const SizedBox(height: 6),
                  TextField(
                    controller: titleCtrl,
                    decoration: InputDecoration(
                      hintText: "e.g. Fresh Surmai Fry / Lunch Combo @ ₹180",
                      filled: true,
                      fillColor: const Color(0xFFF8FAFC),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text("Details & Timings (Expires in 24 hours)", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5, color: Color(0xFF334155))),
                  const SizedBox(height: 6),
                  TextField(
                    controller: contentCtrl,
                    maxLines: 2,
                    maxLength: 140,
                    decoration: InputDecoration(
                      hintText: "e.g. Served fresh with solkadhi & rice until 4 PM. Call ahead to reserve.",
                      filled: true,
                      fillColor: const Color(0xFFF8FAFC),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      if ((gem['daily_notice_title'] ?? '').toString().isNotEmpty) ...[
                        OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFFDC2626),
                            side: const BorderSide(color: Color(0xFFFCA5A5)),
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          icon: const Icon(Icons.delete_outline_rounded, size: 16),
                          label: const Text("Clear Notice", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                          onPressed: () async {
                            final placeId = gem['id']?.toString() ?? "";
                            setState(() {
                              gem['daily_notice_title'] = null;
                              gem['daily_notice_content'] = null;
                              gem['daily_notice_tag'] = null;
                            });
                            Navigator.pop(ctx);
                            await SupabaseService.clearDailyNotice(placeId);
                          },
                        ),
                        const SizedBox(width: 8),
                      ],
                      Expanded(
                        child: MetallicEmbossedButton(
                          label: "PUBLISH TODAY'S NOTICE",
                          icon: Icons.check_circle_rounded,
                          variant: MetallicVariant.emeraldGreen,
                          height: 44,
                          fontSize: 12,
                          isFullWidth: true,
                          onPressed: () async {
                            final title = titleCtrl.text.trim();
                            final content = contentCtrl.text.trim();
                            if (title.isEmpty) return;

                            final placeId = gem['id']?.toString() ?? "";

                            setState(() {
                              gem['daily_notice_title'] = title;
                              gem['daily_notice_content'] = content;
                              gem['daily_notice_tag'] = selectedTag;
                              gem['daily_notice_expires_at'] = DateTime.now().add(const Duration(hours: 24)).toIso8601String();
                            });

                            Navigator.pop(ctx);
                            await SupabaseService.updateDailyNotice(
                              placeId: placeId,
                              title: title,
                              content: content,
                              tag: selectedTag,
                            );

                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(backgroundColor: Color(0xFF16A34A), content: Text("✓ Today's notice published to chalkboard!")),
                              );
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildDailyChalkboardCard(Map<String, dynamic> gem, bool canManage) {
    final title = (gem['daily_notice_title'] ?? '').toString().trim();
    final content = (gem['daily_notice_content'] ?? '').toString().trim();
    final tag = (gem['daily_notice_tag'] ?? 'Special').toString();
    final expiresIso = gem['daily_notice_expires_at']?.toString();

    bool isExpired = false;
    if (expiresIso != null && expiresIso.isNotEmpty) {
      try {
        final expiresAt = DateTime.parse(expiresIso);
        if (DateTime.now().isAfter(expiresAt)) isExpired = true;
      } catch (_) {}
    }

    if (title.isEmpty || isExpired) {
      if (!canManage) return const SizedBox.shrink();
      return Container(
        margin: const EdgeInsets.only(top: 8, bottom: 4),
        child: InkWell(
          onTap: () => _showDailyNoticeModal(gem),
          borderRadius: BorderRadius.circular(10),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFFFFFBEB),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFFDE68A)),
            ),
            child: Row(
              children: const [
                Icon(Icons.add_alert_rounded, size: 14, color: Color(0xFFD97706)),
                SizedBox(width: 6),
                Expanded(
                  child: Text(
                    "+ Post Today's Special / Notice",
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF92400E)),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.only(top: 10, bottom: 4),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 5,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => _showNoticeFlyerModal(gem, canManage),
          child: Padding(
            padding: const EdgeInsets.all(11),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF59E0B),
                        borderRadius: BorderRadius.circular(5),
                      ),
                      child: Text(
                        tag.toUpperCase(),
                        style: const TextStyle(fontSize: 9.5, fontWeight: FontWeight.w900, color: Colors.black87),
                      ),
                    ),
                    const SizedBox(width: 6),
                    const Text("TODAY'S SPECIAL", style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Color(0xFFFCD34D), letterSpacing: 0.5)),
                    const Spacer(),
                    const Icon(Icons.fullscreen_rounded, size: 16, color: Color(0xFF93C5FD)),
                  ],
                ),
                const SizedBox(height: 6),
                Text(title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: Colors.white)),
                if (content.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(content, style: const TextStyle(fontSize: 11.5, color: Color(0xFFCBD5E1), height: 1.3), maxLines: 2, overflow: TextOverflow.ellipsis),
                ],
              ],
            ),
          ),
        ),
      ),
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
                    initialValue: _filterCategories.any((c) => c['label'] == category) && category != "All" ? category : "Pharmacy / Chemist",
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
                  const Text("Phone Number", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5, color: Color(0xFF334155))),
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

                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(backgroundColor: Color(0xFF16A34A), content: Text("✓ Place details updated successfully!")),
                          );
                        }
                      } catch (e) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Failed to update: $e")));
                        }
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
                        if (ctx.mounted) Navigator.pop(ctx);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("✓ User blocked. Messages hidden.")));
                        }
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
                                    color: Colors.black.withValues(alpha: 0.04),
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
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(backgroundColor: const Color(0xFFDC2626), content: Text(verdict['reason'] ?? "Blocked")),
                            );
                          }
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
                if (ctx.mounted) Navigator.pop(ctx);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("✓ Scout blocked.")));
                }
              },
            ),
            if (_isAdmin) ...[
              ListTile(
                leading: const Icon(Icons.gavel_rounded, color: Colors.black87),
                title: const Text("Admin: Ban User Account", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5)),
                onTap: () async {
                  await SupabaseService.banUser(scoutId, "Administrative safety ban");
                  if (ctx.mounted) Navigator.pop(ctx);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("✓ User account banned.")));
                  }
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
                              final senderAvatar = msg['user_avatar_url'] as String?;
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
                                          color: Colors.black.withValues(alpha: 0.04),
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
                                            if (senderAvatar != null && senderAvatar.isNotEmpty) ...[
                                              CircleAvatar(radius: 7, backgroundImage: NetworkImage(senderAvatar)),
                                              const SizedBox(width: 4),
                                            ],
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
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(backgroundColor: const Color(0xFFDC2626), content: Text(verdict['reason'] ?? "Blocked")),
                                );
                              }
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
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text("Save", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _openCityPulseRoom() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (ctx) => CommunityPulseChatScreen(
          activeCity: _currentHubCity,
          backendUrl: widget.backendUrl,
        ),
      ),
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

  void _showEndorseSheet(Map<String, dynamic> gem) {
    final availableTags = [
      "🕒 24 Hours",
      "💳 Card / Digital Pay",
      "🛵 Home Delivery",
      "❄️ AC Seating",
      "🌿 Vegetarian Friendly",
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
                      hintText: "e.g. Try the special regional house special or night counter",
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

                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(backgroundColor: Color(0xFF16A34A), content: Text("✓ Endorsement recorded!")),
                        );
                      }
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
      mapUri = Uri.parse("https://www.google.com/maps/dir/?api=1&destination=$lat,$lon&travelmode=driving");
    } else if (customUrl.isNotEmpty && customUrl.startsWith("http")) {
      mapUri = Uri.parse(customUrl);
    } else {
      final query = Uri.encodeComponent('$placeName, $_currentHubCity');
      mapUri = Uri.parse("https://www.google.com/maps/search/?api=1&query=$query");
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

  Future<void> _contribute() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ContributePlaceScreen(
          activeCity: _currentHubCity,
          backendUrl: widget.backendUrl,
        ),
      ),
    );
    if (result == true) await _loadPlacesForCity(_currentHubCity);
  }

  List<Map<String, dynamic>> get _visiblePlaces {
    final q = _searchQuery.toLowerCase().trim();
    return _places.where((p) {
      if (_selectedCategory != 'All') {
        final category = '${p['category'] ?? ''}'.toLowerCase();
        if (!category.contains(_selectedCategory.toLowerCase())) return false;
      }
      if (q.isEmpty) return true;
      final haystack = [p['name'], p['address'], p['description'], p['category'], p['city'], p['must_try_tip']]
          .map((v) => '$v'.toLowerCase()).join(' ');
      return haystack.contains(q);
    }).toList();
  }

  bool _isFoodPlace(Map<String, dynamic> place) {
    final c = '${place['category'] ?? ''} ${place['subcategory'] ?? ''}'.toLowerCase();
    return RegExp(r'food|restaurant|cafe|café|diner|seafood|bar|bakery|snack|chai|coffee|fast').hasMatch(c);
  }

  String? _providerUrlFor(Map<String, dynamic> place, String provider) {
    final directKey = provider == 'Swiggy' ? 'swiggy_url' : 'zomato_url';
    final direct = '${place[directKey] ?? ''}'.trim();
    if (direct.isNotEmpty && direct != 'null') return direct;
    final providers = place['providers'];
    if (providers is Map) {
      for (final key in [provider.toLowerCase(), provider]) {
        final value = '${providers[key] ?? ''}'.trim();
        if (value.isNotEmpty && value != 'null') return value;
      }
    }
    if (providers is List) {
      for (final item in providers) {
        if (item is! Map) continue;
        final n = '${item['provider'] ?? item['name'] ?? ''}'.toLowerCase();
        if (n == provider.toLowerCase()) {
          final value = '${item['url'] ?? item['link'] ?? ''}'.trim();
          if (value.isNotEmpty && value != 'null') return value;
        }
      }
    }
    return null;
  }

  Future<void> _openUrl(String url, String label) async {
    final uri = Uri.tryParse(url);
    if (uri == null || (uri.scheme != 'http' && uri.scheme != 'https')) return;
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not open $label.')));
    }
  }

  String _placeId(Map<String, dynamic> p) => [p['google_place_id'], p['id'], p['place_id'], p['name']]
      .map((v) => '$v'.trim()).firstWhere((v) => v.isNotEmpty && v != 'null', orElse: () => '');

  Widget _iconAction(IconData icon, String label, VoidCallback onTap, {Color color = const Color(0xFF2563EB)}) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          height: 66,
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: const Color(0xFFE2E8F0)), boxShadow: [BoxShadow(color: Colors.black.withOpacity(.025), blurRadius: 5)]),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 4),
            Text(label, style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: Color(0xFF334155))),
          ]),
        ),
      ),
    );
  }

  Widget _topShortcut(IconData icon, String label, VoidCallback onTap, {bool primary = false}) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          height: 64,
          decoration: BoxDecoration(color: primary ? const Color(0xFFEFF6FF) : Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: primary ? const Color(0xFFBFDBFE) : const Color(0xFFE2E8F0))),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(icon, color: const Color(0xFF2563EB), size: 23),
            const SizedBox(height: 3),
            Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 10.2, fontWeight: FontWeight.w800, color: Color(0xFF334155))),
          ]),
        ),
      ),
    );
  }

  Widget _categoryChip(String label, IconData icon, bool selected) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(color: selected ? const Color(0xFF2563EB) : Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: selected ? const Color(0xFF2563EB) : const Color(0xFFE2E8F0))),
      child: Row(mainAxisSize: MainAxisSize.min, children: [Icon(icon, size: 16, color: selected ? Colors.white : const Color(0xFF2563EB)), const SizedBox(width: 6), Text(label, style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, color: selected ? Colors.white : const Color(0xFF334155))) ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    final places = _visiblePlaces;
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: SafeArea(
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 8, 14, 8),
            child: Row(children: [
              IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.arrow_back_rounded, color: Color(0xFF0F172A))),
              const Icon(Icons.diamond_rounded, color: Color(0xFF2563EB), size: 25),
              const SizedBox(width: 7),
              const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('Community Gems', style: TextStyle(fontSize: 21, fontWeight: FontWeight.w900, color: Color(0xFF0F172A))), Text('Discover real places, local tips & community recommendations', style: TextStyle(fontSize: 10.5, color: Color(0xFF64748B)))])),
              InkWell(onTap: _showLanguageSelectorModal, borderRadius: BorderRadius.circular(20), child: Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8), decoration: BoxDecoration(color: const Color(0xFFEFF6FF), borderRadius: BorderRadius.circular(20), border: Border.all(color: const Color(0xFFBFDBFE))), child: Row(children: [const Icon(Icons.language_rounded, size: 17, color: Color(0xFF2563EB)), const SizedBox(width: 4), Text(_activeLanguage, style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: Color(0xFF1E40AF))), const Icon(Icons.keyboard_arrow_down_rounded, size: 16, color: Color(0xFF2563EB))]))),
            ]),
          ),
          Padding(padding: const EdgeInsets.symmetric(horizontal: 14), child: Row(children: [
            _topShortcut(Icons.explore_rounded, 'Live View', _openCityPulseRoom), const SizedBox(width: 7),
            _topShortcut(Icons.location_on_rounded, 'Nearby', () { setState(() => _selectedCategory = 'All'); _fetchUserLocation(); }), const SizedBox(width: 7),
            _topShortcut(Icons.add_rounded, 'Add Gem', _contribute, primary: true), const SizedBox(width: 7),
            _topShortcut(Icons.bookmark_rounded, 'Saved', () { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Saved places are available on each gem.'))); }), const SizedBox(width: 7),
            _topShortcut(Icons.forum_rounded, 'Community Chat', _openCityPulseRoom),
          ])),
          const SizedBox(height: 10),
          Padding(padding: const EdgeInsets.symmetric(horizontal: 14), child: TextField(
            controller: _searchCtrl,
            onChanged: (_) => setState(() {}),
            onSubmitted: _executeActiveSearch,
            decoration: InputDecoration(hintText: 'Search places, food, pharmacy, salons...', prefixIcon: const Icon(Icons.search_rounded, color: Color(0xFF2563EB)), suffixIcon: IconButton(onPressed: () => _executeActiveSearch(_searchCtrl.text), icon: const Icon(Icons.tune_rounded, color: Color(0xFF475569))), filled: true, fillColor: Colors.white, border: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: const BorderSide(color: Color(0xFFE2E8F0))), enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: const BorderSide(color: Color(0xFFE2E8F0)))) ,
          )),
          const SizedBox(height: 8),
          SizedBox(height: 43, child: ListView(scrollDirection: Axis.horizontal, padding: const EdgeInsets.symmetric(horizontal: 14), children: [
            GestureDetector(onTap: () { setState(() => _selectedCategory = 'All'); _loadPlacesForCity(_currentHubCity); }, child: _categoryChip('All', Icons.grid_view_rounded, _selectedCategory == 'All')), const SizedBox(width: 7),
            ...[('Food', Icons.restaurant_rounded), ('Pharmacy', Icons.local_pharmacy_rounded), ('Shopping', Icons.shopping_bag_rounded), ('Stay', Icons.hotel_rounded)].map((e) => Padding(padding: const EdgeInsets.only(right: 7), child: GestureDetector(onTap: () { setState(() => _selectedCategory = e.$1); _loadPlacesForCity(_currentHubCity); }, child: _categoryChip(e.$1, e.$2, _selectedCategory == e.$1)))),
          ])),
          const SizedBox(height: 8),
          Padding(padding: const EdgeInsets.symmetric(horizontal: 14), child: Row(children: [
            const Icon(Icons.location_on_rounded, color: Color(0xFF2563EB), size: 21), const SizedBox(width: 4), Text(_currentHubCity, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: Color(0xFF0F172A))), const Icon(Icons.keyboard_arrow_down_rounded, color: Color(0xFF2563EB)),
            const Spacer(), Text('${places.length} Gems', style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, color: Color(0xFF334155))), const SizedBox(width: 7), Container(width: 8, height: 8, decoration: const BoxDecoration(color: Color(0xFF16A34A), shape: BoxShape.circle)), const SizedBox(width: 4), Text('${_activeScouts.length + 1} Scouts Live', style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, color: Color(0xFF16A34A))),
          ])),
          const SizedBox(height: 7),
          Expanded(child: RefreshIndicator(onRefresh: () => _loadPlacesForCity(_currentHubCity), child: ListView(padding: const EdgeInsets.fromLTRB(14, 0, 14, 24), children: [
            if (_isLoading) const Padding(padding: EdgeInsets.all(45), child: Center(child: CircularProgressIndicator(color: Color(0xFF2563EB))))
            else if (places.isEmpty) _emptyCommunityState()
            else ...places.map(_placeListCard),
          ]))),
        ]),
      ),
    );
  }

  Widget _emptyCommunityState() => Container(margin: const EdgeInsets.only(top: 30), padding: const EdgeInsets.all(28), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: const Color(0xFFE2E8F0))), child: Column(children: [const Icon(Icons.search_off_rounded, size: 45, color: Color(0xFF94A3B8)), const SizedBox(height: 10), const Text('No real places found', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900)), const SizedBox(height: 5), const Text('Try another search or add a genuine local gem.', textAlign: TextAlign.center, style: TextStyle(color: Color(0xFF64748B))), const SizedBox(height: 14), ElevatedButton.icon(onPressed: _contribute, icon: const Icon(Icons.add), label: const Text('Add Gem'))]));

  Widget _placeListCard(Map<String, dynamic> gem) {
    final name = '${gem['name'] ?? 'Local Place'}';
    final category = '${gem['category'] ?? 'Local Place'}';
    final image = '${gem['image_url'] ?? gem['photo_url'] ?? ''}'.trim();
    final rating = gem['rating'];
    final reviews = gem['review_count'] ?? gem['reviews_count'];
    final gems = (gem['community_endorsements'] ?? gem['upvotes'] ?? 0) is num ? ((gem['community_endorsements'] ?? gem['upvotes'] ?? 0) as num).toInt() : 0;
    final noticeTitle = '${gem['daily_notice_title'] ?? gem['community_notice'] ?? ''}'.trim();
    final noticeContent = '${gem['daily_notice_content'] ?? ''}'.trim();
    final distance = _calculateDistance(gem).replaceFirst('📍 ', '');
    final savedKey = _placeId(gem);
    return Container(margin: const EdgeInsets.only(bottom: 13), padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18), border: Border.all(color: const Color(0xFFE2E8F0)), boxShadow: [BoxShadow(color: Colors.black.withOpacity(.035), blurRadius: 8, offset: const Offset(0, 2))]), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        ClipRRect(borderRadius: BorderRadius.circular(13), child: SizedBox(width: 128, height: 126, child: image.isNotEmpty ? Image.network(image, fit: BoxFit.cover, errorBuilder: (_, __, ___) => _photoFallback()) : _photoFallback())),
        const SizedBox(width: 10),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [Expanded(child: Text(name, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w900, color: Color(0xFF0F172A)))), Container(padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 5), decoration: BoxDecoration(color: const Color(0xFFEFF6FF), borderRadius: BorderRadius.circular(14), border: Border.all(color: const Color(0xFFBFDBFE))), child: Text('💎 $gems Gems', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: Color(0xFF1E40AF))))]),
          const SizedBox(height: 6), _smallTag(category), const SizedBox(height: 6),
          Row(children: [const Icon(Icons.star_rounded, size: 17, color: Color(0xFFF59E0B)), Text(rating == null ? ' New' : ' ${rating.toString()}', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 11.5)), if (reviews != null) Text(' (${reviews.toString()})', style: const TextStyle(color: Color(0xFF64748B), fontSize: 10.5)), const SizedBox(width: 8), const Icon(Icons.location_on_rounded, size: 15, color: Color(0xFF2563EB)), Text(distance, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 10.5, color: Color(0xFF2563EB)))]),
          const SizedBox(height: 5), Text('${gem['description'] ?? gem['must_try_tip'] ?? 'Community-recommended local place.'}', maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 10.8, color: Color(0xFF475569), height: 1.25)),
        ])),
      ]),
      if (noticeTitle.isNotEmpty) Container(margin: const EdgeInsets.only(top: 8), padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7), decoration: BoxDecoration(color: const Color(0xFFFFFBEB), borderRadius: BorderRadius.circular(10), border: Border.all(color: const Color(0xFFFDE68A))), child: Row(children: [const Icon(Icons.campaign_rounded, size: 16, color: Color(0xFFD97706)), const SizedBox(width: 5), Expanded(child: Text('TODAY: $noticeTitle${noticeContent.isNotEmpty ? ' — $noticeContent' : ''}', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 10.2, fontWeight: FontWeight.w800, color: Color(0xFF92400E))))])),
      const SizedBox(height: 9),
      Row(children: [Expanded(child: _outlineButton(Icons.visibility_rounded, 'Explore', () => Navigator.push(context, MaterialPageRoute(builder: (_) => CommunityGemDetailScreen(gem: gem, activeCity: _currentHubCity, backendUrl: widget.backendUrl, language: _activeLanguage, onGemAwarded: () => _handleGemEndorsement(gem), onAskLocals: () => _showAskLocalsModal(gem), onNotice: () => _showDailyNoticeModal(gem)))))), const SizedBox(width: 7), Expanded(child: _outlineButton(Icons.navigation_rounded, 'Navigate', () => _launchMaps('${gem['maps_url'] ?? ''}', name, gem['latitude'], gem['longitude'],))),]),
    ]));
  }

  Widget _photoFallback() => Container(color: const Color(0xFFEAF0F6), child: const Center(child: Icon(Icons.image_outlined, size: 36, color: Color(0xFF94A3B8))));
  Widget _smallTag(String text) => Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5), decoration: BoxDecoration(color: const Color(0xFFFDF2F8), borderRadius: BorderRadius.circular(8)), child: Text(text, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: Color(0xFFBE185D))));
  Widget _outlineButton(IconData icon, String label, VoidCallback onTap) => InkWell(onTap: onTap, borderRadius: BorderRadius.circular(12), child: Container(height: 40, decoration: BoxDecoration(color: label == 'Explore' ? const Color(0xFF2563EB) : Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFF2563EB))), child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(icon, size: 16, color: label == 'Explore' ? Colors.white : const Color(0xFF2563EB)), const SizedBox(width: 5), Text(label, style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w900, color: label == 'Explore' ? Colors.white : const Color(0xFF2563EB)))])));
}

class CommunityGemDetailScreen extends StatefulWidget {
  final Map<String, dynamic> gem;
  final String activeCity;
  final String backendUrl;
  final String language;
  final VoidCallback? onGemAwarded;
  final VoidCallback? onAskLocals;
  final VoidCallback? onNotice;
  const CommunityGemDetailScreen({super.key, required this.gem, required this.activeCity, required this.backendUrl, required this.language, this.onGemAwarded, this.onAskLocals, this.onNotice});
  @override State<CommunityGemDetailScreen> createState() => _CommunityGemDetailScreenState();
}

class _CommunityGemDetailScreenState extends State<CommunityGemDetailScreen> {
  late Map<String, dynamic> gem;
  bool saved = false;
  late String detailLanguage;
  @override void initState() { super.initState(); gem = Map<String, dynamic>.from(widget.gem); detailLanguage = widget.language; }

  bool get isFood { final c='${gem['category'] ?? ''} ${gem['subcategory'] ?? ''}'.toLowerCase(); return RegExp(r'food|restaurant|cafe|café|diner|seafood|bar|bakery|snack|chai|coffee|fast').hasMatch(c); }
  int get gems { final v=gem['community_endorsements'] ?? gem['upvotes'] ?? 0; return v is num ? v.toInt() : int.tryParse('$v') ?? 0; }
  String _distance() {
    final d=gem['_distance_km']; if(d is num) return '${d.toStringAsFixed(d < 1 ? 2 : 1)} km'; return '—';
  }
  String _cityCenterDistance() {
    final lat = double.tryParse('${gem['latitude'] ?? ''}');
    final lng = double.tryParse('${gem['longitude'] ?? ''}');
    if (lat == null || lng == null) return '—';
    final center = TripStateService.getDestinationCoordinates(widget.activeCity.toLowerCase());
    final cLat = (center['lat'] as num?)?.toDouble();
    final cLng = (center['lon'] as num?)?.toDouble();
    if (cLat == null || cLng == null) return '—';
    final meters = Geolocator.distanceBetween(lat, lng, cLat, cLng);
    return meters < 1000 ? '${meters.round()} m' : '${(meters / 1000).toStringAsFixed(1)} km';
  }
  Future<void> _translateTo(String language) async {
    final source = '${gem['local_name'] ?? gem['name'] ?? ''}'.trim();
    if (source.isEmpty) return;
    try {
      final cleanUrl = widget.backendUrl.replaceAll(RegExp(r'/+$'), '');
      final res = await http.post(Uri.parse('$cleanUrl/api/v1/chat'), headers: {'Content-Type':'application/json'}, body: jsonEncode({'message':'Translate this place name accurately into $language. Output only the translation: "$source"','target_language':language})).timeout(const Duration(seconds: 8));
      if (res.statusCode == 200) {
        final d=jsonDecode(res.body); final translated='${d['reply'] ?? d['answer'] ?? ''}'.trim();
        if (translated.isNotEmpty && mounted) setState(() { gem['translated_name']=translated; detailLanguage=language; });
      }
    } catch (_) {}
  }
  void _chooseLanguage() {
    const langs=['English','Marathi','Hindi','Gujarati','Tamil','Telugu','Kannada','Malayalam','Bengali','Punjabi','Arabic','French','Spanish','German'];
    showModalBottomSheet(context:context,builder:(ctx)=>SafeArea(child:ListView(children:langs.map((l)=>ListTile(title:Text(l),trailing:detailLanguage==l?const Icon(Icons.check,color:Color(0xFF2563EB)):null,onTap:(){Navigator.pop(ctx);_translateTo(l);})).toList())));
  }
  String? _provider(String p) { final k=p=='Swiggy'?'swiggy_url':'zomato_url'; final direct='${gem[k] ?? ''}'.trim(); if(direct.isNotEmpty && direct!='null') return direct; final providers=gem['providers']; if(providers is Map){ for(final key in [p.toLowerCase(),p]){final v='${providers[key] ?? ''}'.trim(); if(v.isNotEmpty && v!='null') return v;}} return null; }
  Future<void> _open(String url,String label) async { final u=Uri.tryParse(url); if(u!=null && (u.scheme=='http'||u.scheme=='https') && await canLaunchUrl(u)) await launchUrl(u,mode:LaunchMode.externalApplication); }
  Future<void> _navigate() async { final u='${gem['maps_url'] ?? ''}'.trim(); if(u.isNotEmpty){await _open(u,'Maps'); return;} final lat=gem['latitude']; final lng=gem['longitude']; final name='${gem['name'] ?? ''}'; final address='${gem['address'] ?? ''}'; final q=(lat!=null&&lng!=null)?'$lat,$lng':'$name, $address'; final uri=Uri.https('www.google.com','/maps/search/',{'api':'1','query':q}); if(await canLaunchUrl(uri)) await launchUrl(uri,mode:LaunchMode.externalApplication); }
  Future<void> _call() async { final phone='${gem['contact_phone'] ?? gem['phone'] ?? ''}'.trim(); if(phone.isEmpty)return; final u=Uri.parse('tel:${phone.replaceAll(RegExp(r'[^0-9+]'), '')}'); if(await canLaunchUrl(u)) await launchUrl(u); }
  Future<void> _whatsapp() async { final phone='${gem['contact_phone'] ?? gem['phone'] ?? ''}'.replaceAll(RegExp(r'[^0-9]'), ''); if(phone.isEmpty)return; final u=Uri.parse('https://wa.me/$phone'); if(await canLaunchUrl(u)) await launchUrl(u,mode:LaunchMode.externalApplication); }
  void _awardGem() { widget.onGemAwarded?.call(); }
  void _askAbout() { widget.onAskLocals?.call(); }

  @override Widget build(BuildContext context) {
    final name='${gem['name'] ?? 'Local Place'}'; final image='${gem['image_url'] ?? gem['photo_url'] ?? ''}'.trim(); final category='${gem['category'] ?? 'Local Place'}'; final address='${gem['address'] ?? ''}'.trim(); final phone='${gem['contact_phone'] ?? gem['phone'] ?? ''}'.trim(); final rating=gem['rating']; final reviews=gem['review_count'] ?? gem['reviews_count']; final notice='${gem['daily_notice_title'] ?? gem['community_notice'] ?? ''}'.trim(); final noticeContent='${gem['daily_notice_content'] ?? ''}'.trim(); final swiggy=isFood?_provider('Swiggy'):null; final zomato=isFood?_provider('Zomato'):null;
    return Scaffold(backgroundColor:const Color(0xFFF8FAFC),body:SafeArea(child:Column(children:[
      Expanded(child:ListView(padding:EdgeInsets.zero,children:[
        Stack(children:[SizedBox(height:230,width:double.infinity,child:image.isNotEmpty?Image.network(image,fit:BoxFit.cover,errorBuilder:(_,__,___)=>Container(color:const Color(0xFFE2E8F0),child:const Icon(Icons.image_outlined,size:50))):Container(color:const Color(0xFFE2E8F0),child:const Icon(Icons.image_outlined,size:50))),Positioned(top:12,left:12,child:_circle(Icons.arrow_back_rounded,()=>Navigator.pop(context))),Positioned(top:12,right:12,child:Row(children:[_circle(Icons.share_rounded,(){}),const SizedBox(width:7),_circle(saved?Icons.bookmark_rounded:Icons.bookmark_border_rounded,()=>setState(()=>saved=!saved))])),Positioned(bottom:12,right:12,child:Container(padding:const EdgeInsets.symmetric(horizontal:9,vertical:5),decoration:BoxDecoration(color:Colors.black54,borderRadius:BorderRadius.circular(15)),child:const Text('Photo',style:TextStyle(color:Colors.white,fontSize:10,fontWeight:FontWeight.w800))))]),
        Container(padding:const EdgeInsets.fromLTRB(16,14,16,22),decoration:const BoxDecoration(color:Colors.white,borderRadius:BorderRadius.vertical(top:Radius.circular(22))),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
          Row(crossAxisAlignment:CrossAxisAlignment.start,children:[Expanded(child:Text(name,style:const TextStyle(fontSize:21,fontWeight:FontWeight.w900,color:Color(0xFF0F172A)))),Container(padding:const EdgeInsets.symmetric(horizontal:10,vertical:8),decoration:BoxDecoration(color:const Color(0xFFEFF6FF),borderRadius:BorderRadius.circular(18),border:Border.all(color:const Color(0xFFBFDBFE))),child:Text('💎 $gems Gems',style:const TextStyle(fontWeight:FontWeight.w900,color:Color(0xFF1E40AF))))]),
          const SizedBox(height:7),_smallTag(category),const SizedBox(height:7),Row(children:[const Icon(Icons.star_rounded,color:Color(0xFFF59E0B),size:21),Text(rating==null?' New':' ${rating.toString()}',style:const TextStyle(fontWeight:FontWeight.w900,fontSize:13)),if(reviews!=null)Text(' (${reviews.toString()} reviews)',style:const TextStyle(color:Color(0xFF64748B),fontSize:11.5))]),
          if(notice.isNotEmpty) ...[const SizedBox(height:12),Container(padding:const EdgeInsets.all(12),decoration:BoxDecoration(color:const Color(0xFFFFFBEB),borderRadius:BorderRadius.circular(14),border:Border.all(color:const Color(0xFFFDE68A))),child:Row(children:[const Icon(Icons.campaign_rounded,color:Color(0xFFD97706),size:25),const SizedBox(width:9),Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[const Text("TODAY'S SPECIAL / NOTICE",style:TextStyle(fontSize:10,fontWeight:FontWeight.w900,color:Color(0xFF92400E))),const SizedBox(height:2),Text(notice,style:const TextStyle(fontSize:13,fontWeight:FontWeight.w900,color:Color(0xFF451A03))),if(noticeContent.isNotEmpty)Text(noticeContent,style:const TextStyle(fontSize:11,color:Color(0xFF78350F)))]))]))],
          const SizedBox(height:12),Row(children:[_detailAction(Icons.call_rounded,'Call',_call,Color(0xFF16A34A)),const SizedBox(width:7),_detailAction(Icons.chat_rounded,'WhatsApp',_whatsapp,Color(0xFF16A34A)),const SizedBox(width:7),_detailAction(Icons.navigation_rounded,'Navigate',_navigate,Color(0xFF2563EB)),const SizedBox(width:7),_detailAction(Icons.bookmark_rounded,'Save',()=>setState(()=>saved=!saved)),const SizedBox(width:7),_detailAction(Icons.diamond_rounded,'Gems',_awardGem,Color(0xFF2563EB)),]),
          const SizedBox(height:13),_infoBlock(Icons.location_on_rounded,address.isEmpty?'Address not available':address),
          const SizedBox(height:9),Row(children:[Expanded(child:_metric(Icons.my_location_rounded,_distance(),'from your location')),Expanded(child:_metric(Icons.location_city_rounded,_cityCenterDistance(),'from city center'))]),
          const SizedBox(height:13),if(address.isNotEmpty)Container(height:85,decoration:BoxDecoration(color:const Color(0xFFEFF6FF),borderRadius:BorderRadius.circular(14)),child:Row(children:[const Padding(padding:EdgeInsets.all(14),child:Icon(Icons.map_rounded,color:Color(0xFF2563EB),size:32)),Expanded(child:Text(address,maxLines:2,overflow:TextOverflow.ellipsis,style:const TextStyle(fontSize:11,fontWeight:FontWeight.w700,color:Color(0xFF334155)))),TextButton(onPressed:_navigate,child:const Text('View on Map'))])),
          const SizedBox(height:13),_translationSection(name),
          const SizedBox(height:13),_amenities(gem),
          if(isFood && (swiggy!=null||zomato!=null)) ...[const SizedBox(height:13),_ordering(swiggy,zomato)],
          const SizedBox(height:13),_noticeAction(notice),
          const SizedBox(height:13),_communityInsights(gem),
          const SizedBox(height:13),_askPanel(name),
          if(phone.isNotEmpty)Padding(padding:const EdgeInsets.only(top:12),child:Text('Phone: $phone',style:const TextStyle(fontSize:11,color:Color(0xFF64748B))),),
        ]),),
      ])),
    ])));
  }

  Widget _circle(IconData icon,VoidCallback onTap)=>Material(color:Colors.white.withOpacity(.95),shape:const CircleBorder(),child:InkWell(onTap:onTap,customBorder:const CircleBorder(),child:Padding(padding:const EdgeInsets.all(10),child:Icon(icon,color:const Color(0xFF0F172A),size:21))));
  Widget _smallTag(String text)=>Container(padding:const EdgeInsets.symmetric(horizontal:9,vertical:5),decoration:BoxDecoration(color:const Color(0xFFFDF2F8),borderRadius:BorderRadius.circular(8)),child:Text(text,style:const TextStyle(fontSize:10.5,fontWeight:FontWeight.w800,color:Color(0xFFBE185D))));
  Widget _detailAction(IconData icon,String label,VoidCallback onTap,[Color color=const Color(0xFF2563EB)])=>Expanded(child:InkWell(onTap:onTap,borderRadius:BorderRadius.circular(12),child:Container(height:62,decoration:BoxDecoration(color:Colors.white,borderRadius:BorderRadius.circular(12),border:Border.all(color:const Color(0xFFE2E8F0))),child:Column(mainAxisAlignment:MainAxisAlignment.center,children:[Icon(icon,color:color,size:23),const SizedBox(height:3),Text(label,style:const TextStyle(fontSize:9.5,fontWeight:FontWeight.w800))]))));
  Widget _infoBlock(IconData icon,String text)=>Row(crossAxisAlignment:CrossAxisAlignment.start,children:[Icon(icon,color:const Color(0xFF2563EB),size:23),const SizedBox(width:9),Expanded(child:Text(text,style:const TextStyle(fontSize:12,color:Color(0xFF334155),height:1.35,fontWeight:FontWeight.w600)))]);
  Widget _metric(IconData icon, String big, String small) => Container(
    margin: const EdgeInsets.only(right: 8),
    padding: const EdgeInsets.all(10),
    decoration: BoxDecoration(color: const Color(0xFFF8FAFC), borderRadius: BorderRadius.circular(12)),
    child: Row(children: [
      Icon(icon, color: const Color(0xFF2563EB), size: 20),
      const SizedBox(width: 7),
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(big, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13)),
        Text(small, style: const TextStyle(color: Color(0xFF64748B), fontSize: 9.5)),
      ]),
    ]),
  );
  Widget _translationSection(String name) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: const Color(0xFFE2E8F0))),
    child: Row(children: [
      const Icon(Icons.translate_rounded, color: Color(0xFF2563EB), size: 25),
      const SizedBox(width: 9),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Local Name (${gem['local_language'] ?? 'Original'})', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Color(0xFF64748B))),
        Text('${gem['local_name'] ?? name}', style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800)),
        const SizedBox(height: 3),
        Text('Translation: ${gem['translated_name'] ?? name}', style: const TextStyle(fontSize: 10.5, color: Color(0xFF64748B))),
      ])),
      InkWell(onTap: _chooseLanguage, borderRadius: BorderRadius.circular(18), child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
        decoration: BoxDecoration(color: const Color(0xFFEFF6FF), borderRadius: BorderRadius.circular(16)),
        child: Row(children: [
          const Icon(Icons.language_rounded, size: 15, color: Color(0xFF2563EB)),
          const SizedBox(width: 4),
          Text(detailLanguage, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Color(0xFF1E40AF))),
          const Icon(Icons.keyboard_arrow_down_rounded, size: 15, color: Color(0xFF2563EB)),
        ]),
      )),
    ]),
  );

  Widget _amenities(Map<String, dynamic> p) {
    final raw = p['tags'] ?? p['amenities'] ?? p['endorsement_tags'];
    final tags = <String>[];
    if (raw is List) tags.addAll(raw.map((e) => '$e'));
    if (tags.isEmpty) {
      for (final k in ['free_wifi', 'card_upi', 'budget_friendly', 'family_friendly', 'indoor_seating', 'takeaway']) {
        if (p[k] == true) {
          tags.add(k.replaceAll('_', ' ').split(' ').map((x) => x.isEmpty ? x : x[0].toUpperCase() + x.substring(1)).join(' '));
        }
      }
    }
    if (tags.isEmpty) return const SizedBox.shrink();
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('Amenities & Tags', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900)),
      const SizedBox(height: 8),
      Wrap(spacing: 7, runSpacing: 7, children: tags.take(10).map((t) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(16)),
        child: Text(t.replaceAll('🕒 ', '').replaceAll('💳 ', '').replaceAll('💰 ', '').replaceAll('🛵 ', ''), style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: Color(0xFF334155))),
      )).toList()),
    ]);
  }

  Widget _ordering(String? swiggy, String? zomato) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: const Color(0xFFE2E8F0))),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('🍽 Order Online (if available)', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900)),
      const SizedBox(height: 8),
      Row(children: [
        if (zomato != null) Expanded(child: OutlinedButton.icon(onPressed: () => _open(zomato, 'Zomato'), icon: const Icon(Icons.restaurant_rounded, color: Color(0xFFEF4444)), label: const Text('Order on Zomato', style: TextStyle(color: Color(0xFFDC2626), fontSize: 10, fontWeight: FontWeight.w800)))),
        if (zomato != null && swiggy != null) const SizedBox(width: 7),
        if (swiggy != null) Expanded(child: OutlinedButton.icon(onPressed: () => _open(swiggy, 'Swiggy'), icon: const Icon(Icons.delivery_dining_rounded, color: Color(0xFFF97316)), label: const Text('Order on Swiggy', style: TextStyle(color: Color(0xFFEA580C), fontSize: 10, fontWeight: FontWeight.w800)))),
      ]),
    ]),
  );

  Widget _noticeAction(String notice) => InkWell(
    onTap: widget.onNotice,
    borderRadius: BorderRadius.circular(13),
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
      decoration: BoxDecoration(color: const Color(0xFFFFFBEB), borderRadius: BorderRadius.circular(13), border: Border.all(color: const Color(0xFFFDE68A))),
      child: Row(children: [
        const Icon(Icons.campaign_rounded, size: 18, color: Color(0xFFD97706)),
        const SizedBox(width: 7),
        Expanded(child: Text(notice.isEmpty ? '+ Post Today’s Special / Notice' : 'Edit Today’s Special / Notice', style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w900, color: Color(0xFF92400E)))),
        const Icon(Icons.chevron_right_rounded, size: 18, color: Color(0xFFD97706)),
      ]),
    ),
  );

  Widget _communityInsights(Map<String, dynamic> p) {
    final n = p['community_endorsements'] ?? p['upvotes'] ?? 0;
    final tip = '${p['must_try_tip'] ?? ''}'.trim();
    final love = '${p['community_love'] ?? p['endorsement_summary'] ?? p['community_notice'] ?? ''}'.trim();
    if ('$n' == '0' && tip.isEmpty && love.isEmpty) return const SizedBox.shrink();
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        const Text('Community Insights', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900)),
        const SizedBox(width: 6),
        Text('💎 $n endorsements', style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: Color(0xFF1E40AF))),
        const Spacer(),
        const Text('See All', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: Color(0xFF2563EB))),
      ]),
      const SizedBox(height: 8),
      Row(children: [
        if (love.isNotEmpty) Expanded(child: _insight(Icons.thumb_up_alt_rounded, 'What locals love', love, const Color(0xFFDCFCE7), const Color(0xFF166534))),
        if (love.isNotEmpty && tip.isNotEmpty) const SizedBox(width: 8),
        if (tip.isNotEmpty) Expanded(child: _insight(Icons.favorite_rounded, 'Must try', tip, const Color(0xFFFCE7F3), const Color(0xFFBE185D))),
      ]),
    ]);
  }

  Widget _insight(IconData icon, String title, String text, Color bg, Color fg) => Container(
    padding: const EdgeInsets.all(10),
    decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(14)),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Icon(icon, color: fg, size: 19),
      const SizedBox(height: 4),
      Text(title, style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w900, color: fg)),
      const SizedBox(height: 3),
      Text(text, maxLines: 3, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 10.2, height: 1.25, color: Color(0xFF334155))),
    ]),
  );

  Widget _askPanel(String name) => InkWell(
    onTap: _askAbout,
    borderRadius: BorderRadius.circular(16),
    child: Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(color: const Color(0xFFEFF6FF), borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xFF60A5FA))),
      child: Row(children: [
        Container(padding: const EdgeInsets.all(9), decoration: const BoxDecoration(color: Color(0xFFDBEAFE), shape: BoxShape.circle), child: const Icon(Icons.groups_rounded, color: Color(0xFF2563EB))),
        const SizedBox(width: 9),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Row(children: [Text('Ask About This Place', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w900)), SizedBox(width: 5), Text('Beta', style: TextStyle(fontSize: 8, fontWeight: FontWeight.w900, color: Color(0xFF2563EB)))]),
          Text('Get local tips, timings, best information and more', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 10, color: Color(0xFF64748B))),
          const SizedBox(height: 7),
          Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)), child: Row(children: [
            Expanded(child: Text('Ask about $name...', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 10.5, color: Color(0xFF94A3B8))),),
            const Icon(Icons.send_rounded, color: Color(0xFF2563EB), size: 19),
          ])),
        ])),
      ]),
    ),
  );
}
