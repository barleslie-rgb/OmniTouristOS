import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

class AffiliateConfig {
  static const String bookingComAid = "2420912";
  static const String travelpayoutsMarker = "774359";

  // Clean Booking.com URL with affiliate tracking
  static String getBookingHotelsUrl(String query, {String currency = "INR"}) {
    final sanitized = query
        .replaceAll('&', ' ')
        .replaceAll(RegExp(r'\b(Hotel|Resort|Suites|Residency|Comfort|Boutique)\b', caseSensitive: false), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    final clean = Uri.encodeComponent(sanitized.isNotEmpty ? sanitized : query);
    return "https://www.booking.com/searchresults.html?ss=$clean&selected_currency=$currency&aid=$bookingComAid&marker=$travelpayoutsMarker";
  }

  // WayAway / Aviasales clean direct search via Travelpayouts
  static String getFlightsUrl(String destinationCity, {String currency = "INR"}) {
    final clean = Uri.encodeComponent(destinationCity);
    return "https://www.aviasales.com/search/$clean?currency=${currency.toLowerCase()}&marker=$travelpayoutsMarker";
  }

  // Station-mapped ConfirmTkt search endpoint
  static String getConfirmTktUrl(String city) {
    final c = city.toLowerCase();
    String destCode = "BSR";

    if (c.contains("vasai") || c.contains("virar") || c.contains("bassein")) {
      destCode = "BSR";
    } else if (c.contains("mumbai") || c.contains("bombay")) {
      destCode = "BCT";
    } else if (c.contains("delhi")) {
      destCode = "NDLS";
    } else if (c.contains("jaipur")) {
      destCode = "JP";
    } else if (c.contains("pune")) {
      destCode = "PUNE";
    } else if (c.contains("srinagar") || c.contains("kashmir") || c.contains("pahalgam")) {
      destCode = "SXR";
    } else if (c.contains("bangalore") || c.contains("bengaluru")) {
      destCode = "SBC";
    } else {
      destCode = Uri.encodeComponent(city);
    }
    return "https://www.confirmtkt.com/train-search?source=&destination=$destCode";
  }

  // Official IRCTC Rail Search
  static String getIrctcUrl() {
    return "https://www.irctc.co.in/nget/train-search";
  }
}

class LocationDetailDossierScreen extends StatelessWidget {
  final Map<String, dynamic> landmark;
  final String city;
  final String state;
  final String country;
  final int adults;
  final int kids;
  final String language;
  final List<dynamic>? backendHotels;

  const LocationDetailDossierScreen({
    Key? key,
    required this.landmark,
    required this.city,
    required this.state,
    required this.country,
    required this.adults,
    required this.kids,
    required this.language,
    this.backendHotels,
  }) : super(key: key);

  // Launches directly into external browser (Chrome / Samsung Internet) to bypass 403 Forbidden
  Future<void> _launchExternalUrl(String url) async {
    HapticFeedback.selectionClick();
    try {
      final uri = Uri.parse(url);
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      try {
        final uri = Uri.parse(url);
        await launchUrl(uri, mode: LaunchMode.platformDefault);
      } catch (_) {}
    }
  }

  Future<void> _launchMaps(BuildContext context, double lat, double lng, String title) async {
    HapticFeedback.mediumImpact();
    final clean = Uri.encodeComponent(title);
    final url = (lat == 0.0 && lng == 0.0)
        ? Uri.parse("https://www.google.com/maps/search/?api=1&query=$clean+$city")
        : Uri.parse(
            "https://www.google.com/maps/dir/?api=1&destination=$lat,$lng&destination_place_id=$clean&travelmode=driving");

    try {
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
      }
    } catch (_) {}
  }

  Future<void> _savePassToVault(BuildContext context, String title, String passType) async {
    HapticFeedback.heavyImpact();
    final prefs = await SharedPreferences.getInstance();
    final List<String> existing = prefs.getStringList('omni_family_vault_docs') ?? [];

    final item = jsonEncode({
      "title": title,
      "type": passType,
      "location": "$city, $country",
      "timestamp": DateTime.now().toIso8601String(),
      "status": "Offline Verified",
    });

    existing.add(item);
    await prefs.setStringList('omni_family_vault_docs', existing);

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: const Color(0xFF16A34A),
          content: Text("✓ $title saved to Family Vault for offline access!"),
        ),
      );
    }
  }

  Map<String, dynamic> _detectCurrencyConfig() {
    final c = country.toLowerCase();
    if (c.contains("united arab emirates") || c.contains("uae") || c.contains("dubai")) {
      return {"code": "AED", "symbol": "AED ", "mult": 3.67};
    }
    if (c.contains("united states") || c.contains("usa") || c.contains("america")) {
      return {"code": "USD", "symbol": "\$", "mult": 1.0};
    }
    if (c.contains("united kingdom") || c.contains("uk") || c.contains("london")) {
      return {"code": "GBP", "symbol": "£", "mult": 0.78};
    }
    if (c.contains("europe") || c.contains("france") || c.contains("germany") || c.contains("italy") || c.contains("spain")) {
      return {"code": "EUR", "symbol": "€", "mult": 0.92};
    }
    if (c.contains("japan") || c.contains("tokyo") || c.contains("osaka")) {
      return {"code": "JPY", "symbol": "¥", "mult": 155.0};
    }
    if (c.contains("singapore")) {
      return {"code": "SGD", "symbol": "S\$", "mult": 1.35};
    }
    return {"code": "INR", "symbol": "₹", "mult": 83.5};
  }

  bool _isEurope(String c) {
    final lower = c.toLowerCase();
    return lower.contains("uk") ||
        lower.contains("united kingdom") ||
        lower.contains("france") ||
        lower.contains("germany") ||
        lower.contains("italy") ||
        lower.contains("spain") ||
        lower.contains("europe");
  }

  bool _isIndia(String c) => c.toLowerCase().contains("india");

  Map<String, String> _getDemographicAlert() {
    if (kids > 0) {
      return {
        "role": "Family & Kids Advisory",
        "color": "0xFFEA580C",
        "tip":
            "Stroller access is open on primary exterior routes. Hydration and restroom points are situated at the central checkpoint. Keep young travelers close during peak visitor density hours (4:00 PM - 7:00 PM)."
      };
    } else if (adults == 1) {
      return {
        "role": "Solo Explorer Safety",
        "color": "0xFF0284C7",
        "tip":
            "High pedestrian foot traffic and verified safety. For evening walks, stick to well-lit main boulevards. Use verified app-based ride hails over unmetered curbside taxis."
      };
    } else if (adults == 2) {
      return {
        "role": "Couples Advisory",
        "color": "0xFFE11D48",
        "tip":
            "Golden hour delivers the finest photography and views. Decline unofficial street vendors offering instant printed photos at inflated rates."
      };
    } else {
      return {
        "role": "Group Travel Advisory",
        "color": "0xFF2563EB",
        "tip":
            "Establish an identifiable meeting landmark near the main gates. Main ticketing windows offer group lane clearance for parties over 5."
      };
    }
  }

  List<Map<String, dynamic>> _getScamAlerts() {
    final name = (landmark["name"] ?? "").toString().toLowerCase();
    final lowerCity = city.toLowerCase();

    if (name.contains("gateway") || lowerCity.contains("mumbai")) {
      return [
        {
          "title": "Unauthorized Photographers",
          "desc": "Individuals offering instant photos for ₹30 then demanding ₹200+ after printing unrequested sheets. Politely decline."
        },
        {
          "title": "Ferry Ticket Scalpers",
          "desc": "Touts along the approach asserting harbor counter is closed. Always buy tickets directly at the official harbor booth."
        },
      ];
    } else if (lowerCity.contains("vasai") || lowerCity.contains("virar")) {
      return [
        {
          "title": "Unmetered Autorickshaw Surcharges",
          "desc": "Insist on shared-seat flat fares or meter tariffs from Vasai Road Railway Station rather than unnegotiated direct hires."
        },
        {
          "title": "Private Fort Guides",
          "desc": "Individuals charging fees to guide through Bassein Fort. Entry to the fort is completely free and public."
        },
      ];
    } else if (lowerCity.contains("jaipur")) {
      return [
        {
          "title": "Gem & Jewelry Certification Trap",
          "desc": "Auto drivers diverting you to 'government emporiums' offering fake gem stones with bogus certificates. Politely decline."
        },
      ];
    }

    return [
      {
        "title": "Unofficial Ticket Counters",
        "desc": "Purchase admission tickets solely through official turnstiles or direct verified websites."
      },
      {
        "title": "Unmetered Cab Surcharges",
        "desc": "Ensure meters run from departure, or rely on recognized ride-hail applications."
      },
    ];
  }

  List<Map<String, dynamic>> _getNearbyHotels(String sym, double mult) {
    if (backendHotels != null && backendHotels!.isNotEmpty) {
      return backendHotels!.map((h) {
        final tierStr = (h["tier"] ?? "Comfort (3-4 Star)").toString();
        final basePriceUSD = (h["basePrice"] as num?)?.toDouble() ?? 45.0;
        final price = (basePriceUSD * mult).round();
        final rackPrice = (price * 1.35).round();

        return {
          "name": h["name"] ?? "Hotel in $city",
          "stars": tierStr,
          "rating": "${h['rating'] ?? '4.5'} Verified",
          "booking_price": "$sym$price",
          "rack_price": "$sym$rackPrice",
          "distance": "0.8 km away",
          "image": "https://images.unsplash.com/photo-1566073771259-6a8506099945?auto=format&fit=crop&w=600&q=80",
        };
      }).toList();
    }

    return [
      {
        "name": "Grand Central Palace Hotel $city",
        "stars": "5 Star Luxury",
        "rating": "9.2 Superb",
        "booking_price": "$sym${(110 * mult).round()}",
        "rack_price": "$sym${(150 * mult).round()}",
        "distance": "0.4 km away",
        "image": "https://images.unsplash.com/photo-1566073771259-6a8506099945?auto=format&fit=crop&w=600&q=80",
      },
      {
        "name": "Heritage Central Residency $city",
        "stars": "4 Star Comfort",
        "rating": "8.8 Very Good",
        "booking_price": "$sym${(58 * mult).round()}",
        "rack_price": "$sym${(80 * mult).round()}",
        "distance": "0.9 km away",
        "image": "https://images.unsplash.com/photo-1582719508461-905c673771fd?auto=format&fit=crop&w=600&q=80",
      },
    ];
  }

  @override
  Widget build(BuildContext context) {
    final title = landmark["name"] ?? landmark["title"] ?? "Destination Landmark";
    final category = landmark["category"] ?? "Heritage Spot";
    final description = landmark["detail"] ?? landmark["description"] ?? "Curated point of interest.";
    final timing = landmark["timing"] ?? "Open Daily";
    final fee = landmark["entry"] ?? landmark["entry_fee"] ?? "Free Entry";
    final lat = (landmark["lat"] as num?)?.toDouble() ?? 0.0;
    final lng = (landmark["lng"] as num?)?.toDouble() ?? 0.0;
    final imageUrl = (landmark["image"] != null && landmark["image"].toString().isNotEmpty)
        ? landmark["image"].toString()
        : "https://images.unsplash.com/photo-1590050752117-238cb0fb12b1?auto=format&fit=crop&w=1200&q=80";

    final currConfig = _detectCurrencyConfig();
    final String sym = currConfig["symbol"]!;
    final double mult = currConfig["mult"]!;
    final String currCode = currConfig["code"]!;

    final demoAlert = _getDemographicAlert();
    final scamAlerts = _getScamAlerts();
    final hotels = _getNearbyHotels(sym, mult);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
        actions: [
          IconButton(
            tooltip: "Navigate with Google Maps",
            icon: const Icon(Icons.directions_rounded, color: Color(0xFF2563EB)),
            onPressed: () => _launchMaps(context, lat, lng, title),
          ),
        ],
      ),
      bottomNavigationBar: Container(
        padding: EdgeInsets.fromLTRB(16, 12, 16, MediaQuery.of(context).padding.bottom + 12),
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
        ),
        child: Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF003580),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 0,
                ),
                icon: const Icon(Icons.open_in_browser_rounded, size: 18, color: Color(0xFF38BDF8)),
                label: Text(
                  "Book Stay in $city",
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
                onPressed: () => _launchExternalUrl(
                  AffiliateConfig.getBookingHotelsUrl(city, currency: currCode),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2563EB),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 0,
                ),
                icon: const Icon(Icons.navigation_rounded, size: 18),
                label: const Text("Turn-by-Turn", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                onPressed: () => _launchMaps(context, lat, lng, title),
              ),
            ),
          ],
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: Stack(
                children: [
                  Image.network(
                    imageUrl,
                    height: 220,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      height: 220,
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(colors: [Color(0xFF1E3A8A), Color(0xFF2563EB)]),
                      ),
                      child: const Center(
                        child: Icon(Icons.image_not_supported_rounded, color: Colors.white54, size: 40),
                      ),
                    ),
                  ),
                  Positioned(
                    top: 14,
                    left: 14,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.65),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        category,
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Text(title, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Color(0xFF0F172A))),
            const SizedBox(height: 4),
            Text("$city, $state, $country", style: const TextStyle(fontSize: 13, color: Color(0xFF64748B), fontWeight: FontWeight.w600)),
            const SizedBox(height: 12),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(color: const Color(0xFFEFF6FF), borderRadius: BorderRadius.circular(8)),
                  child: Row(
                    children: [
                      const Icon(Icons.access_time_rounded, size: 14, color: Color(0xFF2563EB)),
                      const SizedBox(width: 6),
                      Text(timing, style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: Color(0xFF1E40AF))),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(color: const Color(0xFFF0FDF4), borderRadius: BorderRadius.circular(8)),
                  child: Row(
                    children: [
                      const Icon(Icons.confirmation_num_rounded, size: 14, color: Color(0xFF16A34A)),
                      const SizedBox(width: 6),
                      Text(fee, style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: Color(0xFF166534))),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Text(description, style: const TextStyle(fontSize: 14, color: Color(0xFF334155), height: 1.45)),
            const SizedBox(height: 20),
            // Demographic Advisory Card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Color(int.parse(demoAlert["color"]!)).withOpacity(0.08),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Color(int.parse(demoAlert["color"]!)).withOpacity(0.3)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.shield_rounded, color: Color(int.parse(demoAlert["color"]!)), size: 24),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          demoAlert["role"]!,
                          style: TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 13.5,
                            color: Color(int.parse(demoAlert["color"]!)),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(demoAlert["tip"]!, style: const TextStyle(fontSize: 12.5, color: Color(0xFF1E293B), height: 1.35)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            // Scam Alerts
            const Text("⚠️ Localized Tourist Traps & Scam Alerts", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 15, color: Color(0xFF0F172A))),
            const SizedBox(height: 10),
            ...scamAlerts.map((s) => Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFFBEB),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFFDE68A)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.warning_amber_rounded, color: Color(0xFFD97706), size: 20),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(s["title"]!, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF92400E))),
                            const SizedBox(height: 2),
                            Text(s["desc"]!, style: const TextStyle(fontSize: 12, color: Color(0xFF78350F))),
                          ],
                        ),
                      ),
                    ],
                  ),
                )),
            const SizedBox(height: 20),
            // Rail Hub: ConfirmTkt + Official IRCTC Portal
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
                      const Icon(Icons.train_rounded, color: Color(0xFF2563EB), size: 20),
                      const SizedBox(width: 8),
                      Text(
                        _isIndia(country)
                            ? "Indian Railways • IRCTC & ConfirmTkt"
                            : _isEurope(country)
                                ? "European Rail & Eurail Pass"
                                : "Regional Transit & Passes",
                        style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13.5, color: Color(0xFF0F172A)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _isIndia(country)
                        ? "Check live seats on ConfirmTkt or book directly via the official IRCTC portal."
                        : "High-speed rail passes and regional transit options.",
                    style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF2563EB),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            elevation: 0,
                          ),
                          icon: const Icon(Icons.open_in_browser_rounded, size: 15),
                          label: Text(
                            _isIndia(country) ? "ConfirmTkt" : "Transit",
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11.5),
                          ),
                          onPressed: () => _launchExternalUrl(AffiliateConfig.getConfirmTktUrl(city)),
                        ),
                      ),
                      if (_isIndia(country)) ...[
                        const SizedBox(width: 8),
                        Expanded(
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF003580),
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              elevation: 0,
                            ),
                            icon: const Icon(Icons.confirmation_number_rounded, size: 15),
                            label: const Text(
                              "Official IRCTC",
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11.5),
                            ),
                            onPressed: () => _launchExternalUrl(AffiliateConfig.getIrctcUrl()),
                          ),
                        ),
                      ],
                      const SizedBox(width: 8),
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF0F172A),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 10),
                        ),
                        icon: const Icon(Icons.folder_special_rounded, size: 16, color: Color(0xFFEA580C)),
                        label: const Text("Vault", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11.5)),
                        onPressed: () => _savePassToVault(context, "$city Transit Pass", "Transit Pass"),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            // Nearby Hotels
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text("🏨 Nearby Stays (Booking.com)", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 15, color: Color(0xFF0F172A))),
                TextButton(
                  onPressed: () => _launchExternalUrl(AffiliateConfig.getBookingHotelsUrl(city, currency: currCode)),
                  child: const Text("View All →", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF2563EB))),
                ),
              ],
            ),
            ...hotels.map((h) => Container(
                  margin: const EdgeInsets.only(bottom: 10),
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
                        child: Image.network(
                          h["image"]!,
                          width: 70,
                          height: 70,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Container(
                            width: 70,
                            height: 70,
                            color: const Color(0xFFEFF6FF),
                            child: const Icon(Icons.hotel_rounded, color: Color(0xFF2563EB)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(h["name"]!, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF0F172A)), maxLines: 1, overflow: TextOverflow.ellipsis),
                            Text("${h["stars"]} • ${h["distance"]}", style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Text(h["booking_price"]!, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w900, color: Color(0xFF16A34A))),
                                const SizedBox(width: 6),
                                Text(h["rack_price"]!, style: const TextStyle(fontSize: 11, decoration: TextDecoration.lineThrough, color: Color(0xFF94A3B8))),
                              ],
                            ),
                          ],
                        ),
                      ),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF003580),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          elevation: 0,
                        ),
                        onPressed: () => _launchExternalUrl(
                          AffiliateConfig.getBookingHotelsUrl("${h['name']} $city", currency: currCode),
                        ),
                        child: const Text("Book", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11.5)),
                      ),
                    ],
                  ),
                )),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }
}