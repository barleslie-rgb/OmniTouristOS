import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:flutter_tts/flutter_tts.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import '../widgets/metallic_embossed_button.dart';

class TouristOSChatScreen extends StatefulWidget {
  final String language;
  final String activeCity;
  final String backendUrl;

  const TouristOSChatScreen({
    Key? key,
    required this.language,
    required this.activeCity,
    required this.backendUrl,
  }) : super(key: key);

  @override
  State<TouristOSChatScreen> createState() => _TouristOSChatScreenState();
}

class _TouristOSChatScreenState extends State<TouristOSChatScreen>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  final TextEditingController _msgCtrl = TextEditingController();
  final ScrollController _scrollCtrl = ScrollController();

  final List<Map<String, dynamic>> _messages = [];
  bool _isTyping = false;

  late stt.SpeechToText _speech;
  bool _isListening = false;

  late FlutterTts _flutterTts;
  int? _currentlySpeakingIndex;

  Position? _currentPosition;
  String? _savedHomeAddress;
  bool _isLostAssistanceActive = false;
  bool _isScanningLocation = false;

  // Regional Western & Central Railway Station Catalog
  static const List<Map<String, dynamic>> _railStations = [
    {"name": "Dahanu Road", "code": "DRD", "lat": 19.9733, "lon": 72.7308, "line": "WR"},
    {"name": "Palghar", "code": "PLG", "lat": 19.6967, "lon": 72.7656, "line": "WR"},
    {"name": "Saphale", "code": "SAH", "lat": 19.5767, "lon": 72.8183, "line": "WR"},
    {"name": "Vaitarna", "code": "VTN", "lat": 19.5186, "lon": 72.8453, "line": "WR"},
    {"name": "Virar", "code": "VR", "lat": 19.4544, "lon": 72.8114, "line": "WR"},
    {"name": "Nallasopara", "code": "NSP", "lat": 19.4181, "lon": 72.8197, "line": "WR"},
    {"name": "Vasai Road", "code": "BSR", "lat": 19.3808, "lon": 72.8317, "line": "WR"},
    {"name": "Naigaon", "code": "NIG", "lat": 19.3522, "lon": 72.8519, "line": "WR"},
    {"name": "Bhayandar", "code": "BYR", "lat": 19.3006, "lon": 72.8528, "line": "WR"},
    {"name": "Mira Road", "code": "MIRA", "lat": 19.2814, "lon": 72.8561, "line": "WR"},
    {"name": "Dahisar", "code": "DIC", "lat": 19.2503, "lon": 72.8592, "line": "WR"},
    {"name": "Borivali", "code": "BVI", "lat": 19.2294, "lon": 72.8572, "line": "WR"},
    {"name": "Kandivali", "code": "KND", "lat": 19.2044, "lon": 72.8522, "line": "WR"},
    {"name": "Malad", "code": "MLD", "lat": 19.1869, "lon": 72.8486, "line": "WR"},
    {"name": "Goregaon", "code": "GMN", "lat": 19.1644, "lon": 72.8483, "line": "WR"},
    {"name": "Andheri", "code": "ADH", "lat": 19.1197, "lon": 72.8464, "line": "WR"},
    {"name": "Bandra", "code": "BA", "lat": 19.0544, "lon": 72.8406, "line": "WR"},
    {"name": "Dadar", "code": "DDR", "lat": 19.0178, "lon": 72.8433, "line": "WR"},
    {"name": "Mumbai Central", "code": "MMCT", "lat": 18.9697, "lon": 72.8194, "line": "WR"},
    {"name": "Churchgate", "code": "CCG", "lat": 18.9322, "lon": 72.8264, "line": "WR"},
    {"name": "Thane", "code": "TNA", "lat": 19.1860, "lon": 72.9756, "line": "CR"},
    {"name": "Kalyan Junction", "code": "KYN", "lat": 19.2436, "lon": 73.1306, "line": "CR"},
    {"name": "Panvel", "code": "PNVL", "lat": 18.9894, "lon": 73.1175, "line": "CR"},
    {"name": "CSMT (VT)", "code": "CSMT", "lat": 18.9400, "lon": 72.8353, "line": "CR"},
  ];

  static const Map<String, Map<String, String>> _dict = {
    "English": {
      "header_title": "Omni Concierge & Motion Radar",
      "header_subtitle": "Conversational travel expert & real-time transit radar",
      "chip_where_am_i": "📍 Where Am I Travelling?",
      "chip_lost": "🆘 I am Lost! Help Me",
      "chip_home": "🏠 Set Home Base",
      "chip_plan": "🗺️ Plan a Trip",
      "chip_season": "☀️ Weather & Months",
      "chip_scams": "⚠️ Scams & Safety",
      "chip_food": "🍲 Local Dishes",
      "hint_text": "Ask anything, inquire about transit or say 'Where am I'...",
      "typing_prefix": "AI Transit Radar is analyzing...",
      "copy_text": "Copy",
      "listen_text": "Listen",
      "stop_text": "Stop",
      "copied_notice": "Text copied to clipboard!",
      "export_header": "Export Travel Intelligence Dossier",
      "initial_greeting": "Hello! I am your Omni TouristOS Concierge & Motion Radar.\n\nAsk me travel questions, or tap 'Where Am I Travelling?' to track your live transit speed and upcoming station.",
    },
    "Marathi": {
      "header_title": "ओम्नी ट्रॅव्हल व मोशन रडार",
      "header_subtitle": "थेट प्रवास मार्गदर्शन, वेग व पुढील स्थानक शोधक",
      "chip_where_am_i": "📍 मी सध्या कुठे प्रवास करत आहे?",
      "chip_lost": "🆘 मी रस्ता चुकलो आहे!",
      "chip_home": "🏠 मुक्कामाचा पत्ता सेव्ह करा",
      "chip_plan": "🗺️ सहलीचे नियोजन",
      "chip_season": "☀️ हवामान माहिती",
      "chip_scams": "⚠️ सुरक्षितता इशारे",
      "chip_food": "🍲 स्थानिक खाद्यसंस्कृती",
      "hint_text": "काहीही विचारा किंवा 'मी सध्या कुठे आहे' म्हणा...",
      "typing_prefix": "मोशन रडार विश्लेषण करत आहे...",
      "copy_text": "कॉपी करा",
      "listen_text": "ऐका",
      "stop_text": "थांबवा",
      "copied_notice": "मजकूर क्लिपबोर्डवर सेव्ह केला!",
      "export_header": "प्रवास अहवाल डाऊनलोड करा",
      "initial_greeting": "नमस्कार! मी तुमचा ओम्नी टूरिस्ट आणि थेट प्रवास रडार मार्गदर्शक आहे.\n\nतुम्ही ट्रेन किंवा गाडीत असाल, तर 'मी सध्या कुठे प्रवास करत आहे?' वर टॅप करा, मी तुमचा वेग व पुढील स्थानक सांगतो.",
    },
    "Hindi": {
      "header_title": "ओम्नी ट्रेवल व मोशन रडार",
      "header_subtitle": "सटीक लाइव्ह स्पीड, लोकेशन व अगला स्टेशन ट्रैकर",
      "chip_where_am_i": "📍 मैं अभी कहाँ यात्रा कर रहा हूँ?",
      "chip_lost": "🆘 मैं रास्ता भटक गया हूँ!",
      "chip_home": "🏠 होटल पता सेट करें",
      "chip_plan": "🗺️ नई ट्रिप प्लान करें",
      "chip_season": "☀️ मौसम की जानकारी",
      "chip_scams": "⚠️ सुरक्षा व अलर्ट्स",
      "chip_food": "🍲 प्रसिद्ध भोजन",
      "hint_text": "कुछ भी पूछें या 'मैं कहाँ हूँ' लिखें...",
      "typing_prefix": "मोशन रडार विश्लेषण कर रहा है...",
      "copy_text": "कॉपी करें",
      "listen_text": "सुनें",
      "stop_text": "रोकें",
      "copied_notice": "टेक्स्ट कॉपी हो गया!",
      "export_header": "यात्रा रिपोर्ट डाउनलोड करें",
      "initial_greeting": "नमस्ते! मैं आपका ओम्नी टूरिस्ट और लाइव मोशन रडार गाइड हूँ।\n\nसटीक लोकेशन, ट्रेन स्पीड और अगले स्टेशन की जानकारी के लिए 'मैं अभी कहाँ यात्रा कर रहा हूँ?' पर टैप करें।",
    }
  };

  String _t(String key) {
    final lang = widget.language.trim();
    if (_dict.containsKey(lang) && _dict[lang]!.containsKey(key)) {
      return _dict[lang]![key]!;
    }
    return _dict["English"]![key] ?? key;
  }

  @override
  void initState() {
    super.initState();
    _speech = stt.SpeechToText();
    _initTts();
    _loadSavedHomeAddress();
    _fetchLiveLocation();

    _messages.add({
      "role": "assistant",
      "text": _t("initial_greeting"),
      "has_document": false,
      "is_lost_card": false,
      "is_motion_card": false,
    });

    _wakeBackend();
  }

  Future<void> _wakeBackend() async {
    try {
      final cleanUrl = widget.backendUrl.replaceAll(RegExp(r'/+$'), '');
      await http.get(Uri.parse("$cleanUrl/api/v1/wake")).timeout(const Duration(seconds: 4));
    } catch (_) {}
  }

  void _initTts() {
    _flutterTts = FlutterTts();
    _flutterTts.setCompletionHandler(() {
      if (mounted) setState(() => _currentlySpeakingIndex = null);
    });
    _flutterTts.setErrorHandler((_) {
      if (mounted) setState(() => _currentlySpeakingIndex = null);
    });
  }

  Future<void> _loadSavedHomeAddress() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString('user_home_base_address');
      if (mounted) setState(() => _savedHomeAddress = saved);
    } catch (_) {}
  }

  Future<void> _saveHomeAddress(String address) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('user_home_base_address', address.trim());
      if (mounted) setState(() => _savedHomeAddress = address.trim());
    } catch (_) {}
  }

  Future<Position?> _fetchLiveLocation() async {
    try {
      final permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
        await Geolocator.requestPermission();
      }
      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.bestForNavigation,
        timeLimit: const Duration(seconds: 6),
      );
      if (mounted) setState(() => _currentPosition = pos);
      return pos;
    } catch (_) {
      return null;
    }
  }

  @override
  void dispose() {
    _flutterTts.stop();
    _speech.stop();
    _msgCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  // Live Motion & Station Prediction Engine
  Map<String, dynamic> _analyzeLiveMotionAndStations(Position pos) {
    final double lat = pos.latitude;
    final double lon = pos.longitude;
    final double speedKmh = math.max(0, pos.speed * 3.6);
    final double heading = pos.heading;

    // Calculate nearest station
    Map<String, dynamic>? closestStation;
    double minDistanceKm = double.infinity;

    for (var st in _railStations) {
      final double distMeters = Geolocator.distanceBetween(
        lat,
        lon,
        st["lat"] as double,
        st["lon"] as double,
      );
      final double distKm = distMeters / 1000.0;
      if (distKm < minDistanceKm) {
        minDistanceKm = distKm;
        closestStation = st;
      }
    }

    // Determine direction of travel (Compass & track vector)
    String direction = "Unknown";
    bool isHeadingNorth = false;
    if (heading >= 315 || heading <= 45) {
      direction = "Northbound (Towards Virar / Dahanu)";
      isHeadingNorth = true;
    } else if (heading >= 135 && heading <= 225) {
      direction = "Southbound (Towards Borivali / Churchgate / CSMT)";
      isHeadingNorth = false;
    } else if (heading > 45 && heading < 135) {
      direction = "Eastbound (Towards Thane / Kalyan)";
    } else {
      direction = "Westbound (Towards Coast)";
    }

    // Motion status mode
    String transitMode = "Standing / Walking";
    if (speedKmh > 35) {
      transitMode = "Fast Moving (Express / Suburban Train or Highway)";
    } else if (speedKmh > 10) {
      transitMode = "In Transit (Auto / Cab / Train Cruising)";
    }

    // Predict Next Station based on trajectory
    Map<String, dynamic>? nextStation;
    double nextStationDistKm = 0.0;

    if (closestStation != null) {
      final int currentIndex = _railStations.indexWhere((s) => s["code"] == closestStation!["code"]);
      if (currentIndex != -1) {
        if (speedKmh > 12) {
          // If moving fast, evaluate whether heading towards next index or previous index
          if (isHeadingNorth && currentIndex > 0) {
            nextStation = _railStations[currentIndex - 1]; // Lower index is north in our list
          } else if (!isHeadingNorth && currentIndex < _railStations.length - 1) {
            nextStation = _railStations[currentIndex + 1]; // Higher index is south
          } else {
            nextStation = closestStation;
          }
        } else {
          nextStation = closestStation;
        }

        if (nextStation != null) {
          final double distM = Geolocator.distanceBetween(
            lat,
            lon,
            nextStation["lat"] as double,
            nextStation["lon"] as double,
          );
          nextStationDistKm = distM / 1000.0;
        }
      }
    }

    return {
      "speedKmh": speedKmh.round(),
      "direction": direction,
      "transitMode": transitMode,
      "closestStation": closestStation?["name"] ?? "Vasai Road",
      "closestCode": closestStation?["code"] ?? "BSR",
      "closestDistKm": minDistanceKm,
      "isAtStation": minDistanceKm < 0.45,
      "nextStation": nextStation?["name"] ?? "Approaching Station",
      "nextCode": nextStation?["code"] ?? "Next",
      "nextDistKm": nextStationDistKm,
      "lat": lat,
      "lon": lon,
    };
  }

  Future<void> _executeLiveMotionRadar() async {
    HapticFeedback.heavyImpact();
    setState(() {
      _isScanningLocation = true;
      _messages.add({
        "role": "user",
        "text": "📍 Where am I travelling right now? Tell me my live station and speed.",
        "has_document": false,
        "is_lost_card": false,
        "is_motion_card": false,
      });
      _isTyping = true;
    });
    _scrollToBottom();

    final pos = await _fetchLiveLocation();
    setState(() => _isScanningLocation = false);

    if (pos == null) {
      setState(() {
        _isTyping = false;
        _messages.add({
          "role": "assistant",
          "text": "### 📡 GPS Location Temporarily Unavailable\n\nPlease ensure Location/GPS permission is enabled in device settings and try again.",
          "has_document": false,
          "is_lost_card": false,
          "is_motion_card": false,
        });
      });
      _scrollToBottom();
      return;
    }

    final radar = _analyzeLiveMotionAndStations(pos);
    final speed = radar["speedKmh"] as int;
    final closest = radar["closestStation"] as String;
    final closestCode = radar["closestCode"] as String;
    final closestDist = (radar["closestDistKm"] as double).toStringAsFixed(1);
    final isAt = radar["isAtStation"] as bool;
    final next = radar["nextStation"] as String;
    final nextCode = radar["nextCode"] as String;
    final nextDist = (radar["nextDistKm"] as double).toStringAsFixed(1);
    final dir = radar["direction"] as String;
    final mode = radar["transitMode"] as String;

    String radarReport;
    if (isAt) {
      radarReport = "### 🚉 You are At **$closest ($closestCode)** Station\n\n"
          "• **Station:** $closest ($closestCode)\n"
          "• **Current Speed:** $speed km/h (Stationary / Platform)\n"
          "• **Coordinates:** ${pos.latitude.toStringAsFixed(4)}, ${pos.longitude.toStringAsFixed(4)}\n\n"
          "You are standing or halted at the station platform area.";
    } else if (speed > 25) {
      radarReport = "### 🚄 Live Transit Motion Detected\n\n"
          "• **Speed:** **$speed km/h**\n"
          "• **Trajectory:** $dir\n"
          "• **Nearest Hub:** $closest ($closestCode) • $closestDist km away\n"
          "• **Predicted Next Station:** **$next ($nextCode)** (approx. **$nextDist km** ahead)\n\n"
          "You are actively moving along the transit line. Estimated arrival at **$next** in ${(radar["nextDistKm"] / (speed / 60)).round()} mins.";
    } else {
      radarReport = "### 📍 Live Street Location Identified\n\n"
          "• **Area:** Near $closest, ${widget.activeCity}\n"
          "• **Speed:** $speed km/h ($mode)\n"
          "• **Nearest Railway Station:** $closest ($closestCode) • $closestDist km away\n\n"
          "You are travelling at local street velocity.";
    }

    if (mounted) {
      setState(() {
        _isTyping = false;
        _messages.add({
          "role": "assistant",
          "text": radarReport,
          "has_document": false,
          "is_lost_card": false,
          "is_motion_card": true,
          "radar_data": radar,
        });
      });
      _scrollToBottom();
      _toggleTts(_messages.length - 1, radarReport);
    }
  }

  Future<void> _toggleListening() async {
    if (_isListening) {
      await _speech.stop();
      if (mounted) setState(() => _isListening = false);
      return;
    }

    final available = await _speech.initialize(
      onError: (_) {
        if (mounted) setState(() => _isListening = false);
      },
      onStatus: (val) {
        if (val == 'done' || val == 'notListening') {
          if (mounted) setState(() => _isListening = false);
        }
      },
    );

    if (available) {
      setState(() => _isListening = true);

      String localeId = "en_IN";
      final lang = widget.language.toLowerCase();
      if (lang.contains("marathi") || widget.language.contains("मराठी")) {
        localeId = "mr_IN";
      } else if (lang.contains("hindi") || widget.language.contains("हिंदी")) {
        localeId = "hi_IN";
      }

      await _speech.listen(
        localeId: localeId,
        onResult: (val) {
          if (mounted) {
            setState(() {
              _msgCtrl.text = val.recognizedWords;
              _msgCtrl.selection = TextSelection.fromPosition(
                TextPosition(offset: _msgCtrl.text.length),
              );
            });
          }
        },
      );
    }
  }

  String _sanitizeForSpeech(String raw) {
    String clean = raw.replaceAll(RegExp(r'###|##|\*\*|•|\*|_'), ' ');
    clean = clean.replaceAll(RegExp(r'\|.*?\|'), ' ');
    clean = clean.replaceAll(RegExp(r'https?:\/\/\S+'), ' ');
    return clean.replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  Future<void> _toggleTts(int index, String text) async {
    if (_currentlySpeakingIndex == index) {
      await _flutterTts.stop();
      if (mounted) setState(() => _currentlySpeakingIndex = null);
      return;
    }

    await _flutterTts.stop();

    String langTag = "en-IN";
    final l = widget.language.toLowerCase();
    if (l.contains("marathi") || widget.language.contains("मराठी")) {
      langTag = "mr-IN";
    } else if (l.contains("hindi") || widget.language.contains("हिंदी")) {
      langTag = "hi-IN";
    }

    await _flutterTts.setLanguage(langTag);
    await _flutterTts.setPitch(1.0);
    await _flutterTts.setSpeechRate(0.50);

    final cleanText = _sanitizeForSpeech(text);
    if (cleanText.isEmpty) return;

    setState(() => _currentlySpeakingIndex = index);
    await _flutterTts.speak(cleanText);
  }

  void _copyToClipboard(String text) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: const Color(0xFF0F172A),
        duration: const Duration(seconds: 2),
        content: Text(_t("copied_notice"), style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
      ),
    );
  }

  Future<void> _launchMapsNavigation(String destination, {bool isWalking = false}) async {
    HapticFeedback.mediumImpact();
    await _fetchLiveLocation();

    Uri mapUri;
    if (_currentPosition != null) {
      mapUri = Uri.parse(
        "https://www.google.com/maps/dir/?api=1"
        "&origin=${_currentPosition!.latitude},${_currentPosition!.longitude}"
        "&destination=${Uri.encodeComponent(destination)}"
        "&travelmode=${isWalking ? 'walking' : 'driving'}",
      );
    } else {
      mapUri = Uri.parse("https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent(destination)}");
    }

    try {
      if (!await launchUrl(mapUri, mode: LaunchMode.externalApplication)) {
        await launchUrl(mapUri, mode: LaunchMode.platformDefault);
      }
    } catch (_) {}
  }

  Future<void> _openCurrentGpsOnMaps() async {
    HapticFeedback.mediumImpact();
    await _fetchLiveLocation();
    if (_currentPosition != null) {
      final uri = Uri.parse("https://maps.google.com/?q=${_currentPosition!.latitude},${_currentPosition!.longitude}");
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _shareRescueLocationViaWhatsApp() async {
    HapticFeedback.heavyImpact();
    await _fetchLiveLocation();
    final String latLng = _currentPosition != null
        ? "https://maps.google.com/?q=${_currentPosition!.latitude},${_currentPosition!.longitude}"
        : "near ${widget.activeCity}";

    final message = "Emergency Alert from Omni TouristOS: I need assistance. My live GPS spot: $latLng";
    await Share.share(message, subject: "Emergency Navigation Support");
  }

  void _showSetHomeBaseDialog() {
    final ctrl = TextEditingController(text: _savedHomeAddress ?? "");
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: const [
            Icon(Icons.home_rounded, color: Color(0xFF2563EB), size: 22),
            SizedBox(width: 8),
            Text("Set Home / Hotel Base", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Tell me your hotel name, stay address, or apartment. If you ever feel lost or ask for directions, I will guide you straight back here.",
              style: TextStyle(fontSize: 12.5, color: Color(0xFF475569)),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: ctrl,
              decoration: InputDecoration(
                labelText: "Hotel / Stay Address",
                hintText: "e.g., The Golden Chariot, Vasai East",
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                prefixIcon: const Icon(Icons.pin_drop_rounded, size: 20, color: Color(0xFF2563EB)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("CANCEL")),
          MetallicEmbossedButton(
            label: "SAVE BASE",
            variant: MetallicVariant.cobaltBlue,
            height: 38,
            fontSize: 12,
            onPressed: () async {
              if (ctrl.text.trim().isNotEmpty) {
                await _saveHomeAddress(ctrl.text.trim());
                Navigator.pop(ctx);
                _sendMessage("I have set my home / hotel base to: ${ctrl.text.trim()}");
              }
            },
          ),
        ],
      ),
    );
  }

  Future<void> _sendMessage(String text) async {
    final cleanText = text.trim();
    if (cleanText.isEmpty) return;

    if (_isListening) {
      await _speech.stop();
      setState(() => _isListening = false);
    }

    final lower = cleanText.toLowerCase();

    // Trigger Live Motion Engine if user asks where they are or about transit motion
    if (lower.contains("where am i") ||
        lower.contains("which station") ||
        lower.contains("what station") ||
        lower.contains("am i on train") ||
        lower.contains("train speed") ||
        lower.contains("kuthlya station") ||
        lower.contains("kaha hu") ||
        lower.contains("agla station")) {
      await _executeLiveMotionRadar();
      return;
    }

    if (lower.startsWith("my hotel is") ||
        lower.startsWith("my stay is") ||
        lower.startsWith("i live at") ||
        lower.startsWith("i am staying at") ||
        lower.startsWith("i have set my home")) {
      final extracted = cleanText.replaceFirst(RegExp(r'^(my hotel is|my stay is|i live at|i am staying at|i have set my home / hotel base to:)', caseSensitive: false), '').trim();
      if (extracted.isNotEmpty) {
        await _saveHomeAddress(extracted);
      }
    }

    final bool isLostSignal = lower.contains("lost") ||
        lower.contains("help me") ||
        lower.contains("take me home") ||
        lower.contains("navigate home") ||
        lower.contains("rasta bhatak") ||
        lower.contains("rasta chuklo");

    if (!isLostSignal) _isLostAssistanceActive = false;

    setState(() {
      _messages.add({
        "role": "user",
        "text": cleanText,
        "has_document": false,
        "is_lost_card": false,
        "is_motion_card": false,
      });
      _isTyping = true;
    });
    _msgCtrl.clear();
    _scrollToBottom();

    if (isLostSignal) {
      await _fetchLiveLocation();
      _isLostAssistanceActive = true;

      String rescueResponse;
      bool hasHome = _savedHomeAddress != null && _savedHomeAddress!.isNotEmpty;

      if (hasHome) {
        rescueResponse = "### 🛡️ Don't Worry, You Are Safe!\n\n"
            "Take a deep breath. I have pinpointed your current location.\n\n"
            "• **Live GPS Coordinates Locked**\n"
            "• **Saved Base:** ${_savedHomeAddress!}\n\n"
            "Tap **NAVIGATE HOME NOW** below to start turn-by-turn routing straight to your stay.";
      } else {
        rescueResponse = "### 🛡️ Stay Calm, You Are Safe With Me!\n\n"
            "Stand somewhere well-lit. I've locked your live GPS coordinates.\n\n"
            "**Look at your surroundings:**\n"
            "1. Can you see a large shop board, bridge, or railway station?\n"
            "2. Or tell me the hotel or building you want to reach.\n\n"
            "Type what you see, and I will navigate you immediately.";
      }

      if (mounted) {
        setState(() {
          _messages.add({
            "role": "assistant",
            "text": rescueResponse,
            "has_document": false,
            "is_lost_card": true,
            "is_motion_card": false,
            "target_destination": hasHome ? _savedHomeAddress! : widget.activeCity,
          });
          _isTyping = false;
        });
        _scrollToBottom();
      }
      return;
    }

    String? generatedAnswer;
    bool hasDoc = false;

    final historyPayload = _messages.take(12).map((m) {
      return {
        "role": m["role"] == "user" ? "user" : "assistant",
        "content": m["text"].toString(),
      };
    }).toList();

    try {
      final cleanUrl = widget.backendUrl.replaceAll(RegExp(r'/+$'), '');
      final res = await http.post(
        Uri.parse("$cleanUrl/api/v1/explore-chat"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "city": widget.activeCity,
          "question": cleanText,
          "target_language": widget.language,
          "chat_history": historyPayload,
          "saved_home_base": _savedHomeAddress ?? "",
          "current_gps": _currentPosition != null ? "${_currentPosition!.latitude},${_currentPosition!.longitude}" : "",
        }),
      ).timeout(const Duration(seconds: 18));

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final ans = data["answer"]?.toString() ?? "";
        if (ans.isNotEmpty) {
          generatedAnswer = ans;
          hasDoc = data["has_document"] ?? false;
        }
      }
    } catch (_) {}

    if (generatedAnswer == null || generatedAnswer.isEmpty) {
      generatedAnswer = "I am actively monitoring **${widget.activeCity}**! Whether you want real-time transit schedules, hidden sights, or route assistance, tell me what you need.";
    }

    final bool autoDoc = hasDoc || generatedAnswer.contains("Day 1") || generatedAnswer.contains("Day 2");

    if (mounted) {
      setState(() {
        _messages.add({
          "role": "assistant",
          "text": generatedAnswer,
          "has_document": autoDoc,
          "export_source_text": generatedAnswer,
          "is_lost_card": false,
          "is_motion_card": false,
          "target_destination": _savedHomeAddress ?? widget.activeCity,
        });
        _isTyping = false;
      });
      _scrollToBottom();
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Widget _renderConciergeTypography(String text, bool isUser) {
    if (isUser) {
      return SelectableText(
        text,
        style: const TextStyle(color: Colors.white, fontSize: 14.5, fontWeight: FontWeight.w500, height: 1.4),
      );
    }

    final lines = text.split("\n");
    final List<Widget> renderedWidgets = [];

    for (String line in lines) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) {
        renderedWidgets.add(const SizedBox(height: 6));
        continue;
      }

      if (trimmed.startsWith("### ")) {
        renderedWidgets.add(
          Padding(
            padding: const EdgeInsets.only(top: 10, bottom: 4),
            child: SelectableText(
              trimmed.replaceFirst("### ", ""),
              style: const TextStyle(fontSize: 16.0, fontWeight: FontWeight.w900, color: Color(0xFF0F172A)),
            ),
          ),
        );
      } else if (trimmed.startsWith("• ") || trimmed.startsWith("* ") || RegExp(r'^\d+\.\s').hasMatch(trimmed)) {
        final content = trimmed.replaceFirst(RegExp(r'^(•|\*|\d+\.)\s*'), '');
        final List<TextSpan> spans = [];
        final parts = content.split("**");

        for (int i = 0; i < parts.length; i++) {
          if (parts[i].isEmpty) continue;
          final isBold = i % 2 == 1;
          spans.add(
            TextSpan(
              text: parts[i],
              style: TextStyle(
                fontWeight: isBold ? FontWeight.w800 : FontWeight.w400,
                color: isBold ? const Color(0xFF0F172A) : const Color(0xFF334155),
                fontSize: 13.5,
                height: 1.45,
              ),
            ),
          );
        }

        renderedWidgets.add(
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("• ", style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF2563EB))),
                Expanded(child: SelectableText.rich(TextSpan(children: spans))),
              ],
            ),
          ),
        );
      } else {
        final List<TextSpan> spans = [];
        final parts = line.split("**");

        for (int i = 0; i < parts.length; i++) {
          if (parts[i].isEmpty) continue;
          final isBold = i % 2 == 1;
          spans.add(
            TextSpan(
              text: parts[i],
              style: TextStyle(
                fontWeight: isBold ? FontWeight.w800 : FontWeight.w400,
                color: isBold ? const Color(0xFF0F172A) : const Color(0xFF334155),
                fontSize: 13.5,
                height: 1.45,
              ),
            ),
          );
        }

        renderedWidgets.add(
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: SelectableText.rich(TextSpan(children: spans)),
          ),
        );
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: renderedWidgets,
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final topInset = MediaQuery.of(context).padding.top;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final systemNavInset = MediaQuery.of(context).padding.bottom;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        systemNavigationBarColor: Colors.transparent,
        systemNavigationBarIconBrightness: Brightness.dark,
      ),
      child: Scaffold(
        backgroundColor: const Color(0xFFF8FAFC),
        body: Column(
          children: [
            // Borderless Canvas Header ($y = 0$)
            Container(
              padding: EdgeInsets.fromLTRB(16, topInset + 6, 16, 10),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                border: Border(bottom: BorderSide(color: const Color(0xFFE2E8F0).withOpacity(0.6), width: 0.6)),
              ),
              child: Row(
                children: [
                  InkWell(
                    onTap: () => Navigator.of(context).pop(),
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFE2E8F0), width: 0.6),
                      ),
                      child: const Icon(Icons.arrow_back_rounded, color: Color(0xFF0F172A), size: 20),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text("CONCIERGE & RADAR", style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Color(0xFF64748B), letterSpacing: 0.5)),
                        Text(_t("header_title"), style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: Color(0xFF0F172A)), maxLines: 1, overflow: TextOverflow.ellipsis),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: "Set Base Hotel",
                    icon: const Icon(Icons.home_work_rounded, color: Color(0xFF2563EB), size: 22),
                    onPressed: _showSetHomeBaseDialog,
                  ),
                ],
              ),
            ),

            // Interactive Quick Command Chips
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              child: Row(
                children: [
                  // Prominent Live Motion Radar Trigger
                  ActionChip(
                    backgroundColor: const Color(0xFFEFF6FF),
                    side: const BorderSide(color: Color(0xFFBFDBFE), width: 0.8),
                    label: Row(
                      children: [
                        const Icon(Icons.radar_rounded, size: 14, color: Color(0xFF2563EB)),
                        const SizedBox(width: 4),
                        Text(_t("chip_where_am_i"), style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w900, color: Color(0xFF1E40AF))),
                      ],
                    ),
                    onPressed: _executeLiveMotionRadar,
                  ),
                  const SizedBox(width: 6),
                  ActionChip(
                    backgroundColor: const Color(0xFFFEF2F2),
                    side: const BorderSide(color: Color(0xFFFCA5A5)),
                    label: Text(_t("chip_lost"), style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w900, color: Color(0xFFDC2626))),
                    onPressed: () => _sendMessage("I am lost! Please guide me and help me find my way."),
                  ),
                  const SizedBox(width: 6),
                  ActionChip(
                    backgroundColor: Colors.white,
                    side: const BorderSide(color: Color(0xFFE2E8F0)),
                    label: Text(_t("chip_plan"), style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: Color(0xFF334155))),
                    onPressed: () => _sendMessage("I'd like to plan a trip to ${widget.activeCity}. Can you guide me?"),
                  ),
                  const SizedBox(width: 6),
                  ActionChip(
                    backgroundColor: Colors.white,
                    side: const BorderSide(color: Color(0xFFE2E8F0)),
                    label: Text(_t("chip_food"), style: const TextStyle(fontSize: 11.5, color: Color(0xFF334155))),
                    onPressed: () => _sendMessage("What are the most famous local dishes and budget eateries in ${widget.activeCity}?"),
                  ),
                ],
              ),
            ),

            // Dialogue & Motion Stream
            Expanded(
              child: ListView.builder(
                controller: _scrollCtrl,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                itemCount: _messages.length,
                itemBuilder: (ctx, i) {
                  final msg = _messages[i];
                  final isUser = msg["role"] == "user";
                  final isMotionCard = msg["is_motion_card"] == true;
                  final isLostCard = msg["is_lost_card"] == true;
                  final isSpeaking = _currentlySpeakingIndex == i;

                  return Align(
                    alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.90),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: isUser
                            ? const Color(0xFF2563EB)
                            : (isMotionCard ? const Color(0xFFF0FDF4) : (isLostCard ? const Color(0xFFFFFBEB) : Colors.white)),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: isUser
                              ? const Color(0xFF1D4ED8)
                              : (isMotionCard ? const Color(0xFFBBF7D0) : (isLostCard ? const Color(0xFFFDE68A) : const Color(0xFFE2E8F0))),
                          width: 0.6,
                        ),
                        boxShadow: [
                          BoxShadow(color: Colors.black.withOpacity(0.015), blurRadius: 6, offset: const Offset(0, 2)),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _renderConciergeTypography(msg["text"], isUser),

                          // Live Radar Telemetry Cockpit Card
                          if (isMotionCard && !isUser) ...[
                            const SizedBox(height: 12),
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(color: const Color(0xFF86EFAC), width: 0.8),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: const [
                                      Icon(Icons.navigation_rounded, color: Color(0xFF16A34A), size: 16),
                                      SizedBox(width: 6),
                                      Text("TRANSIT RADAR LOCK", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 11, color: Color(0xFF15803D))),
                                    ],
                                  ),
                                  const SizedBox(height: 10),
                                  SizedBox(
                                    width: double.infinity,
                                    height: 46,
                                    child: ElevatedButton.icon(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: const Color(0xFF16A34A),
                                        foregroundColor: Colors.white,
                                        elevation: 0,
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                      ),
                                      icon: const Icon(Icons.map_rounded, size: 16),
                                      label: const Text("VIEW LIVE POSITION ON MAP", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                                      onPressed: _openCurrentGpsOnMaps,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],

                          if (isLostCard && !isUser) ...[
                            const SizedBox(height: 12),
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(color: const Color(0xFFFCD34D)),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (_savedHomeAddress != null && _savedHomeAddress!.isNotEmpty) ...[
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
                                        icon: const Icon(Icons.directions_walk_rounded, size: 18),
                                        label: const Text("NAVIGATE HOME NOW (GPS)", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5)),
                                        onPressed: () => _launchMapsNavigation(_savedHomeAddress!, isWalking: true),
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                  ],
                                  Row(
                                    children: [
                                      Expanded(
                                        child: SizedBox(
                                          height: 46,
                                          child: OutlinedButton.icon(
                                            style: OutlinedButton.styleFrom(
                                              foregroundColor: const Color(0xFF0F172A),
                                              side: const BorderSide(color: Color(0xFFCBD5E1)),
                                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                            ),
                                            icon: const Icon(Icons.my_location_rounded, size: 16, color: Color(0xFF2563EB)),
                                            label: const Text("Current Pin", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11.5)),
                                            onPressed: _openCurrentGpsOnMaps,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: SizedBox(
                                          height: 46,
                                          child: ElevatedButton.icon(
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: const Color(0xFF0F172A),
                                              foregroundColor: Colors.white,
                                              elevation: 0,
                                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                            ),
                                            icon: const Icon(Icons.share_location_rounded, size: 16),
                                            label: const Text("Share SOS", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11.5)),
                                            onPressed: _shareRescueLocationViaWhatsApp,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],

                          if (!isUser) ...[
                            const SizedBox(height: 10),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                InkWell(
                                  onTap: () => _toggleTts(i, msg["text"]),
                                  borderRadius: BorderRadius.circular(6),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: isSpeaking ? const Color(0xFFFEE2E2) : const Color(0xFFEFF6FF),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Row(
                                      children: [
                                        Icon(isSpeaking ? Icons.stop_circle_rounded : Icons.volume_up_rounded, size: 13, color: isSpeaking ? const Color(0xFFDC2626) : const Color(0xFF2563EB)),
                                        const SizedBox(width: 4),
                                        Text(isSpeaking ? _t("stop_text") : _t("listen_text"), style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: isSpeaking ? const Color(0xFFDC2626) : const Color(0xFF2563EB))),
                                      ],
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                InkWell(
                                  onTap: () => _copyToClipboard(msg["text"]),
                                  borderRadius: BorderRadius.circular(6),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(6)),
                                    child: Row(
                                      children: [
                                        const Icon(Icons.copy_rounded, size: 12, color: Color(0xFF64748B)),
                                        const SizedBox(width: 4),
                                        Text(_t("copy_text"), style: const TextStyle(fontSize: 10.5, color: Color(0xFF64748B), fontWeight: FontWeight.bold)),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),

            if (_isTyping)
              Padding(
                padding: const EdgeInsets.only(left: 20, bottom: 8),
                child: Row(
                  children: [
                    const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF2563EB))),
                    const SizedBox(width: 8),
                    Text(_t("typing_prefix"), style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B), fontWeight: FontWeight.w600)),
                  ],
                ),
              ),

            // Standardized Chat Input Cockpit
            Container(
              padding: EdgeInsets.fromLTRB(14, 8, 14, bottomInset > 0 ? bottomInset + 8 : systemNavInset + 12),
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(top: BorderSide(color: Color(0xFFE2E8F0), width: 0.6)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _msgCtrl,
                      style: const TextStyle(fontSize: 14),
                      decoration: InputDecoration(
                        hintText: _isListening ? "Listening..." : _t("hint_text"),
                        hintStyle: TextStyle(fontSize: 12.5, color: _isListening ? const Color(0xFFDC2626) : const Color(0xFF94A3B8)),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: const BorderSide(color: Color(0xFFE2E8F0), width: 0.6)),
                        filled: true,
                        fillColor: const Color(0xFFF8FAFC),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        isDense: true,
                      ),
                      onSubmitted: _sendMessage,
                    ),
                  ),
                  const SizedBox(width: 6),
                  CircleAvatar(
                    backgroundColor: _isListening ? const Color(0xFFDC2626) : const Color(0xFFEFF6FF),
                    radius: 19,
                    child: IconButton(
                      icon: Icon(_isListening ? Icons.mic : Icons.mic_none_rounded, size: 18, color: _isListening ? Colors.white : const Color(0xFF2563EB)),
                      onPressed: _toggleListening,
                    ),
                  ),
                  const SizedBox(width: 6),
                  CircleAvatar(
                    backgroundColor: const Color(0xFF2563EB),
                    radius: 19,
                    child: IconButton(
                      icon: const Icon(Icons.arrow_upward_rounded, size: 18, color: Colors.white),
                      onPressed: () => _sendMessage(_msgCtrl.text),
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
}