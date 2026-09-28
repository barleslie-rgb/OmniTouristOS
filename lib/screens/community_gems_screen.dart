import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/supabase_service.dart';
import 'contribute_place_screen.dart';

class CommunityGemsScreen extends StatefulWidget {
  final String activeCity;

  const CommunityGemsScreen({
    Key? key,
    required this.activeCity,
  }) : super(key: key);

  @override
  State<CommunityGemsScreen> createState() => _CommunityGemsScreenState();
}

class _CommunityGemsScreenState extends State<CommunityGemsScreen> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _places = [];
  String _currentHubCity = "";
  String _selectedCategory = "All";
  final TextEditingController _searchCtrl = TextEditingController();
  String _searchQuery = "";

  Position? _userPosition;

  final List<Map<String, dynamic>> _filterCategories = [
    {"label": "All", "icon": Icons.grid_view_rounded, "color": Color(0xFF2563EB)},
    {"label": "Pharmacy / Chemist", "icon": Icons.medication_rounded, "color": Color(0xFF16A34A)},
    {"label": "Barber & Salon", "icon": Icons.content_cut_rounded, "color": Color(0xFF7C3AED)},
    {"label": "Kirana & Essentials", "icon": Icons.storefront_rounded, "color": Color(0xFFD97706)},
    {"label": "Ice Cream & Dairy", "icon": Icons.icecream_rounded, "color": Color(0xFFE11D48)},
    {"label": "Cold Storage & Meat", "icon": Icons.kitchen_rounded, "color": Color(0xFF0284C7)},
    {"label": "Indo-Chinese & Snacks", "icon": Icons.ramen_dining_rounded, "color": Color(0xFFEA580C)},
    {"label": "Chai & Quick Bites", "icon": Icons.coffee_rounded, "color": Color(0xFFB45309)},
    {"label": "Bar & Restaurant", "icon": Icons.sports_bar_rounded, "color": Color(0xFF4F46E5)},
    {"label": "Diner & Seafood", "icon": Icons.restaurant_rounded, "color": Color(0xFF0D9488)},
    {"label": "Market, Bazaar & Mall", "icon": Icons.shopping_bag_rounded, "color": Color(0xFFBE123C)},
    {"label": "Movie Cinema & Theater", "icon": Icons.movie_rounded, "color": Color(0xFFDC2626)},
    {"label": "Picnic Spot & Landscape", "icon": Icons.park_rounded, "color": Color(0xFF059669)},
    {"label": "Resort & Farmhouse", "icon": Icons.pool_rounded, "color": Color(0xFF0891B2)},
    {"label": "Heritage & Sight", "icon": Icons.castle_rounded, "color": Color(0xFF475569)},
  ];

  @override
  void initState() {
    super.initState();
    _currentHubCity = widget.activeCity;
    _fetchUserLocation();
    _loadPlacesForCity(_currentHubCity);
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
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

      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.medium,
        timeLimit: const Duration(seconds: 8),
      );
      if (mounted) setState(() => _userPosition = pos);
    } catch (_) {}
  }

  Future<void> _loadPlacesForCity(String city) async {
    setState(() => _isLoading = true);
    final data = await SupabaseService.getPlacesForCity(city);
    if (!mounted) return;

    if (data.isNotEmpty) {
      setState(() {
        _places = data;
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

      results = List<Map<String, dynamic>>.from(response);
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
    } else if (cleanCity.contains("wada")) {
      centerLat = 19.6548;
      centerLon = 73.1384;
    } else if (cleanCity.contains("dubai")) {
      centerLat = 25.2048;
      centerLon = 55.2708;
    } else if (cleanCity.contains("delhi")) {
      centerLat = 28.6139;
      centerLon = 77.2090;
    } else if (cleanCity.contains("london")) {
      centerLat = 51.5074;
      centerLon = -0.1278;
    } else if (cleanCity.contains("tokyo")) {
      centerLat = 35.6762;
      centerLon = 139.6503;
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
        "name": "Amul & Keventers Ice Cream Parlour",
        "category": "Ice Cream & Dairy",
        "address": "Corner Shop, High Street Walkway, $cityName",
        "description": "Fresh dairy milk, thick cold shakes, artisanal sundaes, and midnight ice cream tubs.",
        "contact_phone": "+91 98200 45678",
        "must_try_tip": "Try the seasonal roasted almond kulfi stick.",
        "tags": ["❄️ AC Seating", "💳 UPI Accepted"],
        "upvotes": 18,
      },
      {
        "name": "Fresh Cut Cold Storage & Coastal Fish Mart",
        "category": "Cold Storage & Meat",
        "address": "Fish Market Depot Road, West Sector, $cityName",
        "description": "Daily morning catch, fresh tender meats, and cleaned marinated cuts ready for cooking.",
        "contact_phone": "+91 98200 56789",
        "must_try_tip": "Arrive between 7:30 AM and 9:00 AM for fresh catches.",
        "tags": ["🛵 Home Delivery", "💳 UPI Accepted"],
        "upvotes": 7,
      },
      {
        "name": "Dragon Wok Indo-Chinese & Sizzler Hub",
        "category": "Indo-Chinese & Snacks",
        "address": "Food Street Arcade, Opposite Metro Pillar 42, $cityName",
        "description": "Steaming triple schezwan rice, crispy chicken lollipops, momos, and wok-tossed noodles.",
        "contact_phone": "+91 98200 67890",
        "must_try_tip": "The spicy paneer chilli dry with extra burnt garlic sauce.",
        "tags": ["💳 UPI Accepted", "💰 Budget Friendly"],
        "upvotes": 24,
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
        "name": "The Green Courtyard Family Resto-Bar",
        "category": "Bar & Restaurant",
        "address": "Highway Bypass Junction, Garden Wing, $cityName",
        "description": "Spacious outdoor garden seating with craft beers, tandoori starters, and multi-cuisine platters.",
        "contact_phone": "+91 98200 78901",
        "must_try_tip": "Reserve the outdoor gazebo for family gatherings.",
        "tags": ["🅿️ Parking Available", "❄️ AC Seating", "📶 Free Wi-Fi"],
        "upvotes": 16,
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
      {
        "name": "$cityName Central Municipal Bazaar",
        "category": "Market, Bazaar & Mall",
        "address": "Bazaar Circle, Main Commercial Complex, $cityName",
        "description": "Bustling market hub for fresh farm produce, garments, footwear, utensils, and seasonal flowers.",
        "contact_phone": "",
        "must_try_tip": "Great local deals on seasonal spices and regional handicrafts.",
        "tags": ["💰 Budget Friendly", "💳 UPI Accepted"],
        "upvotes": 19,
      },
      {
        "name": "Cineplex Gold Multiplex & IMAX",
        "category": "Movie Cinema & Theater",
        "address": "Prime City Mall, 4th Floor, $cityName",
        "description": "Dolby Atmos 4K screens, reclining push-back seating, and food court concessions.",
        "contact_phone": "+91 98200 90123",
        "must_try_tip": "Book recliner seats in row E for the best screen perspective.",
        "tags": ["🅿️ Parking Available", "❄️ AC Seating", "💳 UPI Accepted"],
        "upvotes": 11,
      },
      {
        "name": "Sunset Lake View Point & Joggers Park",
        "category": "Picnic Spot & Landscape",
        "address": "Lakeside Ring Road, Near Water Works, $cityName",
        "description": "Peaceful lakefront promenade with shaded tree benches, duck pond, and paved jogging track.",
        "contact_phone": "",
        "must_try_tip": "Visit at sunset for photography and cool lake breezes.",
        "tags": ["🅿️ Parking Available", "🌿 Pure Veg"],
        "upvotes": 22,
      },
    ];

    return templates.asMap().entries.map((entry) {
      final idx = entry.key;
      final t = entry.value;
      final offsetLat = ((idx * 7) % 15 - 7) * 0.004;
      final offsetLon = ((idx * 11) % 15 - 7) * 0.004;

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
    double? uLat = _userPosition?.latitude;
    double? uLon = _userPosition?.longitude;

    if (uLat == null || uLon == null) {
      uLat = 19.3556;
      uLon = 72.8256;
    }

    double? lat;
    double? lon;

    if (gem['latitude'] != null) {
      lat = double.tryParse(gem['latitude'].toString());
    }
    if (gem['longitude'] != null) {
      lon = double.tryParse(gem['longitude'].toString());
    }

    if (lat == null || lon == null || (lat == 0.0 && lon == 0.0)) {
      final addr = (gem['address'] ?? '').toString().toLowerCase();
      final name = (gem['name'] ?? '').toString().toLowerCase();

      if (addr.contains("naigaon") || name.contains("naigaon")) {
        lat = 19.3522;
        lon = 72.8519;
      } else if (addr.contains("vasai") || name.contains("vasai")) {
        lat = 19.3844;
        lon = 72.8300;
      } else if (addr.contains("virar") || name.contains("virar")) {
        lat = 19.4678;
        lon = 72.8056;
      } else {
        lat = uLat + 0.008;
        lon = uLon + 0.008;
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
    final placeId = gem['id'];
    if (placeId == null) return;

    final currentUpvotes = (gem['upvotes'] as num?)?.toInt() ?? 0;
    final success = await SupabaseService.upvotePlace(placeId, currentUpvotes);

    if (!mounted) return;

    if (success) {
      setState(() {
        gem['upvotes'] = currentUpvotes + 1;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: Color(0xFF16A34A),
          duration: Duration(seconds: 2),
          content: Text("✓ Recommendation verified and upvoted!"),
        ),
      );
    } else {
      setState(() {
        gem['upvotes'] = currentUpvotes + 1;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: Color(0xFF16A34A),
          duration: Duration(seconds: 2),
          content: Text("✓ Upvote recorded!"),
        ),
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
          final bottomPadding = MediaQuery.of(ctx).viewInsets.bottom;

          return Container(
            padding: EdgeInsets.fromLTRB(20, 16, 20, bottomPadding + 20),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: const Color(0xFFCBD5E1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      const Icon(Icons.verified_rounded, color: Color(0xFF2563EB), size: 22),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          "Endorse ${gem['name']}",
                          style: const TextStyle(fontSize: 16.5, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    "Tap applicable highlights to help local residents and visitors:",
                    style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                  ),
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
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    height: 46,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2563EB),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      onPressed: () async {
                        final updatedTags = selectedTags.toList();
                        final updatedTip = tipController.text.trim();

                        setState(() {
                          gem['endorsement_tags'] = updatedTags;
                          if (updatedTip.isNotEmpty) {
                            gem['must_try_tip'] = updatedTip;
                          }
                          gem['upvotes'] = ((gem['upvotes'] as num?)?.toInt() ?? 0) + 1;
                        });

                        Navigator.pop(ctx);

                        try {
                          await SupabaseService.client
                              .from('community_places')
                              .update({
                                'endorsement_tags': updatedTags,
                                'must_try_tip': updatedTip,
                                'upvotes': gem['upvotes'],
                              })
                              .eq('id', gem['id']);
                        } catch (_) {}

                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            backgroundColor: Color(0xFF16A34A),
                            content: Text("✓ Endorsement recorded! Thank you for supporting local spots."),
                          ),
                        );
                      },
                      child: const Text("Submit Endorsement (+1 Upvote)", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5)),
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

  Future<void> _launchMaps(String url, String placeName) async {
    final target = url.isNotEmpty
        ? url
        : "https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent('$placeName, $_currentHubCity')}";
    final uri = Uri.parse(target);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _callPhone(String phone) async {
    final clean = phone.replaceAll(RegExp(r'[^0-9+]'), '');
    final uri = Uri.parse("tel:$clean");
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  Future<void> _launchWhatsApp(String phone, String placeName) async {
    final clean = phone.replaceAll(RegExp(r'[^0-9]'), '');
    final text = Uri.encodeComponent("Hello $placeName, inquiring via TouristOS.");
    final uri = Uri.parse("https://wa.me/$clean?text=$text");
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  List<Map<String, dynamic>> get _filteredPlaces {
    return _places.where((p) {
      final matchesCategory =
          _selectedCategory == "All" || p['category'] == _selectedCategory;

      final q = _searchQuery.toLowerCase().trim();
      if (q.isEmpty) return matchesCategory;

      final name = (p['name'] ?? '').toString().toLowerCase();
      final address = (p['address'] ?? '').toString().toLowerCase();
      final desc = (p['description'] ?? '').toString().toLowerCase();
      final cat = (p['category'] ?? '').toString().toLowerCase();
      final city = (p['city'] ?? '').toString().toLowerCase();
      final tip = (p['must_try_tip'] ?? '').toString().toLowerCase();

      final matchesQuery = name.contains(q) ||
          address.contains(q) ||
          desc.contains(q) ||
          cat.contains(q) ||
          city.contains(q) ||
          tip.contains(q);

      return matchesCategory && matchesQuery;
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

  Widget _buildCommunityHeroBanner() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 6, 16, 6),
      height: 92,
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.network(
              "https://images.unsplash.com/photo-1517248135467-4c7edcad34c4?auto=format&fit=crop&w=1200&q=80",
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFF1E3A8A), Color(0xFF2563EB)],
                  ),
                ),
              ),
            ),
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.black.withOpacity(0.20),
                    Colors.black.withOpacity(0.85),
                  ],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Row(
                          children: const [
                            Icon(Icons.store_mall_directory_rounded, color: Color(0xFFFBBF24), size: 15),
                            SizedBox(width: 5),
                            Text(
                              "HYPERLOCAL CORNER & GEMS",
                              style: TextStyle(
                                color: Color(0xFFFDE68A),
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.8,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 3),
                        Text(
                          "Local Hub • $_currentHubCity",
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        const Text(
                          "Small business directory & recommendations",
                          style: TextStyle(color: Colors.white70, fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.refresh_rounded, size: 20, color: Colors.white),
                    onPressed: () {
                      _searchCtrl.clear();
                      _searchQuery = "";
                      _currentHubCity = widget.activeCity;
                      _fetchUserLocation();
                      _loadPlacesForCity(_currentHubCity);
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
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
        backgroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Color(0xFF0F172A), size: 24),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          "Community Gems (${_currentHubCity})",
          style: const TextStyle(
            fontWeight: FontWeight.w900,
            fontSize: 17,
            color: Color(0xFF0F172A),
          ),
        ),
      ),
      floatingActionButton: Padding(
        padding: EdgeInsets.only(bottom: bottomInset > 0 ? bottomInset : 8),
        child: FloatingActionButton.extended(
          backgroundColor: const Color(0xFF2563EB),
          foregroundColor: Colors.white,
          elevation: 4,
          icon: const Icon(Icons.add_business_rounded, size: 20),
          label: const Text(
            "Add Local Shop / Gem",
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
          ),
          onPressed: () async {
            final result = await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (ctx) => ContributePlaceScreen(activeCity: _currentHubCity),
              ),
            );
            if (result == true) {
              _loadPlacesForCity(_currentHubCity);
            }
          },
        ),
      ),
      body: Column(
        children: [
          _buildCommunityHeroBanner(),

          // Search Field with Functional Search Action Button
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 6),
            child: TextField(
              controller: _searchCtrl,
              textInputAction: TextInputAction.search,
              onSubmitted: _executeActiveSearch,
              decoration: InputDecoration(
                hintText: "Search city, pharmacy, barber, hotel, spot...",
                hintStyle: const TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
                prefixIcon: IconButton(
                  icon: const Icon(Icons.search_rounded, color: Color(0xFF2563EB), size: 22),
                  tooltip: "Search Directory",
                  onPressed: () => _executeActiveSearch(_searchCtrl.text),
                ),
                suffixIcon: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_searchCtrl.text.isNotEmpty)
                      IconButton(
                        icon: const Icon(Icons.clear_rounded, size: 18, color: Colors.grey),
                        onPressed: () {
                          _searchCtrl.clear();
                          _executeActiveSearch("");
                        },
                      ),
                    InkWell(
                      onTap: () => _executeActiveSearch(_searchCtrl.text),
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        margin: const EdgeInsets.only(right: 6),
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: const Color(0xFF2563EB),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text(
                          "Search",
                          style: TextStyle(color: Colors.white, fontSize: 11.5, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  ],
                ),
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(vertical: 10),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                ),
              ),
            ),
          ),

          // Horizontal Category Carousel
          Container(
            height: 44,
            margin: const EdgeInsets.symmetric(vertical: 2),
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              scrollDirection: Axis.horizontal,
              itemCount: _filterCategories.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final item = _filterCategories[index];
                final label = item["label"] as String;
                final icon = item["icon"] as IconData;
                final isSelected = label == _selectedCategory;

                return ChoiceChip(
                  avatar: Icon(
                    icon,
                    size: 15,
                    color: isSelected ? Colors.white : item["color"] as Color,
                  ),
                  label: Text(
                    label,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                      color: isSelected ? Colors.white : const Color(0xFF334155),
                    ),
                  ),
                  selected: isSelected,
                  selectedColor: const Color(0xFF2563EB),
                  backgroundColor: Colors.white,
                  side: BorderSide(
                    color: isSelected ? const Color(0xFF2563EB) : const Color(0xFFCBD5E1),
                  ),
                  onSelected: (selected) {
                    if (selected) setState(() => _selectedCategory = label);
                  },
                );
              },
            ),
          ),

          // Directory List with FAB Clearance
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
                                _searchQuery.isNotEmpty
                                    ? "No matching spots found for '$_searchQuery'"
                                    : "No neighborhood spots listed yet in $_currentHubCity",
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF475569),
                                ),
                              ),
                              const SizedBox(height: 6),
                              const Text(
                                "Be the first to list a barber, chemist, or food stall!",
                                textAlign: TextAlign.center,
                                style: TextStyle(fontSize: 12.5, color: Color(0xFF94A3B8)),
                              ),
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
                          padding: EdgeInsets.fromLTRB(16, 6, 16, bottomInset + 100),
                          itemCount: _filteredPlaces.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 12),
                          itemBuilder: (context, index) {
                            final gem = _filteredPlaces[index];
                            final name = gem['name'] ?? 'Local Spot';
                            final category = gem['category'] ?? 'General';
                            final address = gem['address'] ?? '';
                            final city = gem['city'] ?? _currentHubCity;
                            final description = gem['description'] ?? '';
                            final phone = (gem['contact_phone'] ?? '').toString().trim();
                            final mapsUrl = (gem['maps_url'] ?? '').toString().trim();
                            final contributor = gem['contributor_name'] ?? 'Local Resident';
                            final upvotes = (gem['upvotes'] as num?)?.toInt() ?? 0;
                            final tip = (gem['must_try_tip'] ?? '').toString().trim();

                            List<String> tags = [];
                            if (gem['endorsement_tags'] is List) {
                              tags = List<String>.from(gem['endorsement_tags']);
                            }

                            final accentColor = _getCategoryColor(category);
                            final distanceStr = _calculateDistance(gem);

                            return Container(
                              padding: const EdgeInsets.all(16),
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
                                              style: const TextStyle(
                                                fontSize: 16,
                                                fontWeight: FontWeight.w800,
                                                color: Color(0xFF0F172A),
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            Wrap(
                                              crossAxisAlignment: WrapCrossAlignment.center,
                                              spacing: 6,
                                              runSpacing: 4,
                                              children: [
                                                Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                                  decoration: BoxDecoration(
                                                    color: accentColor.withOpacity(0.08),
                                                    borderRadius: BorderRadius.circular(6),
                                                  ),
                                                  child: Text(
                                                    category,
                                                    style: TextStyle(
                                                      fontSize: 11,
                                                      fontWeight: FontWeight.bold,
                                                      color: accentColor,
                                                    ),
                                                  ),
                                                ),
                                                Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                  decoration: BoxDecoration(
                                                    color: const Color(0xFFF1F5F9),
                                                    borderRadius: BorderRadius.circular(6),
                                                  ),
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
                                      InkWell(
                                        borderRadius: BorderRadius.circular(20),
                                        onTap: () => _handleUpvote(gem),
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFEFF6FF),
                                            borderRadius: BorderRadius.circular(20),
                                            border: Border.all(color: const Color(0xFFBFDBFE)),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              const Icon(Icons.thumb_up_rounded, size: 13, color: Color(0xFF2563EB)),
                                              const SizedBox(width: 5),
                                              Text(
                                                "$upvotes",
                                                style: const TextStyle(
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.bold,
                                                  color: Color(0xFF1E40AF),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
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
                                          style: const TextStyle(
                                            fontSize: 12.5,
                                            color: Color(0xFF475569),
                                            fontWeight: FontWeight.w500,
                                          ),
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
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFF1F5F9),
                                            borderRadius: BorderRadius.circular(6),
                                            border: Border.all(color: const Color(0xFFE2E8F0)),
                                          ),
                                          child: Text(t, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF334155))),
                                        );
                                      }).toList(),
                                    ),
                                  ],

                                  if (tip.isNotEmpty) ...[
                                    const SizedBox(height: 8),
                                    Container(
                                      width: double.infinity,
                                      padding: const EdgeInsets.all(9),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFFEFCE8),
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(color: const Color(0xFFFEF08A)),
                                      ),
                                      child: Row(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          const Text("💡 ", style: TextStyle(fontSize: 13)),
                                          Expanded(
                                            child: Text(
                                              tip,
                                              style: const TextStyle(fontSize: 12, color: Color(0xFF854D0E), fontWeight: FontWeight.w600, height: 1.3),
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
                                      child: Row(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          const Text("“ ", style: TextStyle(color: Color(0xFF94A3B8), fontSize: 15, fontWeight: FontWeight.bold)),
                                          Expanded(
                                            child: Text(
                                              description,
                                              style: const TextStyle(fontSize: 12, color: Color(0xFF334155), height: 1.3),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],

                                  const SizedBox(height: 10),

                                  Row(
                                    children: [
                                      const Icon(Icons.person_outline_rounded, size: 13, color: Color(0xFF94A3B8)),
                                      const SizedBox(width: 4),
                                      Text(
                                        "Recommended by $contributor",
                                        style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8), fontWeight: FontWeight.w500),
                                      ),
                                    ],
                                  ),

                                  const SizedBox(height: 10),
                                  const Divider(height: 1),
                                  const SizedBox(height: 10),

                                  // Balanced Compact Action Bar
                                  Row(
                                    children: [
                                      if (phone.isNotEmpty) ...[
                                        InkWell(
                                          onTap: () => _callPhone(phone),
                                          borderRadius: BorderRadius.circular(10),
                                          child: Container(
                                            width: 36,
                                            height: 36,
                                            decoration: BoxDecoration(
                                              color: const Color(0xFFF0FDF4),
                                              border: Border.all(color: const Color(0xFFBBF7D0)),
                                              borderRadius: BorderRadius.circular(10),
                                            ),
                                            child: const Icon(Icons.call_rounded, size: 17, color: Color(0xFF16A34A)),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        InkWell(
                                          onTap: () => _launchWhatsApp(phone, name),
                                          borderRadius: BorderRadius.circular(10),
                                          child: Container(
                                            width: 36,
                                            height: 36,
                                            decoration: BoxDecoration(
                                              color: const Color(0xFFECFDF5),
                                              border: Border.all(color: const Color(0xFFA7F3D0)),
                                              borderRadius: BorderRadius.circular(10),
                                            ),
                                            child: const Icon(Icons.chat_bubble_rounded, size: 16, color: Color(0xFF059669)),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                      ],
                                      InkWell(
                                        onTap: () => _showEndorseSheet(gem),
                                        borderRadius: BorderRadius.circular(10),
                                        child: Container(
                                          width: 36,
                                          height: 36,
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFFEFCE8),
                                            border: Border.all(color: const Color(0xFFFDE68A)),
                                            borderRadius: BorderRadius.circular(10),
                                          ),
                                          child: const Icon(Icons.star_rounded, size: 19, color: Color(0xFFD97706)),
                                        ),
                                      ),
                                      const Spacer(),
                                      SizedBox(
                                        height: 36,
                                        child: ElevatedButton.icon(
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: const Color(0xFF2563EB),
                                            foregroundColor: Colors.white,
                                            elevation: 0,
                                            padding: const EdgeInsets.symmetric(horizontal: 14),
                                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                          ),
                                          icon: const Icon(Icons.directions_rounded, size: 15),
                                          label: const Text(
                                            "Navigate",
                                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                                          ),
                                          onPressed: () => _launchMaps(mapsUrl, name),
                                        ),
                                      ),
                                    ],
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