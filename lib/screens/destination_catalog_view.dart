import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import '../services/trip_state_service.dart';
import '../widgets/metallic_embossed_button.dart';

class DestinationCatalogView extends StatefulWidget {
  final String language;
  final String activeCity;
  final String activeState;
  final String activeCountry;
  final String backendUrl;
  final Function(String destinationCity)? onSelectDestinationForFlights;

  const DestinationCatalogView({
    Key? key,
    required this.language,
    required this.activeCity,
    required this.activeState,
    required this.activeCountry,
    this.backendUrl = "https://omni-backend-pk28.onrender.com",
    this.onSelectDestinationForFlights,
  }) : super(key: key);

  @override
  State<DestinationCatalogView> createState() => _DestinationCatalogViewState();
}

class _DestinationCatalogViewState extends State<DestinationCatalogView> with SingleTickerProviderStateMixin {
  late TextEditingController _cityCtrl;
  late TextEditingController _stateCtrl;
  late TextEditingController _countryCtrl;

  late TabController _subTabController;
  int _currentSubTab = 0; // 0 = Sights & Itineraries, 1 = Stays & Hotels

  int _adults = 2;
  int _kids = 0;
  DateTime _startDate = DateTime.now().add(const Duration(days: 3));
  DateTime _returnDate = DateTime.now().add(const Duration(days: 7));

  bool _isFilterExpanded = false;
  bool _isLoading = false;
  String _selectedCategory = "All";
  String _selectedHotelTier = "All";

  String _currencyCode = "INR";
  String _currencySymbol = "₹";
  static const String _travelPayoutsAid = "774359";

  List<Map<String, dynamic>> _locations = [];
  List<Map<String, dynamic>> _stays = [];

  final List<String> _categories = [
    "All",
    "Heritage & Forts",
    "Sacred & Spiritual",
    "Beaches & Coast",
    "Nature & Wildlife",
    "Culinary & Bazaars",
  ];

  final List<String> _hotelTiers = [
    "All",
    "Budget Comfort",
    "4-Star & Executive",
    "5-Star Luxury Resort",
  ];

  static const Map<String, String> _browserHeaders = {
    "User-Agent": "OmniTouristOS/4.0 (contact: info@touristos.app) Chrome/120.0 Mobile Safari/537.36",
    "Accept": "application/json,image/webp,image/*,*/*;q=0.8",
  };

  @override
  void initState() {
    super.initState();
    _cityCtrl = TextEditingController(text: widget.activeCity);
    _stateCtrl = TextEditingController(text: widget.activeState);
    _countryCtrl = TextEditingController(text: widget.activeCountry);

    _subTabController = TabController(length: 2, vsync: this);
    _subTabController.addListener(() {
      if (_subTabController.indexIsChanging) {
        setState(() => _currentSubTab = _subTabController.index);
      }
    });

    _resolveLocalCurrency();
    _loadLocations();
  }

  @override
  void dispose() {
    _cityCtrl.dispose();
    _stateCtrl.dispose();
    _countryCtrl.dispose();
    _subTabController.dispose();
    super.dispose();
  }

  void _resolveLocalCurrency() {
    final city = _cityCtrl.text.trim().toLowerCase();
    final country = _countryCtrl.text.trim().toLowerCase();

    if (city.contains("dubai") || city.contains("abu dhabi") || country.contains("uae") || country.contains("emirates")) {
      _currencyCode = "AED";
      _currencySymbol = "AED ";
    } else if (city.contains("singapore") || country.contains("singapore")) {
      _currencyCode = "SGD";
      _currencySymbol = "S\$";
    } else if (city.contains("london") || country.contains("united kingdom") || country.contains("uk")) {
      _currencyCode = "GBP";
      _currencySymbol = "£";
    } else if (city.contains("tokyo") || country.contains("japan")) {
      _currencyCode = "JPY";
      _currencySymbol = "¥";
    } else if (city.contains("bangkok") || country.contains("thailand")) {
      _currencyCode = "THB";
      _currencySymbol = "฿";
    } else if (["france", "germany", "italy", "spain", "paris", "rome"].any((c) => city.contains(c) || country.contains(c))) {
      _currencyCode = "EUR";
      _currencySymbol = "€";
    } else if (country.contains("india") || ["vasai", "virar", "mumbai", "pune", "delhi", "goa", "jaipur", "bengaluru"].any((c) => city.contains(c))) {
      _currencyCode = "INR";
      _currencySymbol = "₹";
    } else {
      _currencyCode = "USD";
      _currencySymbol = "\$";
    }
  }

  Future<void> _loadLocations() async {
    final city = _cityCtrl.text.trim();
    final state = _stateCtrl.text.trim();
    final country = _countryCtrl.text.trim();

    if (city.isEmpty) return;

    _resolveLocalCurrency();
    setState(() => _isLoading = true);

    try {
      final cleanUrl = widget.backendUrl.replaceAll(RegExp(r'/+$'), '');
      final res = await http.post(
        Uri.parse("$cleanUrl/api/v1/explore-city"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "city": city,
          "state": state,
          "country": country,
          "target_language": widget.language,
          "adults": _adults,
          "kids": _kids,
          "start_date": _startDate.toIso8601String().split('T')[0],
          "return_date": _returnDate.toIso8601String().split('T')[0],
        }),
      ).timeout(const Duration(seconds: 12));

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final rawSpots = (data["landmarks"] ?? data["places"] ?? []) as List;
        final rawHotels = (data["hotels"] ?? []) as List;

        if (rawSpots.length >= 8) {
          final List<Map<String, dynamic>> enriched = [];
          for (int i = 0; i < rawSpots.length; i++) {
            final item = Map<String, dynamic>.from(rawSpots[i]);
            item["distance"] = _formatDistanceString(item["distance"], i);
            enriched.add(item);
          }

          if (mounted) {
            setState(() {
              _locations = enriched;
              _stays = rawHotels.map((e) => Map<String, dynamic>.from(e)).toList();
              _isLoading = false;
            });
            _enrichLandmarkPhotosInParallel(enriched);
            return;
          }
        }
      }
    } catch (_) {}

    await _buildCuratedHubOrFetchLive(city, state, country);
    if (mounted) setState(() => _isLoading = false);
  }

  String _formatDistanceString(dynamic rawDist, int fallbackIndex) {
    if (rawDist == null) {
      return "${((fallbackIndex + 1) * 1.2).toStringAsFixed(1)} km from Center";
    }
    final str = rawDist.toString();
    final match = RegExp(r'(\d+(?:\.\d+)?)').firstMatch(str);
    if (match != null) {
      final val = double.tryParse(match.group(1) ?? "");
      if (val != null) {
        return "${val.toStringAsFixed(1)} km from Center";
      }
    }
    return str;
  }

  Future<void> _enrichLandmarkPhotosInParallel(List<Map<String, dynamic>> list) async {
    for (int i = 0; i < list.length; i++) {
      final spot = list[i];
      final currentImgs = spot["images"] as List?;
      if (currentImgs == null || currentImgs.isEmpty || currentImgs.first.toString().contains("unsplash")) {
        final realWikiPhoto = await _fetchWikipediaThumbnail(spot["name"] ?? "");
        if (realWikiPhoto != null && realWikiPhoto.isNotEmpty && mounted) {
          setState(() {
            spot["images"] = [realWikiPhoto];
          });
        }
      }
    }
  }

  Future<String?> _fetchWikipediaThumbnail(String title) async {
    try {
      final cleanTitle = title.replaceAll(RegExp(r'\(.*?\)'), '').trim().replaceAll(' ', '_');
      final uri = Uri.parse("https://en.wikipedia.org/api/rest_v1/page/summary/${Uri.encodeComponent(cleanTitle)}");
      final res = await http.get(uri, headers: _browserHeaders).timeout(const Duration(seconds: 3));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (data["thumbnail"] != null && data["thumbnail"]["source"] != null) {
          final String src = data["thumbnail"]["source"];
          return src.replaceAll(RegExp(r'/\d+px-'), '/1000px-');
        }
      }
    } catch (_) {}
    return null;
  }

  Future<void> _buildCuratedHubOrFetchLive(String city, String state, String country) async {
    final lower = city.toLowerCase();
    List<Map<String, dynamic>> spots = [];
    List<Map<String, dynamic>> hotels = [];

    if (lower.contains("dubai")) {
      spots = _getDubai30Curated();
      hotels = _getDubaiHotels();
    } else if (lower.contains("singapore")) {
      spots = _getSingapore30Curated();
      hotels = _getSingaporeHotels();
    } else if (lower.contains("vasai") || lower.contains("virar") || lower.contains("nalasopara")) {
      spots = _getVasaiVirar30();
      hotels = _getVasaiHotels();
    } else {
      spots = await _fetchDynamicWikipediaSpotsWithThumbs(city);
      hotels = [
        {
          "name": "Grand Central Executive Stay $city",
          "tier": "4-Star & Executive",
          "rating": "8.8",
          "reviews": "1,240",
          "price": _currencyCode == "INR" ? 3800 : 95,
          "phone": "+1 800 555 0122",
          "distance": "1.1 km from Center",
          "amenities": "Free Wi-Fi • Breakfast • Gym",
          "lat": 0.0,
          "lng": 0.0
        },
        {
          "name": "Boutique Heritage Suites $city",
          "tier": "Budget Comfort",
          "rating": "8.5",
          "reviews": "820",
          "price": _currencyCode == "INR" ? 2200 : 55,
          "phone": "+1 800 555 0144",
          "distance": "2.4 km from Center",
          "amenities": "Free Wi-Fi • AC • 24/7 Desk",
          "lat": 0.0,
          "lng": 0.0
        }
      ];
    }

    setState(() {
      _locations = spots;
      _stays = hotels;
    });
  }

  Future<List<Map<String, dynamic>>> _fetchDynamicWikipediaSpotsWithThumbs(String city) async {
    final List<Map<String, dynamic>> results = [];
    try {
      final searchUrl = Uri.parse(
        "https://en.wikipedia.org/w/api.php?action=query&list=search&srsearch=${Uri.encodeComponent('$city tourist attractions landmarks points of interest')}&format=json&srlimit=20",
      );
      final res = await http.get(searchUrl, headers: _browserHeaders).timeout(const Duration(seconds: 4));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final searchItems = (data["query"]?["search"] ?? []) as List;

        for (int i = 0; i < searchItems.length; i++) {
          final item = searchItems[i];
          final String title = item["title"] ?? "";
          final String snippet = (item["snippet"] ?? "")
              .replaceAll(RegExp(r'<[^>]*>'), '')
              .replaceAll('&quot;', '"');

          if (title.isNotEmpty && !title.toLowerCase().contains("list of")) {
            final thumbUrl = await _fetchWikipediaThumbnail(title) ??
                "https://images.unsplash.com/photo-1488646953014-85cb44e25828?w=800&q=80";

            results.add({
              "name": title,
              "category": i % 3 == 0 ? "Heritage & Forts" : (i % 3 == 1 ? "Nature & Wildlife" : "Culinary & Bazaars"),
              "distance": "${((i + 1) * 1.3).toStringAsFixed(1)} km from Center",
              "timing": "09:00 AM – 06:30 PM",
              "entry": "Public Access / Ticketed",
              "lat": 0.0,
              "lng": 0.0,
              "images": [thumbUrl],
              "history": snippet.isNotEmpty ? snippet : "Prominent architectural and regional tourist destination in $city.",
              "best_food": "Local specialty cuisines and evening dining.",
              "things_to_do": "Walking tours, cultural sightseeing, and landscape photography.",
              "best_time": "Morning or sunset hours.",
              "scams_and_warnings": "Always obtain entry passes directly from the official ticket counter."
            });
          }
        }
      }
    } catch (_) {}

    return results;
  }

  List<Map<String, dynamic>> _getDubai30Curated() {
    return [
      {
        "name": "Burj Khalifa & Observation Decks",
        "category": "Heritage & Forts",
        "distance": "0.5 km from Center",
        "timing": "08:30 AM – 11:00 PM",
        "entry": "AED 179",
        "lat": 25.1972,
        "lng": 55.2744,
        "images": ["https://images.unsplash.com/photo-1512453979798-5ea266f8880c?w=800&q=80"],
        "history": "At 828 meters, Burj Khalifa is the tallest building on Earth, spanning 163 levels with dual observation decks overlooking the Persian Gulf.",
        "best_food": "At.mosphere Level 122 fine dining or Arabic shawarma at Dubai Mall.",
        "things_to_do": "Visit levels 124, 125 & 148, view Dubai Fountain shows from above.",
        "best_time": "Sunset slot (5:00 PM – 6:30 PM).",
        "scams_and_warnings": "Book official At The Top passes online; refuse touts outside mall gates."
      },
      {
        "name": "Museum of the Future",
        "category": "Heritage & Forts",
        "distance": "2.8 km from Center",
        "timing": "09:30 AM – 07:00 PM",
        "entry": "AED 149",
        "lat": 25.2192,
        "lng": 55.2819,
        "images": ["https://images.unsplash.com/photo-1634148545802-86f3630f9a72?w=800&q=80"],
        "history": "Architectural masterpiece shaped like a torus wrapped in Arabic calligraphy poetry, demonstrating space tech, ecosystems, and bioengineering of 2071.",
        "best_food": "Robotic barista espresso inside the entrance lobby.",
        "things_to_do": "Interactive space station orbital simulation and viewing deck.",
        "best_time": "Morning time slots. Advance booking is mandatory.",
        "scams_and_warnings": "Tickets are strictly reservation-only; no same-day counter tickets available."
      },
      {
        "name": "The Dubai Mall & Dubai Fountain",
        "category": "Culinary & Bazaars",
        "distance": "0.4 km from Center",
        "timing": "10:00 AM – 12:00 AM",
        "entry": "Free Public Access",
        "lat": 25.1985,
        "lng": 55.2796,
        "images": ["https://images.unsplash.com/photo-1580674684081-7617fbf3d745?w=800&q=80"],
        "history": "One of the world's largest retail and leisure hubs with over 1,200 shops, Olympic ice rink, and giant indoor aquarium.",
        "best_food": "Al Hallab Lebanese kebabs, Ladurée pastries, and camel-milk gelato.",
        "things_to_do": "Watch choreographed fountain performances every 30 minutes in the evening.",
        "best_time": "Evening from 6:00 PM onwards.",
        "scams_and_warnings": "Note your parking zone column code before shopping."
      },
      {
        "name": "Palm Jumeirah & The View at The Palm",
        "category": "Nature & Wildlife",
        "distance": "16.4 km from Center",
        "timing": "09:00 AM – 10:00 PM",
        "entry": "AED 100",
        "lat": 25.1124,
        "lng": 55.1390,
        "images": ["https://images.unsplash.com/photo-1546412414-e1885259563a?w=800&q=80"],
        "history": "Artificial offshore archipelago shaped like a palm tree, crowned by luxury resorts, pristine beaches, and the Palm Monorail.",
        "best_food": "Waterfront dining at Club Vista Mare and fresh seafood grills.",
        "things_to_do": "Ride the monorail, visit Nakheel Mall Level 52 observation terrace.",
        "best_time": "Sunset for 360-degree Arabian Gulf panoramas.",
        "scams_and_warnings": "Use official RTA metered taxis or the automated monorail."
      }
    ];
  }

  List<Map<String, dynamic>> _getDubaiHotels() {
    return [
      {
        "name": "JW Marriott Marquis Hotel Dubai",
        "tier": "5-Star Luxury Resort",
        "rating": "9.2",
        "reviews": "9,400",
        "price": 680,
        "phone": "+971 4 414 0000",
        "distance": "1.2 km from Dubai Mall",
        "amenities": "Twin 72-story Towers • 14 Restaurants • Saray Spa",
        "lat": 25.1852,
        "lng": 55.2581
      },
      {
        "name": "Rove Downtown Dubai",
        "tier": "4-Star & Executive",
        "rating": "9.1",
        "reviews": "5,800",
        "price": 340,
        "phone": "+971 4 561 9000",
        "distance": "0.8 km from Burj Khalifa",
        "amenities": "Burj View Pool • Cinema • Free Shuttle",
        "lat": 25.2012,
        "lng": 55.2810
      },
      {
        "name": "Atlantis, The Palm",
        "tier": "5-Star Luxury Resort",
        "rating": "9.4",
        "reviews": "18,200",
        "price": 1450,
        "phone": "+971 4 426 2000",
        "distance": "Palm Jumeirah Crescent",
        "amenities": "Free Waterpark • Private Beach • Michelin Dining",
        "lat": 25.1304,
        "lng": 55.1171
      }
    ];
  }

  List<Map<String, dynamic>> _getSingapore30Curated() {
    return [
      {
        "name": "Gardens by the Bay & Supertree Grove",
        "category": "Nature & Wildlife",
        "distance": "1.2 km from Center",
        "timing": "05:00 AM – 02:00 AM",
        "entry": "Outdoor Free (Domes SGD 32)",
        "lat": 1.2816,
        "lng": 103.8636,
        "images": ["https://images.unsplash.com/photo-1525625293386-3f8f99389edd?w=800&q=80"],
        "history": "Futuristic 101-hectare horticultural attraction housing 16-story vertical Supertree gardens, the Flower Dome, and Cloud Forest misty waterfall.",
        "best_food": "Satay by the Bay food court for chicken/mutton satay with peanut sauce.",
        "things_to_do": "Watch the Garden Rhapsody light show at 7:45 PM and walk the OCBC Skyway.",
        "best_time": "Late afternoon through evening light shows.",
        "scams_and_warnings": "Bring a light jacket for the indoor Cloud Forest dome; climate-controlled to 23°C."
      },
      {
        "name": "Marina Bay Sands SkyPark & Observation Deck",
        "category": "Heritage & Forts",
        "distance": "0.8 km from Center",
        "timing": "11:00 AM – 09:00 PM",
        "entry": "SGD 30 Observation Deck",
        "lat": 1.2834,
        "lng": 103.8607,
        "images": ["https://images.unsplash.com/photo-1506351421178-63b52a2d15c8?w=800&q=80"],
        "history": "Architectural icon designed by Moshe Safdie featuring three 55-story hotel towers connected by a cantilevering 340-meter SkyPark.",
        "best_food": "CÉ LA VI rooftop bar, or local laksa and Hainanese chicken rice at Rasapura Masters.",
        "things_to_do": "Take in panoramic city views across the Singapore Strait.",
        "best_time": "6:00 PM to view both day and illuminated night cityscapes.",
        "scams_and_warnings": "The infinity pool is accessible strictly to hotel guests with room keycards."
      }
    ];
  }

  List<Map<String, dynamic>> _getSingaporeHotels() {
    return [
      {
        "name": "Marina Bay Sands Hotel",
        "tier": "5-Star Luxury Resort",
        "rating": "9.3",
        "reviews": "14,800",
        "price": 680,
        "phone": "+65 6688 8868",
        "distance": "0.3 km from Bayfront MRT",
        "amenities": "World Famous Infinity Pool • Casino • Banyan Tree Spa",
        "lat": 1.2834,
        "lng": 103.8607
      }
    ];
  }

  List<Map<String, dynamic>> _getVasaiVirar30() {
    return [
      {
        "name": "Bassein Fort (Fort Vasai)",
        "category": "Heritage & Forts",
        "distance": "1.2 km from Center",
        "timing": "06:00 AM – 06:30 PM",
        "entry": "Free Public Entry",
        "lat": 19.3308,
        "lng": 72.8149,
        "images": ["https://images.unsplash.com/photo-1590050752117-238cb0fb12b1?w=800&q=80"],
        "history": "Built by the Sultan of Gujarat and fortified by the Portuguese in 1534, captured by Peshwa Chimaji Appa in 1739.",
        "best_food": "Vasai Fried Bombil, Surmai Curry, and traditional Christian Fugiyas.",
        "things_to_do": "Explore 500-year-old carved cathedral arches, climb coastal bastion ramparts.",
        "best_time": "October to March.",
        "scams_and_warnings": "Avoid isolated corners after sunset. Agree on rickshaw fares beforehand (~₹100-₹130)."
      },
      {
        "name": "Jivdani Mata Hill Temple & Funicular",
        "category": "Sacred & Spiritual",
        "distance": "3.5 km from Virar Station",
        "timing": "05:30 AM – 08:30 PM",
        "entry": "Free (Funicular Ropeway ₹150)",
        "lat": 19.4678,
        "lng": 72.8256,
        "images": ["https://images.unsplash.com/photo-1561361066-613d52d91986?w=800&q=80"],
        "history": "Ancient hilltop shrine dedicated to Goddess Jivdani overlooking the entire Virar horizon.",
        "best_food": "Temple Mahaprasad Laddu, Virar Mawa Peda.",
        "things_to_do": "Ride the modern glass funicular ropeway, climb the 1,400 steps.",
        "best_time": "Early morning 6:00 AM – 9:00 AM.",
        "scams_and_warnings": "Keep food and sunglasses safely tucked away from hilltop monkeys."
      }
    ];
  }

  List<Map<String, dynamic>> _getVasaiHotels() {
    return [
      {
        "name": "The Golden Chariot Vasai Hotel & Spa",
        "tier": "4-Star & Executive",
        "rating": "8.8",
        "reviews": "1,820",
        "price": 3800,
        "phone": "+91 250 248 1000",
        "distance": "1.8 km from Center",
        "amenities": "Swimming Pool • Rooftop Bar • Business Center",
        "lat": 19.3941,
        "lng": 72.8512
      }
    ];
  }

  Future<void> _launchMapsNavigation(double lat, double lng, String label) async {
    HapticFeedback.mediumImpact();
    final Uri mapUri = (lat == 0.0 || lng == 0.0)
        ? Uri.parse("https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent('$label, ${_cityCtrl.text.trim()}')}")
        : Uri.parse("https://www.google.com/maps/dir/?api=1&destination=$lat,$lng&destination_place_id=${Uri.encodeComponent(label)}&travelmode=driving");

    try {
      if (!await launchUrl(mapUri, mode: LaunchMode.externalApplication)) {
        await launchUrl(mapUri, mode: LaunchMode.platformDefault);
      }
    } catch (_) {}
  }

  Future<void> _launchBookingDotCom(String hotelName) async {
    HapticFeedback.heavyImpact();
    final city = _cityCtrl.text.trim();
    final checkIn = _startDate.toIso8601String().split('T')[0];
    final checkOut = _returnDate.toIso8601String().split('T')[0];

    final searchTarget = "$hotelName, $city";
    final url = Uri.parse(
      "https://www.booking.com/searchresults.html?"
      "ss=${Uri.encodeComponent(searchTarget)}"
      "&checkin=$checkIn"
      "&checkout=$checkOut"
      "&group_adults=$_adults"
      "&group_children=$_kids"
      "&no_rooms=1"
      "&selected_currency=$_currencyCode"
      "&aid=$_travelPayoutsAid",
    );

    try {
      if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
        await launchUrl(url, mode: LaunchMode.inAppBrowserView);
      }
    } catch (_) {}
  }

  Future<void> _bookmarkToItinerary(Map<String, dynamic> item) async {
    HapticFeedback.mediumImpact();
    final String title = item["name"] ?? "Sight Visit";
    final String dist = item["distance"] ?? "";
    final String cat = item["category"] ?? "Explore";

    final displayLabel = "$cat • $dist (Scheduled: ${_startDate.day}/${_startDate.month})";

    await TripStateService.syncActiveCityAndTransit(
      city: _cityCtrl.text.trim(),
      state: _stateCtrl.text.trim(),
      country: _countryCtrl.text.trim(),
    );

    await TripStateService.addItineraryItem(
      title,
      cat,
      displayLabel,
      scheduledDateTime: DateTime.now().add(const Duration(hours: 2)),
    );

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: const Color(0xFF16A34A),
          content: Text("✓ Added '$title' to your Active Trip Schedule!"),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  void _generateFullDayByDayItinerary() async {
    HapticFeedback.heavyImpact();
    final city = _cityCtrl.text.trim();
    final days = _returnDate.difference(_startDate).inDays;
    final totalDays = days > 0 ? days : 4;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text("Syncing $totalDays-Day Smart Schedule for $city..."),
        duration: const Duration(seconds: 2),
      ),
    );

    await TripStateService.syncActiveCityAndTransit(
      city: city,
      state: _stateCtrl.text.trim(),
      country: _countryCtrl.text.trim(),
    );

    final spotsToSchedule = _locations.take(totalDays * 2).toList();
    for (int i = 0; i < spotsToSchedule.length; i++) {
      final spot = spotsToSchedule[i];
      final dayOffset = (i / 2).floor();
      final isMorning = i % 2 == 0;
      final scheduleDate = DateTime.now().add(Duration(days: dayOffset, hours: isMorning ? 1 : 5));

      final timeSlot = isMorning ? "Day ${dayOffset + 1} Morning (10:00 AM)" : "Day ${dayOffset + 1} Afternoon (03:30 PM)";
      await TripStateService.addItineraryItem(
        spot["name"] ?? "Sight Visit",
        spot["category"] ?? "Sightseeing",
        "$timeSlot • ${spot['distance']}",
        scheduledDateTime: scheduleDate,
      );
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: const Color(0xFF16A34A),
          content: Text("✓ $totalDays-Day Itinerary Synced for $city!"),
          duration: const Duration(seconds: 4),
        ),
      );
    }
  }

  void _openDetailDossierModal(Map<String, dynamic> item) {
    HapticFeedback.lightImpact();
    final List<String> images = List<String>.from(item["images"] ?? []);
    final double lat = (item["lat"] as num?)?.toDouble() ?? 0.0;
    final double lng = (item["lng"] as num?)?.toDouble() ?? 0.0;
    final String name = item["name"] ?? "Destination";

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => SizedBox(
        height: MediaQuery.of(context).size.height * 0.90,
        child: Column(
          children: [
            Container(
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              width: 44,
              height: 4,
              decoration: BoxDecoration(color: const Color(0xFFCBD5E1), borderRadius: BorderRadius.circular(10)),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 30),
                children: [
                  if (images.isNotEmpty)
                    SizedBox(
                      height: 220,
                      child: PageView.builder(
                        itemCount: images.length,
                        itemBuilder: (context, idx) => Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(18),
                            child: _buildReliableNetworkImage(images[idx]),
                          ),
                        ),
                      ),
                    ),
                  const SizedBox(height: 14),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          name,
                          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: Color(0xFF0F172A)),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(color: const Color(0xFFEFF6FF), borderRadius: BorderRadius.circular(8)),
                        child: Text(item["category"] ?? "Heritage", style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF2563EB))),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      const Icon(Icons.near_me_rounded, size: 14, color: Color(0xFF64748B)),
                      const SizedBox(width: 4),
                      Text(item["distance"] ?? "Near Center", style: const TextStyle(fontSize: 12, color: Color(0xFF64748B), fontWeight: FontWeight.w600)),
                      const Spacer(),
                      Text(item["entry"] ?? "Free", style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF16A34A))),
                    ],
                  ),

                  const SizedBox(height: 16),

                  Row(
                    children: [
                      Expanded(
                        flex: 3,
                        child: MetallicEmbossedButton(
                          label: "Turn-by-Turn GPS",
                          icon: Icons.navigation_rounded,
                          variant: MetallicVariant.cobaltBlue,
                          height: 42,
                          fontSize: 12.5,
                          onPressed: () {
                            Navigator.pop(ctx);
                            _launchMapsNavigation(lat, lng, name);
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        flex: 2,
                        child: MetallicEmbossedButton(
                          label: "+ My Trip",
                          icon: Icons.bookmark_add_rounded,
                          variant: MetallicVariant.emeraldGreen,
                          height: 42,
                          fontSize: 12,
                          onPressed: () {
                            _bookmarkToItinerary(item);
                          },
                        ),
                      ),
                    ],
                  ),

                  const Divider(height: 28),

                  _buildDossierSection(Icons.history_edu_rounded, "Heritage & History", item["history"] ?? "Historical background records."),
                  _buildDossierSection(Icons.restaurant_rounded, "Must-Try Local Cuisines", item["best_food"] ?? "Signature street and regional delicacies."),
                  _buildDossierSection(Icons.checklist_rounded, "Best Things To Do", item["things_to_do"] ?? "Sightseeing, walks, and photography."),
                  _buildDossierSection(Icons.groups_rounded, "Best Time & Who Should Visit", item["best_time"] ?? "Ideal for all travelers."),

                  Container(
                    margin: const EdgeInsets.symmetric(vertical: 10),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEF2F2),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFFCA5A5), width: 0.6),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.warning_amber_rounded, color: Color(0xFFDC2626), size: 22),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text("Scam Alerts & Travel Advisory", style: TextStyle(color: Color(0xFF991B1B), fontWeight: FontWeight.w900, fontSize: 13)),
                              const SizedBox(height: 4),
                              Text(item["scams_and_warnings"] ?? "Always obtain entry passes directly from the official ticket counter.", style: const TextStyle(color: Color(0xFFB91C1C), fontSize: 12, height: 1.35)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDossierSection(IconData icon, String title, String body) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: const Color(0xFF2563EB)),
              const SizedBox(width: 8),
              Text(title, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14, color: Color(0xFF0F172A))),
            ],
          ),
          const SizedBox(height: 5),
          Text(body, style: const TextStyle(fontSize: 13, color: Color(0xFF334155), height: 1.4)),
        ],
      ),
    );
  }

  Widget _buildReliableNetworkImage(String imageUrl, {double? height}) {
    return Image.network(
      imageUrl,
      height: height,
      width: double.infinity,
      headers: _browserHeaders,
      fit: BoxFit.cover,
      loadingBuilder: (context, child, loadingProgress) {
        if (loadingProgress == null) return child;
        return Container(
          height: height ?? 190,
          color: const Color(0xFFF1F5F9),
          child: const Center(
            child: SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF2563EB)),
            ),
          ),
        );
      },
      errorBuilder: (context, error, stackTrace) {
        return Container(
          height: height ?? 190,
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF1E3A8A), Color(0xFF0F172A)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: const Center(
            child: Icon(Icons.location_city_rounded, color: Colors.white54, size: 42),
          ),
        );
      },
    );
  }

  Widget _buildHotelCard(Map<String, dynamic> h) {
    final hLat = (h["lat"] as num?)?.toDouble() ?? 0.0;
    final hLng = (h["lng"] as num?)?.toDouble() ?? 0.0;
    final hName = h["name"] ?? "Hotel";
    final price = h["price"] ?? 3500;
    final rating = h["rating"] ?? "8.8";
    final reviews = h["reviews"] ?? "1,200";
    final tier = h["tier"] ?? "4-Star & Executive";
    final dist = h["distance"] ?? "Near Center";
    final amenities = h["amenities"] ?? "Free Wi-Fi • Breakfast • Pool";

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0), width: 0.6),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.015), blurRadius: 8, offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(hName, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15, color: Color(0xFF0F172A))),
                    const SizedBox(height: 3),
                    Text("$tier • $dist", style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B))),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(color: const Color(0xFF16A34A), borderRadius: BorderRadius.circular(8)),
                child: Row(
                  children: [
                    const Icon(Icons.star_rounded, size: 14, color: Colors.white),
                    const SizedBox(width: 4),
                    Text(rating, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 12, color: Colors.white)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(6)),
            child: Text(amenities, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF475569))),
          ),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("$_currencySymbol$price", style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: Color(0xFF16A34A))),
                  Text("per night (taxes included) • $reviews reviews", style: const TextStyle(fontSize: 10, color: Color(0xFF64748B))),
                ],
              ),
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.directions_walk_rounded, color: Color(0xFF2563EB)),
                    onPressed: () => _launchMapsNavigation(hLat, hLng, hName),
                  ),
                  MetallicEmbossedButton(
                    label: "Book via Booking.com",
                    icon: Icons.open_in_browser_rounded,
                    variant: MetallicVariant.deepNavy,
                    height: 38,
                    fontSize: 11,
                    onPressed: () => _launchBookingDotCom(hName),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filteredLocations = _selectedCategory == "All"
        ? _locations
        : _locations.where((l) => (l["category"] ?? "").toString().toLowerCase().contains(_selectedCategory.toLowerCase())).toList();

    final filteredHotels = _selectedHotelTier == "All"
        ? _stays
        : _stays.where((h) => (h["tier"] ?? "").toString().toLowerCase().contains(_selectedHotelTier.toLowerCase())).toList();

    return RefreshIndicator(
      onRefresh: _loadLocations,
      color: const Color(0xFF2563EB),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 30),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 3-BOX LOCATION & DATE FILTER CARD
            if (_isFilterExpanded) ...[
              Container(
                margin: const EdgeInsets.only(bottom: 14),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFFE2E8F0), width: 0.6),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 3)),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text("DESTINATION PARAMETERS", style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: Color(0xFF64748B), letterSpacing: 0.5)),
                        IconButton(
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          icon: const Icon(Icons.close_rounded, size: 20, color: Color(0xFF64748B)),
                          onPressed: () => setState(() => _isFilterExpanded = false),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    
                    // Box 1: City / Destination
                    TextField(
                      controller: _cityCtrl,
                      decoration: InputDecoration(
                        labelText: "City or Destination",
                        hintText: "e.g., Vasai-Virar, Tokyo, Dubai",
                        prefixIcon: const Icon(Icons.location_city_rounded, color: Color(0xFF2563EB), size: 20),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        isDense: true,
                      ),
                    ),
                    const SizedBox(height: 10),

                    // Box 2 & Box 3: State / Region & Country
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _stateCtrl,
                            decoration: InputDecoration(
                              labelText: "State / Region",
                              hintText: "e.g., Maharashtra, Kanto",
                              prefixIcon: const Icon(Icons.map_rounded, color: Color(0xFF64748B), size: 20),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                              isDense: true,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            controller: _countryCtrl,
                            decoration: InputDecoration(
                              labelText: "Country",
                              hintText: "e.g., India, Japan, UAE",
                              prefixIcon: const Icon(Icons.public_rounded, color: Color(0xFF64748B), size: 20),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                              isDense: true,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),

                    // Date Selectors
                    Row(
                      children: [
                        Expanded(
                          child: InkWell(
                            onTap: () async {
                              final picked = await showDatePicker(
                                context: context,
                                initialDate: _startDate,
                                firstDate: DateTime.now(),
                                lastDate: DateTime.now().add(const Duration(days: 365)),
                              );
                              if (picked != null) setState(() => _startDate = picked);
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                              decoration: BoxDecoration(border: Border.all(color: const Color(0xFFCBD5E1)), borderRadius: BorderRadius.circular(10)),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text("Check-In", style: TextStyle(fontSize: 10, color: Color(0xFF64748B))),
                                  Text("${_startDate.day}/${_startDate.month}/${_startDate.year}", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5)),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: InkWell(
                            onTap: () async {
                              final picked = await showDatePicker(
                                context: context,
                                initialDate: _returnDate,
                                firstDate: _startDate,
                                lastDate: DateTime.now().add(const Duration(days: 365)),
                              );
                              if (picked != null) setState(() => _returnDate = picked);
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                              decoration: BoxDecoration(border: Border.all(color: const Color(0xFFCBD5E1)), borderRadius: BorderRadius.circular(10)),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text("Check-Out", style: TextStyle(fontSize: 10, color: Color(0xFF64748B))),
                                  Text("${_returnDate.day}/${_returnDate.month}/${_returnDate.year}", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5)),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    MetallicEmbossedButton(
                      label: "SEARCH DESTINATIONS & STAYS",
                      icon: Icons.travel_explore_rounded,
                      variant: MetallicVariant.cobaltBlue,
                      isFullWidth: true,
                      height: 44,
                      onPressed: () {
                        setState(() => _isFilterExpanded = false);
                        _loadLocations();
                      },
                    ),
                  ],
                ),
              ),
            ] else ...[
              // Soft Surface Anchor Bar
              Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: const Color(0xFFE2E8F0), width: 0.6),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withOpacity(0.015), blurRadius: 6, offset: const Offset(0, 2)),
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "${_cityCtrl.text.trim()}, ${_stateCtrl.text.trim()}",
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: Color(0xFF0F172A)),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            "${_countryCtrl.text.trim()} • ${_startDate.day}/${_startDate.month} to ${_returnDate.day}/${_returnDate.month}",
                            style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B), fontWeight: FontWeight.w500),
                          ),
                        ],
                      ),
                    ),
                    InkWell(
                      onTap: () => setState(() => _isFilterExpanded = true),
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEFF6FF),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFFBFDBFE), width: 0.6),
                        ),
                        child: Row(
                          children: const [
                            Icon(Icons.tune_rounded, size: 14, color: Color(0xFF2563EB)),
                            SizedBox(width: 4),
                            Text("Change", style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: Color(0xFF1E40AF))),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            // Floating Capsule Sub-Tab Switcher (Sights vs Stays)
            Container(
              padding: const EdgeInsets.all(3.5),
              decoration: BoxDecoration(
                color: const Color(0xFFE2E8F0).withOpacity(0.7),
                borderRadius: BorderRadius.circular(16),
              ),
              child: TabBar(
                controller: _subTabController,
                indicator: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 4, offset: const Offset(0, 1)),
                  ],
                ),
                labelColor: const Color(0xFF2563EB),
                unselectedLabelColor: const Color(0xFF64748B),
                labelStyle: const TextStyle(fontWeight: FontWeight.w900, fontSize: 12.5),
                tabs: [
                  Tab(height: 34, text: "🏛️ Sights (${_locations.length})"),
                  Tab(height: 34, text: "🏨 Stays & Hotels (${_stays.length})"),
                ],
              ),
            ),

            const SizedBox(height: 12),

            // SIGHTS SUB-VIEW
            if (_currentSubTab == 0) ...[
              // MakeMyTrip Smart Schedule Banner (Luxury Deep Navy)
              Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF0F172A), Color(0xFF1E3A8A)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: const Color(0xFF334155), width: 0.6),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(color: Colors.white.withOpacity(0.12), shape: BoxShape.circle),
                      child: const Icon(Icons.auto_awesome_rounded, color: Colors.white, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: const [
                          Text("Generate Smart Itinerary", style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 13)),
                          Text("Auto-schedules sights onto your Dashboard.", style: TextStyle(color: Colors.white70, fontSize: 11)),
                        ],
                      ),
                    ),
                    MetallicEmbossedButton(
                      label: "SYNC ITINERARY",
                      variant: MetallicVariant.emeraldGreen,
                      height: 34,
                      fontSize: 10,
                      onPressed: _generateFullDayByDayItinerary,
                    ),
                  ],
                ),
              ),

              // Filter Chips
              SizedBox(
                height: 34,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: _categories.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 6),
                  itemBuilder: (context, idx) {
                    final cat = _categories[idx];
                    final isSel = cat == _selectedCategory;
                    return ChoiceChip(
                      label: Text(cat),
                      selected: isSel,
                      selectedColor: const Color(0xFF2563EB),
                      backgroundColor: Colors.white,
                      labelStyle: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: isSel ? Colors.white : const Color(0xFF475569),
                      ),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      onSelected: (val) {
                        if (val) setState(() => _selectedCategory = cat);
                      },
                    );
                  },
                ),
              ),

              const SizedBox(height: 12),

              if (_isLoading)
                const Center(child: Padding(padding: EdgeInsets.all(40), child: CircularProgressIndicator(color: Color(0xFF2563EB))))
              else
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: filteredLocations.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 14),
                  itemBuilder: (context, i) {
                    final lm = filteredLocations[i];
                    final String name = lm["name"] ?? "Destination Spot";
                    final String cat = lm["category"] ?? "Heritage";
                    final String dist = lm["distance"] ?? "Near Center";
                    final String timing = lm["timing"] ?? "Open Daily";
                    final double lat = (lm["lat"] as num?)?.toDouble() ?? 0.0;
                    final double lng = (lm["lng"] as num?)?.toDouble() ?? 0.0;
                    final List<String> images = List<String>.from(lm["images"] ?? []);
                    final String primaryImage = images.isNotEmpty
                        ? images.first
                        : "https://images.unsplash.com/photo-1488646953014-85cb44e25828?w=800&q=80";

                    return Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: const Color(0xFFE2E8F0), width: 0.6),
                        boxShadow: [
                          BoxShadow(color: Colors.black.withOpacity(0.015), blurRadius: 8, offset: const Offset(0, 2)),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          ClipRRect(
                            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                            child: Stack(
                              children: [
                                _buildReliableNetworkImage(primaryImage, height: 180),
                                Positioned(
                                  top: 10,
                                  left: 10,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(color: Colors.black.withOpacity(0.55), borderRadius: BorderRadius.circular(8)),
                                    child: Text("#${i + 1} Top Attraction", style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                                  ),
                                ),
                                Positioned(
                                  top: 10,
                                  right: 10,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(color: const Color(0xFF2563EB), borderRadius: BorderRadius.circular(8)),
                                    child: Text(cat, style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.all(14),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: Color(0xFF0F172A))),
                                const SizedBox(height: 3),
                                Text(lm["history"] ?? "Explore landmark details and heritage history.", style: const TextStyle(fontSize: 12, color: Color(0xFF475569)), maxLines: 2, overflow: TextOverflow.ellipsis),
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    const Icon(Icons.near_me_rounded, size: 13, color: Color(0xFF64748B)),
                                    const SizedBox(width: 4),
                                    Text(dist, style: const TextStyle(fontSize: 11, color: Color(0xFF64748B), fontWeight: FontWeight.w500)),
                                    const Spacer(),
                                    const Icon(Icons.access_time_rounded, size: 13, color: Color(0xFF64748B)),
                                    const SizedBox(width: 4),
                                    Text(timing, style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                                  ],
                                ),
                                const Divider(height: 20),
                                Row(
                                  children: [
                                    Expanded(
                                      child: MetallicEmbossedButton(
                                        label: "Dossier",
                                        icon: Icons.info_outline_rounded,
                                        variant: MetallicVariant.titaniumSilver,
                                        height: 38,
                                        fontSize: 11.5,
                                        onPressed: () => _openDetailDossierModal(lm),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: MetallicEmbossedButton(
                                        label: "GPS Direct",
                                        icon: Icons.navigation_rounded,
                                        variant: MetallicVariant.cobaltBlue,
                                        height: 38,
                                        fontSize: 11.5,
                                        onPressed: () => _launchMapsNavigation(lat, lng, name),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    InkWell(
                                      onTap: () => _bookmarkToItinerary(lm),
                                      borderRadius: BorderRadius.circular(10),
                                      child: Container(
                                        padding: const EdgeInsets.all(9),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFEFF6FF),
                                          borderRadius: BorderRadius.circular(10),
                                          border: Border.all(color: const Color(0xFFBFDBFE), width: 0.6),
                                        ),
                                        child: const Icon(Icons.bookmark_add_rounded, color: Color(0xFF2563EB), size: 18),
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
            ] else ...[
              // STAYS & HOTELS SUB-VIEW
              SizedBox(
                height: 34,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: _hotelTiers.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 6),
                  itemBuilder: (context, idx) {
                    final t = _hotelTiers[idx];
                    final isSel = t == _selectedHotelTier;
                    return ChoiceChip(
                      label: Text(t),
                      selected: isSel,
                      selectedColor: const Color(0xFF2563EB),
                      backgroundColor: Colors.white,
                      labelStyle: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: isSel ? Colors.white : const Color(0xFF475569),
                      ),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      onSelected: (val) {
                        if (val) setState(() => _selectedHotelTier = t);
                      },
                    );
                  },
                ),
              ),

              const SizedBox(height: 12),

              if (_isLoading)
                const Center(child: Padding(padding: EdgeInsets.all(40), child: CircularProgressIndicator(color: Color(0xFF2563EB))))
              else if (filteredHotels.isEmpty)
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
                  child: const Center(
                    child: Text("No properties found for this tier. Try selecting 'All'.", style: TextStyle(color: Color(0xFF64748B))),
                  ),
                )
              else
                ...filteredHotels.map((h) => _buildHotelCard(h)).toList(),
            ],

            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}