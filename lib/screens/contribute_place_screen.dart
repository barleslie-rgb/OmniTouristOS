import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/supabase_service.dart';
import '../widgets/metallic_embossed_button.dart';

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

  File? _pickedImage;
  final ImagePicker _picker = ImagePicker();

  static const String _cloudinaryCloudName = "punxig5z";
  static const String _cloudinaryPreset = "omni_gems_preset";

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

  Future<void> _pickImage(ImageSource source) async {
    try {
      final XFile? file = await _picker.pickImage(
        source: source,
        maxWidth: 1200,
        maxHeight: 1200,
        imageQuality: 85,
      );
      if (file != null) {
        setState(() => _pickedImage = File(file.path));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error selecting photo: $e")),
        );
      }
    }
  }

  Future<String?> _uploadToCloudinary(File imageFile) async {
    try {
      final uri = Uri.parse("https://api.cloudinary.com/v1_1/$_cloudinaryCloudName/image/upload");
      final request = http.MultipartRequest("POST", uri);
      request.fields["upload_preset"] = _cloudinaryPreset;
      request.files.add(await http.MultipartFile.fromPath("file", imageFile.path));

      final streamedResponse = await request.send().timeout(const Duration(seconds: 25));
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data["secure_url"] as String?;
      }
    } catch (_) {}
    return null;
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

  // Pre-submission duplicate check against existing city records
  Future<Map<String, dynamic>?> _checkExistingDuplicate(String name, String city) async {
    try {
      await SupabaseService.ensureInitialized();
      final normalized = name.toLowerCase().trim();
      final res = await SupabaseService.client
          .from('community_places')
          .select()
          .ilike('city', '%$city%');

      final list = List<Map<String, dynamic>>.from(res);
      for (var p in list) {
        final existing = (p['name'] ?? '').toString().toLowerCase().trim();
        if (existing == normalized ||
            (existing.contains(normalized) && normalized.length > 5) ||
            (normalized.contains(existing) && existing.length > 5)) {
          return p;
        }
      }
    } catch (_) {}
    return null;
  }

  Future<void> _submitGem() async {
    if (!_formKey.currentState!.validate()) return;

    final targetName = _nameCtrl.text.trim();
    setState(() => _isSubmitting = true);

    // Duplicate verification warning
    final duplicateMatch = await _checkExistingDuplicate(targetName, _currentCity);
    if (duplicateMatch != null && mounted) {
      final shouldContinue = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: const [
              Icon(Icons.warning_amber_rounded, color: Color(0xFFD97706), size: 24),
              SizedBox(width: 8),
              Text("Place Already Exists", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
            ],
          ),
          content: Text(
            "'${duplicateMatch['name']}' is already listed in $_currentCity.\n\n"
            "Would you like to continue submitting your listing or cancel to avoid duplicates?",
            style: const TextStyle(fontSize: 13, color: Color(0xFF475569)),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text("Cancel & View Existing"),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2563EB),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text("Submit Anyway", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      );

      if (shouldContinue != true) {
        setState(() => _isSubmitting = false);
        return;
      }
    }

    String? imageUrl;
    if (_pickedImage != null) {
      imageUrl = await _uploadToCloudinary(_pickedImage!);
    }

    // Resolve creator ID
    String creatorId = "anonymous";
    try {
      final supaUser = Supabase.instance.client.auth.currentUser;
      if (supaUser != null) {
        creatorId = supaUser.id;
      }
    } catch (_) {}

    final newPlace = {
      "city": _currentCity,
      "name": targetName,
      "category": _selectedCategory,
      "address": _addressCtrl.text.trim(),
      "contact_phone": _phoneCtrl.text.trim(),
      "maps_url": _mapsUrlCtrl.text.trim(),
      "must_try_tip": _tipCtrl.text.trim(),
      "endorsement_tags": _selectedTags.toList(),
      "latitude": _detectedLat,
      "longitude": _detectedLon,
      "image_url": imageUrl,
      "created_by_user_id": creatorId,
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
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final systemNavInset = MediaQuery.of(context).padding.bottom;

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
        padding: EdgeInsets.fromLTRB(18, 16, 18, bottomInset > 0 ? bottomInset + 20 : systemNavInset + 28),
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

              // Storefront / Food Photo Uploader Card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFCBD5E1)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "Storefront / Food Photo (Optional)",
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF334155)),
                    ),
                    const SizedBox(height: 10),
                    if (_pickedImage != null) ...[
                      Stack(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Image.file(_pickedImage!, height: 150, width: double.infinity, fit: BoxFit.cover),
                          ),
                          Positioned(
                            top: 8,
                            right: 8,
                            child: CircleAvatar(
                              backgroundColor: Colors.black54,
                              radius: 16,
                              child: IconButton(
                                padding: EdgeInsets.zero,
                                icon: const Icon(Icons.close, color: Colors.white, size: 16),
                                onPressed: () => setState(() => _pickedImage = null),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                    ],
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: const Color(0xFF2563EB),
                              side: const BorderSide(color: Color(0xFF2563EB)),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                            icon: const Icon(Icons.camera_alt_rounded, size: 16),
                            label: const Text("Camera", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                            onPressed: () => _pickImage(ImageSource.camera),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: const Color(0xFF334155),
                              side: const BorderSide(color: Color(0xFFCBD5E1)),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                            icon: const Icon(Icons.photo_library_rounded, size: 16),
                            label: const Text("Gallery", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                            onPressed: () => _pickImage(ImageSource.gallery),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              MetallicEmbossedButton(
                label: _isLocating ? "FETCHING SPOT GPS..." : "AUTO-DETECT SPOT VIA GPS",
                icon: Icons.my_location_rounded,
                variant: MetallicVariant.titaniumSilver,
                height: 44,
                fontSize: 12.5,
                isFullWidth: true,
                onPressed: _isLocating ? null : _detectCurrentSpotLocation,
              ),

              const SizedBox(height: 16),

              const Text("Shop / Spot Name *", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF334155))),
              const SizedBox(height: 6),
              TextFormField(
                controller: _nameCtrl,
                decoration: InputDecoration(
                  hintText: "e.g. Sanjivani 24/7 Medical / Royal Chinese",
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

              MetallicEmbossedButton(
                label: _isSubmitting ? "PUBLISHING TO DIRECTORY..." : "PUBLISH TO COMMUNITY DIRECTORY",
                icon: Icons.check_circle_rounded,
                variant: MetallicVariant.emeraldGreen,
                height: 48,
                fontSize: 13.5,
                isFullWidth: true,
                onPressed: _isSubmitting ? null : _submitGem,
              ),
            ],
          ),
        ),
      ),
    );
  }
}