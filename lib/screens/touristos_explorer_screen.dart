import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import '../services/offline_cache_service.dart';
import '../services/affiliate_launcher_service.dart';
import 'flights_and_stays_hub_screen.dart';
import 'location_details_dossier_screen.dart';

class TouristOSExplorerScreen extends StatefulWidget {
  final String language;
  final String initialCountry;
  final String initialState;
  final String initialCity;
  final String backendUrl;

  const TouristOSExplorerScreen({
    Key? key,
    required this.language,
    this.initialCountry = "India",
    this.initialState = "Maharashtra",
    this.initialCity = "Mumbai",
    this.backendUrl = "https://omni-backend-pk28.onrender.com",
  }) : super(key: key);

  @override
  State<TouristOSExplorerScreen> createState() => _TouristOSExplorerScreenState();
}

class _TouristOSExplorerScreenState extends State<TouristOSExplorerScreen> {
  late TextEditingController _cityCtrl;
  late TextEditingController _stateCtrl;
  late TextEditingController _countryCtrl;

  int _adults = 2;
  int _kids = 0;
  bool _isExpanded = true;
  bool _isLoading = false;
  String _statusMessage = "";
  String _selectedCategory = "All";

  List<dynamic> _landmarks = [];
  List<dynamic> _hotels = [];

  final List<String> _categories = [
    "All",
    "Historic Bastion",
    "Sacred Pilgrimage",
    "Coastal & Beach",
    "Nature & Scenic",
    "Entertainment & Nightlife",
  ];

  @override
  void initState() {
    super.initState();
    _cityCtrl = TextEditingController(text: widget.initialCity);
    _stateCtrl = TextEditingController(text: widget.initialState);
    _countryCtrl = TextEditingController(text: widget.initialCountry);
    _fetchDestinationData();
  }

  @override
  void dispose() {
    _cityCtrl.dispose();
    _stateCtrl.dispose();
    _countryCtrl.dispose();
    super.dispose();
  }

  Future<void> _fetchDestinationData() async {
    final city = _cityCtrl.text.trim();
    final state = _stateCtrl.text.trim();
    final country = _countryCtrl.text.trim();

    if (city.isEmpty) return;

    setState(() {
      _isLoading = true;
      _landmarks = [];
      _hotels = [];
      _statusMessage = "Loading verified landmarks and accommodations for $city...";
    });

    final cached = await OfflineCacheService.getCachedCityDossier(city);
    if (cached != null && mounted) {
      _parseDossierResponse(cached);
    }

    try {
      final cleanUrl = widget.backendUrl.replaceAll(RegExp(r'/+$'), '');
      final uri = Uri.parse("$cleanUrl/api/v1/explore-city");

      final response = await http
          .post(
            uri,
            headers: {"Content-Type": "application/json"},
            body: jsonEncode({
              "city": city,
              "state": state,
              "country": country,
              "target_language": widget.language,
              "adults": _adults,
              "kids": _kids,
              "request_count": 30,
            }),
          )
          .timeout(
            const Duration(seconds: 40),
            onTimeout: () => throw Exception("timeout"),
          );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (mounted) {
          _parseDossierResponse(data);
          await OfflineCacheService.saveCityDossier(city, data);
        }
      } else {
        if (_landmarks.isEmpty && mounted) {
          _buildRichFallbackCatalog(city, state, country);
        }
      }
    } catch (e) {
      if (_landmarks.isEmpty && mounted) {
        _buildRichFallbackCatalog(city, state, country);
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _parseDossierResponse(Map<String, dynamic> data) {
    List<dynamic> spots = [];
    List<dynamic> hotels = [];

    if (data.containsKey("pillars") && data["pillars"] is Map) {
      final p = data["pillars"] as Map<String, dynamic>;
      spots = p["heritage"] ?? [];
      hotels = p["real_hotels"] ?? [];
    } else {
      spots = data["landmarks"] ?? data["places"] ?? [];
      hotels = data["hotels"] ?? [];
    }

    if (spots.isEmpty) {
      _buildRichFallbackCatalog(_cityCtrl.text.trim(), _stateCtrl.text.trim(), _countryCtrl.text.trim());
      return;
    }

    setState(() {
      _landmarks = spots;
      _hotels = hotels;
    });
  }

  Future<void> _launchMaps(double lat, double lng, String label) async {
    HapticFeedback.selectionClick();
    final cleanLabel = Uri.encodeComponent(label);
    final url = (lat == 0.0 && lng == 0.0)
        ? Uri.parse("https://www.google.com/maps/search/?api=1&query=$cleanLabel+${_cityCtrl.text}")
        : Uri.parse(
            "https://www.google.com/maps/dir/?api=1&destination=$lat,$lng&destination_place_id=$cleanLabel&travelmode=driving");

    try {
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
      }
    } catch (_) {}
  }

  void _openDetailDossier(Map<String, dynamic> item) {
    HapticFeedback.mediumImpact();
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (ctx) => LocationDetailDossierScreen(
          landmark: item,
          city: _cityCtrl.text.trim(),
          state: _stateCtrl.text.trim(),
          country: _countryCtrl.text.trim(),
          adults: _adults,
          kids: _kids,
          language: widget.language,
          backendHotels: _hotels,
        ),
      ),
    );
  }

  void _buildRichFallbackCatalog(String city, String state, String country) {
    final lower = city.toLowerCase();
    List<Map<String, dynamic>> generated = [];

    if (lower.contains("jaipur")) {
      generated = [
        {
          "name": "Amber Fort (Amer Palace)",
          "category": "Historic Bastion",
          "timing": "08:00 AM - 05:30 PM",
          "entry_fee": "₹100 (Indians) / ₹500 (Foreigners)",
          "lat": 26.9855,
          "lng": 75.8513,
          "description": "Opulent 16th-century hilltop fortress built by Raja Man Singh I, famed for its Sheesh Mahal and artistic Hindu elements.",
          "image": "https://upload.wikimedia.org/wikipedia/commons/thumb/1/14/Amber_Fort_Jaipur.jpg/1200px-Amber_Fort_Jaipur.jpg"
        },
        {
          "name": "Hawa Mahal (Palace of Winds)",
          "category": "Historic Bastion",
          "timing": "09:00 AM - 04:30 PM",
          "entry_fee": "₹50 (Indians) / ₹200 (Foreigners)",
          "lat": 26.9239,
          "lng": 75.8267,
          "description": "Famed five-story red and pink sandstone palace with 953 jharokhas designed by Lal Chand Ustad in 1799.",
          "image": "https://upload.wikimedia.org/wikipedia/commons/thumb/4/4e/Hawa_Mahal_2011.jpg/1200px-Hawa_Mahal_2011.jpg"
        },
        {
          "name": "City Palace of Jaipur",
          "category": "Historic Bastion",
          "timing": "09:30 AM - 05:00 PM",
          "entry_fee": "₹300 / ₹700",
          "lat": 26.9258,
          "lng": 75.8237,
          "description": "Stately royal residence built by Maharaja Sawai Jai Singh II blending Rajput, Mughal, and European architecture.",
          "image": "https://upload.wikimedia.org/wikipedia/commons/thumb/c/cb/City_Palace%2C_Jaipur_2015.jpg/1200px-City_Palace%2C_Jaipur_2015.jpg"
        },
        {
          "name": "Jal Mahal (Water Palace)",
          "category": "Nature & Scenic",
          "timing": "Viewable 24 Hours",
          "entry_fee": "Free",
          "lat": 26.9534,
          "lng": 75.8462,
          "description": "Serene Rajput-style palace situated in the middle of Man Sagar Lake, surrounded by the Aravalli hills.",
          "image": "https://upload.wikimedia.org/wikipedia/commons/thumb/a/a2/Jal_Mahal_Jaipur.jpg/1200px-Jal_Mahal_Jaipur.jpg"
        },
        {
          "name": "Jantar Mantar Observatory",
          "category": "Historic Bastion",
          "timing": "09:00 AM - 04:30 PM",
          "entry_fee": "₹50 / ₹200",
          "lat": 26.9248,
          "lng": 75.8246,
          "description": "UNESCO World Heritage collection of 19 architectural astronomical instruments completed in 1734.",
          "image": "https://upload.wikimedia.org/wikipedia/commons/thumb/3/3a/Jantar_Mantar_Jaipur_1.jpg/1200px-Jantar_Mantar_Jaipur_1.jpg"
        },
        {
          "name": "Nahargarh Fort",
          "category": "Historic Bastion",
          "timing": "10:00 AM - 05:30 PM",
          "entry_fee": "₹50 / ₹200",
          "lat": 26.9374,
          "lng": 75.8155,
          "description": "Hillside fort along the Aravalli ridge providing sweeping sunset panoramas of Jaipur city.",
          "image": "https://upload.wikimedia.org/wikipedia/commons/thumb/f/fa/Nahargarh_Fort_Overview.jpg/1200px-Nahargarh_Fort_Overview.jpg"
        },
      ];
    } else if (lower.contains("mumbai")) {
      generated = [
        {
          "name": "Gateway of India",
          "category": "Historic Bastion",
          "timing": "Open 24 Hours",
          "entry_fee": "Free",
          "lat": 18.9220,
          "lng": 72.8347,
          "description": "Iconic 26m Indo-Saracenic basalt arch built to commemorate the 1911 visit of King George V.",
          "image": "https://upload.wikimedia.org/wikipedia/commons/thumb/d/df/Gateway_of_India_Mumbai.jpg/1200px-Gateway_of_India_Mumbai.jpg"
        },
        {
          "name": "Chhatrapati Shivaji Maharaj Terminus (CSMT)",
          "category": "Historic Bastion",
          "timing": "Open 24 Hours",
          "entry_fee": "Free",
          "lat": 18.9400,
          "lng": 72.8354,
          "description": "UNESCO World Heritage Gothic Revival railway terminus and architectural landmark.",
          "image": "https://upload.wikimedia.org/wikipedia/commons/thumb/7/7b/Victoria_Terminus_Mumbai.jpg/1200px-Victoria_Terminus_Mumbai.jpg"
        },
        {
          "name": "Marine Drive Promenade",
          "category": "Coastal & Beach",
          "timing": "Open 24 Hours",
          "entry_fee": "Free",
          "lat": 18.9432,
          "lng": 72.8230,
          "description": "3.6km C-shaped coastal boulevard known as Queen's Necklace overlooking the Arabian Sea.",
          "image": "https://upload.wikimedia.org/wikipedia/commons/thumb/6/64/Marine_Drive_Mumbai_Evening.jpg/1200px-Marine_Drive_Mumbai_Evening.jpg"
        },
      ];
    } else {
      generated = [
        {
          "name": "$city Historic Old Quarter",
          "category": "Historic Bastion",
          "timing": "Open daily",
          "entry_fee": "Free",
          "lat": 0.0,
          "lng": 0.0,
          "description": "The heritage civic core, historic architecture, and pedestrian streets of $city, $country.",
          "image": "https://images.unsplash.com/photo-1519671482749-fd09be7ccebf?auto=format&fit=crop&w=1200&q=80"
        },
        {
          "name": "$city Scenic Promenade",
          "category": "Coastal & Beach",
          "timing": "Open 24 Hours",
          "entry_fee": "Free",
          "lat": 0.0,
          "lng": 0.0,
          "description": "Central strolling avenue and viewpoint celebrating the regional landscape of $city.",
          "image": "https://images.unsplash.com/photo-1507525428034-b723cf961d3e?auto=format&fit=crop&w=1200&q=80"
        },
      ];
    }

    setState(() => _landmarks = generated);
  }

  @override
  Widget build(BuildContext context) {
    final city = _cityCtrl.text.trim();

    final filteredLandmarks = _selectedCategory == "All"
        ? _landmarks
        : _landmarks.where((l) {
            final cat = (l["category"] ?? "").toString().toLowerCase();
            return cat.contains(_selectedCategory.toLowerCase());
          }).toList();

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: RefreshIndicator(
        onRefresh: _fetchDestinationData,
        color: const Color(0xFF2563EB),
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                  boxShadow: [
                    BoxShadow(
                        color: Colors.black.withOpacity(0.03),
                        blurRadius: 10,
                        offset: const Offset(0, 4)),
                  ],
                ),
                child: Column(
                  children: [
                    ListTile(
                      dense: true,
                      leading: const Icon(Icons.tune_rounded,
                          color: Color(0xFF2563EB), size: 20),
                      title: Text(
                        "Destination Cockpit: $city",
                        style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 14,
                            color: Color(0xFF0F172A)),
                      ),
                      trailing: IconButton(
                        icon: Icon(_isExpanded
                            ? Icons.keyboard_arrow_up_rounded
                            : Icons.keyboard_arrow_down_rounded),
                        onPressed: () =>
                            setState(() => _isExpanded = !_isExpanded),
                      ),
                    ),
                    if (_isExpanded) ...[
                      const Divider(height: 1, color: Color(0xFFF1F5F9)),
                      Padding(
                        padding: const EdgeInsets.all(14),
                        child: Column(
                          children: [
                            TextField(
                              controller: _cityCtrl,
                              decoration: InputDecoration(
                                labelText: "Destination / City",
                                prefixIcon: const Icon(Icons.location_city_rounded,
                                    size: 18),
                                border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12)),
                                contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 10),
                                isDense: true,
                              ),
                            ),
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                Expanded(
                                  child: TextField(
                                    controller: _countryCtrl,
                                    decoration: InputDecoration(
                                      labelText: "Country",
                                      prefixIcon: const Icon(Icons.public_rounded,
                                          size: 18),
                                      border: OutlineInputBorder(
                                          borderRadius:
                                              BorderRadius.circular(12)),
                                      contentPadding:
                                          const EdgeInsets.symmetric(
                                              horizontal: 12, vertical: 10),
                                      isDense: true,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: TextField(
                                    controller: _stateCtrl,
                                    decoration: InputDecoration(
                                      labelText: "State / Region",
                                      prefixIcon: const Icon(Icons.map_rounded,
                                          size: 18),
                                      border: OutlineInputBorder(
                                          borderRadius:
                                              BorderRadius.circular(12)),
                                      contentPadding:
                                          const EdgeInsets.symmetric(
                                              horizontal: 12, vertical: 10),
                                      isDense: true,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                Expanded(
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 10, vertical: 4),
                                    decoration: BoxDecoration(
                                      border: Border.all(
                                          color: const Color(0xFFCBD5E1)),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        const Text("Adults",
                                            style: TextStyle(
                                                fontSize: 12,
                                                fontWeight: FontWeight.bold)),
                                        Row(
                                          children: [
                                            IconButton(
                                              icon: const Icon(Icons.remove,
                                                  size: 14),
                                              onPressed: _adults > 1
                                                  ? () => setState(
                                                      () => _adults--)
                                                  : null,
                                            ),
                                            Text("$_adults",
                                                style: const TextStyle(
                                                    fontWeight:
                                                        FontWeight.bold)),
                                            IconButton(
                                              icon: const Icon(Icons.add,
                                                  size: 14),
                                              onPressed: () =>
                                                  setState(() => _adults++),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 10, vertical: 4),
                                    decoration: BoxDecoration(
                                      border: Border.all(
                                          color: const Color(0xFFCBD5E1)),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        const Text("Kids",
                                            style: TextStyle(
                                                fontSize: 12,
                                                fontWeight: FontWeight.bold)),
                                        Row(
                                          children: [
                                            IconButton(
                                              icon: const Icon(Icons.remove,
                                                  size: 14),
                                              onPressed: _kids > 0
                                                  ? () => setState(
                                                      () => _kids--)
                                                  : null,
                                            ),
                                            Text("$_kids",
                                                style: const TextStyle(
                                                    fontWeight:
                                                        FontWeight.bold)),
                                            IconButton(
                                              icon: const Icon(Icons.add,
                                                  size: 14),
                                              onPressed: () =>
                                                  setState(() => _kids++),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            SizedBox(
                              width: double.infinity,
                              height: 44,
                              child: ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF2563EB),
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12)),
                                ),
                                onPressed: _isLoading
                                    ? null
                                    : () {
                                        HapticFeedback.selectionClick();
                                        _fetchDestinationData();
                                      },
                                icon: _isLoading
                                    ? const SizedBox(
                                        width: 16,
                                        height: 16,
                                        child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: Colors.white),
                                      )
                                    : const Icon(Icons.explore_rounded,
                                        size: 18),
                                label: Text(
                                  _isLoading
                                      ? "Exploring Landmarks..."
                                      : "EXPLORE DESTINATION",
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              const SizedBox(height: 14),

              Row(
                children: [
                  Expanded(
                    child: InkWell(
                      onTap: () {
                        HapticFeedback.selectionClick();
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (ctx) => FlightsAndStaysHubScreen(
                              initialCity: _cityCtrl.text.trim(),
                              initialCountry: _countryCtrl.text.trim(),
                              initialTab: 0,
                            ),
                          ),
                        );
                      },
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            vertical: 10, horizontal: 10),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEFF6FF),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFBFDBFE)),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: const [
                            Icon(Icons.flight_takeoff_rounded,
                                size: 16, color: Color(0xFF2563EB)),
                            SizedBox(width: 6),
                            Text("Book Flights",
                                style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF1D4ED8))),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: InkWell(
                      onTap: () {
                        // Direct, sanitized Booking.com search launch without broken intermediate routes
                        AffiliateLauncherService.launchBookingStays(
                          city: _cityCtrl.text.trim(),
                          country: _countryCtrl.text.trim(),
                          adults: _adults,
                          children: _kids,
                          currency: "INR",
                        );
                      },
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            vertical: 10, horizontal: 10),
                        decoration: BoxDecoration(
                          color: const Color(0xFF003580),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: const [
                            Icon(Icons.open_in_browser_rounded,
                                size: 16, color: Color(0xFF38BDF8)),
                            SizedBox(width: 6),
                            Text("Booking.com",
                                style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white)),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 18),

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    "Explore • $city (${_landmarks.length} Verified)",
                    style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 16,
                        color: Color(0xFF0F172A)),
                  ),
                  IconButton(
                    tooltip: "Reload",
                    icon: const Icon(Icons.refresh_rounded,
                        color: Color(0xFF2563EB)),
                    onPressed: _fetchDestinationData,
                  ),
                ],
              ),

              SizedBox(
                height: 38,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: _categories.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (context, i) {
                    final cat = _categories[i];
                    final isSelected = cat == _selectedCategory;
                    return ChoiceChip(
                      label: Text(cat),
                      selected: isSelected,
                      selectedColor: const Color(0xFF2563EB),
                      backgroundColor: Colors.white,
                      labelStyle: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.bold,
                        color: isSelected
                            ? Colors.white
                            : const Color(0xFF64748B),
                      ),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16)),
                      onSelected: (val) {
                        if (val) setState(() => _selectedCategory = cat);
                      },
                    );
                  },
                ),
              ),

              const SizedBox(height: 14),

              _isLoading
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 40),
                        child: Column(
                          children: [
                            const CircularProgressIndicator(
                                color: Color(0xFF2563EB)),
                            const SizedBox(height: 14),
                            Text(_statusMessage,
                                style: const TextStyle(
                                    fontSize: 12, color: Color(0xFF64748B))),
                          ],
                        ),
                      ),
                    )
                  : filteredLandmarks.isEmpty
                      ? Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(32),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                          ),
                          child: Column(
                            children: [
                              const Icon(Icons.domain_disabled_rounded,
                                  size: 42, color: Color(0xFFCBD5E1)),
                              const SizedBox(height: 10),
                              Text("No landmarks found for $city",
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13.5,
                                      color: Color(0xFF475569))),
                              const SizedBox(height: 4),
                              const Text(
                                  "Tap 'Explore Destination' or check connection.",
                                  style: TextStyle(
                                      fontSize: 11.5, color: Color(0xFF94A3B8))),
                            ],
                          ),
                        )
                      : ListView.separated(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: filteredLandmarks.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 14),
                          itemBuilder: (context, i) {
                            final lm = filteredLandmarks[i];
                            final title = lm["name"] ?? "Point of Interest";
                            final cat = lm["category"] ?? "Heritage Spot";
                            final desc = lm["detail"] ?? lm["description"] ?? "";
                            final timing = lm["timing"] ?? "Open Daily";
                            final lat = (lm["lat"] as num?)?.toDouble() ?? 0.0;
                            final lng = (lm["lng"] as num?)?.toDouble() ?? 0.0;
                            final imageUrl = (lm["image"] != null && lm["image"].toString().isNotEmpty)
                                ? lm["image"].toString()
                                : "https://images.unsplash.com/photo-1590050752117-238cb0fb12b1?auto=format&fit=crop&w=800&q=80";

                            return Container(
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(18),
                                border: Border.all(color: const Color(0xFFE2E8F0)),
                                boxShadow: [
                                  BoxShadow(
                                      color: Colors.black.withOpacity(0.02),
                                      blurRadius: 8,
                                      offset: const Offset(0, 2)),
                                ],
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  ClipRRect(
                                    borderRadius: const BorderRadius.vertical(
                                        top: Radius.circular(18)),
                                    child: Stack(
                                      children: [
                                        Image.network(
                                          imageUrl,
                                          height: 165,
                                          width: double.infinity,
                                          fit: BoxFit.cover,
                                          errorBuilder: (_, __, ___) =>
                                              Container(
                                            height: 165,
                                            decoration: const BoxDecoration(
                                              gradient: LinearGradient(colors: [
                                                Color(0xFF1E3A8A),
                                                Color(0xFF2563EB)
                                              ]),
                                            ),
                                            child: const Center(
                                                child: Icon(
                                                    Icons.account_balance_rounded,
                                                    color: Colors.white54,
                                                    size: 36)),
                                          ),
                                        ),
                                        Positioned(
                                          top: 10,
                                          left: 10,
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 8, vertical: 4),
                                            decoration: BoxDecoration(
                                              color:
                                                  Colors.black.withOpacity(0.65),
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                            ),
                                            child: Text("#${i + 1} Top Pick",
                                                style: const TextStyle(
                                                    color: Colors.white,
                                                    fontSize: 10.5,
                                                    fontWeight: FontWeight.bold)),
                                          ),
                                        ),
                                        Positioned(
                                          top: 10,
                                          right: 10,
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 8, vertical: 4),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFF2563EB),
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                            ),
                                            child: Text(cat,
                                                style: const TextStyle(
                                                    color: Colors.white,
                                                    fontSize: 10.5,
                                                    fontWeight: FontWeight.bold)),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),

                                  Padding(
                                    padding: const EdgeInsets.all(14),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(title,
                                            style: const TextStyle(
                                                fontSize: 15.5,
                                                fontWeight: FontWeight.w900,
                                                color: Color(0xFF0F172A))),
                                        const SizedBox(height: 4),
                                        Text(desc,
                                            style: const TextStyle(
                                                fontSize: 12.5,
                                                color: Color(0xFF475569),
                                                height: 1.3),
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis),
                                        const SizedBox(height: 10),
                                        Row(
                                          children: [
                                            const Icon(
                                                Icons.access_time_rounded,
                                                size: 13,
                                                color: Color(0xFF64748B)),
                                            const SizedBox(width: 4),
                                            Text(timing,
                                                style: const TextStyle(
                                                    fontSize: 11,
                                                    fontWeight: FontWeight.w600,
                                                    color: Color(0xFF64748B))),
                                          ],
                                        ),
                                        const Divider(
                                            height: 18, color: Color(0xFFF1F5F9)),

                                        Row(
                                          children: [
                                            Expanded(
                                              child: OutlinedButton.icon(
                                                style: OutlinedButton.styleFrom(
                                                  foregroundColor:
                                                      const Color(0xFF0F172A),
                                                  side: const BorderSide(
                                                      color: Color(0xFFCBD5E1)),
                                                  padding:
                                                      const EdgeInsets.symmetric(
                                                          vertical: 10),
                                                  shape: RoundedRectangleBorder(
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                              10)),
                                                ),
                                                icon: const Icon(
                                                    Icons.manage_search_rounded,
                                                    size: 16,
                                                    color: Color(0xFF2563EB)),
                                                label: const Text("Explore",
                                                    style: TextStyle(
                                                        fontWeight:
                                                            FontWeight.bold,
                                                        fontSize: 12.5)),
                                                onPressed: () =>
                                                    _openDetailDossier(lm),
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            Expanded(
                                              child: ElevatedButton.icon(
                                                style: ElevatedButton.styleFrom(
                                                  backgroundColor:
                                                      const Color(0xFF2563EB),
                                                  foregroundColor: Colors.white,
                                                  padding:
                                                      const EdgeInsets.symmetric(
                                                          vertical: 10),
                                                  shape: RoundedRectangleBorder(
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                              10)),
                                                  elevation: 0,
                                                ),
                                                icon: const Icon(
                                                    Icons.navigation_rounded,
                                                    size: 15),
                                                label: const Text("Navigate",
                                                    style: TextStyle(
                                                        fontWeight:
                                                            FontWeight.bold,
                                                        fontSize: 12.5)),
                                                onPressed: () =>
                                                    _launchMaps(lat, lng, title),
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
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }
}