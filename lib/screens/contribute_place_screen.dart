import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import '../services/supabase_service.dart';

class ContributePlaceScreen extends StatefulWidget {
  final String activeCity;

  const ContributePlaceScreen({
    Key? key,
    required this.activeCity,
  }) : super(key: key);

  @override
  State<ContributePlaceScreen> createState() => _ContributePlaceScreenState();
}

class _ContributePlaceScreenState extends State<ContributePlaceScreen> {
  final _formKey = GlobalKey<FormState>();

  final TextEditingController _nameCtrl = TextEditingController();
  final TextEditingController _addressCtrl = TextEditingController();
  final TextEditingController _phoneCtrl = TextEditingController();
  final TextEditingController _mapsUrlCtrl = TextEditingController();
  final TextEditingController _tipCtrl = TextEditingController();
  final TextEditingController _contributorCtrl = TextEditingController();

  late String _currentCity;
  String _selectedCategory = "Pharmacy / Chemist";
  bool _isLocating = false;
  bool _isSubmitting = false;

  double? _detectedLat;
  double? _detectedLon;

  final List<String> _availableTags = [
    "🕒 24 Hours",
    "💳 UPI Accepted",
    "🛵 Home Delivery",
    "❄️ AC Seating",
    "🌿 Pure Veg",
    "💰 Budget Friendly",
    "🅿️ Parking Available",
    "📶 Free Wi-Fi",
  ];
  final Set<String> _selectedTags = {};

  final List<String> _categories = [
    "Pharmacy / Chemist",
    "Barber & Salon",
    "Kirana & Essentials",
    "Ice Cream & Dairy",
    "Cold Storage & Meat",
    "Indo-Chinese & Snacks",
    "Chai & Quick Bites",
    "Bar & Restaurant",
    "Diner & Seafood",
    "Market, Bazaar & Mall",
    "Movie Cinema & Theater",
    "Picnic Spot & Landscape",
    "Resort & Farmhouse",
    "Heritage & Sight",
  ];

  @override
  void initState() {
    super.initState();
    _currentCity = widget.activeCity;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _addressCtrl.dispose();
    _phoneCtrl.dispose();
    _mapsUrlCtrl.dispose();
    _tipCtrl.dispose();
    _contributorCtrl.dispose();
    super.dispose();
  }

  Future<void> _detectCurrentSpotLocation() async {
    if (_isLocating) return;
    setState(() => _isLocating = true);

    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Location services are disabled on this device.")),
          );
        }
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) return;
      }
      if (permission == LocationPermission.deniedForever) return;

      Position pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 10),
      );

      _detectedLat = pos.latitude;
      _detectedLon = pos.longitude;

      final mapsPin = "https://www.google.com/maps/search/?api=1&query=${pos.latitude},${pos.longitude}";

      final uri = Uri.parse(
        "https://nominatim.openstreetmap.org/reverse?format=json&lat=${pos.latitude}&lon=${pos.longitude}&zoom=18&addressdetails=1",
      );
      final res = await http.get(uri, headers: {"User-Agent": "OmniTouristOS/1.0"}).timeout(const Duration(seconds: 8));

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final addr = data["address"] as Map<String, dynamic>?;

        if (addr != null && mounted) {
          String road = (addr["road"] ?? addr["pedestrian"] ?? addr["suburb"] ?? "").toString().trim();
          String neighbourhood = (addr["neighbourhood"] ?? addr["residential"] ?? addr["suburb"] ?? "").toString().trim();
          String cityDetected = (addr["city"] ?? addr["town"] ?? addr["municipality"] ?? addr["county"] ?? _currentCity).toString().trim();

          if (cityDetected.toLowerCase().contains("mumbai") || cityDetected.toLowerCase().contains("bombay")) {
            cityDetected = "Mumbai";
          } else if (cityDetected.toLowerCase().contains("vasai") || cityDetected.toLowerCase().contains("virar")) {
            cityDetected = "Vasai-Virar";
          }

          String formattedAddress = [road, neighbourhood, cityDetected].where((s) => s.isNotEmpty).join(", ");

          setState(() {
            _currentCity = cityDetected;
            _addressCtrl.text = formattedAddress;
            _mapsUrlCtrl.text = mapsPin;
          });

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: const Color(0xFF16A34A),
              content: Text("✓ Spot identified: $formattedAddress"),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Could not retrieve GPS coordinates: $e")),
        );
      }
    } finally {
      if (mounted) setState(() => _isLocating = false);
    }
  }

  Future<void> _submitGem() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);

    final newPlace = {
      "city": _currentCity,
      "name": _nameCtrl.text.trim(),
      "category": _selectedCategory,
      "address": _addressCtrl.text.trim(),
      "contact_phone": _phoneCtrl.text.trim(),
      "maps_url": _mapsUrlCtrl.text.trim(),
      "must_try_tip": _tipCtrl.text.trim(),
      "endorsement_tags": _selectedTags.toList(),
      "latitude": _detectedLat,
      "longitude": _detectedLon,
      "contributor_name": _contributorCtrl.text.trim().isNotEmpty
          ? _contributorCtrl.text.trim()
          : "Local Explorer",
      "upvotes": 1,
    };

    final success = await SupabaseService.addPlace(newPlace);

    if (!mounted) return;
    setState(() => _isSubmitting = false);

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: Color(0xFF16A34A),
          content: Text("✓ Local Gem submitted to community directory!"),
        ),
      );
      Navigator.pop(context, true);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: Color(0xFFDC2626),
          content: Text("Submission failed. Please check connection."),
        ),
      );
    }
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
          "Recommend in $_currentCity",
          style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 17, color: Color(0xFF0F172A)),
        ),
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(18, 16, 18, bottomInset + 24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFBFDBFE)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.storefront_rounded, color: Color(0xFF2563EB), size: 24),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        "Help fellow travelers and locals discover hidden corner stalls, reliable chemists, and neighborhood businesses in $_currentCity.",
                        style: const TextStyle(fontSize: 12.5, color: Color(0xFF1E40AF), height: 1.35),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF2563EB),
                  side: const BorderSide(color: Color(0xFF2563EB)),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: _isLocating ? null : _detectCurrentSpotLocation,
                icon: _isLocating
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF2563EB)))
                    : const Icon(Icons.my_location_rounded, size: 18),
                label: Text(
                  _isLocating ? "Fetching Exact Coordinates..." : "Auto-Detect My Current Spot (GPS)",
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
              ),

              const SizedBox(height: 16),

              const Text("Shop / Spot Name *", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF334155))),
              const SizedBox(height: 6),
              TextFormField(
                controller: _nameCtrl,
                decoration: InputDecoration(
                  hintText: "e.g. Sanjivani 24/7 Medical / Royal Chinese / Pop Tate's",
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                ),
                validator: (val) => val == null || val.trim().isEmpty ? "Please enter the spot name" : null,
              ),

              const SizedBox(height: 16),

              const Text("Category *", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF334155))),
              const SizedBox(height: 6),
              DropdownButtonFormField<String>(
                value: _selectedCategory,
                isExpanded: true,
                decoration: InputDecoration(
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                ),
                items: _categories.map((c) => DropdownMenuItem(value: c, child: Text(c, overflow: TextOverflow.ellipsis))).toList(),
                onChanged: (val) => setState(() => _selectedCategory = val!),
              ),

              const SizedBox(height: 16),

              const Text("Address / Neighborhood Street *", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF334155))),
              const SizedBox(height: 6),
              TextFormField(
                controller: _addressCtrl,
                decoration: InputDecoration(
                  hintText: "e.g. Near Station Road, Opp. Municipal Garden",
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                ),
                validator: (val) => val == null || val.trim().isEmpty ? "Please specify location/street" : null,
              ),

              const SizedBox(height: 16),

              const Text("Phone / WhatsApp Number", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF334155))),
              const SizedBox(height: 6),
              TextFormField(
                controller: _phoneCtrl,
                keyboardType: TextInputType.phone,
                decoration: InputDecoration(
                  hintText: "e.g. +91 9876543210 (For 1-tap call & WhatsApp)",
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                ),
              ),

              const SizedBox(height: 16),

              const Text("Endorsement Badges (Select all that apply)", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF334155))),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _availableTags.map((tag) {
                  final isSelected = _selectedTags.contains(tag);
                  return FilterChip(
                    label: Text(tag, style: TextStyle(fontSize: 12, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
                    selected: isSelected,
                    selectedColor: const Color(0xFFDBEAFE),
                    checkmarkColor: const Color(0xFF2563EB),
                    labelStyle: TextStyle(color: isSelected ? const Color(0xFF1E40AF) : const Color(0xFF334155)),
                    onSelected: (val) {
                      setState(() {
                        if (val) {
                          _selectedTags.add(tag);
                        } else {
                          _selectedTags.remove(tag);
                        }
                      });
                    },
                  );
                }).toList(),
              ),

              const SizedBox(height: 16),

              const Text("Google Maps Link", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF334155))),
              const SizedBox(height: 6),
              TextFormField(
                controller: _mapsUrlCtrl,
                keyboardType: TextInputType.url,
                decoration: InputDecoration(
                  hintText: "Auto-filled by GPS button above or paste https://maps.app.goo.gl/...",
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                ),
              ),

              const SizedBox(height: 16),

              const Text("Must-Try Item / Unique Tip (Max 100 chars)", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF334155))),
              const SizedBox(height: 6),
              TextFormField(
                controller: _tipCtrl,
                maxLength: 100,
                decoration: InputDecoration(
                  hintText: "e.g. Best triple Schezwan fried rice, delivers till 2:00 AM.",
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                ),
              ),

              const SizedBox(height: 16),

              const Text("Your Name / Alias", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF334155))),
              const SizedBox(height: 6),
              TextFormField(
                controller: _contributorCtrl,
                decoration: InputDecoration(
                  hintText: "e.g. Leslie D. (Defaults to 'Local Explorer')",
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                ),
              ),

              const SizedBox(height: 24),

              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2563EB),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: _isSubmitting ? null : _submitGem,
                  icon: _isSubmitting
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.check_circle_rounded, size: 20),
                  label: Text(
                    _isSubmitting ? "Publishing Gem..." : "Publish to Community Directory",
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14.5),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}