import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import '../widgets/metallic_embossed_button.dart';

class FlightBookingView extends StatefulWidget {
  final String language;
  final String activeOriginCity;
  final String initialDestinationCity;
  final String backendUrl;

  const FlightBookingView({
    Key? key,
    required this.language,
    required this.activeOriginCity,
    this.initialDestinationCity = "Singapore",
    this.backendUrl = "https://omni-backend-pk28.onrender.com",
  }) : super(key: key);

  @override
  State<FlightBookingView> createState() => _FlightBookingViewState();
}

class _FlightBookingViewState extends State<FlightBookingView> {
  late TextEditingController _originAirportCtrl;
  late TextEditingController _destAirportCtrl;

  DateTime _departureDate = DateTime.now().add(const Duration(days: 5));
  DateTime _returnDate = DateTime.now().add(const Duration(days: 12));

  int _adults = 1;
  int _kids = 0;
  String _cabinClass = "Economy";
  bool _isRoundTrip = true;

  bool _isLoading = false;
  String _currencyCode = "INR";
  String _currencySymbol = "₹";
  static const String _travelPayoutsMarker = "774359";

  List<Map<String, dynamic>> _homeCarriers = [];
  List<Map<String, dynamic>> _destCarriers = [];

  final List<String> _cabinClasses = [
    "Economy",
    "Premium Economy",
    "Business",
    "First Class",
  ];

  static const Map<String, String> _cityToIata = {
    "mumbai": "BOM",
    "vasai": "BOM",
    "virar": "BOM",
    "nalasopara": "BOM",
    "pune": "PNQ",
    "delhi": "DEL",
    "bengaluru": "BLR",
    "bangalore": "BLR",
    "chennai": "MAA",
    "kolkata": "CCU",
    "hyderabad": "HYD",
    "goa": "GOI",
    "jaipur": "JAI",
    "ahmedabad": "AMD",
    "singapore": "SIN",
    "dubai": "DXB",
    "london": "LHR",
    "paris": "CDG",
    "tokyo": "HND",
    "bangkok": "BKK",
    "new york": "JFK",
    "doha": "DOH",
    "kuala lumpur": "KUL",
  };

  @override
  void initState() {
    super.initState();
    final originCode = _resolveAirportCode(widget.activeOriginCity, "BOM");
    final destCode = _resolveAirportCode(widget.initialDestinationCity, "SIN");

    _originAirportCtrl = TextEditingController(text: originCode);
    _destAirportCtrl = TextEditingController(text: destCode);

    _resolveLocalCurrency();
    _recalculateAndGenerateFlights();
  }

  @override
  void didUpdateWidget(covariant FlightBookingView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialDestinationCity != widget.initialDestinationCity) {
      final destCode = _resolveAirportCode(widget.initialDestinationCity, "SIN");
      _destAirportCtrl.text = destCode;
      _recalculateAndGenerateFlights();
    }
  }

  @override
  void dispose() {
    _originAirportCtrl.dispose();
    _destAirportCtrl.dispose();
    super.dispose();
  }

  String _resolveAirportCode(String rawCity, String fallback) {
    final clean = rawCity.toLowerCase().trim();
    for (var entry in _cityToIata.entries) {
      if (clean.contains(entry.key)) {
        return entry.value;
      }
    }
    if (rawCity.trim().length == 3) return rawCity.trim().toUpperCase();
    return fallback;
  }

  String _getCityDisplayName(String iata) {
    switch (iata.toUpperCase()) {
      case "BOM":
        return "Mumbai CSMIA";
      case "DEL":
        return "New Delhi IGI";
      case "BLR":
        return "Bengaluru Kempegowda";
      case "SIN":
        return "Singapore Changi";
      case "DXB":
        return "Dubai International";
      case "LHR":
        return "London Heathrow";
      case "BKK":
        return "Bangkok Suvarnabhumi";
      case "DOH":
        return "Doha Hamad";
      case "PNQ":
        return "Pune Lohegaon";
      case "GOI":
        return "Goa Dabolim";
      default:
        return iata;
    }
  }

  String _extractIata(String raw) {
    final clean = raw.trim();
    if (clean.length >= 3) {
      return clean.substring(0, 3).toUpperCase();
    }
    return "BOM";
  }

  void _resolveLocalCurrency() {
    final origin = _extractIata(_originAirportCtrl.text);

    if (["BOM", "DEL", "BLR", "PNQ", "MAA", "CCU", "HYD", "GOI", "JAI", "AMD"].contains(origin)) {
      _currencyCode = "INR";
      _currencySymbol = "₹";
    } else if (origin == "DXB") {
      _currencyCode = "AED";
      _currencySymbol = "AED ";
    } else if (origin == "LHR") {
      _currencyCode = "GBP";
      _currencySymbol = "£";
    } else if (origin == "CDG") {
      _currencyCode = "EUR";
      _currencySymbol = "€";
    } else if (origin == "SIN") {
      _currencyCode = "SGD";
      _currencySymbol = "S\$";
    } else if (origin == "BKK") {
      _currencyCode = "THB";
      _currencySymbol = "฿";
    } else if (origin == "HND") {
      _currencyCode = "JPY";
      _currencySymbol = "¥";
    } else {
      _currencyCode = "USD";
      _currencySymbol = "\$";
    }
  }

  double _getCabinMultiplier() {
    switch (_cabinClass) {
      case "Premium Economy":
        return 1.55;
      case "Business":
        return 2.85;
      case "First Class":
        return 4.60;
      case "Economy":
      default:
        return 1.0;
    }
  }

  void _recalculateAndGenerateFlights() {
    _resolveLocalCurrency();
    final origin = _extractIata(_originAirportCtrl.text);
    final dest = _extractIata(_destAirportCtrl.text);

    final bool isDomesticIndia = ["BOM", "DEL", "BLR", "PNQ", "MAA", "CCU", "HYD", "GOI"].contains(origin) &&
        ["BOM", "DEL", "BLR", "PNQ", "MAA", "CCU", "HYD", "GOI"].contains(dest);

    final double multiplier = _getCabinMultiplier();

    List<Map<String, dynamic>> home = [];
    List<Map<String, dynamic>> foreign = [];

    if (origin == "BOM" || origin == "DEL" || origin == "BLR") {
      home = [
        {
          "airline": "IndiGo Airlines",
          "code": "6E",
          "flight_no": "6E 1305",
          "is_home_carrier": true,
          "departure": "07:15 AM",
          "arrival": isDomesticIndia ? "09:25 AM" : "03:40 PM",
          "duration": isDomesticIndia ? "2h 10m" : "5h 55m",
          "stops": "Non-stop",
          "base_economy": isDomesticIndia ? 4800 : 18500,
          "price": ((isDomesticIndia ? 4800 : 18500) * multiplier).round(),
          "cabin_baggage": "7 kg Cabin",
          "checkin_baggage": isDomesticIndia ? "15 kg Check-in" : "20 kg Check-in",
          "aircraft": "Airbus A321neo",
          "features": _cabinClass == "Economy"
              ? "Standard Seat • Buy Onboard"
              : (_cabinClass == "Premium Economy" ? "XL Legroom • Priority Baggage" : "Stretch Seating • Hot Meals Included"),
        },
        {
          "airline": "Air India",
          "code": "AI",
          "flight_no": "AI 382",
          "is_home_carrier": true,
          "departure": "11:30 AM",
          "arrival": isDomesticIndia ? "01:45 PM" : "07:55 PM",
          "duration": isDomesticIndia ? "2h 15m" : "5h 55m",
          "stops": "Non-stop",
          "base_economy": isDomesticIndia ? 5600 : 21900,
          "price": ((isDomesticIndia ? 5600 : 21900) * multiplier).round(),
          "cabin_baggage": "8 kg Cabin",
          "checkin_baggage": isDomesticIndia ? "20 kg Check-in" : "25 kg Check-in",
          "aircraft": "Boeing 787-8 Dreamliner",
          "features": _cabinClass == "Business"
              ? "180° Flatbed • Maharajah Lounge Access"
              : (_cabinClass == "First Class" ? "Private Luxury Suite • Chauffeur Transit" : "Complimentary Hot Meal • Free Entertainment"),
        },
        {
          "airline": "Vistara (Air India Group)",
          "code": "UK",
          "flight_no": "UK 105",
          "is_home_carrier": true,
          "departure": "06:40 PM",
          "arrival": isDomesticIndia ? "08:50 PM" : "02:50 AM",
          "duration": isDomesticIndia ? "2h 10m" : "5h 40m",
          "stops": "Non-stop",
          "base_economy": isDomesticIndia ? 6100 : 23400,
          "price": ((isDomesticIndia ? 6100 : 23400) * multiplier).round(),
          "cabin_baggage": "7 kg Cabin",
          "checkin_baggage": isDomesticIndia ? "20 kg Check-in" : "30 kg Check-in",
          "aircraft": "Airbus A321LR",
          "features": _cabinClass == "Business"
              ? "Lie-Flat Suites • Gourmet Dining"
              : (_cabinClass == "Premium Economy" ? "Dedicated Cabin • 33\" Seat Pitch" : "Star Alliance Privileges • Free Seat Selection"),
        },
      ];

      if (dest == "SIN") {
        foreign = [
          {
            "airline": "Singapore Airlines",
            "code": "SQ",
            "flight_no": "SQ 423",
            "is_home_carrier": false,
            "departure": "11:45 PM",
            "arrival": "07:45 AM",
            "duration": "5h 30m",
            "stops": "Non-stop",
            "base_economy": 27800,
            "price": (27800 * multiplier).round(),
            "cabin_baggage": "7 kg Cabin",
            "checkin_baggage": "30 kg Check-in",
            "aircraft": "Airbus A350-900",
            "features": _cabinClass == "First Class"
                ? "KrisWorld Private Suite • Book the Cook"
                : (_cabinClass == "Business" ? "SilverKris Lounge • Direct Aisle Access" : "KrisWorld 1,800+ Movies • Singapore Girl Service"),
          },
          {
            "airline": "Scoot Airlines",
            "code": "TR",
            "flight_no": "TR 541",
            "is_home_carrier": false,
            "departure": "01:10 AM",
            "arrival": "09:05 AM",
            "duration": "5h 25m",
            "stops": "Non-stop",
            "base_economy": 16200,
            "price": (16200 * multiplier).round(),
            "cabin_baggage": "10 kg Cabin",
            "checkin_baggage": "20 kg Add-on",
            "aircraft": "Boeing 787-9 Dreamliner",
            "features": _cabinClass == "Business" ? "ScootPlus Wide Recliner • 30kg Luggage" : "ScootinSilence Quiet Zone • Dreamliner Cabin",
          },
        ];
      } else if (dest == "DXB") {
        foreign = [
          {
            "airline": "Emirates",
            "code": "EK",
            "flight_no": "EK 501",
            "is_home_carrier": false,
            "departure": "04:30 AM",
            "arrival": "06:15 AM",
            "duration": "3h 15m",
            "stops": "Non-stop",
            "base_economy": 22400,
            "price": (22400 * multiplier).round(),
            "cabin_baggage": "7 kg Cabin",
            "checkin_baggage": "30 kg Check-in",
            "aircraft": "Boeing 777-300ER",
            "features": _cabinClass == "First Class" ? "Shower Spa • Private Suite • Dom Pérignon" : (_cabinClass == "Business" ? "Onboard Bar Lounge • Chauffeur Drive" : "ice Entertainment 6,500+ Channels"),
          },
        ];
      }
    }

    setState(() {
      _homeCarriers = home;
      _destCarriers = foreign;
      _isLoading = false;
    });
  }

  Future<void> _searchFlightOffers() async {
    setState(() => _isLoading = true);
    final origin = _extractIata(_originAirportCtrl.text);
    final dest = _extractIata(_destAirportCtrl.text);

    try {
      final cleanUrl = widget.backendUrl.replaceAll(RegExp(r'/+$'), '');
      final res = await http.post(
        Uri.parse("$cleanUrl/api/v1/search-flights"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "origin": origin,
          "destination": dest,
          "departure_date": _departureDate.toIso8601String().split('T')[0],
          "return_date": _isRoundTrip ? _returnDate.toIso8601String().split('T')[0] : null,
          "adults": _adults,
          "kids": _kids,
          "cabin_class": _cabinClass,
        }),
      ).timeout(const Duration(seconds: 8));

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final list = (data["flights"] ?? data["routes"] ?? []) as List;
        if (list.isNotEmpty) {
          _splitHierarchy(list.map((e) => Map<String, dynamic>.from(e)).toList());
          if (mounted) setState(() => _isLoading = false);
          return;
        }
      }
    } catch (_) {}

    _recalculateAndGenerateFlights();
  }

  void _splitHierarchy(List<Map<String, dynamic>> allFlights) {
    List<Map<String, dynamic>> home = [];
    List<Map<String, dynamic>> foreign = [];

    for (var f in allFlights) {
      final name = (f["airline"] ?? "").toString().toLowerCase();
      if (name.contains("indigo") || name.contains("air india") || name.contains("vistara") || name.contains("akasa")) {
        home.add(f);
      } else {
        foreign.add(f);
      }
    }

    setState(() {
      _homeCarriers = home.isNotEmpty ? home : allFlights;
      _destCarriers = foreign;
    });
  }

  Future<void> _bookOnTravelpayouts(Map<String, dynamic> flight) async {
    HapticFeedback.heavyImpact();
    final origin = _extractIata(_originAirportCtrl.text);
    final dest = _extractIata(_destAirportCtrl.text);

    final String departDateStr = _departureDate.toIso8601String().split('T')[0];
    final String returnDateStr = _isRoundTrip ? _returnDate.toIso8601String().split('T')[0] : "";
    final String cabinParam = _cabinClass == 'Business' ? 'c' : (_cabinClass == 'First Class' ? 'f' : (_cabinClass == 'Premium Economy' ? 'w' : 'y'));

    final Uri url = Uri.parse(
      "https://tp.media/r?marker=$_travelPayoutsMarker&p=4114&u=" +
          Uri.encodeComponent(
            "https://www.aviasales.com/search/"
            "$origin${departDateStr.replaceAll('-', '')}"
            "$dest${_isRoundTrip ? returnDateStr.replaceAll('-', '') : ''}"
            "$_adults$_kids$cabinParam"
            "?currency=$_currencyCode",
          ),
    );

    try {
      if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
        await launchUrl(url, mode: LaunchMode.inAppBrowserView);
      }
    } catch (_) {
      final Uri fallbackBooking = Uri.parse(
        "https://flights.booking.com/flights/$origin-$dest/"
        "?type=${_isRoundTrip ? 'ROUNDTRIP' : 'ONEWAY'}"
        "&adults=$_adults"
        "&children=$_kids"
        "&cabinClass=${_cabinClass.toUpperCase().replaceAll(' ', '_')}"
        "&depart=$departDateStr"
        "${_isRoundTrip ? '&return=$returnDateStr' : ''}"
        "&aid=$_travelPayoutsMarker",
      );
      await launchUrl(fallbackBooking, mode: LaunchMode.externalApplication);
    }
  }

  void _swapAirports() {
    HapticFeedback.lightImpact();
    final temp = _originAirportCtrl.text;
    setState(() {
      _originAirportCtrl.text = _destAirportCtrl.text;
      _destAirportCtrl.text = temp;
    });
    _recalculateAndGenerateFlights();
  }

  void _showPassengerPickerDialog() {
    HapticFeedback.lightImpact();
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: const [
              Icon(Icons.people_alt_rounded, color: Color(0xFF2563EB), size: 22),
              SizedBox(width: 8),
              Text("Select Passengers", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Text("Adults", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                      Text("Age 12+ years", style: TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                    ],
                  ),
                  Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.remove_circle_outline, color: Color(0xFF64748B)),
                        onPressed: _adults > 1
                            ? () {
                                HapticFeedback.lightImpact();
                                setDialogState(() => _adults--);
                                setState(() {});
                              }
                            : null,
                      ),
                      Text("$_adults", style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
                      IconButton(
                        icon: const Icon(Icons.add_circle_outline, color: Color(0xFF2563EB)),
                        onPressed: _adults < 9
                            ? () {
                                HapticFeedback.lightImpact();
                                setDialogState(() => _adults++);
                                setState(() {});
                              }
                            : null,
                      ),
                    ],
                  ),
                ],
              ),
              const Divider(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Text("Children", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                      Text("Age 2-11 years", style: TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                    ],
                  ),
                  Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.remove_circle_outline, color: Color(0xFF64748B)),
                        onPressed: _kids > 0
                            ? () {
                                HapticFeedback.lightImpact();
                                setDialogState(() => _kids--);
                                setState(() {});
                              }
                            : null,
                      ),
                      Text("$_kids", style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
                      IconButton(
                        icon: const Icon(Icons.add_circle_outline, color: Color(0xFF2563EB)),
                        onPressed: _kids < 8
                            ? () {
                                HapticFeedback.lightImpact();
                                setDialogState(() => _kids++);
                                setState(() {});
                              }
                            : null,
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
          actions: [
            SizedBox(
              width: double.infinity,
              height: 46,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2563EB),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                onPressed: () {
                  Navigator.pop(ctx);
                  _recalculateAndGenerateFlights();
                },
                child: const Text("CONFIRM PASSENGERS", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showAirportPickerModal(bool isOrigin) {
    HapticFeedback.lightImpact();
    final ctrl = TextEditingController(text: isOrigin ? _originAirportCtrl.text : _destAirportCtrl.text);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          isOrigin ? "Select Origin Airport" : "Select Destination Airport",
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: ctrl,
              autofocus: true,
              decoration: InputDecoration(
                labelText: "IATA Code or City Name",
                hintText: "e.g., BOM, SIN, DXB, London",
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                prefixIcon: Icon(
                  isOrigin ? Icons.flight_takeoff_rounded : Icons.flight_land_rounded,
                  color: const Color(0xFF2563EB),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: ["BOM", "DEL", "BLR", "SIN", "DXB", "LHR", "BKK", "HND"].map((code) {
                return ActionChip(
                  label: Text(code, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                  onPressed: () {
                    ctrl.text = code;
                  },
                );
              }).toList(),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("CANCEL")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2563EB),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () {
              final code = _resolveAirportCode(ctrl.text.trim(), isOrigin ? "BOM" : "SIN");
              setState(() {
                if (isOrigin) {
                  _originAirportCtrl.text = code;
                } else {
                  _destAirportCtrl.text = code;
                }
              });
              Navigator.pop(ctx);
              _recalculateAndGenerateFlights();
            },
            child: const Text("SET AIRPORT"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final originIata = _extractIata(_originAirportCtrl.text);
    final destIata = _extractIata(_destAirportCtrl.text);

    return RefreshIndicator(
      onRefresh: _searchFlightOffers,
      color: const Color(0xFF2563EB),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 30),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Luxury Boarding Pass Parameters Card
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFFE2E8F0), width: 0.6),
                boxShadow: [
                  BoxShadow(color: Colors.black.withOpacity(0.015), blurRadius: 10, offset: const Offset(0, 3)),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Trip Type & Cabin Class Selector
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(3),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            GestureDetector(
                              onTap: () {
                                HapticFeedback.selectionClick();
                                setState(() => _isRoundTrip = true);
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                decoration: BoxDecoration(
                                  color: _isRoundTrip ? Colors.white : Colors.transparent,
                                  borderRadius: BorderRadius.circular(9),
                                  boxShadow: _isRoundTrip ? [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 4)] : null,
                                ),
                                child: Text(
                                  "Round Trip",
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.bold,
                                    color: _isRoundTrip ? const Color(0xFF2563EB) : const Color(0xFF64748B),
                                  ),
                                ),
                              ),
                            ),
                            GestureDetector(
                              onTap: () {
                                HapticFeedback.selectionClick();
                                setState(() => _isRoundTrip = false);
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                decoration: BoxDecoration(
                                  color: !_isRoundTrip ? Colors.white : Colors.transparent,
                                  borderRadius: BorderRadius.circular(9),
                                  boxShadow: !_isRoundTrip ? [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 4)] : null,
                                ),
                                child: Text(
                                  "One Way",
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.bold,
                                    color: !_isRoundTrip ? const Color(0xFF2563EB) : const Color(0xFF64748B),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEFF6FF),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFFBFDBFE), width: 0.6),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: _cabinClass,
                            isDense: true,
                            icon: const Icon(Icons.arrow_drop_down, color: Color(0xFF2563EB)),
                            items: _cabinClasses.map((c) {
                              return DropdownMenuItem(
                                value: c,
                                child: Text(c, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF1E293B))),
                              );
                            }).toList(),
                            onChanged: (val) {
                              if (val != null) {
                                HapticFeedback.selectionClick();
                                setState(() => _cabinClass = val);
                                _recalculateAndGenerateFlights();
                              }
                            },
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 18),

                  // Interactive Flight Hub Route Display
                  Row(
                    children: [
                      Expanded(
                        child: InkWell(
                          onTap: () => _showAirportPickerModal(true),
                          borderRadius: BorderRadius.circular(14),
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: const Color(0xFFE2E8F0), width: 0.6),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text("DEPARTURE", style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, color: Color(0xFF64748B), letterSpacing: 0.5)),
                                const SizedBox(height: 2),
                                Text(originIata, style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: Color(0xFF0F172A))),
                                Text(_getCityDisplayName(originIata), style: const TextStyle(fontSize: 11, color: Color(0xFF475569), fontWeight: FontWeight.w500), maxLines: 1, overflow: TextOverflow.ellipsis),
                              ],
                            ),
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: InkWell(
                          onTap: _swapAirports,
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: const Color(0xFFEFF6FF),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: const Color(0xFFBFDBFE), width: 0.6),
                            ),
                            child: const Icon(Icons.swap_horiz_rounded, color: Color(0xFF2563EB), size: 20),
                          ),
                        ),
                      ),
                      Expanded(
                        child: InkWell(
                          onTap: () => _showAirportPickerModal(false),
                          borderRadius: BorderRadius.circular(14),
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: const Color(0xFFE2E8F0), width: 0.6),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text("DESTINATION", style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, color: Color(0xFF64748B), letterSpacing: 0.5)),
                                const SizedBox(height: 2),
                                Text(destIata, style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: Color(0xFF0F172A))),
                                Text(_getCityDisplayName(destIata), style: const TextStyle(fontSize: 11, color: Color(0xFF475569), fontWeight: FontWeight.w500), maxLines: 1, overflow: TextOverflow.ellipsis),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 14),

                  // Dates & Passenger Selectors
                  Row(
                    children: [
                      Expanded(
                        flex: 3,
                        child: InkWell(
                          onTap: () async {
                            final picked = await showDatePicker(
                              context: context,
                              initialDate: _departureDate,
                              firstDate: DateTime.now(),
                              lastDate: DateTime.now().add(const Duration(days: 365)),
                            );
                            if (picked != null) {
                              setState(() => _departureDate = picked);
                              if (_returnDate.isBefore(_departureDate)) {
                                setState(() => _returnDate = _departureDate.add(const Duration(days: 4)));
                              }
                            }
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: const Color(0xFFE2E8F0), width: 0.6),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text("DATES", style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, color: Color(0xFF64748B))),
                                const SizedBox(height: 2),
                                Text(
                                  "${_departureDate.day}/${_departureDate.month}${_isRoundTrip ? ' – ${_returnDate.day}/${_returnDate.month}' : ' (One-Way)'}",
                                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12.5, color: Color(0xFF0F172A)),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        flex: 2,
                        child: InkWell(
                          onTap: _showPassengerPickerDialog,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: const Color(0xFFE2E8F0), width: 0.6),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text("PASSENGERS", style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, color: Color(0xFF64748B))),
                                const SizedBox(height: 2),
                                Text(
                                  "$_adults Ad${_kids > 0 ? ', $_kids Ch' : ''}",
                                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12.5, color: Color(0xFF2563EB)),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // Uniform Sized Primary Search Button (Height 46)
                  SizedBox(
                    width: double.infinity,
                    height: 46,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2563EB),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      icon: const Icon(Icons.search_rounded, size: 18),
                      label: const Text(
                        "SEARCH SCHEDULED FLIGHTS",
                        style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, letterSpacing: 0.5),
                      ),
                      onPressed: _searchFlightOffers,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 18),

            if (_isLoading)
              const Center(child: Padding(padding: EdgeInsets.all(40), child: CircularProgressIndicator(color: Color(0xFF2563EB))))
            else ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: const [
                      Icon(Icons.flight_takeoff_rounded, size: 15, color: Color(0xFF2563EB)),
                      SizedBox(width: 6),
                      Text("Origin & Home Flag Airlines", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13.5, color: Color(0xFF0F172A))),
                    ],
                  ),
                  Text("$_currencySymbol ($_currencyCode)", style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: Color(0xFF16A34A))),
                ],
              ),
              const SizedBox(height: 10),

              ..._homeCarriers.map((f) => _buildFlightCard(f, true)).toList(),

              if (_destCarriers.isNotEmpty) ...[
                const SizedBox(height: 16),
                Row(
                  children: const [
                    Icon(Icons.public_rounded, size: 15, color: Color(0xFF0284C7)),
                    SizedBox(width: 6),
                    Text("Destination International Airlines", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13.5, color: Color(0xFF0F172A))),
                  ],
                ),
                const SizedBox(height: 10),
                ..._destCarriers.map((f) => _buildFlightCard(f, false)).toList(),
              ],
            ],

            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  Widget _buildFlightCard(Map<String, dynamic> f, bool isHome) {
    final String airline = f["airline"] ?? "Airline";
    final String flightNo = f["flight_no"] ?? "";
    final String dept = f["departure"] ?? "08:00 AM";
    final String arr = f["arrival"] ?? "02:00 PM";
    final String dur = f["duration"] ?? "5h";
    final String stops = f["stops"] ?? "Non-stop";
    final int singleSeatPrice = f["price"] ?? 15000;
    final int totalBookingPrice = singleSeatPrice * (_adults + _kids);
    final String cabinBag = f["cabin_baggage"] ?? "7 kg";
    final String checkinBag = f["checkin_baggage"] ?? "15 kg";
    final String aircraft = f["aircraft"] ?? "Airbus A320";
    final String features = f["features"] ?? "Standard Route Service";

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
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
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEFF6FF),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.flight_rounded, size: 16, color: Color(0xFF2563EB)),
                  ),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(airline, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14, color: Color(0xFF0F172A))),
                      Text("$flightNo • $aircraft", style: const TextStyle(fontSize: 10.5, color: Color(0xFF64748B))),
                    ],
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text("$_currencySymbol$singleSeatPrice", style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: Color(0xFF16A34A))),
                  Text("per passenger ($_cabinClass)", style: const TextStyle(fontSize: 9.5, color: Color(0xFF64748B), fontWeight: FontWeight.w600)),
                ],
              ),
            ],
          ),

          const SizedBox(height: 14),

          // Visual Timeline Layout
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(dept, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15, color: Color(0xFF0F172A))),
                  Text(_extractIata(_originAirportCtrl.text), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF64748B))),
                ],
              ),
              Column(
                children: [
                  Text(dur, style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: Color(0xFF64748B))),
                  const SizedBox(height: 2),
                  SizedBox(
                    width: 90,
                    child: Row(
                      children: const [
                        Expanded(child: Divider(color: Color(0xFFCBD5E1), thickness: 1)),
                        Icon(Icons.arrow_forward_rounded, size: 12, color: Color(0xFF2563EB)),
                      ],
                    ),
                  ),
                  Text(stops, style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, color: stops.contains("Non") ? const Color(0xFF16A34A) : const Color(0xFFD97706))),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(arr, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15, color: Color(0xFF0F172A))),
                  Text(_extractIata(_destAirportCtrl.text), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF64748B))),
                ],
              ),
            ],
          ),

          const SizedBox(height: 14),

          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(6)),
                child: Row(
                  children: [
                    const Icon(Icons.luggage_rounded, size: 12, color: Color(0xFF475569)),
                    const SizedBox(width: 4),
                    Text(cabinBag, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF475569))),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(color: const Color(0xFFF0FDF4), borderRadius: BorderRadius.circular(6)),
                child: Row(
                  children: [
                    const Icon(Icons.shopping_bag_rounded, size: 12, color: Color(0xFF16A34A)),
                    const SizedBox(width: 4),
                    Text(checkinBag, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF16A34A))),
                  ],
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(color: const Color(0xFFEFF6FF), borderRadius: BorderRadius.circular(6)),
                child: Text(features, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF2563EB))),
              ),
            ],
          ),

          if ((_adults + _kids) > 1) ...[
            const SizedBox(height: 8),
            Text(
              "Total Fare (${_adults + _kids} Pax): $_currencySymbol$totalBookingPrice $_currencyCode",
              style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
            ),
          ],

          const Divider(height: 24),

          // Uniform Action Button (Height 46, Color 0xFF2563EB)
          SizedBox(
            width: double.infinity,
            height: 46,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2563EB),
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              icon: const Icon(Icons.open_in_new_rounded, size: 16),
              label: const Text(
                "Book with Official Airline (Travelpayouts)",
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
              ),
              onPressed: () => _bookOnTravelpayouts(f),
            ),
          ),
        ],
      ),
    );
  }
}