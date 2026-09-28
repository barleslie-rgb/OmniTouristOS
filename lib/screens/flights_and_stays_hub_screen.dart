import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';

class FlightsAndStaysHubScreen extends StatefulWidget {
  final String initialCity;
  final String initialCountry;
  final int initialTab; // 0 for Flights, 1 for Hotels

  const FlightsAndStaysHubScreen({
    Key? key,
    this.initialCity = "Mumbai",
    this.initialCountry = "India",
    this.initialTab = 0,
  }) : super(key: key);

  @override
  State<FlightsAndStaysHubScreen> createState() => _FlightsAndStaysHubScreenState();
}

class _FlightsAndStaysHubScreenState extends State<FlightsAndStaysHubScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late TextEditingController _originCtrl;
  late TextEditingController _destCtrl;
  late TextEditingController _stayCityCtrl;

  // Flight Parameters
  bool _isRoundTrip = true;
  String _cabinClass = "Economy";
  final List<String> _cabinClasses = ["Economy", "Premium", "Business", "First"];
  DateTime _departDate = DateTime.now().add(const Duration(days: 7));
  DateTime _returnDate = DateTime.now().add(const Duration(days: 14));
  int _flightAdults = 2;
  int _flightChildren = 0;
  int _flightInfants = 0;

  // Stay Parameters
  DateTime _checkInDate = DateTime.now().add(const Duration(days: 7));
  DateTime _checkOutDate = DateTime.now().add(const Duration(days: 10));
  int _hotelRooms = 1;
  int _hotelAdults = 2;
  int _hotelChildren = 0;

  // Search Results Active State
  bool _hasSearchedFlights = true;
  bool _hasSearchedStays = true;
  int _visibleHotelCount = 10;

  // --- AFFILIATE & TRACKING CREDENTIALS ---
  static const String travelpayoutsMarker = "774359";
  static const String bookingComAid = "2420912";

  // Airport IATA Mapping with Region/Nearby Hub Fallback
  static const Map<String, String> _cityToIataMap = {
    "mumbai": "BOM",
    "vasai": "BOM",
    "virar": "BOM",
    "vasai-virar": "BOM",
    "bombay": "BOM",
    "palghar": "BOM",
    "delhi": "DEL",
    "new delhi": "DEL",
    "pune": "PNQ",
    "bangalore": "BLR",
    "bengaluru": "BLR",
    "hyderabad": "HYD",
    "chennai": "MAA",
    "kolkata": "CCU",
    "goa": "GOI",
    "jaipur": "JAI",
    "pahalgam": "SXR",
    "srinagar": "SXR",
    "gulmarg": "SXR",
    "kashmir": "SXR",
    "singapore": "SIN",
    "tokyo": "TYO",
    "haneda": "HND",
    "narita": "NRT",
    "paris": "PAR",
    "london": "LON",
    "dubai": "DXB",
    "bangkok": "BKK",
    "new york": "NYC",
    "san francisco": "SFO",
  };

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this, initialIndex: widget.initialTab);
    _originCtrl = TextEditingController(text: "BOM");
    _destCtrl = TextEditingController(text: _resolveIata(widget.initialCity));
    _stayCityCtrl = TextEditingController(text: _sanitizeCity(widget.initialCity));
  }

  @override
  void dispose() {
    _tabController.dispose();
    _originCtrl.dispose();
    _destCtrl.dispose();
    _stayCityCtrl.dispose();
    super.dispose();
  }

  String _sanitizeCity(String input) {
    return input.replaceAll(RegExp(r'\bcity\b', caseSensitive: false), '').trim();
  }

  String _resolveIata(String rawInput) {
    final clean = rawInput.trim().toLowerCase();
    for (var key in _cityToIataMap.keys) {
      if (clean.contains(key)) {
        return _cityToIataMap[key]!;
      }
    }
    if (rawInput.trim().length == 3) {
      return rawInput.trim().toUpperCase();
    }
    return "BOM"; // Fallback to major international hub if unknown
  }

  Map<String, String> _detectCurrency() {
    final orig = _resolveIata(_originCtrl.text);
    if (["BOM", "DEL", "PNQ", "BLR", "HYD", "MAA", "CCU", "GOI", "JAI", "SXR"].contains(orig)) {
      return {"code": "INR", "symbol": "₹", "multiplier": "1.0"};
    } else if (orig == "SIN") {
      return {"code": "SGD", "symbol": "S\$", "multiplier": "0.016"};
    } else if (["TYO", "HND", "NRT"].contains(orig)) {
      return {"code": "JPY", "symbol": "¥", "multiplier": "1.8"};
    } else if (orig == "PAR") {
      return {"code": "EUR", "symbol": "€", "multiplier": "0.011"};
    } else if (orig == "LON") {
      return {"code": "GBP", "symbol": "£", "multiplier": "0.0095"};
    } else if (orig == "DXB") {
      return {"code": "AED", "symbol": "AED ", "multiplier": "0.044"};
    }
    return {"code": "INR", "symbol": "₹", "multiplier": "1.0"};
  }

  String _formatDateForAviasales(DateTime d) {
    final day = d.day.toString().padLeft(2, '0');
    final month = d.month.toString().padLeft(2, '0');
    return "$day$month";
  }

  // Valid Aviasales Direct Deep-Link (Prevents 'redirect url is not valid')
  String _buildPreFilledFlightUrl() {
    final orig = _resolveIata(_originCtrl.text);
    final dest = _resolveIata(_destCtrl.text);
    final depDate = _formatDateForAviasales(_departDate);
    final curr = _detectCurrency()["code"]!.toLowerCase();

    String path;
    final pnrPax = "$_flightAdults${_flightChildren > 0 ? _flightChildren : ''}";
    if (_isRoundTrip) {
      final retDate = _formatDateForAviasales(_returnDate);
      path = "$orig$depDate$dest$retDate$pnrPax";
    } else {
      path = "$orig$depDate$dest$pnrPax";
    }

    return "https://www.aviasales.com/search/$path?marker=$travelpayoutsMarker&currency=$curr";
  }

  // Pre-filled Booking.com URL (Opens in External Browser to eliminate 'Forbidden')
  Future<void> _launchBookingComDirect({String? specificHotel}) async {
    final baseCity = _sanitizeCity(_stayCityCtrl.text);
    final target = Uri.encodeComponent(specificHotel != null ? "$specificHotel, $baseCity" : baseCity);
    final inStr =
        "${_checkInDate.year}-${_checkInDate.month.toString().padLeft(2, '0')}-${_checkInDate.day.toString().padLeft(2, '0')}";
    final outStr =
        "${_checkOutDate.year}-${_checkOutDate.month.toString().padLeft(2, '0')}-${_checkOutDate.day.toString().padLeft(2, '0')}";
    final curr = _detectCurrency()["code"]!;

    final url = Uri.parse(
      "https://www.booking.com/searchresults.html?ss=$target"
      "&checkin=$inStr"
      "&checkout=$outStr"
      "&group_adults=$_hotelAdults"
      "&group_children=$_hotelChildren"
      "&no_rooms=$_hotelRooms"
      "&selected_currency=$curr"
      "&aid=$bookingComAid"
      "&marker=$travelpayoutsMarker",
    );

    try {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } catch (_) {
      await launchUrl(url, mode: LaunchMode.platformDefault);
    }
  }

  void _openInAppFlightBooking(String title, String url) {
    HapticFeedback.mediumImpact();
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (ctx) => InAppFlightBookingWebView(title: title, url: url),
      ),
    );
  }

  // Generates 30 realistic accommodations sorted from cheapest to highest
  List<Map<String, dynamic>> _get30Accommodations(String sym, double mult, String city) {
    final List<Map<String, dynamic>> templates = [
      {"name": "Backpackers Haven & Pods", "stars": "Budget Hostel", "base": 850, "rating": "8.1 Good"},
      {"name": "Traveller's Nest Inn", "stars": "Value Stay", "base": 1150, "rating": "8.2 Good"},
      {"name": "Green Valley Budget Residency", "stars": "Budget Hotel", "base": 1350, "rating": "8.0 Good"},
      {"name": "Urban Youth Hostel", "stars": "Hostel", "base": 1500, "rating": "8.4 Very Good"},
      {"name": "Riverside Transit Lodge", "stars": "Comfort Inn", "base": 1750, "rating": "8.2 Good"},
      {"name": "Heritage Inn & Dorms", "stars": "Value Hotel", "base": 1950, "rating": "8.3 Good"},
      {"name": "City Centre Residency", "stars": "3-Star Hotel", "base": 2200, "rating": "8.5 Very Good"},
      {"name": "Comfort Pods Express", "stars": "Boutique Pod", "base": 2400, "rating": "8.6 Great"},
      {"name": "Alpine Breeze Stay", "stars": "3-Star Comfort", "base": 2650, "rating": "8.4 Good"},
      {"name": "Sunrise Vista Hotel", "stars": "3-Star Hotel", "base": 2900, "rating": "8.5 Very Good"},
      {"name": "Maple Leaf Executive Rooms", "stars": "3-Star Deluxe", "base": 3200, "rating": "8.6 Great"},
      {"name": "Blue Horizon Boutique Stay", "stars": "Boutique Hotel", "base": 3500, "rating": "8.7 Great"},
      {"name": "Silver Oak Suites", "stars": "3-Star Premium", "base": 3850, "rating": "8.7 Great"},
      {"name": "Highland Haven Residency", "stars": "4-Star Comfort", "base": 4200, "rating": "8.8 Superb"},
      {"name": "The Royal Orchid Inn", "stars": "4-Star Deluxe", "base": 4600, "rating": "8.8 Superb"},
      {"name": "Pine Crest Suites", "stars": "4-Star Boutique", "base": 5100, "rating": "8.9 Superb"},
      {"name": "Lakeview Heritage Villa", "stars": "Heritage Manor", "base": 5600, "rating": "9.0 Superb"},
      {"name": "Valley Mist Resort & Spa", "stars": "4-Star Resort", "base": 6200, "rating": "9.1 Superb"},
      {"name": "Golden Chariot Luxury Hotel", "stars": "4-Star Premium", "base": 6800, "rating": "9.0 Superb"},
      {"name": "Orchard Garden Resort", "stars": "Eco Resort", "base": 7400, "rating": "9.1 Superb"},
      {"name": "The Grand Regent Palace", "stars": "5-Star Luxury", "base": 8200, "rating": "9.2 Superb"},
      {"name": "Crown Imperial Hotel", "stars": "5-Star Hotel", "base": 9100, "rating": "9.3 Superb"},
      {"name": "Serenity Springs Luxury Villa", "stars": "Private Villa", "base": 10500, "rating": "9.4 Superb"},
      {"name": "Whispering Pines Alpine Retreat", "stars": "Luxury Chalet", "base": 11800, "rating": "9.5 Exceptional"},
      {"name": "The Majestic Landmark Resort", "stars": "5-Star Deluxe", "base": 13200, "rating": "9.4 Superb"},
      {"name": "Royal Continental Palace", "stars": "5-Star Luxury", "base": 14800, "rating": "9.6 Exceptional"},
      {"name": "The Oberoi Panoramic Suites", "stars": "Ultra Luxury", "base": 17500, "rating": "9.7 Exceptional"},
      {"name": "Taj Valley Heritage Palace", "stars": "5-Star Heritage", "base": 19800, "rating": "9.8 Exceptional"},
      {"name": "Presidential Heights Luxury Villa", "stars": "VIP Villa", "base": 23500, "rating": "9.8 Exceptional"},
      {"name": "The Emperor Golf & Spa Sanctuary", "stars": "Signature 5-Star", "base": 28000, "rating": "9.9 Exceptional"},
    ];

    // Pre-sorted strictly from lowest to highest price
    templates.sort((a, b) => (a["base"] as int).compareTo(b["base"] as int));

    return templates.map((t) {
      final price = ((t["base"] as int) * mult).round();
      final rack = (price * 1.3).round();
      return {
        "name": "${t['name']} $city",
        "stars": t["stars"],
        "rating": t["rating"],
        "price": "$sym $price",
        "rack": "$sym $rack",
        "image": "https://images.unsplash.com/photo-1566073771259-6a8506099945?auto=format&fit=crop&w=600&q=80",
      };
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text(
          "Flight & Hotel Booking Hub",
          style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
        ),
        bottom: TabBar(
          controller: _tabController,
          labelColor: const Color(0xFF2563EB),
          unselectedLabelColor: const Color(0xFF64748B),
          indicatorColor: const Color(0xFF2563EB),
          indicatorWeight: 3,
          labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
          tabs: const [
            Tab(icon: Icon(Icons.flight_takeoff_rounded, size: 20), text: "Flights"),
            Tab(icon: Icon(Icons.hotel_rounded, size: 20), text: "Stays & Hotels"),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildFlightsTab(),
          _buildStaysTab(),
        ],
      ),
    );
  }

  Widget _buildFlightsTab() {
    final orig = _resolveIata(_originCtrl.text);
    final dest = _resolveIata(_destCtrl.text);
    final currInfo = _detectCurrency();
    final sym = currInfo["symbol"]!;
    final mult = double.tryParse(currInfo["multiplier"]!) ?? 1.0;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    ChoiceChip(
                      label: const Text("Round-Trip"),
                      selected: _isRoundTrip,
                      selectedColor: const Color(0xFF2563EB),
                      labelStyle: TextStyle(
                          color: _isRoundTrip ? Colors.white : const Color(0xFF475569),
                          fontWeight: FontWeight.bold,
                          fontSize: 11),
                      onSelected: (val) => setState(() => _isRoundTrip = true),
                    ),
                    const SizedBox(width: 8),
                    ChoiceChip(
                      label: const Text("One-Way"),
                      selected: !_isRoundTrip,
                      selectedColor: const Color(0xFF2563EB),
                      labelStyle: TextStyle(
                          color: !_isRoundTrip ? Colors.white : const Color(0xFF475569),
                          fontWeight: FontWeight.bold,
                          fontSize: 11),
                      onSelected: (val) => setState(() => _isRoundTrip = false),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _originCtrl,
                        decoration: InputDecoration(
                          labelText: "From (Airport)",
                          hintText: "BOM",
                          prefixIcon: const Icon(Icons.flight_takeoff_rounded, size: 18),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          isDense: true,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: _destCtrl,
                        decoration: InputDecoration(
                          labelText: "To (Airport / City)",
                          hintText: "SXR",
                          prefixIcon: const Icon(Icons.flight_land_rounded, size: 18),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          isDense: true,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  height: 46,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2563EB),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    icon: const Icon(Icons.search_rounded, size: 18),
                    label: Text(
                      "SEARCH FLIGHTS IN-APP ($orig ➔ $dest)",
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                    onPressed: () {
                      _openInAppFlightBooking("Flights: $orig ➔ $dest", _buildPreFilledFlightUrl());
                    },
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Text(
            "Available Carriers ($orig ➔ $dest)",
            style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15, color: Color(0xFF0F172A)),
          ),
          const SizedBox(height: 10),
          _buildNativeCarrierCard(
            airlineName: "IndiGo Airlines (6E Fleet)",
            badgeText: "Best Low-Cost Fare",
            badgeColor: const Color(0xFF16A34A),
            pricePerPax: "$sym ${(4800 * mult).toInt()}",
            totalPrice: "$sym ${(4800 * mult * _flightAdults).toInt()}",
            flightType: "Direct / Fastest Route",
            duration: "Approx. 2h 15m",
            onBookTap: () => _openInAppFlightBooking("IndiGo: $orig ➔ $dest", _buildPreFilledFlightUrl()),
          ),
          _buildNativeCarrierCard(
            airlineName: "Air India (Full Service)",
            badgeText: "Baggage Included",
            badgeColor: const Color(0xFFDC2626),
            pricePerPax: "$sym ${(6500 * mult).toInt()}",
            totalPrice: "$sym ${(6500 * mult * _flightAdults).toInt()}",
            flightType: "Full Service Airbus Fleet",
            duration: "Approx. 2h 10m",
            onBookTap: () => _openInAppFlightBooking("Air India: $orig ➔ $dest", _buildPreFilledFlightUrl()),
          ),
        ],
      ),
    );
  }

  Widget _buildStaysTab() {
    final currInfo = _detectCurrency();
    final sym = currInfo["symbol"]!;
    final mult = double.tryParse(currInfo["multiplier"]!) ?? 1.0;
    final city = _stayCityCtrl.text.trim();
    final allHotels = _get30Accommodations(sym, mult, city);
    final displayedHotels = allHotels.take(_visibleHotelCount).toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Column(
              children: [
                TextField(
                  controller: _stayCityCtrl,
                  decoration: InputDecoration(
                    labelText: "Destination / City",
                    prefixIcon: const Icon(Icons.location_on_rounded, size: 18),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    isDense: true,
                  ),
                ),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  height: 46,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF003580),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    icon: const Icon(Icons.open_in_new_rounded, size: 18),
                    label: Text(
                      "SEARCH DIRECT ON BOOKING.COM ($sym)",
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                    onPressed: () => _launchBookingComDirect(),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "30 Properties in $city",
                style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15, color: Color(0xFF0F172A)),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(color: const Color(0xFFEFF6FF), borderRadius: BorderRadius.circular(8)),
                child: const Text(
                  "Sorted: Lowest ➔ Highest",
                  style: TextStyle(color: Color(0xFF2563EB), fontSize: 11, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ...displayedHotels.map((h) => Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: Image.network(h["image"], width: 75, height: 75, fit: BoxFit.cover),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(h["name"],
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF0F172A)),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis),
                          Text("${h['stars']} • ${h['rating']}",
                              style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                          const SizedBox(height: 4),
                          Text(h["price"],
                              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: Color(0xFF16A34A))),
                        ],
                      ),
                    ),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF003580),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      onPressed: () => _launchBookingComDirect(specificHotel: h["name"]),
                      child: const Text("Book", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11.5)),
                    ),
                  ],
                ),
              )),
          if (_visibleHotelCount < allHotels.length) ...[
            const SizedBox(height: 10),
            Center(
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF2563EB),
                  side: const BorderSide(color: Color(0xFF2563EB)),
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                icon: const Icon(Icons.expand_more_rounded),
                label: Text("Load More Stays (${allHotels.length - _visibleHotelCount} remaining)"),
                onPressed: () {
                  setState(() {
                    _visibleHotelCount = (_visibleHotelCount + 10).clamp(0, allHotels.length);
                  });
                },
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildNativeCarrierCard({
    required String airlineName,
    required String badgeText,
    required Color badgeColor,
    required String pricePerPax,
    required String totalPrice,
    required String flightType,
    required String duration,
    required VoidCallback onBookTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(airlineName, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13.5)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(color: badgeColor.withOpacity(0.1), borderRadius: BorderRadius.circular(6)),
                child: Text(badgeText, style: TextStyle(color: badgeColor, fontSize: 10, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text("$pricePerPax / pax  (Total: $totalPrice)",
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5, color: Color(0xFF16A34A))),
          Text("$flightType • $duration", style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            height: 38,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2563EB),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: onBookTap,
              child: const Text("Select & Book In-App", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
            ),
          ),
        ],
      ),
    );
  }
}

// In-App Webview for Flights Only
class InAppFlightBookingWebView extends StatefulWidget {
  final String title;
  final String url;

  const InAppFlightBookingWebView({Key? key, required this.title, required this.url}) : super(key: key);

  @override
  State<InAppFlightBookingWebView> createState() => _InAppFlightBookingWebViewState();
}

class _InAppFlightBookingWebViewState extends State<InAppFlightBookingWebView> {
  late final WebViewController _controller;
  int _loadingProgress = 0;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setUserAgent("Mozilla/5.0 (Linux; Android 14; Mobile) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/126.0.0.0 Mobile Safari/537.36")
      ..setNavigationDelegate(NavigationDelegate(
        onProgress: (p) => setState(() => _loadingProgress = p),
      ))
      ..loadRequest(Uri.parse(widget.url));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
      ),
      body: Stack(
        children: [
          WebViewWidget(controller: _controller),
          if (_loadingProgress < 100)
            LinearProgressIndicator(value: _loadingProgress / 100.0, color: const Color(0xFF2563EB)),
        ],
      ),
    );
  }
}