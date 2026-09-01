import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:audioplayers/audioplayers.dart';
import 'package:file_picker/file_picker.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

// LIVE CLOUD BACKEND URL ON RENDER
const String kBaseApiUrl = "https://omni-backend-pk28.onrender.com";

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const OmniTouristOS());
}

class OmniTouristOS extends StatelessWidget {
  const OmniTouristOS({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Omni TouristOS',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF090A10),
        primaryColor: const Color(0xFF7C4DFF),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF8B5CF6),
          secondary: Color(0xFF06B6D4),
          surface: Color(0xFF131622),
        ),
        fontFamily: 'Roboto',
      ),
      home: const MainShellScreen(),
    );
  }
}

class MainShellScreen extends StatefulWidget {
  const MainShellScreen({super.key});

  @override
  State<MainShellScreen> createState() => _MainShellScreenState();
}

class _MainShellScreenState extends State<MainShellScreen> {
  int _currentNavIndex = 0; // 0: Home, 1: PaperPilot, 2: TouristOS, 3: Saved, 4: Settings
  int _paperPilotTab = 0; // 0: Document Auditor, 1: Live Q&A Studio, 2: Universal File Converter
  int _touristPage = 1;

  String selectedLanguage = "English";
  final List<String> languages = [
    "English", "Hindi (हिन्दी)", "Marathi (मराठी)", "Sanskrit (संस्कृतम्)",
    "Gujarati (ગુજરાતી)", "Bengali (বাংলা)", "Tamil (தமிழ்)", "Telugu (తెలుగు)",
    "Malayalam (മലയാളം)", "Kannada (ಕನ್ನಡ)", "Punjabi (ਪੰਜਾਬੀ)", "Urdu (اردو)",
    "Arabic (العربية)", "Spanish (Español)", "French (Français)", "German (Deutsch)",
    "Japanese (日本語)", "Russian (Русский)"
  ];

  final Map<String, String> languageLocales = {
    "English": "en_US",
    "Hindi (हिन्दी)": "hi_IN",
    "Marathi (मराठी)": "mr_IN",
    "Sanskrit (संस्कृतम्)": "sa_IN",
    "Gujarati (ગુજરાતી)": "gu_IN",
    "Bengali (বাংলা)": "bn_IN",
    "Tamil (தமிழ்)": "ta_IN",
    "Telugu (తెలుగు)": "te_IN",
    "Malayalam (മലയാളം)": "ml_IN",
    "Kannada (ಕನ್ನಡ)": "kn_IN",
    "Punjabi (ਪੰਜਾਬੀ)": "pa_IN",
    "Urdu (اردو)": "ur_PK",
    "Arabic (العربية)": "ar_SA",
    "Spanish (Español)": "es_ES",
    "French (Français)": "fr_FR",
    "German (Deutsch)": "de_DE",
    "Japanese (日本語)": "ja_JP",
    "Russian (Русский)": "ru_RU",
  };

  String selectedGroupType = "Family";
  final List<String> groupOptions = ["Family", "Couple", "Solo", "Friends"];

  String selectedDiet = "All Foods";
  final List<String> dietOptions = ["All Foods", "Strictly Vegetarian"];

  String selectedTime = "5 Hours";
  final List<String> timeOptions = ["3 Hours", "5 Hours", "1 Day", "2+ Days"];

  final Map<String, Map<String, List<String>>> worldLocations = {
    "India": {
      "Maharashtra": ["Mumbai", "Vasai-Virar", "Pune", "Wada", "Palghar", "Nagpur", "Nashik"],
      "Delhi NCR": ["New Delhi", "Gurugram", "Noida"],
      "Goa": ["Panaji", "Calangute", "Margao", "Vasco da Gama"],
      "Karnataka": ["Bengaluru", "Mysuru", "Hampi"],
      "Tamil Nadu": ["Chennai", "Madurai", "Ooty"],
      "Rajasthan": ["Jaipur", "Udaipur", "Jodhpur"],
      "Kerala": ["Kochi", "Munnar", "Alleppey"],
      "West Bengal": ["Kolkata", "Darjeeling"]
    },
    "United States": {
      "New York": ["New York City", "Buffalo"],
      "California": ["Los Angeles", "San Francisco", "San Diego"],
      "Florida": ["Miami", "Orlando"],
      "Nevada": ["Las Vegas", "Reno"]
    },
    "United Arab Emirates": {
      "Dubai": ["Downtown Dubai", "Dubai Marina", "Palm Jumeirah"],
      "Abu Dhabi": ["Abu Dhabi City", "Yas Island"]
    },
    "United Kingdom": {
      "England": ["London", "Manchester", "Birmingham", "Oxford"],
      "Scotland": ["Edinburgh", "Glasgow"]
    },
    "France": {
      "Île-de-France": ["Paris", "Versailles"],
      "Provence": ["Nice", "Cannes"]
    },
    "Japan": {
      "Kanto": ["Tokyo", "Yokohama"],
      "Kansai": ["Kyoto", "Osaka"]
    }
  };

  String selectedCountry = "India";
  String selectedState = "Maharashtra";
  String selectedCity = "Mumbai";

  final TextEditingController _customCityController = TextEditingController(text: "Mumbai");

  bool isAnalyzing = false;
  bool isAsking = false;
  String? analysisResult;
  String? detectedDestinationBanner;
  String selectedFileName = "No file chosen";
  PlatformFile? chatAttachedFile;

  // Voice Input (Speech to Text)
  late stt.SpeechToText _speech;
  bool _isListening = false;
  bool _voiceEnabled = true;

  // Image Progress Simulation
  double imageGenProgress = 0.0;
  bool isGeneratingImage = false;

  PlatformFile? converterFile;
  String targetFormat = "pdf";
  bool isConverting = false;
  double conversionProgress = 0.0;
  String conversionStatus = "Ready";
  String? convertedDownloadUrl;

  final TextEditingController _questionController = TextEditingController();
  final ScrollController _chatScrollController = ScrollController();
  List<Map<String, dynamic>> chatHistory = [];

  bool isPlanning = false;
  Map<String, dynamic>? structuredDestinationData;
  double currentLat = 19.3456;
  double currentLng = 72.8343;
  String currentCoords = "19.3456° N, 72.8343° E";

  bool isExploring = false;
  Map<String, dynamic>? exploringSpot;
  final TextEditingController _exploreChatController = TextEditingController();
  final ScrollController _exploreScrollController = ScrollController();
  List<Map<String, dynamic>> exploreChatHistory = [];
  bool isExploreAsking = false;

  final List<Map<String, String>> savedItemsList = [];
  String selectedExportFormat = "none";

  late AudioPlayer _audioPlayer;

  @override
  void initState() {
    super.initState();
    _audioPlayer = AudioPlayer();
    _speech = stt.SpeechToText();
    _fetchLiveGpsCoordinates();
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    _customCityController.dispose();
    _questionController.dispose();
    _chatScrollController.dispose();
    _exploreChatController.dispose();
    _exploreScrollController.dispose();
    super.dispose();
  }

  Future<void> _fetchLiveGpsCoordinates() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return;
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) return;
      }
      Position pos = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
      if (mounted) {
        setState(() {
          currentLat = pos.latitude;
          currentLng = pos.longitude;
          currentCoords = "${pos.latitude.toStringAsFixed(4)}° N, ${pos.longitude.toStringAsFixed(4)}° E";
        });
      }
    } catch (_) {}
  }

  Future<void> _toggleVoiceListening(TextEditingController controller) async {
    if (!_voiceEnabled) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Voice input is disabled in Settings.")),
      );
      return;
    }

    if (_isListening) {
      await _speech.stop();
      setState(() => _isListening = false);
    } else {
      bool available = await _speech.initialize(
        onError: (val) => setState(() => _isListening = false),
        onStatus: (val) {
          if (val == 'done' || val == 'notListening') {
            setState(() => _isListening = false);
          }
        },
      );
      if (available) {
        setState(() => _isListening = true);
        String locale = languageLocales[selectedLanguage] ?? "en_US";
        _speech.listen(
          localeId: locale,
          onResult: (val) {
            setState(() {
              controller.text = val.recognizedWords;
            });
          },
        );
      } else {
        setState(() => _isListening = false);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Microphone permission not granted or voice input unavailable.")),
          );
        }
      }
    }
  }

  Future<void> _launchExternalUrl(String urlString) async {
    try {
      final Uri uri = Uri.parse(urlString);
      final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!launched) {
        await launchUrl(uri, mode: LaunchMode.platformDefault);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Could not open link: $e")));
      }
    }
  }

  void _launchGoogleMapsDirections(String spotName) {
    String activeCity = _customCityController.text.trim().isNotEmpty ? _customCityController.text.trim() : selectedCity;
    String destinationQuery = "$spotName, $activeCity, $selectedCountry";
    String mapsUrl = "https://www.google.com/maps/dir/?api=1&destination=${Uri.encodeComponent(destinationQuery)}";
    _launchExternalUrl(mapsUrl);
  }

  void _copyToClipboard(String text) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        backgroundColor: Color(0xFF1E2436),
        behavior: SnackBarBehavior.floating,
        content: Row(
          children: [
            Icon(Icons.check_circle, color: Color(0xFF06B6D4), size: 18),
            SizedBox(width: 8),
            Text("Copied response to clipboard!"),
          ],
        ),
      ),
    );
  }

  void _showFullScreenImage(String imageUrl) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: Colors.black,
          insetPadding: const EdgeInsets.all(8),
          child: Stack(
            alignment: Alignment.topRight,
            children: [
              Center(
                child: InteractiveViewer(
                  panEnabled: true,
                  minScale: 0.5,
                  maxScale: 4.0,
                  child: Image.network(
                    imageUrl,
                    fit: BoxFit.contain,
                    loadingBuilder: (context, child, progress) {
                      if (progress == null) return child;
                      return const Center(child: CircularProgressIndicator(color: Color(0xFF06B6D4)));
                    },
                    errorBuilder: (context, error, stackTrace) => const Center(
                      child: Text("Unable to preview image asset", style: TextStyle(color: Colors.white)),
                    ),
                  ),
                ),
              ),
              Positioned(
                top: 10,
                right: 10,
                left: 10,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    ElevatedButton.icon(
                      onPressed: () => _launchExternalUrl(imageUrl),
                      icon: const Icon(Icons.download_rounded, color: Colors.black, size: 16),
                      label: const Text("DOWNLOAD HD", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 12)),
                      style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF06B6D4)),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close, color: Colors.white, size: 26),
                      style: IconButton.styleFrom(backgroundColor: Colors.black54),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _scrollToBottom(ScrollController controller) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (controller.hasClients) {
        controller.animateTo(
          controller.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _openExploreView(Map<String, dynamic> spot) {
    setState(() {
      exploringSpot = spot;
      isExploring = true;
      exploreChatHistory = [
        {"sender": "ai", "text": "Hello! I am your **Omni Tour Concierge** for **${spot['title']}**.\n\nAsk me about verified hotel bookings, local specialties, transit options, or safety precautions!"}
      ];
    });
    _scrollToBottom(_exploreScrollController);
  }

  void _saveItemToBookmarks(String title, String details) {
    setState(() {
      savedItemsList.add({"title": title, "details": details});
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: const Color(0xFF1E2436),
        behavior: SnackBarBehavior.floating,
        content: Row(
          children: [
            const Icon(Icons.bookmark_added, color: Color(0xFF06B6D4), size: 20),
            const SizedBox(width: 10),
            Expanded(child: Text("Saved '$title' to Bookmarks", overflow: TextOverflow.ellipsis)),
          ],
        ),
      ),
    );
  }

  void _confirmDeleteBookmark(int index) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF131622),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: const BorderSide(color: Color(0xFF1F2436))),
          title: const Text("Delete Saved Item?"),
          content: Text("Are you sure you want to delete '${savedItemsList[index]['title']}' from your bookmarks?"),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text("Keep", style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red[800]),
              onPressed: () {
                setState(() {
                  savedItemsList.removeAt(index);
                });
                Navigator.of(context).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Item removed from bookmarks.")),
                );
              },
              child: const Text("Delete"),
            ),
          ],
        );
      },
    );
  }

  void _openInAppHotelBookingDialog(Map<String, dynamic> hotel) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF131622),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: const BorderSide(color: Color(0xFF1F2436))),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: const Color(0xFF8B5CF6).withOpacity(0.2), borderRadius: BorderRadius.circular(8)),
                child: const Icon(Icons.hotel, color: Color(0xFF8B5CF6), size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  hotel['name']?.toString() ?? "Hotel Booking",
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(hotel['type']?.toString() ?? "Verified Stay", style: const TextStyle(color: Color(0xFF06B6D4), fontSize: 13, fontWeight: FontWeight.w600)),
                    Text(hotel['price']?.toString() ?? "₹2,999/night", style: const TextStyle(color: Color(0xFF10B981), fontSize: 15, fontWeight: FontWeight.bold)),
                  ],
                ),
                const SizedBox(height: 6),
                Text("${hotel['rating']} • ${hotel['reviews'] ?? 'Verified Guest Reviews'}", style: const TextStyle(color: Color(0xFFF59E0B), fontSize: 12)),
                const Divider(color: Color(0xFF1F2436), height: 20),
                Text("📍 ${hotel['address']}", style: const TextStyle(fontSize: 12, color: Colors.white70)),
                const SizedBox(height: 4),
                Text("📞 Front Desk: ${hotel['phone']}", style: const TextStyle(fontSize: 12, color: Color(0xFF06B6D4))),
                const SizedBox(height: 10),
                Text(hotel['description']?.toString() ?? "Prime sanitized accommodation with certified safety standards.", style: const TextStyle(fontSize: 12, color: Colors.grey, height: 1.4)),
                const SizedBox(height: 12),
                const Text("Amenities Included:", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white)),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: ((hotel['amenities'] as List?) ?? ["Free Wi-Fi", "AC", "Breakfast"]).map((a) => Chip(
                    label: Text(a.toString(), style: const TextStyle(fontSize: 10, color: Colors.white)),
                    backgroundColor: const Color(0xFF1A1F30),
                    side: BorderSide.none,
                    padding: EdgeInsets.zero,
                  )).toList(),
                ),
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: const Color(0xFF10B981).withOpacity(0.12), borderRadius: BorderRadius.circular(8), border: Border.all(color: const Color(0xFF10B981).withOpacity(0.3))),
                  child: const Row(
                    children: [
                      Icon(Icons.verified_user, color: Color(0xFF10B981), size: 18),
                      SizedBox(width: 8),
                      Expanded(child: Text("Zero Cancellation Fee • Pay at Check-in Guaranteed", style: TextStyle(fontSize: 11, color: Color(0xFF10B981), fontWeight: FontWeight.w500))),
                    ],
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text("Close", style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.of(context).pop();
                _showBookingConfirmationVoucher(hotel);
              },
              icon: const Icon(Icons.check_circle, color: Colors.black, size: 16),
              label: const Text("CONFIRM BOOKING NOW", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF06B6D4),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ],
        );
      },
    );
  }

  void _showBookingConfirmationVoucher(Map<String, dynamic> hotel) {
    String bookingId = "OMNI-${DateTime.now().millisecondsSinceEpoch.toString().substring(6)}";
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF131622),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: Color(0xFF06B6D4), width: 1.5),
          ),
          title: const Row(
            children: [
              Icon(Icons.verified, color: Color(0xFF06B6D4), size: 24),
              SizedBox(width: 10),
              Text("Booking Confirmed!", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(color: const Color(0xFF1A1F30), borderRadius: BorderRadius.circular(10)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("BOOKING ID: $bookingId", style: const TextStyle(color: Color(0xFF06B6D4), fontWeight: FontWeight.bold, fontSize: 13)),
                    const SizedBox(height: 6),
                    Text("Hotel: ${hotel['name']}", style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 2),
                    Text("Price: ${hotel['price']}", style: const TextStyle(color: Color(0xFF10B981), fontSize: 13, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 2),
                    Text("Address: ${hotel['address']}", style: const TextStyle(color: Colors.grey, fontSize: 11)),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              const Text("✓ Instant confirmation voucher generated and stored securely.", style: TextStyle(color: Colors.white70, fontSize: 12)),
              const Text("✓ Present this reservation ID directly at the check-in desk.", style: TextStyle(color: Colors.white70, fontSize: 12)),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                _saveItemToBookmarks(hotel['name']!.toString(), "Booking ID: $bookingId | Rate: ${hotel['price']}");
                Navigator.of(context).pop();
              },
              child: const Text("Save Voucher to Bookmarks", style: TextStyle(color: Color(0xFF8B5CF6), fontWeight: FontWeight.bold)),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF06B6D4),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: const Text("DONE", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }

  Future<void> _pickAndSendDocument() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'docx', 'xlsx', 'png', 'jpg', 'jpeg', 'txt', 'webp'],
        withData: true,
      );
      if (result == null || result.files.isEmpty) return;
      PlatformFile pickedFile = result.files.first;

      setState(() {
        isAnalyzing = true;
        analysisResult = null;
        detectedDestinationBanner = null;
        selectedFileName = pickedFile.name;
      });

      var request = http.MultipartRequest('POST', Uri.parse('$kBaseApiUrl/api/v1/analyze-document'));
      request.fields['target_language'] = selectedLanguage;

      Uint8List? fileBytes = pickedFile.bytes;
      if (fileBytes != null && fileBytes.isNotEmpty) {
        request.files.add(http.MultipartFile.fromBytes('file', fileBytes, filename: pickedFile.name));
      } else if (pickedFile.path != null) {
        request.files.add(await http.MultipartFile.fromPath('file', pickedFile.path!));
      }

      var streamedResponse = await request.send();
      var response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        var jsonRes = jsonDecode(response.body);
        var data = jsonRes['data'];
        setState(() {
          analysisResult = data['plain_summary'];
          detectedDestinationBanner = data['detected_destination'];
          if (detectedDestinationBanner != null && detectedDestinationBanner!.isNotEmpty) {
            _customCityController.text = detectedDestinationBanner!;
          }
          chatHistory.add({"sender": "ai", "text": "Document **${pickedFile.name}** audited successfully.\n\n*Review the executive summary or ask any specific questions below.*", "download_url": ""});
        });
        _scrollToBottom(_chatScrollController);
      }
    } catch (e) {
      setState(() { analysisResult = "Error uploading file: $e"; });
    } finally {
      setState(() { isAnalyzing = false; });
    }
  }

  Future<void> _pickConverterFile() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'docx', 'xlsx', 'pptx', 'png', 'jpg', 'jpeg', 'txt', 'webp', 'bmp', 'gif'],
        withData: true,
      );
      if (result != null && result.files.isNotEmpty) {
        setState(() {
          converterFile = result.files.first;
          convertedDownloadUrl = null;
          conversionProgress = 0.0;
          conversionStatus = "Ready to convert";
        });
      }
    } catch (_) {}
  }

  Future<void> _startFileConversion() async {
    if (converterFile == null) return;
    setState(() {
      isConverting = true;
      conversionProgress = 0.20;
      conversionStatus = "Converting format to .$targetFormat...";
    });

    try {
      var request = http.MultipartRequest('POST', Uri.parse('$kBaseApiUrl/api/v1/convert-file'));
      request.fields['target_format'] = targetFormat;

      Uint8List? bytes = converterFile!.bytes;
      if (bytes != null && bytes.isNotEmpty) {
        request.files.add(http.MultipartFile.fromBytes('file', bytes, filename: converterFile!.name));
      } else if (converterFile!.path != null) {
        request.files.add(await http.MultipartFile.fromPath('file', converterFile!.path!));
      }

      var streamedResponse = await request.send();
      var response = await http.Response.fromStream(streamedResponse);
      String responseBody = response.body;

      if (response.statusCode == 200) {
        var data = jsonDecode(responseBody);
        setState(() {
          conversionProgress = 1.00;
          conversionStatus = "Conversion Complete! (100%)";
          convertedDownloadUrl = data['download_url'];
        });
      } else {
        setState(() { conversionStatus = "Conversion failed on server."; });
      }
    } catch (e) {
      setState(() { conversionStatus = "Error: $e"; });
    } finally {
      setState(() { isConverting = false; });
    }
  }

  Future<void> _pickChatFile() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'docx', 'xlsx', 'png', 'jpg', 'jpeg', 'txt', 'webp'],
        withData: true,
      );
      if (result != null && result.files.isNotEmpty) {
        setState(() {
          chatAttachedFile = result.files.first;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFF1E2436),
            content: Text("📎 Attached: ${result.files.first.name}"),
          ),
        );
      }
    } catch (_) {}
  }

  Future<void> _askQuestion([String? presetQuery]) async {
    String query = presetQuery ?? _questionController.text.trim();
    if (query.isEmpty && chatAttachedFile == null) return;

    final isImagePrompt = query.toLowerCase().contains("image") ||
        query.toLowerCase().contains("logo") ||
        query.toLowerCase().contains("design") ||
        query.toLowerCase().contains("artwork") ||
        query.toLowerCase().contains("generate");

    setState(() {
      isAsking = true;
      if (isImagePrompt) {
        isGeneratingImage = true;
        imageGenProgress = 0.10;
      }
      chatHistory.add({
        "sender": "user",
        "text": query.isEmpty ? "Uploaded file: ${chatAttachedFile?.name}" : query,
        "image_url": null,
        "download_url": ""
      });
      _questionController.clear();
    });
    _scrollToBottom(_chatScrollController);

    Timer? progressTimer;
    if (isImagePrompt) {
      progressTimer = Timer.periodic(const Duration(milliseconds: 600), (timer) {
        if (mounted && isGeneratingImage) {
          setState(() {
            if (imageGenProgress < 0.90) {
              imageGenProgress += 0.20;
            }
          });
        }
      });
    }

    try {
      var request = http.MultipartRequest('POST', Uri.parse('$kBaseApiUrl/api/v1/ask-question'));
      request.fields['question'] = query.isEmpty ? "Please review this attached file." : query;
      request.fields['target_language'] = selectedLanguage;
      request.fields['export_format'] = selectedExportFormat;

      if (chatAttachedFile != null) {
        Uint8List? bytes = chatAttachedFile!.bytes;
        if (bytes != null && bytes.isNotEmpty) {
          request.files.add(http.MultipartFile.fromBytes('file', bytes, filename: chatAttachedFile!.name));
        } else if (chatAttachedFile!.path != null) {
          request.files.add(await http.MultipartFile.fromPath('file', chatAttachedFile!.path!));
        }
      }

      var streamedResponse = await request.send();
      var response = await http.Response.fromStream(streamedResponse);
      String responseBody = response.body;

      if (response.statusCode == 200) {
        var data = jsonDecode(responseBody);
        setState(() {
          imageGenProgress = 1.0;
          chatHistory.add({
            "sender": "ai", 
            "text": data['answer'] ?? "Response processed.",
            "image_url": data['image_url'],
            "audio_url": data['audio_url'],
            "download_url": data['download_url'] ?? ""
          });
          chatAttachedFile = null;
        });
      } else {
        setState(() {
          chatHistory.add({
            "sender": "ai",
            "text": "Omni TouristOS engine is experiencing high traffic. Please tap send again in a moment.",
            "image_url": null,
            "download_url": ""
          });
        });
      }
    } catch (e) {
      setState(() {
        chatHistory.add({"sender": "ai", "text": "Connection Error: $e", "image_url": null, "download_url": ""});
      });
    } finally {
      progressTimer?.cancel();
      setState(() {
        isAsking = false;
        isGeneratingImage = false;
        imageGenProgress = 0.0;
      });
      _scrollToBottom(_chatScrollController);
    }
  }

  Future<void> _getTouristRecommendations() async {
    String destinationToSearch = _customCityController.text.trim().isNotEmpty
        ? _customCityController.text.trim()
        : "$selectedCity, $selectedState, $selectedCountry";

    setState(() {
      isPlanning = true;
      structuredDestinationData = null;
    });

    try {
      var response = await http.post(
        Uri.parse('$kBaseApiUrl/api/v1/touristos-recommend'),
        body: {
          'time_available': selectedTime,
          'location': destinationToSearch,
          'group_type': selectedGroupType,
          'dietary_preference': selectedDiet,
          'target_language': selectedLanguage,
        },
      );

      if (response.statusCode == 200) {
        var res = jsonDecode(response.body);
        setState(() {
          structuredDestinationData = res['data'];
          _touristPage = 1;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error fetching guide: $e")));
      }
    } finally {
      setState(() { isPlanning = false; });
    }
  }

  Future<void> _askExploreChat() async {
    String query = _exploreChatController.text.trim();
    if (query.isEmpty || exploringSpot == null) return;

    setState(() {
      isExploreAsking = true;
      exploreChatHistory.add({"sender": "user", "text": query});
      _exploreChatController.clear();
    });
    _scrollToBottom(_exploreScrollController);

    try {
      var response = await http.post(
        Uri.parse('$kBaseApiUrl/api/v1/explore-chat'),
        body: {
          'spot_name': exploringSpot!['title']!.toString(),
          'question': query,
          'group_type': selectedGroupType,
          'dietary_preference': selectedDiet,
          'target_language': selectedLanguage,
        },
      );

      if (response.statusCode == 200) {
        var data = jsonDecode(response.body);
        setState(() {
          exploreChatHistory.add({
            "sender": "ai", 
            "text": data['answer'],
            "audio_url": data['audio_url']
          });
        });
      }
    } catch (e) {
      setState(() { exploreChatHistory.add({"sender": "ai", "text": "Connection Error: $e"}); });
    } finally {
      setState(() { isExploreAsking = false; });
      _scrollToBottom(_exploreScrollController);
    }
  }

  void _showExportFormatDialog() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF131622),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("Export Chat Response Format", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                const SizedBox(height: 6),
                const Text("Select how you want Omni TouristOS to generate export files:", style: TextStyle(color: Colors.grey, fontSize: 12)),
                const SizedBox(height: 16),
                _buildExportOptionTile("Chat Only (No Export)", "none", Icons.chat_bubble_outline),
                _buildExportOptionTile("Microsoft Word Document (.docx)", "docx", Icons.description_outlined),
                _buildExportOptionTile("Excel Spreadsheet (.xlsx)", "xlsx", Icons.table_chart_outlined),
                _buildExportOptionTile("PowerPoint Presentation (.pptx)", "pptx", Icons.slideshow_outlined),
                _buildExportOptionTile("Plain Text File (.txt)", "txt", Icons.text_snippet_outlined),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildExportOptionTile(String label, String value, IconData icon) {
    final bool isSelected = selectedExportFormat == value;
    return ListTile(
      leading: Icon(icon, color: isSelected ? const Color(0xFF06B6D4) : Colors.grey),
      title: Text(label, style: TextStyle(color: isSelected ? Colors.white : Colors.grey[300], fontWeight: isSelected ? FontWeight.bold : FontWeight.normal, fontSize: 13)),
      trailing: isSelected ? const Icon(Icons.check_circle, color: Color(0xFF06B6D4), size: 18) : null,
      onTap: () {
        setState(() => selectedExportFormat = value);
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Export format set to: ${label.split('(')[0]}")),
        );
      },
    );
  }

  void _showLegalPolicyDialog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF131622),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.85,
          minChildSize: 0.5,
          maxChildSize: 0.95,
          expand: false,
          builder: (context, scrollController) {
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(color: Colors.grey[600], borderRadius: BorderRadius.circular(2)),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(color: const Color(0xFF8B5CF6).withOpacity(0.2), borderRadius: BorderRadius.circular(8)),
                        child: const Icon(Icons.privacy_tip_outlined, color: Color(0xFF06B6D4), size: 20),
                      ),
                      const SizedBox(width: 10),
                      const Text("Privacy Policy & Terms", style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Colors.white)),
                    ],
                  ),
                  const Divider(color: Color(0xFF1F2436), height: 24),
                  Expanded(
                    child: ListView(
                      controller: scrollController,
                      children: const [
                        Text("Publisher: Velnova Enterprises", style: TextStyle(color: Color(0xFF8B5CF6), fontWeight: FontWeight.bold, fontSize: 13)),
                        SizedBox(height: 8),
                        Text(
                          "Welcome to Omni TouristOS. We are committed to transparency and privacy. Please review how our system manages your data:",
                          style: TextStyle(fontSize: 12.5, color: Colors.white70, height: 1.45),
                        ),
                        SizedBox(height: 14),
                        Text("1. Document Audits & Storage", style: TextStyle(color: Color(0xFF06B6D4), fontWeight: FontWeight.bold, fontSize: 13)),
                        SizedBox(height: 4),
                        Text(
                          "Files uploaded for audit (PDFs, images, tickets, contracts) are processed securely over encrypted channels. We do not sell or permanently harvest your private documents.",
                          style: TextStyle(fontSize: 12, color: Colors.grey, height: 1.4),
                        ),
                        SizedBox(height: 12),
                        Text("2. Microphone & Speech Recognition", style: TextStyle(color: Color(0xFF06B6D4), fontWeight: FontWeight.bold, fontSize: 13)),
                        SizedBox(height: 4),
                        Text(
                          "Voice input streams audio in real time solely to transcribe your speech into text prompts in your selected language. Voice recordings are never stored on cloud servers.",
                          style: TextStyle(fontSize: 12, color: Colors.grey, height: 1.4),
                        ),
                        SizedBox(height: 12),
                        Text("3. GPS Location & Emergency Shield", style: TextStyle(color: Color(0xFF06B6D4), fontWeight: FontWeight.bold, fontSize: 13)),
                        SizedBox(height: 4),
                        Text(
                          "Live GPS coordinates are utilized solely on-device to assemble verified local stays, nearby attractions, and immediate emergency contact routes. Your movement history is not tracked.",
                          style: TextStyle(fontSize: 12, color: Colors.grey, height: 1.4),
                        ),
                        SizedBox(height: 12),
                        Text("4. Terms of Service & Advisories", style: TextStyle(color: Color(0xFF06B6D4), fontWeight: FontWeight.bold, fontSize: 13)),
                        SizedBox(height: 4),
                        Text(
                          "Omni TouristOS provides AI-driven logistical suggestions. Hotel reservation vouchers (OMNI-XXXXXX) are generated for direct verification at venue check-in desks.",
                          style: TextStyle(fontSize: 12, color: Colors.grey, height: 1.4),
                        ),
                        SizedBox(height: 20),
                      ],
                    ),
                  ),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF06B6D4),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      child: const Text("I UNDERSTAND & AGREE", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 12)),
                    ),
                  )
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool isMobile = MediaQuery.of(context).size.width < 800;

    return Scaffold(
      resizeToAvoidBottomInset: true,
      appBar: isMobile
          ? AppBar(
              backgroundColor: const Color(0xFF0E111A),
              elevation: 0,
              title: Text(
                _getHeaderTitle(),
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
              ),
              actions: [
                DropdownButton<String>(
                  value: selectedLanguage,
                  dropdownColor: const Color(0xFF131622),
                  underline: const SizedBox(),
                  icon: const Icon(Icons.language, size: 18, color: Color(0xFF06B6D4)),
                  items: languages.map((l) => DropdownMenuItem(value: l, child: Text(l, style: const TextStyle(fontSize: 12, color: Colors.white)))).toList(),
                  onChanged: (val) {
                    if (val != null) {
                      setState(() => selectedLanguage = val);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text("Language & Voice Engine updated to $val")),
                      );
                    }
                  },
                ),
                const SizedBox(width: 8),
              ],
            )
          : null,
      drawer: isMobile ? Drawer(child: SafeArea(child: _buildSidebarContent(isDrawer: true))) : null,
      body: SafeArea(
        child: isMobile
            ? _buildMainContent(isMobile: true)
            : Row(
                children: [
                  SizedBox(
                    width: 260,
                    child: _buildSidebarContent(isDrawer: false),
                  ),
                  Expanded(
                    child: Column(
                      children: [
                        _buildDesktopHeader(),
                        Expanded(
                          child: _buildMainContent(isMobile: false),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildDesktopHeader() {
    return Container(
      height: 65,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      decoration: const BoxDecoration(
        color: Color(0xFF0E111A),
        border: Border(bottom: BorderSide(color: Color(0xFF1F2436))),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Text(_getHeaderTitle(), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
              const SizedBox(width: 14),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF8B5CF6).withOpacity(0.15),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: const Color(0xFF8B5CF6).withOpacity(0.3)),
                ),
                child: const Text("Omni TouristOS Core • Velnova Enterprises", style: TextStyle(fontSize: 11, color: Color(0xFF06B6D4), fontWeight: FontWeight.w500)),
              )
            ],
          ),
          Row(
            children: [
              const Icon(Icons.language, size: 18, color: Colors.grey),
              const SizedBox(width: 8),
              DropdownButton<String>(
                value: selectedLanguage,
                dropdownColor: const Color(0xFF131622),
                underline: const SizedBox(),
                items: languages.map((l) => DropdownMenuItem(value: l, child: Text(l, style: const TextStyle(fontSize: 13, color: Colors.white)))).toList(),
                onChanged: (val) {
                  if (val != null) {
                    setState(() => selectedLanguage = val);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text("Language & Voice Engine updated to $val")),
                    );
                  }
                },
              ),
              const SizedBox(width: 15),
              IconButton(onPressed: () {}, icon: const Icon(Icons.notifications_none_rounded, color: Colors.grey, size: 20)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSidebarContent({required bool isDrawer}) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF0B0D14),
        border: Border(right: BorderSide(color: Color(0xFF1F2436), width: 1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(22.0),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Image.asset(
                    'assets/logo.png',
                    width: 44,
                    height: 44,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(colors: [Color(0xFF8B5CF6), Color(0xFF06B6D4)]),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.explore_rounded, color: Colors.white, size: 24),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("Omni TouristOS", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white)),
                    Text("Velnova Enterprises", style: TextStyle(color: Color(0xFF06B6D4), fontSize: 10, fontWeight: FontWeight.bold)),
                  ],
                ),
              ],
            ),
          ),
          const Divider(color: Color(0xFF1F2436), height: 1),
          const SizedBox(height: 10),
          _buildSidebarNav(0, Icons.grid_view_rounded, "Home Dashboard", isDrawer),
          _buildSidebarNav(1, Icons.description_rounded, "Omni PaperPilot", isDrawer),
          _buildSidebarNav(2, Icons.explore_rounded, "TouristOS Guide", isDrawer),
          _buildSidebarNav(3, Icons.bookmark_rounded, "Saved Items", isDrawer),
          _buildSidebarNav(4, Icons.settings_rounded, "Settings & About", isDrawer),
          const Spacer(),
          Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFF131622),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFF1F2436)),
            ),
            child: Row(
              children: [
                const CircleAvatar(
                  radius: 18,
                  backgroundColor: Color(0xFF8B5CF6),
                  child: Text("V", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
                const SizedBox(width: 10),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("Velnova Enterprise", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.white)),
                      Text("TouristOS Cloud Engine", style: TextStyle(color: Color(0xFF06B6D4), fontSize: 10)),
                    ],
                  ),
                ),
                Icon(Icons.verified, size: 16, color: Colors.amber[400]),
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _buildSidebarNav(int index, IconData icon, String title, bool isDrawer) {
    bool isSelected = _currentNavIndex == index;
    return InkWell(
      onTap: () {
        setState(() {
          _currentNavIndex = index;
          isExploring = false;
        });
        if (isDrawer) Navigator.of(context).pop();
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF8B5CF6).withOpacity(0.18) : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          border: isSelected ? Border.all(color: const Color(0xFF8B5CF6).withOpacity(0.4)) : null,
        ),
        child: Row(
          children: [
            Icon(icon, size: 18, color: isSelected ? const Color(0xFF06B6D4) : Colors.grey),
            const SizedBox(width: 12),
            Text(title, style: TextStyle(color: isSelected ? Colors.white : Colors.grey[400], fontWeight: isSelected ? FontWeight.bold : FontWeight.normal, fontSize: 13)),
          ],
        ),
      ),
    );
  }

  String _getHeaderTitle() {
    if (isExploring && exploringSpot != null) return "Explore — ${exploringSpot!['title']}";
    if (_currentNavIndex == 0) return "Home Dashboard";
    if (_currentNavIndex == 1) return "Omni PaperPilot";
    if (_currentNavIndex == 2) return "TouristOS Guide";
    if (_currentNavIndex == 3) return "Saved Items & Bookmarks";
    return "Settings & About";
  }

  Widget _buildMainContent({required bool isMobile}) {
    return Container(
      color: const Color(0xFF090A10),
      child: _currentNavIndex == 1 && _paperPilotTab == 1
          ? _buildOmniPaperPilotStudio(isMobile: isMobile)
          : ListView(
              padding: EdgeInsets.all(isMobile ? 16.0 : 24.0),
              children: [
                if (_currentNavIndex == 0) _buildHomeDashboard(isMobile: isMobile),
                if (_currentNavIndex == 1 && _paperPilotTab != 1) _buildPaperPilotScreen(isMobile: isMobile),
                if (_currentNavIndex == 2) _buildTouristOSScreen(isMobile: isMobile),
                if (_currentNavIndex == 3) _buildSavedItemsScreen(),
                if (_currentNavIndex == 4) _buildSettingsScreen(),
              ],
            ),
    );
  }

  // ================= 1. HOME DASHBOARD =================
  Widget _buildHomeDashboard({required bool isMobile}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("Welcome back, Leslie! 👋", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white)),
        const SizedBox(height: 6),
        const Text("Select a TouristOS module to audit documents, create visuals, or navigate smart journeys.", style: TextStyle(color: Colors.grey, fontSize: 13)),
        const SizedBox(height: 25),

        if (isMobile) ...[
          _buildActionHeroCard("Omni PaperPilot", "Document Intelligence, Visual Audit, AI Studio & Universal File Converter.", Icons.description_rounded, const Color(0xFF8B5CF6), () => setState(() => _currentNavIndex = 1)),
          const SizedBox(height: 14),
          _buildActionHeroCard("TouristOS Guide", "Travel Companion, Verified Stays, Destination Dossier & Emergency Contacts.", Icons.explore_rounded, const Color(0xFF06B6D4), () => setState(() => _currentNavIndex = 2)),
        ] else
          Row(
            children: [
              Expanded(child: _buildActionHeroCard("Omni PaperPilot", "Document Intelligence, Visual Audit, AI Studio & Universal File Converter.", Icons.description_rounded, const Color(0xFF8B5CF6), () => setState(() => _currentNavIndex = 1))),
              const SizedBox(width: 20),
              Expanded(child: _buildActionHeroCard("TouristOS Guide", "Travel Companion, Verified Stays, Destination Dossier & Emergency Contacts.", Icons.explore_rounded, const Color(0xFF06B6D4), () => setState(() => _currentNavIndex = 2))),
            ],
          ),
        const SizedBox(height: 30),

        const Text("Core Intelligence Capabilities", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
        const SizedBox(height: 14),
        if (isMobile) ...[
          _buildFeatureBadge(Icons.auto_awesome, "Omni AI Studio & Voice", "Clean white canvas, multi-lingual speech-to-text & step image generator", isMobile: true),
          const SizedBox(height: 10),
          _buildFeatureBadge(Icons.transform_rounded, "Universal Converter", "Convert Images, PDF, Word, Excel, PPTX, and TXT", isMobile: true),
          const SizedBox(height: 10),
          _buildFeatureBadge(Icons.hotel_class_outlined, "Verified Accommodations", "12+ live stays with in-app vouchers and direct routing", isMobile: true),
        ] else
          Row(
            children: [
              _buildFeatureBadge(Icons.auto_awesome, "Omni AI Studio & Voice", "Clean white canvas, multi-lingual speech-to-text & step image generator"),
              const SizedBox(width: 14),
              _buildFeatureBadge(Icons.transform_rounded, "Universal Converter", "Convert Images, PDF, Word, Excel, PPTX, and TXT"),
              const SizedBox(width: 14),
              _buildFeatureBadge(Icons.hotel_class_outlined, "Verified Accommodations", "12+ live stays with in-app vouchers and direct routing"),
            ],
          )
      ],
    );
  }

  Widget _buildActionHeroCard(String title, String subtitle, IconData icon, Color accent, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          color: const Color(0xFF131622),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFF1F2436)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: accent.withOpacity(0.18), borderRadius: BorderRadius.circular(12)),
              child: Icon(icon, size: 28, color: accent),
            ),
            const SizedBox(height: 16),
            Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
            const SizedBox(height: 6),
            Text(subtitle, style: const TextStyle(color: Colors.grey, fontSize: 12, height: 1.4)),
            const SizedBox(height: 16),
            Row(
              children: [
                Text("Open $title", style: TextStyle(color: accent, fontWeight: FontWeight.bold, fontSize: 13)),
                const SizedBox(width: 6),
                Icon(Icons.arrow_forward_rounded, size: 16, color: accent),
              ],
            )
          ],
        ),
      ),
    );
  }

  Widget _buildFeatureBadge(IconData icon, String title, String desc, {bool isMobile = false}) {
    Widget card = Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF0F121C),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF1F2436)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: const Color(0xFF06B6D4)),
          const SizedBox(height: 10),
          Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white)),
          const SizedBox(height: 4),
          Text(desc, style: const TextStyle(fontSize: 11, color: Colors.grey, height: 1.3)),
        ],
      ),
    );

    return isMobile ? card : Expanded(child: card);
  }

  // ================= 2. OMNI PAPERPILOT =================
  Widget _buildPaperPilotScreen({required bool isMobile}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _buildPillTab(0, "Document Auditor", _paperPilotTab == 0, () => setState(() => _paperPilotTab = 0)),
              const SizedBox(width: 10),
              _buildPillTab(1, "Live Omni AI Studio", _paperPilotTab == 1, () => setState(() => _paperPilotTab = 1)),
              const SizedBox(width: 10),
              _buildPillTab(2, "Universal File Converter", _paperPilotTab == 2, () => setState(() => _paperPilotTab = 2)),
            ],
          ),
        ),
        const SizedBox(height: 20),

        if (_paperPilotTab == 0) ...[
          Container(
            padding: EdgeInsets.all(isMobile ? 20 : 36),
            decoration: BoxDecoration(
              color: const Color(0xFF131622),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFF1F2436)),
            ),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(color: const Color(0xFF8B5CF6).withOpacity(0.18), shape: BoxShape.circle),
                  child: const Icon(Icons.cloud_upload_outlined, size: 40, color: Color(0xFF8B5CF6)),
                ),
                const SizedBox(height: 16),
                const Text("Upload any Image, Ticket, Invoice, or PDF for Multimodal AI Audit", textAlign: TextAlign.center, style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white)),
                const SizedBox(height: 6),
                const Text("Supported formats: PNG, JPG, JPEG, WEBP, PDF, DOCX (Max 50MB)", textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: Colors.grey)),
                const SizedBox(height: 20),
                ElevatedButton.icon(
                  onPressed: isAnalyzing ? null : _pickAndSendDocument,
                  icon: const Icon(Icons.folder_open_rounded, color: Colors.black, size: 18),
                  label: Text(isAnalyzing ? "Auditing Document..." : "Browse Document / Image", style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF06B6D4),
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
                if (selectedFileName != "No file chosen") ...[
                  const SizedBox(height: 12),
                  Text("Selected File: $selectedFileName", textAlign: TextAlign.center, style: const TextStyle(fontSize: 12, color: Color(0xFF06B6D4), fontWeight: FontWeight.w500)),
                ],
              ],
            ),
          ),
          const SizedBox(height: 20),

          if (detectedDestinationBanner != null)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [Color(0xFF1E1A38), Color(0xFF0F172A)]),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFF06B6D4)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.flight_takeoff_rounded, color: Color(0xFF06B6D4), size: 24),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text("✈️ Trip to $detectedDestinationBanner Detected!", style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF06B6D4), fontSize: 14)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text("TouristOS has assembled verified stays, attractions, and emergency details for $detectedDestinationBanner.", style: const TextStyle(fontSize: 12, color: Colors.white70)),
                  const SizedBox(height: 10),
                  ElevatedButton(
                    onPressed: () {
                      setState(() {
                        _customCityController.text = detectedDestinationBanner!;
                        _currentNavIndex = 2;
                      });
                      _getTouristRecommendations();
                    },
                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF06B6D4), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                    child: Text("Explore $detectedDestinationBanner", style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
                  )
                ],
              ),
            ),
          const SizedBox(height: 20),

          if (analysisResult != null)
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFF131622),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFF1F2436)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.verified_outlined, color: Color(0xFFF59E0B), size: 22),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text("Secure Document Audit & Visual Breakdown", style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFFF59E0B))),
                      ),
                    ],
                  ),
                  const Divider(color: Color(0xFF1F2436), height: 24),
                  MarkdownBody(
                    data: analysisResult!,
                    styleSheet: MarkdownStyleSheet(
                      p: const TextStyle(color: Colors.white70, fontSize: 13, height: 1.5),
                      h3: const TextStyle(color: Color(0xFF06B6D4), fontSize: 15, fontWeight: FontWeight.bold),
                      listBullet: const TextStyle(color: Color(0xFF8B5CF6)),
                    ),
                  ),
                ],
              ),
            ),
        ]

        else if (_paperPilotTab == 2) ...[
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFF131622),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFF1F2436)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.transform_rounded, color: Color(0xFF06B6D4), size: 24),
                    SizedBox(width: 12),
                    Expanded(child: Text("Universal File Converter Studio", style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Colors.white))),
                  ],
                ),
                const SizedBox(height: 6),
                const Text("Convert between all Image, Document, Spreadsheet, Presentation, and Text formats seamlessly.", style: TextStyle(color: Colors.grey, fontSize: 12)),
                const Divider(color: Color(0xFF1F2436), height: 26),

                ElevatedButton.icon(
                  onPressed: _pickConverterFile,
                  icon: const Icon(Icons.upload_file_rounded, color: Colors.black, size: 18),
                  label: const Text("SELECT FILE TO CONVERT", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 12)),
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF06B6D4), padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14)),
                ),
                if (converterFile != null) ...[
                  const SizedBox(height: 10),
                  Text("📄 Loaded: ${converterFile!.name}", style: const TextStyle(color: Color(0xFF10B981), fontWeight: FontWeight.bold, fontSize: 12), overflow: TextOverflow.ellipsis),
                ],
                const SizedBox(height: 20),

                if (converterFile != null) ...[
                  Wrap(
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 12,
                    children: [
                      const Text("Target Format:", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.white)),
                      DropdownButton<String>(
                        value: targetFormat,
                        dropdownColor: const Color(0xFF1A1F30),
                        items: const [
                          DropdownMenuItem(value: "pdf", child: Text("PDF Document (.pdf)", style: TextStyle(color: Colors.white, fontSize: 13))),
                          DropdownMenuItem(value: "docx", child: Text("Word Document (.docx)", style: TextStyle(color: Colors.white, fontSize: 13))),
                          DropdownMenuItem(value: "xlsx", child: Text("Excel Spreadsheet (.xlsx)", style: TextStyle(color: Colors.white, fontSize: 13))),
                          DropdownMenuItem(value: "pptx", child: Text("PowerPoint Presentation (.pptx)", style: TextStyle(color: Colors.white, fontSize: 13))),
                          DropdownMenuItem(value: "png", child: Text("PNG Image (.png)", style: TextStyle(color: Colors.white, fontSize: 13))),
                          DropdownMenuItem(value: "jpg", child: Text("JPEG Image (.jpg)", style: TextStyle(color: Colors.white, fontSize: 13))),
                          DropdownMenuItem(value: "webp", child: Text("WebP Image (.webp)", style: TextStyle(color: Colors.white, fontSize: 13))),
                          DropdownMenuItem(value: "txt", child: Text("Plain Text (.txt)", style: TextStyle(color: Colors.white, fontSize: 13))),
                        ],
                        onChanged: (val) { if (val != null) setState(() => targetFormat = val); },
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: isConverting ? null : _startFileConversion,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF8B5CF6),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      child: Text(isConverting ? "Converting Format..." : "START CONVERSION TO .$targetFormat", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                    ),
                  ),
                  const SizedBox(height: 20),

                  if (isConverting || conversionProgress > 0) ...[
                    Text("Status: $conversionStatus", style: const TextStyle(color: Color(0xFF06B6D4), fontWeight: FontWeight.bold, fontSize: 13)),
                    const SizedBox(height: 10),
                    LinearProgressIndicator(
                      value: conversionProgress,
                      backgroundColor: const Color(0xFF090A10),
                      color: const Color(0xFF06B6D4),
                      minHeight: 8,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ],

                  if (convertedDownloadUrl != null) ...[
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () => _launchExternalUrl(convertedDownloadUrl!),
                        icon: const Icon(Icons.download_rounded, color: Colors.black, size: 20),
                        label: const Text("DOWNLOAD CONVERTED FILE NOW", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 13)),
                        style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF06B6D4), padding: const EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                      ),
                    ),
                  ]
                ]
              ],
            ),
          )
        ]
      ],
    );
  }

  // ================= OMNI AI WHITE CANVAS STUDIO =================
  Widget _buildOmniPaperPilotStudio({required bool isMobile}) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          color: const Color(0xFF0E111A),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildPillTab(0, "Document Auditor", false, () => setState(() => _paperPilotTab = 0)),
                const SizedBox(width: 10),
                _buildPillTab(1, "Live Omni AI Studio", true, () => setState(() => _paperPilotTab = 1)),
                const SizedBox(width: 10),
                _buildPillTab(2, "Universal File Converter", false, () => setState(() => _paperPilotTab = 2)),
              ],
            ),
          ),
        ),
        Expanded(
          child: Container(
            color: const Color(0xFFFFFFFF),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: const BoxDecoration(
                    color: Color(0xFFF8F9FA),
                    border: Border(bottom: BorderSide(color: Color(0xFFE5E7EB))),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(colors: [Color(0xFF4285F4), Color(0xFF9B72CB), Color(0xFFD96570), Color(0xFFF2A900)]),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(Icons.auto_awesome, color: Colors.white, size: 16),
                          ),
                          const SizedBox(width: 10),
                          const Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text("Omni AI Studio Enterprise", style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF1F1F20))),
                              Text("Document Q&A, Visual Studio & Voice Assistant", style: TextStyle(fontSize: 10, color: Color(0xFF5F6368))),
                            ],
                          ),
                        ],
                      ),
                      ElevatedButton.icon(
                        onPressed: _showExportFormatDialog,
                        icon: const Icon(Icons.file_download_outlined, size: 14, color: Color(0xFF1967D2)),
                        label: Text(
                          selectedExportFormat == "none" ? "Export" : selectedExportFormat.toUpperCase(),
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF1967D2)),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFE8F0FE),
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: chatHistory.isEmpty
                      ? Center(
                          child: SingleChildScrollView(
                            padding: const EdgeInsets.all(24),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(16),
                                  decoration: const BoxDecoration(
                                    color: Color(0xFFF0F4F9),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(Icons.auto_awesome, size: 40, color: Color(0xFF4285F4)),
                                ),
                                const SizedBox(height: 16),
                                const Text("What would you like Omni AI to create or audit?", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1F1F20))),
                                const SizedBox(height: 6),
                                const Text("Type questions, tap the microphone to speak, or ask to generate logos and 3D visual concepts.", textAlign: TextAlign.center, style: TextStyle(fontSize: 13, color: Color(0xFF5F6368))),
                              ],
                            ),
                          ),
                        )
                      : ListView.builder(
                          controller: _chatScrollController,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
                          itemCount: chatHistory.length + (isAsking ? 1 : 0),
                          itemBuilder: (context, index) {
                            if (index == chatHistory.length && isAsking) {
                              return OmniThinkingBubble(
                                isGeneratingImage: isGeneratingImage,
                                imageGenProgress: imageGenProgress,
                              );
                            }
                            final msg = chatHistory[index];
                            final isUser = msg['sender'] == 'user';
                            return _buildOmniMessageTile(msg, isUser);
                          },
                        ),
                ),
                Container(
                  height: 38,
                  margin: const EdgeInsets.only(bottom: 6),
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    children: [
                      _buildOmniChip("✨ Generate a modern travel logo", () => _askQuestion("Generate a modern, sleek minimalist vector logo for my travel and safety tech company called Omni Super-App")),
                      _buildOmniChip("🛡️ Audit for hidden penalties & traps", () => _askQuestion("Check this document for hidden penalty clauses, cancellation fees, or traps.")),
                      _buildOmniChip("🎨 3D concept artwork hologram", () => _askQuestion("Generate a 3D isometric futuristic concept art of an AI travel assistant hologram")),
                      _buildOmniChip("📝 Summarize key takeaways in 3 points", () => _askQuestion("Summarize the most critical takeaways in 3 bullet points.")),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: const BoxDecoration(
                    color: Color(0xFFFFFFFF),
                    border: Border(top: BorderSide(color: Color(0xFFE5E7EB))),
                  ),
                  child: Row(
                    children: [
                      IconButton(
                        onPressed: _pickChatFile,
                        icon: const Icon(Icons.add_circle_outline_rounded, color: Color(0xFF4285F4), size: 26),
                        tooltip: "Attach Document / Image",
                      ),
                      if (chatAttachedFile != null)
                        Container(
                          margin: const EdgeInsets.only(right: 8),
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(color: const Color(0xFFE8F0FE), borderRadius: BorderRadius.circular(16)),
                          child: Row(
                            children: [
                              Text(chatAttachedFile!.name, style: const TextStyle(fontSize: 11, color: Color(0xFF1967D2), fontWeight: FontWeight.bold)),
                              const SizedBox(width: 4),
                              GestureDetector(
                                onTap: () => setState(() => chatAttachedFile = null),
                                child: const Icon(Icons.close, size: 14, color: Color(0xFF1967D2)),
                              ),
                            ],
                          ),
                        ),
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF0F4F9),
                            borderRadius: BorderRadius.circular(28),
                          ),
                          child: TextField(
                            controller: _questionController,
                            onSubmitted: (_) => _askQuestion(),
                            style: const TextStyle(fontSize: 14, color: Color(0xFF1F1F20)),
                            maxLines: 4,
                            minLines: 1,
                            decoration: const InputDecoration(
                              hintText: "Ask Omni AI or Generate any image",
                              hintStyle: TextStyle(color: Color(0xFF747775), fontSize: 13.5),
                              border: InputBorder.none,
                              contentPadding: EdgeInsets.symmetric(vertical: 12),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      IconButton(
                        onPressed: () => _toggleVoiceListening(_questionController),
                        icon: Icon(
                          _isListening ? Icons.mic : Icons.mic_none_rounded,
                          color: _isListening ? Colors.redAccent : const Color(0xFF4285F4),
                          size: 24,
                        ),
                        tooltip: "Voice Speak ($selectedLanguage)",
                      ),
                      Container(
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(colors: [Color(0xFF4285F4), Color(0xFF9B72CB)]),
                        ),
                        child: IconButton(
                          onPressed: isAsking ? null : () => _askQuestion(),
                          icon: isAsking
                              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                              : const Icon(Icons.send_rounded, color: Colors.white, size: 20),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildOmniMessageTile(Map<String, dynamic> msg, bool isUser) {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      child: isUser
          ? Row(
              mainAxisAlignment: MainAxisAlignment.end,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Flexible(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF0F4F9),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: const Color(0xFFE1E3E1)),
                    ),
                    child: Text(
                      msg['text'],
                      style: const TextStyle(fontSize: 15, color: Color(0xFF1F1F20), height: 1.4),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                const CircleAvatar(
                  radius: 16,
                  backgroundColor: Color(0xFF4285F4),
                  child: Text("V", style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
                ),
              ],
            )
          : Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(colors: [Color(0xFF4285F4), Color(0xFF9B72CB), Color(0xFFD96570), Color(0xFFF2A900)]),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.auto_awesome, color: Colors.white, size: 16),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      MarkdownBody(
                        data: msg['text'],
                        selectable: true,
                        styleSheet: MarkdownStyleSheet(
                          p: const TextStyle(fontSize: 15.5, color: Color(0xFF1F1F20), height: 1.55, fontWeight: FontWeight.w400),
                          h1: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF1F1F20)),
                          h2: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1F1F20)),
                          h3: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF1967D2)),
                          strong: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1F1F20)),
                          listBullet: const TextStyle(color: Color(0xFF1967D2), fontSize: 16),
                          tableBorder: TableBorder.all(color: const Color(0xFFE0E2EC), width: 1),
                          tableHead: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1F1F20)),
                          tableBody: const TextStyle(color: Color(0xFF1F1F20)),
                          blockquoteDecoration: BoxDecoration(
                            color: const Color(0xFFF0F4F9),
                            borderRadius: BorderRadius.circular(8),
                            border: const Border(left: BorderSide(color: Color(0xFF4285F4), width: 4)),
                          ),
                        ),
                      ),
                      if (msg['image_url'] != null && msg['image_url'].toString().isNotEmpty) ...[
                        const SizedBox(height: 14),
                        GestureDetector(
                          onTap: () => _showFullScreenImage(msg['image_url']),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(16),
                            child: Stack(
                              alignment: Alignment.bottomRight,
                              children: [
                                Image.network(
                                  msg['image_url'],
                                  height: 280,
                                  width: double.infinity,
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) => Container(
                                    height: 180,
                                    color: const Color(0xFFF0F4F9),
                                    child: const Center(child: Icon(Icons.image_outlined, size: 40, color: Color(0xFF4285F4))),
                                  ),
                                ),
                                Container(
                                  margin: const EdgeInsets.all(10),
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                  decoration: BoxDecoration(color: Colors.black87, borderRadius: BorderRadius.circular(8)),
                                  child: const Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.zoom_in_rounded, color: Colors.white, size: 14),
                                      SizedBox(width: 4),
                                      Text("Tap to Zoom", style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            ElevatedButton.icon(
                              onPressed: () => _launchExternalUrl(msg['image_url']),
                              icon: const Icon(Icons.download_rounded, color: Colors.white, size: 16),
                              label: const Text("DOWNLOAD HD IMAGE", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11)),
                              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1967D2)),
                            ),
                          ],
                        ),
                      ],
                      if (msg['download_url'] != null && msg['download_url'].toString().isNotEmpty) ...[
                        const SizedBox(height: 10),
                        ElevatedButton.icon(
                          onPressed: () => _launchExternalUrl(msg['download_url']),
                          icon: const Icon(Icons.download_rounded, color: Colors.white, size: 16),
                          label: const Text("Download Exported Studio Asset", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11)),
                          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1967D2)),
                        ),
                      ],
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.copy_rounded, size: 18, color: Color(0xFF747775)),
                            tooltip: "Copy to Clipboard",
                            onPressed: () => _copyToClipboard(msg['text']),
                          ),
                          if (msg['audio_url'] != null && msg['audio_url'].toString().isNotEmpty)
                            IconButton(
                              icon: const Icon(Icons.volume_up_rounded, size: 20, color: Color(0xFF4285F4)),
                              tooltip: "Listen (Voice TTS)",
                              onPressed: () => _audioPlayer.play(UrlSource(msg['audio_url'])),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildOmniChip(String text, VoidCallback onTap) {
    return Container(
      margin: const EdgeInsets.only(right: 8),
      child: ActionChip(
        label: Text(text, style: const TextStyle(fontSize: 11.5, color: Color(0xFF1F1F20), fontWeight: FontWeight.w500)),
        backgroundColor: const Color(0xFFF0F4F9),
        side: const BorderSide(color: Color(0xFFE1E3E1)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        onPressed: onTap,
      ),
    );
  }

  // ================= 3. TOURISTOS GUIDE =================
  Widget _buildTouristOSScreen({required bool isMobile}) {
    if (isExploring && exploringSpot != null) {
      return _buildExploreDetailView();
    }

    final sortedCountries = worldLocations.keys.toList()..sort();
    final statesForCountry = (worldLocations[selectedCountry]?.keys.toList() ?? [])..sort();
    final citiesForState = worldLocations[selectedCountry]?[selectedState] ?? [];

    String activeDestinationTitle = _customCityController.text.trim().isNotEmpty
        ? _customCityController.text.trim()
        : "$selectedCity, $selectedCountry";

    final destData = structuredDestinationData;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: const Color(0xFF131622),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFF1F2436)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 10,
                runSpacing: 8,
                children: [
                  const Text("Plan Your Safe Journey with Omni AI Guide", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(color: const Color(0xFF10B981).withOpacity(0.15), borderRadius: BorderRadius.circular(6)),
                    child: Text("📍 GPS: $currentCoords", style: const TextStyle(fontSize: 11, color: Color(0xFF10B981), fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
              const Divider(color: Color(0xFF1F2436), height: 24),

              if (isMobile) ...[
                _buildDropdownField("Country (A-Z):", selectedCountry, sortedCountries, (val) {
                  if (val != null) {
                    setState(() {
                      selectedCountry = val;
                      selectedState = worldLocations[val]!.keys.first;
                      selectedCity = worldLocations[val]![selectedState]!.first;
                    });
                  }
                }),
                const SizedBox(height: 10),
                _buildDropdownField("State / UT:", statesForCountry.contains(selectedState) ? selectedState : statesForCountry.first, statesForCountry, (val) {
                  if (val != null) {
                    setState(() {
                      selectedState = val;
                      selectedCity = worldLocations[selectedCountry]![val]!.first;
                    });
                  }
                }),
                const SizedBox(height: 10),
                _buildDropdownField("City Destination:", citiesForState.contains(selectedCity) ? selectedCity : (citiesForState.isNotEmpty ? citiesForState.first : ""), citiesForState, (val) {
                  if (val != null) setState(() => selectedCity = val);
                }),
              ] else
                Row(
                  children: [
                    Expanded(child: _buildDropdownField("Country (A-Z):", selectedCountry, sortedCountries, (val) {
                      if (val != null) {
                        setState(() {
                          selectedCountry = val;
                          selectedState = worldLocations[val]!.keys.first;
                          selectedCity = worldLocations[val]![selectedState]!.first;
                        });
                      }
                    })),
                    const SizedBox(width: 14),
                    Expanded(child: _buildDropdownField("State / UT:", statesForCountry.contains(selectedState) ? selectedState : statesForCountry.first, statesForCountry, (val) {
                      if (val != null) {
                        setState(() {
                          selectedState = val;
                          selectedCity = worldLocations[selectedCountry]![val]!.first;
                        });
                      }
                    })),
                    const SizedBox(width: 14),
                    Expanded(child: _buildDropdownField("City Destination:", citiesForState.contains(selectedCity) ? selectedCity : (citiesForState.isNotEmpty ? citiesForState.first : ""), citiesForState, (val) {
                      if (val != null) setState(() => selectedCity = val);
                    })),
                  ],
                ),
              const SizedBox(height: 14),

              if (isMobile) ...[
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text("Custom Search Location:", style: TextStyle(fontSize: 11, color: Color(0xFF06B6D4))),
                    const SizedBox(height: 4),
                    TextField(
                      controller: _customCityController,
                      style: const TextStyle(fontSize: 13),
                      decoration: InputDecoration(
                        hintText: "e.g., Mumbai, Vasai, Virar, Colaba...",
                        hintStyle: const TextStyle(color: Colors.grey),
                        filled: true,
                        fillColor: const Color(0xFF090A10),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFF1F2436))),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFF1F2436))),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                _buildDropdownField("Traveling As:", selectedGroupType, groupOptions, (val) { if (val != null) setState(() => selectedGroupType = val); }),
                const SizedBox(height: 10),
                _buildDropdownField("Dietary Preference:", selectedDiet, dietOptions, (val) { if (val != null) setState(() => selectedDiet = val); }),
                const SizedBox(height: 10),
                _buildDropdownField("Available Time:", selectedTime, timeOptions, (val) { if (val != null) setState(() => selectedTime = val); }),
              ] else
                Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text("Custom Search Location:", style: TextStyle(fontSize: 11, color: Color(0xFF06B6D4))),
                          const SizedBox(height: 4),
                          TextField(
                            controller: _customCityController,
                            style: const TextStyle(fontSize: 13),
                            decoration: InputDecoration(
                              hintText: "e.g., Mumbai, Vasai, Virar, Colaba...",
                              hintStyle: const TextStyle(color: Colors.grey),
                              filled: true,
                              fillColor: const Color(0xFF090A10),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFF1F2436))),
                              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFF1F2436))),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(child: _buildDropdownField("Traveling As:", selectedGroupType, groupOptions, (val) { if (val != null) setState(() => selectedGroupType = val); })),
                    const SizedBox(width: 14),
                    Expanded(child: _buildDropdownField("Dietary Preference:", selectedDiet, dietOptions, (val) { if (val != null) setState(() => selectedDiet = val); })),
                    const SizedBox(width: 14),
                    Expanded(child: _buildDropdownField("Available Time:", selectedTime, timeOptions, (val) { if (val != null) setState(() => selectedTime = val); })),
                  ],
                ),
              const SizedBox(height: 18),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: isPlanning ? null : _getTouristRecommendations,
                  icon: const Icon(Icons.search_rounded, color: Colors.black),
                  label: Text(
                    isPlanning ? "Curating Places for $activeDestinationTitle..." : "SEARCH PLACES & STAYS ($activeDestinationTitle)",
                    style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF06B6D4),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),

        if (isPlanning)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(32.0),
              child: Column(
                children: [
                  CircularProgressIndicator(color: Color(0xFF06B6D4)),
                  SizedBox(height: 12),
                  Text("Omni AI Concierge is assembling verified places, stays, and emergency routes...", textAlign: TextAlign.center, style: TextStyle(color: Colors.grey, fontSize: 13)),
                ],
              ),
            ),
          ),

        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text("Top Attractions in $activeDestinationTitle (Page $_touristPage of ${_getMaxPages()})", overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white)),
            ),
            Row(
              children: [
                IconButton(
                  onPressed: _touristPage > 1 ? () => setState(() => _touristPage--) : null,
                  icon: const Icon(Icons.chevron_left_rounded, color: Colors.white),
                ),
                Text("$_touristPage / ${_getMaxPages()}", style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 12)),
                IconButton(
                  onPressed: _touristPage < _getMaxPages() ? () => setState(() => _touristPage++) : null,
                  icon: const Icon(Icons.chevron_right_rounded, color: Colors.white),
                ),
              ],
            )
          ],
        ),
        const SizedBox(height: 12),
        if (isMobile)
          Column(
            children: _buildCurrentTouristCards(isMobile: true),
          )
        else
          Row(
            children: _buildCurrentTouristCards(isMobile: false),
          ),
        const SizedBox(height: 25),

        if (destData != null) ...[
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFF131622),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFF1F2436)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 10,
                  runSpacing: 6,
                  children: [
                    Text("📍 Destination Overview — $activeDestinationTitle", style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF06B6D4))),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(color: const Color(0xFF8B5CF6).withOpacity(0.2), borderRadius: BorderRadius.circular(6)),
                      child: Text(destData['distance_from_center']?.toString() ?? activeDestinationTitle, style: const TextStyle(color: Colors.white, fontSize: 11)),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(destData['destination_summary']?.toString() ?? "", style: const TextStyle(fontSize: 13, height: 1.5, color: Colors.white70)),
                const SizedBox(height: 14),

                const Text("⚡ Verified Facilities & Infrastructure:", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFFF59E0B))),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: ((destData['facilities'] as List?) ?? ["High-Speed Wi-Fi", "Verified Stays", "24/7 Transit", "ATM Access"]).map((f) => Chip(
                    label: Text(f.toString(), style: const TextStyle(fontSize: 11, color: Colors.white)),
                    backgroundColor: const Color(0xFF1A1F30),
                    side: BorderSide.none,
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                  )).toList(),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    const Icon(Icons.directions_transit, size: 16, color: Color(0xFF10B981)),
                    const SizedBox(width: 6),
                    Expanded(child: Text("Transit: ${destData['transport_availability'] ?? 'Local Trains, Auto-rickshaws, App Cabs'}", style: const TextStyle(fontSize: 12, color: Color(0xFF10B981)))),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          Text("🏨 Available Stays & Accommodations in $activeDestinationTitle (${((destData['hotels'] as List?) ?? []).length} Verified)", style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFFF59E0B))),
          const SizedBox(height: 12),
          Column(
            children: ((destData['hotels'] as List?) ?? []).map((h) {
              final hotelMap = Map<String, dynamic>.from(h);
              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF131622),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFF1F2436)),
                ),
                child: Column(
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(color: const Color(0xFF8B5CF6).withOpacity(0.18), borderRadius: BorderRadius.circular(12)),
                          child: const Icon(Icons.hotel_class_rounded, size: 24, color: Color(0xFF8B5CF6)),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Text(hotelMap['name']?.toString() ?? "Hotel", style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white), overflow: TextOverflow.ellipsis),
                                  ),
                                  Text(hotelMap['price']?.toString() ?? "₹2,499/night", style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF10B981))),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text("${hotelMap['type']} • ${hotelMap['rating']} (${hotelMap['reviews'] ?? 'Verified Reviews'})", style: const TextStyle(fontSize: 11, color: Color(0xFF06B6D4))),
                              Text("📍 ${hotelMap['address']} • 📞 ${hotelMap['phone']}", style: const TextStyle(fontSize: 10, color: Colors.grey)),
                              const SizedBox(height: 6),
                              Wrap(
                                spacing: 6,
                                children: ((hotelMap['amenities'] as List?) ?? ["AC", "Breakfast", "Wi-Fi"]).map((a) => Text("✓ $a", style: const TextStyle(fontSize: 10, color: Colors.white70))).toList(),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () => _openInAppHotelBookingDialog(hotelMap),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF06B6D4),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        child: const Text("SELECT & BOOK", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 11)),
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 24),

          if (isMobile) ...[
            _buildThingsToDoCard(destData),
            const SizedBox(height: 16),
            _buildFoodCard(destData),
          ] else
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: _buildThingsToDoCard(destData)),
                const SizedBox(width: 16),
                Expanded(child: _buildFoodCard(destData)),
              ],
            ),
          const SizedBox(height: 25),
        ],

        _buildMandatoryEmergencySection(activeDestinationTitle),
      ],
    );
  }

  Widget _buildDropdownField(String label, String value, List<String> items, ValueChanged<String?> onChanged) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
        const SizedBox(height: 4),
        DropdownButtonFormField<String>(
          value: items.contains(value) ? value : (items.isNotEmpty ? items.first : null),
          dropdownColor: const Color(0xFF131622),
          decoration: _inputDropdownDecoration(),
          items: items.map((i) => DropdownMenuItem(value: i, child: Text(i, style: const TextStyle(fontSize: 12), overflow: TextOverflow.ellipsis))).toList(),
          onChanged: onChanged,
        ),
      ],
    );
  }

  Widget _buildThingsToDoCard(Map<String, dynamic> destData) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(color: const Color(0xFF131622), borderRadius: BorderRadius.circular(14), border: Border.all(color: const Color(0xFF1F2436))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.checklist_rounded, color: Color(0xFF06B6D4), size: 18),
              SizedBox(width: 8),
              Text("🎯 Best Things to Do", style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF06B6D4))),
            ],
          ),
          const Divider(color: Color(0xFF1F2436), height: 20),
          ...((destData['best_things_to_do'] as List?) ?? []).map((item) => Padding(
            padding: const EdgeInsets.symmetric(vertical: 4.0),
            child: Text("• $item", style: const TextStyle(fontSize: 12, color: Colors.white70, height: 1.4)),
          )),
        ],
      ),
    );
  }

  Widget _buildFoodCard(Map<String, dynamic> destData) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(color: const Color(0xFF131622), borderRadius: BorderRadius.circular(14), border: Border.all(color: const Color(0xFF1F2436))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.restaurant_rounded, color: Color(0xFF10B981), size: 18),
              SizedBox(width: 8),
              Text("🍽️ Best Food, Bars & Markets", style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF10B981))),
            ],
          ),
          const Divider(color: Color(0xFF1F2436), height: 20),
          ...((destData['best_food_to_try'] as List?) ?? []).map((item) => Padding(
            padding: const EdgeInsets.symmetric(vertical: 4.0),
            child: Text("• $item", style: const TextStyle(fontSize: 12, color: Colors.white70, height: 1.4)),
          )),
        ],
      ),
    );
  }

  Widget _buildPillTab(int index, String title, bool isSelected, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF8B5CF6) : const Color(0xFF131622),
          borderRadius: BorderRadius.circular(8),
          border: isSelected ? null : Border.all(color: const Color(0xFF1F2436)),
        ),
        child: Text(title, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: isSelected ? Colors.white : Colors.grey)),
      ),
    );
  }

  InputDecoration _inputDropdownDecoration() {
    return InputDecoration(
      filled: true,
      fillColor: const Color(0xFF090A10),
      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFF1F2436))),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFF1F2436))),
    );
  }

  Widget _buildMandatoryEmergencySection(String destinationTitle) {
    final em = structuredDestinationData?['emergency'] ?? {};
    bool isMumbai = destinationTitle.toLowerCase().contains("mumbai");

    String hospital = em['hospital_name']?.toString() ?? (isMumbai ? "Lilavati Hospital & Research Centre (Bandra)" : "Cardinal Gracias Memorial Hospital (Vasai West)");
    String hospitalPhone = em['hospital_phone']?.toString() ?? (isMumbai ? "+91 22 2675 1000" : "+91 250 232 2356");

    String police = em['police_name']?.toString() ?? (isMumbai ? "Mumbai Police HQ & Control Room" : "Vasai West Police Station");
    String policePhone = em['police_phone']?.toString() ?? (isMumbai ? "+91 22 2262 0111" : "+91 250 233 2333");

    String fire = em['fire_name']?.toString() ?? (isMumbai ? "Mumbai Fire Brigade HQ" : "VVCMC Fire Brigade HQ");
    String firePhone = em['fire_phone']?.toString() ?? (isMumbai ? "101 / +91 22 2307 6111" : "+91 250 233 2101");

    String pharmacy = em['pharmacy_name']?.toString() ?? (isMumbai ? "Apollo 24/7 Pharmacy Fort" : "Noble 24/7 Chemist & Druggists");
    String pharmacyPhone = em['pharmacy_phone']?.toString() ?? (isMumbai ? "+91 22 2200 4567" : "+91 98200 12345");

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1414),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.red.withOpacity(0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.warning_amber_rounded, color: Colors.redAccent, size: 22),
              const SizedBox(width: 8),
              Expanded(
                child: Text("🚨 Safety & Emergency Contacts ($destinationTitle)", style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.redAccent)),
              ),
            ],
          ),
          const Divider(color: Colors.white12, height: 20),
          _buildEmergencyRow("🏥 Hospital:", hospital, hospitalPhone),
          const SizedBox(height: 8),
          _buildEmergencyRow("👮 Police Station:", police, policePhone),
          const SizedBox(height: 8),
          _buildEmergencyRow("🚒 Fire Station:", fire, firePhone),
          const SizedBox(height: 8),
          _buildEmergencyRow("💊 24/7 Pharmacy:", pharmacy, pharmacyPhone),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => _launchGoogleMapsDirections("Emergency Hospital Police"),
              icon: const Icon(Icons.phone, size: 16, color: Colors.white),
              label: const Text("EMERGENCY DIAL 112 / 911 (LIVE GPS ASSIST)", textAlign: TextAlign.center, style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11)),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red[800], padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmergencyRow(String label, String name, String phone) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(child: Text("$label $name", style: const TextStyle(fontSize: 12, color: Colors.white), maxLines: 1, overflow: TextOverflow.ellipsis)),
        const SizedBox(width: 10),
        Text(phone, style: const TextStyle(fontSize: 11, color: Color(0xFF06B6D4), fontWeight: FontWeight.bold)),
      ],
    );
  }

  int _getMaxPages() {
    List spots = structuredDestinationData?['spots'] ?? _getDefaultSpots();
    return (spots.length / 3).ceil().clamp(1, 10);
  }

  List<Map<String, dynamic>> _getDefaultSpots() {
    return [
      {
        "title": "Gateway of India",
        "rating": "⭐ 4.9 (45k+)",
        "dist": "Colaba Coast",
        "phone": "+91 22 2284 3989",
        "images": ["https://images.unsplash.com/photo-1570168007204-dfb528c6958f?q=80&w=800&auto=format&fit=crop"],
        "tag": "Historic Landmark"
      },
      {
        "title": "Marine Drive Promenade",
        "rating": "⭐ 4.8 (38k+)",
        "dist": "South Shoreline",
        "phone": "Public Promenade",
        "images": ["https://images.unsplash.com/photo-1566552881560-0be862a7c445?q=80&w=800&auto=format&fit=crop"],
        "tag": "Sunset & Coastline"
      },
      {
        "title": "Bandra-Worli Sea Link",
        "rating": "⭐ 4.8 (21k+)",
        "dist": "West Highway",
        "phone": "Toll Bridge",
        "images": ["https://images.unsplash.com/photo-1595658658481-d53d3f999875?q=80&w=800&auto=format&fit=crop"],
        "tag": "Architectural Icon"
      }
    ];
  }

  List<Widget> _buildCurrentTouristCards({required bool isMobile}) {
    List spots = structuredDestinationData?['spots'] ?? _getDefaultSpots();

    int startIndex = (_touristPage - 1) * 3;
    if (startIndex >= spots.length) startIndex = 0;
    int endIndex = (startIndex + 3).clamp(0, spots.length);
    List pageSpots = spots.sublist(startIndex, endIndex);

    return pageSpots.map<Widget>((spot) {
      String firstImg = "https://images.unsplash.com/photo-1570168007204-dfb528c6958f?q=80&w=800&auto=format&fit=crop";
      if (spot['images'] != null && (spot['images'] as List).isNotEmpty) {
        firstImg = spot['images'][0].toString();
      }

      Widget card = Container(
        margin: EdgeInsets.symmetric(horizontal: isMobile ? 0 : 6, vertical: isMobile ? 6 : 0),
        decoration: BoxDecoration(color: const Color(0xFF131622), borderRadius: BorderRadius.circular(14), border: Border.all(color: const Color(0xFF1F2436))),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
              child: Image.network(
                firstImg, 
                height: 140, 
                width: double.infinity, 
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => Container(
                  height: 140, 
                  color: const Color(0xFF1A1F30),
                  child: const Center(child: Icon(Icons.landscape, color: Color(0xFF06B6D4))),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(12.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(spot['rating']?.toString() ?? "⭐ 4.8", style: const TextStyle(color: Color(0xFFF59E0B), fontSize: 11, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 2),
                  Text(spot['title']?.toString() ?? "Spot", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.white), maxLines: 1, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 2),
                  Text("📞 ${spot['phone'] ?? 'Public Landmark'}", style: const TextStyle(color: Color(0xFF06B6D4), fontSize: 10), maxLines: 1),
                  Text("📍 ${spot['dist'] ?? ''}", style: const TextStyle(color: Colors.grey, fontSize: 10), maxLines: 1),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () => _launchGoogleMapsDirections(spot['title']!.toString()),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF06B6D4),
                            padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 8),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                          ),
                          child: const Text("ROUTE", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.black)),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () => _openExploreView(Map<String, dynamic>.from(spot)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF8B5CF6),
                            padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 8),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                          ),
                          child: const Text("EXPLORE", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white)),
                        ),
                      ),
                      const SizedBox(width: 4),
                      IconButton(
                        onPressed: () => _saveItemToBookmarks(spot['title']!.toString(), "Rating: ${spot['rating']} | Location: ${spot['dist']}"),
                        icon: const Icon(Icons.bookmark_add_outlined, size: 18, color: Color(0xFF06B6D4)),
                        tooltip: "Save",
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      );

      return isMobile ? card : Expanded(child: card);
    }).toList();
  }

  // ================= 4. EXPLORE VIEW (OMNI TOUR CONCIERGE CHAT) =================
  Widget _buildExploreDetailView() {
    final spot = exploringSpot!;
    String spotTitle = spot['title']?.toString() ?? "Destination";

    List<String> imageList = [];
    if (spot['images'] != null && spot['images'] is List) {
      for (var img in (spot['images'] as List)) {
        imageList.add(img.toString());
      }
    }
    if (imageList.isEmpty) {
      imageList.add("https://images.unsplash.com/photo-1570168007204-dfb528c6958f?q=80&w=800&auto=format&fit=crop");
    }

    final destData = structuredDestinationData;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ElevatedButton.icon(
          onPressed: () => setState(() => isExploring = false),
          icon: const Icon(Icons.arrow_back, size: 16, color: Colors.white),
          label: const Text("Back to Directory", style: TextStyle(color: Colors.white)),
          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF131622), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: 220,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: imageList.length,
            itemBuilder: (context, idx) {
              return Container(
                width: 300,
                margin: const EdgeInsets.only(right: 12),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: Image.network(
                    imageList[idx],
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => Container(
                      color: const Color(0xFF1A1F30),
                      child: const Center(child: Icon(Icons.landscape, size: 40, color: Color(0xFF06B6D4))),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(color: const Color(0xFF131622), borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xFF1F2436))),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(child: Text(spotTitle, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white), overflow: TextOverflow.ellipsis)),
                  Text(spot['rating']?.toString() ?? "⭐ 4.8", style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFFF59E0B))),
                ],
              ),
              const SizedBox(height: 6),
              Text("📞 Contact: ${spot['phone'] ?? 'Public Landmark'}  |  📍 Location: ${spot['dist'] ?? ''}", style: const TextStyle(color: Color(0xFF06B6D4), fontSize: 12)),
              const Divider(color: Color(0xFF1F2436), height: 24),
              Wrap(
                spacing: 12,
                runSpacing: 10,
                children: [
                  ElevatedButton.icon(
                    onPressed: () => _launchGoogleMapsDirections(spotTitle),
                    icon: const Icon(Icons.map_rounded, color: Colors.black, size: 16),
                    label: const Text("ROUTE IN GOOGLE MAPS", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 12)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF06B6D4),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                  ElevatedButton.icon(
                    onPressed: () => _saveItemToBookmarks(spotTitle, "Explored & Bookmarked"),
                    icon: const Icon(Icons.bookmark_add_rounded, color: Colors.white, size: 16),
                    label: const Text("SAVE PLAN", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF8B5CF6),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        if (destData != null) ...[
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(color: const Color(0xFF131622), borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xFF1F2436))),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("🏨 Nearby Stays & Verified Accommodations", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFFF59E0B))),
                const SizedBox(height: 12),
                ...((destData['hotels'] as List?) ?? []).map((h) {
                  final hotelMap = Map<String, dynamic>.from(h);
                  return Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0E111A),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFF1F2436)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(hotelMap['name']?.toString() ?? "Hotel", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.white)),
                              Text("${hotelMap['type']} • ${hotelMap['price']}", style: const TextStyle(color: Color(0xFF10B981), fontSize: 12)),
                              Text("📍 ${hotelMap['address']} • 📞 ${hotelMap['phone']}", style: const TextStyle(color: Colors.grey, fontSize: 10)),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          onPressed: () => _openInAppHotelBookingDialog(hotelMap),
                          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF06B6D4), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                          child: const Text("BOOK", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 11)),
                        ),
                      ],
                    ),
                  );
                }),
              ],
            ),
          ),
          const SizedBox(height: 20),
        ],
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFFFFFFFF),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE5E7EB)),
          ),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: const BoxDecoration(
                  color: Color(0xFFF8F9FA),
                  borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
                  border: Border(bottom: BorderSide(color: Color(0xFFE5E7EB))),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(colors: [Color(0xFF4285F4), Color(0xFF9B72CB)]),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.auto_awesome, color: Colors.white, size: 16),
                    ),
                    const SizedBox(width: 10),
                    Text("Omni Tour Concierge — $spotTitle", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF1F1F20))),
                  ],
                ),
              ),
              Container(
                height: 320,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: ListView.builder(
                  controller: _exploreScrollController,
                  itemCount: exploreChatHistory.length + (isExploreAsking ? 1 : 0),
                  itemBuilder: (context, index) {
                    if (index == exploreChatHistory.length && isExploreAsking) {
                      return const OmniThinkingBubble();
                    }
                    final msg = exploreChatHistory[index];
                    final isUser = msg['sender'] == 'user';
                    return _buildOmniMessageTile(msg, isUser);
                  },
                ),
              ),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: const BoxDecoration(
                  color: Color(0xFFFFFFFF),
                  borderRadius: BorderRadius.vertical(bottom: Radius.circular(16)),
                  border: Border(top: BorderSide(color: Color(0xFFE5E7EB))),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF0F4F9),
                          borderRadius: BorderRadius.circular(24),
                        ),
                        child: TextField(
                          controller: _exploreChatController,
                          onSubmitted: (_) => _askExploreChat(),
                          style: const TextStyle(fontSize: 13.5, color: Color(0xFF1F1F20)),
                          decoration: const InputDecoration(
                            hintText: "Ask best timing, table reservation, local veg food...",
                            hintStyle: TextStyle(color: Color(0xFF747775), fontSize: 12),
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.symmetric(vertical: 10),
                          ),
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => _toggleVoiceListening(_exploreChatController),
                      icon: Icon(
                        _isListening ? Icons.mic : Icons.mic_none_rounded,
                        color: _isListening ? Colors.redAccent : const Color(0xFF4285F4),
                        size: 22,
                      ),
                      tooltip: "Voice ($selectedLanguage)",
                    ),
                    IconButton(
                      onPressed: isExploreAsking ? null : _askExploreChat,
                      icon: isExploreAsking
                          ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF4285F4)))
                          : const Icon(Icons.send_rounded, color: Color(0xFF4285F4), size: 20),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ================= 5. SAVED ITEMS & BOOKMARKS =================
  Widget _buildSavedItemsScreen() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("⭐ Bookmarked Places & Saved Booking Vouchers", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFFF59E0B))),
        const SizedBox(height: 6),
        const Text("All your booked stays, reserved itinerary vouchers, and favorited spots.", style: TextStyle(color: Colors.grey, fontSize: 12)),
        const SizedBox(height: 20),
        if (savedItemsList.isEmpty)
          Container(
            padding: const EdgeInsets.all(32),
            alignment: Alignment.center,
            decoration: BoxDecoration(color: const Color(0xFF131622), borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xFF1F2436))),
            child: const Text("No bookmarks yet. Browse TouristOS Guide and tap 'SAVE PLAN' or book a stay!", textAlign: TextAlign.center, style: TextStyle(color: Colors.grey, fontSize: 13)),
          )
        else
          ...savedItemsList.asMap().entries.map((entry) {
            int index = entry.key;
            var item = entry.value;
            return Container(
              margin: const EdgeInsets.symmetric(vertical: 6),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(color: const Color(0xFF131622), borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFF1F2436))),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(item['title']!, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white), overflow: TextOverflow.ellipsis),
                        const SizedBox(height: 4),
                        Text(item['details']!, style: const TextStyle(fontSize: 11, color: Color(0xFF06B6D4))),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Row(
                    children: [
                      ElevatedButton(
                        onPressed: () => _launchGoogleMapsDirections(item['title']!),
                        style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF06B6D4), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                        child: const Text("NAVIGATE", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 10)),
                      ),
                      const SizedBox(width: 6),
                      IconButton(
                        onPressed: () => _confirmDeleteBookmark(index),
                        icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 20),
                        tooltip: "Delete Item",
                      ),
                    ],
                  ),
                ],
              ),
            );
          }),
      ],
    );
  }

  // ================= 6. SETTINGS & ABOUT SECTION =================
  Widget _buildSettingsScreen() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("⚙️ Settings & System About", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF06B6D4))),
        const SizedBox(height: 16),

        // Preferences Card
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: const Color(0xFF131622), borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xFF1F2436))),
          child: Column(
            children: [
              SwitchListTile(
                title: const Text("Dark Theme (Enterprise OLED Mode)", style: TextStyle(color: Colors.white, fontSize: 13)),
                value: true,
                onChanged: (val) {},
                activeColor: const Color(0xFF8B5CF6),
              ),
              const Divider(color: Color(0xFF1F2436)),
              SwitchListTile(
                title: const Text("Speech & Voice Command Mode", style: TextStyle(color: Colors.white, fontSize: 13)),
                subtitle: Text("Voice recognition active in $selectedLanguage", style: const TextStyle(color: Colors.grey, fontSize: 11)),
                value: _voiceEnabled,
                onChanged: (val) => setState(() => _voiceEnabled = val),
                activeColor: const Color(0xFF06B6D4),
              ),
              const Divider(color: Color(0xFF1F2436)),
              SwitchListTile(
                title: const Text("Automatic Live GPS Tracking", style: TextStyle(color: Colors.white, fontSize: 13)),
                value: true,
                onChanged: (val) {},
                activeColor: const Color(0xFF8B5CF6),
              ),
              const Divider(color: Color(0xFF1F2436)),
              SwitchListTile(
                title: const Text("Voice Co-Pilot Audio Alerts", style: TextStyle(color: Colors.white, fontSize: 13)),
                value: true,
                activeColor: const Color(0xFF8B5CF6),
                onChanged: (val) {},
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // About Omni TouristOS Card with 3D Logo Asset
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: const Color(0xFF131622),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFF1F2436)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.asset(
                      'assets/logo.png',
                      width: 54,
                      height: 54,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => Container(
                        width: 54,
                        height: 54,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(colors: [Color(0xFF8B5CF6), Color(0xFF06B6D4)]),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.explore_rounded, color: Colors.white, size: 28),
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("Omni TouristOS", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
                      Text("Developed by Velnova Enterprises", style: TextStyle(color: Color(0xFF06B6D4), fontSize: 12, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ],
              ),
              const Divider(color: Color(0xFF1F2436), height: 26),
              const Text(
                "Omni TouristOS is an all-in-one multimodal operating hub consolidating document security auditing, visual asset synthesis, universal file transformation, and real-time GPS travel assistance into a unified workspace.",
                style: TextStyle(fontSize: 12.5, color: Colors.white70, height: 1.45),
              ),
              const SizedBox(height: 16),
              _buildAboutFeatureLine("📄 Omni PaperPilot", "Document fraud audit, trap detection & summary extraction."),
              _buildAboutFeatureLine("🎨 Omni AI Studio", "High-speed reasoning, speech-to-text & HD image generator."),
              _buildAboutFeatureLine("🗺️ TouristOS Concierge", "GPS destination directories, hotel vouchers & emergency shield."),
              _buildAboutFeatureLine("🔄 Universal Converter", "Instant conversion across Documents, Sheets, PPT & Images."),
              const Divider(color: Color(0xFF1F2436), height: 24),
              
              // Legal Policy Button
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _showLegalPolicyDialog,
                  icon: const Icon(Icons.privacy_tip_outlined, size: 16, color: Color(0xFF06B6D4)),
                  label: const Text("VIEW PRIVACY POLICY & TERMS OF SERVICE", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF06B6D4))),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Color(0xFF06B6D4)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ),
              const SizedBox(height: 14),

              const Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text("Cloud Status: Connected", style: TextStyle(color: Color(0xFF10B981), fontSize: 12, fontWeight: FontWeight.bold)),
                  Text("Publisher: Velnova Enterprises", style: TextStyle(color: Colors.grey, fontSize: 11)),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildAboutFeatureLine(String title, String desc) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.white)),
          const SizedBox(width: 6),
          Expanded(child: Text("— $desc", style: const TextStyle(fontSize: 11.5, color: Colors.grey))),
        ],
      ),
    );
  }
}

// ================= ANIMATED OMNI AI THOUGHT PROCESS & SHIMMER WIDGET =================
class OmniThinkingBubble extends StatefulWidget {
  final bool isGeneratingImage;
  final double imageGenProgress;

  const OmniThinkingBubble({
    super.key,
    this.isGeneratingImage = false,
    this.imageGenProgress = 0.0,
  });

  @override
  State<OmniThinkingBubble> createState() => _OmniThinkingBubbleState();
}

class _OmniThinkingBubbleState extends State<OmniThinkingBubble>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _shimmerAnim;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat();

    _shimmerAnim = Tween<double>(begin: -1.0, end: 2.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOutSine),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final double pulse = (_controller.value <= 0.5)
            ? _controller.value * 2
            : (1.0 - _controller.value) * 2;

        return Container(
          margin: const EdgeInsets.only(bottom: 20),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Transform.scale(
                scale: 0.95 + (0.08 * pulse),
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: const [
                        Color(0xFF4285F4),
                        Color(0xFF9B72CB),
                        Color(0xFFD96570),
                        Color(0xFFF2A900),
                      ],
                      transform: GradientRotation(_controller.value * 2 * 3.14159),
                    ),
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF4285F4).withOpacity(0.35 * pulse),
                        blurRadius: 10,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                  child: const Icon(Icons.auto_awesome, color: Colors.white, size: 16),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: widget.isGeneratingImage
                    ? Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "✨ Synthesizing Visual Asset... ${(widget.imageGenProgress * 100).toInt()}%",
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF1967D2),
                            ),
                          ),
                          const SizedBox(height: 8),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(6),
                            child: LinearProgressIndicator(
                              value: widget.imageGenProgress,
                              backgroundColor: const Color(0xFFE8F0FE),
                              color: const Color(0xFF4285F4),
                              minHeight: 6,
                            ),
                          ),
                        ],
                      )
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          ShaderMask(
                            shaderCallback: (bounds) {
                              return LinearGradient(
                                begin: Alignment.centerLeft,
                                end: Alignment.centerRight,
                                colors: const [
                                  Color(0xFF1F1F20),
                                  Color(0xFF4285F4),
                                  Color(0xFF9B72CB),
                                  Color(0xFFD96570),
                                  Color(0xFF1F1F20),
                                ],
                                stops: [
                                  (_shimmerAnim.value - 0.3).clamp(0.0, 1.0),
                                  (_shimmerAnim.value - 0.15).clamp(0.0, 1.0),
                                  _shimmerAnim.value.clamp(0.0, 1.0),
                                  (_shimmerAnim.value + 0.15).clamp(0.0, 1.0),
                                  (_shimmerAnim.value + 0.3).clamp(0.0, 1.0),
                                ],
                              ).createShader(bounds);
                            },
                            child: const Text(
                              "Omni TouristOS is analyzing & structuring response...",
                              style: TextStyle(
                                fontSize: 14.5,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                          ),
                          const SizedBox(height: 10),
                          _buildSkeletonLine(widthFactor: 0.85),
                          const SizedBox(height: 6),
                          _buildSkeletonLine(widthFactor: 0.65),
                          const SizedBox(height: 6),
                          _buildSkeletonLine(widthFactor: 0.40),
                        ],
                      ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSkeletonLine({required double widthFactor}) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return Container(
          height: 10,
          width: constraints.maxWidth * widthFactor,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(5),
            gradient: LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: const [
                Color(0xFFF0F4F9),
                Color(0xFFD3E3FD),
                Color(0xFFE8DEF8),
                Color(0xFFF0F4F9),
              ],
              stops: [
                (_shimmerAnim.value - 0.3).clamp(0.0, 1.0),
                (_shimmerAnim.value - 0.1).clamp(0.0, 1.0),
                (_shimmerAnim.value + 0.1).clamp(0.0, 1.0),
                (_shimmerAnim.value + 0.3).clamp(0.0, 1.0),
              ],
            ),
          ),
        );
      },
    );
  }
}