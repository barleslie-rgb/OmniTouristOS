import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'touristos_explorer_screen.dart';

class PaperPilotScreen extends StatefulWidget {
  final String language;
  final String backendUrl;
  final Function(String)? onDestinationDiscovered;

  const PaperPilotScreen({
    Key? key,
    required this.language,
    this.backendUrl = "https://omni-backend-pk28.onrender.com",
    this.onDestinationDiscovered,
  }) : super(key: key);

  static void stopActiveSpeech() {
    _PaperPilotScreenState.globalStopTts();
  }

  @override
  State<PaperPilotScreen> createState() => _PaperPilotScreenState();
}

class _PaperPilotScreenState extends State<PaperPilotScreen>
    with WidgetsBindingObserver {
  File? _selectedFile;
  Uint8List? _fileBytes;
  String? _selectedFileName;
  int _selectedFileSize = 0;
  bool _isImageFile = false;

  bool _isAnalyzing = false;
  String? _analysisReport;
  String? _detectedDestination;
  List<String> _suggestions = [];
  String? _errorMessage;

  bool _showQuickTip = true;

  final TextEditingController _chatController = TextEditingController();
  final List<Map<String, String>> _chatMessages = [];
  bool _isChatLoading = false;

  static FlutterTts? _activeTtsInstance;
  late FlutterTts _flutterTts;
  bool _isSpeaking = false;
  late stt.SpeechToText _speech;

  final ImagePicker _imagePicker = ImagePicker();

  List<Map<String, dynamic>> _recentScans = [];
  static const String _scansStorageKey = "paper_pilot_recent_scans";

  static const Map<String, Map<String, String>> _dict = {
    "English": {
      "title": "Document Audit",
      "subtitle": "Audit legal liabilities, examine land records (7/12), notices, and stamp papers.",
      "quick_tip_title": "Quick Tip",
      "quick_tip_body": "Make sure the document is well lit and placed on a flat surface for the best results.",
      "camera": "Camera",
      "pick_file": "Pick File",
      "scan_btn": "Scan & Audit Document",
      "auditing_btn": "Auditing Document...",
      "recent_scans": "Recent Scans",
      "clear_all": "Clear All",
      "ready_size": "Size: {size} KB • Ready for Forensic Audit",
      "forensic_report": "Forensic Audit & Legal Breakdown",
      "audio_ready": "Audio Reader Ready",
      "audio_active": "Audio playback active...",
      "listen": "Listen",
      "stop": "Mute / Stop",
      "report_copied": "Report copied to clipboard.",
      "directives": "Explore & Verify Directives:",
      "chat_header": "Inquiry & Dialogue:",
      "chat_hint": "Ask anything about this document...",
      "select_error": "Please select or capture a document first.",
    },
    "Marathi": {
      "title": "दस्तऐवज तपासणी",
      "subtitle": "कायदेशीर कागदपत्रे, ७/१२, नोटिसा, मुद्रांक व पुरावे तपासा.",
      "quick_tip_title": "महत्त्वाची टीप",
      "quick_tip_body": "उत्तम तपासणीसाठी कागदपत्र सपाट पृष्ठभागावर ठेवा आणि पुरेसा प्रकाश असल्याची खात्री करा.",
      "camera": "कॅमेरा",
      "pick_file": "फाईल निवडा",
      "scan_btn": "कागदपत्र स्कॅन व तपासणी करा",
      "auditing_btn": "तपासणी सुरू आहे...",
      "recent_scans": "अलीकडील स्कॅन",
      "clear_all": "सर्व हटवा",
      "ready_size": "आकार: {size} KB • तपासणीसाठी सज्ज",
      "forensic_report": "न्यायवैद्यक व कायदेशीर तपासणी अहवाल",
      "audio_ready": "वाचून ऐकण्यासाठी तयार",
      "audio_active": "वाचन सुरू आहे...",
      "listen": "ऐका (Speak)",
      "stop": "थांबवा (Mute)",
      "report_copied": "अहवाल कॉपी केला.",
      "directives": "पुढील मार्गदर्शक सूचना:",
      "chat_header": "कागदपत्र संवाद व प्रश्नोत्तरे:",
      "chat_hint": "या कागदपत्राबद्दल कोणताही प्रश्न विचारा...",
      "select_error": "कृपया आधी कागदपत्र निवडा किंवा फोटो काढा.",
    },
    "Hindi": {
      "title": "दस्तावेज़ फोरेंसिक ऑडिट",
      "subtitle": "कानूनी दस्तावेज, 7/12, नोटिस और स्टाम्प पेपर की जांच करें।",
      "quick_tip_title": "त्वरित सलाह",
      "quick_tip_body": "सर्वोत्तम परिणामों के लिए दस्तावेज़ को समतल सतह पर रखें और पर्याप्त रोशनी सुनिश्चित करें।",
      "camera": "कैमरा",
      "pick_file": "फ़ाइल चुनें",
      "scan_btn": "दस्तावेज़ स्कैन और जांचें",
      "auditing_btn": "जांच चल रही है...",
      "recent_scans": "हाल के स्कैन",
      "clear_all": "सभी हटाएं",
      "ready_size": "आकार: {size} KB • ऑडिट के लिए तैयार",
      "forensic_report": "फोरेंसिक ऑडिट और कानूनी विश्लेषण",
      "audio_ready": "ऑडियो सुनने के लिए तैयार",
      "audio_active": "ऑडियो चल रहा है...",
      "listen": "रिपोर्ट सुनें",
      "stop": "म्यूट / बंद करें",
      "report_copied": "रिपोर्ट कॉपी की गई।",
      "directives": "आगे के निर्देश व सुझाव:",
      "chat_header": "दस्तावेज़ पूछताछ व संवाद:",
      "chat_hint": "इस दस्तावेज़ के बारे में कुछ भी पूछें...",
      "select_error": "कृपया पहले दस्तावेज़ चुनें या फोटो लें।",
    },
    "Gujarati": {
      "title": "ફોરેન્સિક દસ્તાવેજ તપાસ",
      "subtitle": "કાનૂની દસ્તાવેજો, 7/12, નોટિસ અને સ્ટેમ્પ પેપરનું નિરીક્ષણ કરો.",
      "quick_tip_title": "ઝડપી ટીપ",
      "quick_tip_body": "શ્રેષ્ઠ પરિણામો માટે દસ્તાવેજ સપાટ સપાટી પર રાખો અને પૂરતો પ્રકાશ હોવાની ખાતરી કરો.",
      "camera": "કેમેરા",
      "pick_file": "ફાઇલ પસંદ કરો",
      "scan_btn": "દસ્તાવેજ સ્કેન અને તપાસ કરો",
      "auditing_btn": "તપાસ ચાલુ છે...",
      "recent_scans": "તાજેતરના સ્કેન",
      "clear_all": "બધું સાફ કરો",
      "ready_size": "કદ: {size} KB • તપાસ માટે તૈયાર",
      "forensic_report": "ફોરેન્સિક ઑડિટ અને કાનૂની અહેવાલ",
      "audio_ready": "ઓડિયો સાંભળવા માટે તૈયાર",
      "audio_active": "ઓડિયો ચાલુ છે...",
      "listen": "સાંભળો",
      "stop": "બંધ કરો",
      "report_copied": "અહેવાલ કોપી કર્યો.",
      "directives": "આગળની માર્ગદર્શિકા:",
      "chat_header": "દસ્તાવેજ પ્રશ્નોત્તરી:",
      "chat_hint": "આ દસ્તાવેજ વિશે કંઈપણ પૂછો...",
      "select_error": "કૃપા કરીને પહેલા દસ્તાવેજ પસંદ કરો.",
    },
  };

  String _t(String key) {
    final lang = widget.language.trim();
    if (_dict.containsKey(lang) && _dict[lang]!.containsKey(key)) {
      return _dict[lang]![key]!;
    }
    return _dict["English"]![key] ?? key;
  }

  static void globalStopTts() {
    try {
      _activeTtsInstance?.stop();
    } catch (_) {}
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initTts();
    _speech = stt.SpeechToText();
    _loadPersistedScans();
  }

  Future<void> _loadPersistedScans() async {
    final prefs = await SharedPreferences.getInstance();
    final rawJson = prefs.getString(_scansStorageKey);
    if (rawJson != null && rawJson.isNotEmpty) {
      try {
        final List<dynamic> decoded = jsonDecode(rawJson);
        setState(() {
          _recentScans = decoded.map((e) => Map<String, dynamic>.from(e)).toList();
        });
      } catch (_) {}
    }
  }

  Future<void> _saveScannedDocumentRecord({
    required String fileName,
    required String report,
    String? destination,
    List<String>? directives,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now();
    final dateFormatted = "${_getMonthName(now.month)} ${now.day}, ${now.year}";

    String docType = "Audit Report";
    final lowerReport = report.toLowerCase();
    if (lowerReport.contains("7/12") || lowerReport.contains("सातबारा")) {
      docType = "7/12 Record";
    } else if (lowerReport.contains("stamp") || lowerReport.contains("मुद्रांक")) {
      docType = "Stamp Paper";
    } else if (lowerReport.contains("notice") || lowerReport.contains("नोटीस")) {
      docType = "Legal Notice";
    } else if (lowerReport.contains("power of attorney") || lowerReport.contains("कुलमुखत्यारपत्र")) {
      docType = "Power of Attorney";
    }

    final newRecord = {
      "id": DateTime.now().millisecondsSinceEpoch.toString(),
      "name": fileName,
      "type": docType,
      "date": dateFormatted,
      "report": report,
      "detected_destination": destination,
      "suggestions": directives ?? [],
      "status": "Audited",
    };

    setState(() {
      _recentScans.removeWhere((item) => item["name"] == fileName);
      _recentScans.insert(0, newRecord);
      if (_recentScans.length > 15) {
        _recentScans = _recentScans.sublist(0, 15);
      }
    });

    await prefs.setString(_scansStorageKey, jsonEncode(_recentScans));
  }

  Future<void> _clearAllRecentScans() async {
    final shouldClear = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text("Clear Scanned Records?", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        content: const Text("This will permanently clear your local scan history and saved forensic reports."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("Cancel")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFDC2626),
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text("Clear All"),
          ),
        ],
      ),
    );

    if (shouldClear == true) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_scansStorageKey);
      setState(() {
        _recentScans.clear();
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Scan history cleared.")),
      );
    }
  }

  void _restoreHistoricalScan(Map<String, dynamic> item) {
    _stopSpeech();
    setState(() {
      _selectedFileName = item["name"];
      _analysisReport = item["report"];
      _detectedDestination = item["detected_destination"];
      _suggestions = List<String>.from(item["suggestions"] ?? []);
      _errorMessage = null;
      _chatMessages.clear();
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: const Color(0xFF2563EB),
        content: Text("Restored: ${item['name']}"),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  static String _getMonthName(int m) {
    const months = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"];
    return months[m - 1];
  }

  void _initTts() {
    _flutterTts = FlutterTts();
    _activeTtsInstance = _flutterTts;

    _flutterTts.setStartHandler(() {
      if (mounted) setState(() => _isSpeaking = true);
    });

    _flutterTts.setCompletionHandler(() {
      if (mounted) setState(() => _isSpeaking = false);
    });

    _flutterTts.setCancelHandler(() {
      if (mounted) setState(() => _isSpeaking = false);
    });

    _flutterTts.setErrorHandler((msg) {
      if (mounted) setState(() => _isSpeaking = false);
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive) {
      _stopSpeech();
    }
  }

  Future<void> _configureTtsForLanguage() async {
    final lang = widget.language.toLowerCase().trim();

    final Map<String, String> localeMap = {
      "marathi": "mr-IN",
      "मराठी": "mr-IN",
      "hindi": "hi-IN",
      "हिंदी": "hi-IN",
      "gujarati": "gu-IN",
      "ગુજરાતી": "gu-IN",
      "tamil": "ta-IN",
      "தமிழ்": "ta-IN",
      "telugu": "te-IN",
      "తెలుగు": "te-IN",
      "kannada": "kn-IN",
      "ಕನ್ನಡ": "kn-IN",
      "bengali": "bn-IN",
      "বাংলা": "bn-IN",
      "malayalam": "ml-IN",
      "മലയാളം": "ml-IN",
      "punjabi": "pa-IN",
      "ਪੰਜਾਬੀ": "pa-IN",
      "spanish": "es-ES",
      "español": "es-ES",
      "french": "fr-FR",
      "français": "fr-FR",
      "german": "de-DE",
      "deutsch": "de-DE",
      "arabic": "ar-SA",
      "العربية": "ar-SA",
      "english": "en-IN",
    };

    String selectedLocale = "en-US";
    for (final entry in localeMap.entries) {
      if (lang.contains(entry.key)) {
        selectedLocale = entry.value;
        break;
      }
    }

    await _flutterTts.setLanguage(selectedLocale);
    await _flutterTts.setPitch(1.0);
    await _flutterTts.setSpeechRate(0.48);
  }

  @override
  void didUpdateWidget(covariant PaperPilotScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.language != widget.language && _analysisReport != null) {
      _stopSpeech();
      _retranslateActiveReport();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _stopSpeech();
    _chatController.dispose();
    super.dispose();
  }

  Future<void> _stopSpeech() async {
    try {
      await _flutterTts.stop();
    } catch (_) {}
    if (mounted) {
      setState(() => _isSpeaking = false);
    }
  }

  Future<void> _startSpeech() async {
    if (_analysisReport == null || _analysisReport!.isEmpty) return;
    await _stopSpeech();
    await _configureTtsForLanguage();

    final cleanSpoken = _analysisReport!
        .replaceAll(RegExp(r'[*#_`|]'), '')
        .replaceAll(RegExp(r'🚨\s*\[.*?\]:'), 'Warning:')
        .trim();

    if (mounted) setState(() => _isSpeaking = true);
    await _flutterTts.speak(cleanSpoken);
  }

  Future<void> _captureFromCamera() async {
    _stopSpeech();
    try {
      final XFile? photo = await _imagePicker.pickImage(
        source: ImageSource.camera,
        maxWidth: 1600,
        maxHeight: 1600,
        imageQuality: 88,
      );

      if (photo != null) {
        final bytes = await photo.readAsBytes();
        setState(() {
          _selectedFile = File(photo.path);
          _fileBytes = bytes;
          _selectedFileName = photo.name.isNotEmpty
              ? photo.name
              : "Camera_Capture_${DateTime.now().millisecondsSinceEpoch}.jpg";
          _selectedFileSize = bytes.length;
          _isImageFile = true;
          _errorMessage = null;
        });
      }
    } catch (e) {
      setState(() => _errorMessage = "Camera error: $e");
    }
  }

  Future<void> _pickDocumentFile() async {
    _stopSpeech();
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: [
          'pdf',
          'jpg',
          'jpeg',
          'png',
          'webp',
          'docx',
          'xlsx',
          'pptx',
          'txt',
          'csv'
        ],
        withData: true,
      );

      if (result != null && result.files.isNotEmpty) {
        final file = result.files.first;
        final ext = (file.extension ?? "").toLowerCase();
        final isImg = ['jpg', 'jpeg', 'png', 'webp'].contains(ext);

        setState(() {
          _selectedFileName = file.name;
          _selectedFileSize = file.size;
          _fileBytes = file.bytes;
          if (file.path != null) {
            _selectedFile = File(file.path!);
          }
          _isImageFile = isImg;
          _errorMessage = null;
        });
      }
    } catch (e) {
      setState(() => _errorMessage = "File selection error: $e");
    }
  }

  Future<void> _analyzeDocument() async {
    _stopSpeech();
    if (_fileBytes == null && _selectedFile == null) {
      setState(() => _errorMessage = _t("select_error"));
      return;
    }

    setState(() {
      _isAnalyzing = true;
      _errorMessage = null;
      _analysisReport = null;
      _detectedDestination = null;
      _suggestions.clear();
      _chatMessages.clear();
    });

    try {
      final cleanBaseUrl = widget.backendUrl.replaceAll(RegExp(r'/+$'), '');
      final uri = Uri.parse("$cleanBaseUrl/api/v1/analyze-document");

      var request = http.MultipartRequest("POST", uri);
      request.fields["target_language"] = widget.language;

      if (_fileBytes != null) {
        request.files.add(
          http.MultipartFile.fromBytes(
            'file',
            _fileBytes!,
            filename: _selectedFileName ?? "document.pdf",
          ),
        );
      } else if (_selectedFile != null) {
        request.files.add(
          await http.MultipartFile.fromPath(
            'file',
            _selectedFile!.path,
            filename: _selectedFileName ?? "document.pdf",
          ),
        );
      }

      final streamedResponse =
          await request.send().timeout(const Duration(seconds: 45));
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data["status"] == "success") {
          final resData = data["data"] ?? {};
          final reportText = resData["actionable_advisory"] ??
              data["raw_text"] ??
              "Analysis completed.";
          final detectedDest = resData["detected_destination"];
          final directives = List<String>.from(resData["suggestions"] ?? []);

          setState(() {
            _analysisReport = reportText;
            _detectedDestination = detectedDest;
            _suggestions = directives;
          });

          await _saveScannedDocumentRecord(
            fileName: _selectedFileName ?? "Scanned_Document.pdf",
            report: reportText,
            destination: detectedDest,
            directives: directives,
          );

          if (_detectedDestination != null &&
              widget.onDestinationDiscovered != null) {
            widget.onDestinationDiscovered!(_detectedDestination!);
          }
        } else {
          setState(() => _errorMessage =
              data["message"] ?? "Analysis could not be completed.");
        }
      } else {
        setState(() =>
            _errorMessage = "Server returned error: ${response.statusCode}");
      }
    } catch (e) {
      setState(() => _errorMessage = "Scan error: $e");
    } finally {
      if (mounted) setState(() => _isAnalyzing = false);
    }
  }

  Future<void> _retranslateActiveReport() async {
    if (_analysisReport == null) return;
    setState(() => _isAnalyzing = true);

    try {
      final cleanBaseUrl = widget.backendUrl.replaceAll(RegExp(r'/+$'), '');
      final res = await http.post(
        Uri.parse("$cleanBaseUrl/api/v1/translate-report"),
        body: {
          "report_text": _analysisReport!,
          "target_language": widget.language,
        },
      ).timeout(const Duration(seconds: 25));

      if (res.statusCode == 200) {
        final d = jsonDecode(res.body);
        if (d["status"] == "success") {
          setState(() => _analysisReport = d["translated_report"]);
        }
      }
    } catch (_) {
    } finally {
      if (mounted) setState(() => _isAnalyzing = false);
    }
  }

  Future<void> _sendQuestion(String query) async {
    _stopSpeech();
    if (query.trim().isEmpty) return;
    final userQ = query.trim();
    _chatController.clear();

    setState(() {
      _chatMessages.add({"sender": "user", "text": userQ});
      _isChatLoading = true;
    });

    try {
      final cleanBaseUrl = widget.backendUrl.replaceAll(RegExp(r'/+$'), '');
      final res = await http.post(
        Uri.parse("$cleanBaseUrl/api/v1/ask-question"),
        body: {
          "question": userQ,
          "target_language": widget.language,
          "active_document_context": _analysisReport ?? "",
        },
      ).timeout(const Duration(seconds: 20));

      if (res.statusCode == 200) {
        final d = jsonDecode(res.body);
        final reply = d["answer"] ?? "Query answered.";
        setState(() {
          _chatMessages.add({"sender": "ai", "text": reply});
        });
      } else {
        setState(() {
          _chatMessages.add({
            "sender": "ai",
            "text": "Server responded with code: ${res.statusCode}"
          });
        });
      }
    } catch (e) {
      setState(() {
        _chatMessages.add({"sender": "ai", "text": "Notice: $e"});
      });
    } finally {
      if (mounted) setState(() => _isChatLoading = false);
    }
  }

  List<Widget> _renderGrokContent(String rawText) {
    final List<Widget> widgets = [];
    final lines = rawText.split("\n");
    List<List<String>> tableBuffer = [];

    void flushTable() {
      if (tableBuffer.isEmpty) return;
      final headers = tableBuffer.first;
      final rows = tableBuffer.skip(1).toList();

      widgets.add(
        Container(
          margin: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFCBD5E1)),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: Table(
              border: TableBorder(
                  horizontalInside:
                      BorderSide(color: Colors.grey.shade200, width: 1)),
              children: [
                TableRow(
                  decoration: const BoxDecoration(color: Color(0xFFF1F5F9)),
                  children: headers
                      .map((h) => Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 10),
                            child: Text(
                              h.trim(),
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                  color: Color(0xFF0F172A)),
                            ),
                          ))
                      .toList(),
                ),
                ...rows.map(
                  (r) => TableRow(
                    children: r
                        .map((c) => Padding(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 10),
                              child: Text(
                                c.trim(),
                                style: const TextStyle(
                                    fontSize: 15,
                                    height: 1.45,
                                    color: Color(0xFF1E293B)),
                              ),
                            ))
                        .toList(),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
      tableBuffer = [];
    }

    for (int i = 0; i < lines.length; i++) {
      final line = lines[i].trimRight();
      final trimmed = line.trim();

      if (trimmed.startsWith("|") && trimmed.endsWith("|")) {
        if (RegExp(r'^\|[\s\-:|]+\|$').hasMatch(trimmed)) continue;
        final cols = trimmed.split("|").where((c) => c.isNotEmpty).toList();
        if (cols.isNotEmpty) {
          tableBuffer.add(cols);
          continue;
        }
      } else {
        flushTable();
      }

      if (trimmed.isEmpty) {
        widgets.add(const SizedBox(height: 8));
        continue;
      }

      if (trimmed.contains("🚨") ||
          trimmed.contains("[SUSPICIOUS / RISK]") ||
          trimmed.contains("[धोका / कायदेशीर जोखीम]") ||
          trimmed.contains("[जोखिम / कानूनी दायित्व]")) {
        widgets.add(
          Container(
            margin: const EdgeInsets.symmetric(vertical: 8),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFFEF2F2),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFF87171), width: 1.2),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("🚨 ", style: TextStyle(fontSize: 20)),
                Expanded(
                  child: Text(
                    trimmed.replaceAll("🚨", "").trim(),
                    style: const TextStyle(
                        color: Color(0xFFB91C1C),
                        fontWeight: FontWeight.w700,
                        fontSize: 15.5,
                        height: 1.45),
                  ),
                ),
              ],
            ),
          ),
        );
        continue;
      }

      if (trimmed.startsWith("###") ||
          trimmed.startsWith("##") ||
          trimmed.startsWith("#")) {
        final hTitle =
            trimmed.replaceAll(RegExp(r'^#+\s*'), '').replaceAll("**", "");
        widgets.add(
          Padding(
            padding: const EdgeInsets.only(top: 16, bottom: 6),
            child: Text(
              hTitle,
              style: const TextStyle(
                fontSize: 18.5,
                fontWeight: FontWeight.w800,
                color: Color(0xFF0F172A),
                letterSpacing: -0.3,
              ),
            ),
          ),
        );
        continue;
      }

      if (trimmed.startsWith("•") ||
          trimmed.startsWith("-") ||
          trimmed.startsWith("*")) {
        final rawBullet = trimmed.substring(1).trim();
        widgets.add(
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.only(top: 3),
                  child: Text("• ",
                      style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF2563EB))),
                ),
                Expanded(child: _renderInlineBold(rawBullet)),
              ],
            ),
          ),
        );
        continue;
      }

      widgets.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: _renderInlineBold(trimmed),
        ),
      );
    }

    flushTable();
    return widgets;
  }

  Widget _renderInlineBold(String text) {
    final List<TextSpan> spans = [];
    final parts = text.split("**");

    for (int i = 0; i < parts.length; i++) {
      if (parts[i].isEmpty) continue;
      final isBold = i % 2 == 1;
      spans.add(
        TextSpan(
          text: parts[i],
          style: TextStyle(
            fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
            color: isBold ? const Color(0xFF0F172A) : const Color(0xFF334155),
            fontSize: 16,
            height: 1.55,
          ),
        ),
      );
    }
    return SelectableText.rich(TextSpan(children: spans));
  }

  Widget _buildTopPreviewCard() {
    if (_selectedFileName == null) return const SizedBox.shrink();

    final sizeKb = (_selectedFileSize / 1024).toStringAsFixed(1);
    final isPdf = _selectedFileName!.toLowerCase().endsWith(".pdf");

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFCBD5E1)),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 8,
              offset: const Offset(0, 2)),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: _isImageFile && _fileBytes != null
                ? Image.memory(
                    _fileBytes!,
                    width: 64,
                    height: 64,
                    fit: BoxFit.cover,
                  )
                : Container(
                    width: 64,
                    height: 64,
                    color: isPdf
                        ? const Color(0xFFFEF2F2)
                        : const Color(0xFFEFF6FF),
                    child: Icon(
                      isPdf
                          ? Icons.picture_as_pdf_rounded
                          : Icons.description_rounded,
                      color: isPdf
                          ? const Color(0xFFDC2626)
                          : const Color(0xFF2563EB),
                      size: 34,
                    ),
                  ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _selectedFileName!,
                  style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                      color: Color(0xFF0F172A)),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  _t("ready_size").replaceAll("{size}", sizeKb),
                  style:
                      const TextStyle(fontSize: 12.5, color: Color(0xFF64748B)),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close_rounded, size: 22, color: Colors.grey),
            onPressed: () {
              _stopSpeech();
              setState(() {
                _selectedFile = null;
                _fileBytes = null;
                _selectedFileName = null;
                _selectedFileSize = 0;
                _isImageFile = false;
                _analysisReport = null;
              });
            },
          ),
        ],
      ),
    );
  }

  Widget _buildQuickTipBanner() {
    if (!_showQuickTip || _analysisReport != null) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF0FDF4),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFBBF7D0)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: const BoxDecoration(
              color: Color(0xFFDCFCE7),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.lightbulb_rounded, color: Color(0xFF16A34A), size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _t("quick_tip_title"),
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF166534),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _t("quick_tip_body"),
                  style: const TextStyle(
                    fontSize: 11.5,
                    color: Color(0xFF14532D),
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close_rounded, size: 18, color: Color(0xFF15803D)),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            onPressed: () {
              setState(() => _showQuickTip = false);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildRecentScansTray() {
    if (_analysisReport != null) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              _t("recent_scans"),
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: Color(0xFF0F172A),
              ),
            ),
            if (_recentScans.isNotEmpty)
              InkWell(
                onTap: _clearAllRecentScans,
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                  child: Text(
                    _t("clear_all"),
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFFDC2626),
                    ),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 10),
        if (_recentScans.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: const [
                Icon(Icons.history_rounded, size: 18, color: Color(0xFF94A3B8)),
                SizedBox(width: 8),
                Text(
                  "No audited records yet. Scanned docs will appear here.",
                  style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                ),
              ],
            ),
          )
        else
          SizedBox(
            height: 96,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _recentScans.length,
              separatorBuilder: (_, __) => const SizedBox(width: 10),
              itemBuilder: (context, index) {
                final item = _recentScans[index];
                final isPdf = (item["name"] ?? "").toString().toLowerCase().endsWith(".pdf");

                return InkWell(
                  onTap: () => _restoreHistoricalScan(item),
                  borderRadius: BorderRadius.circular(14),
                  child: Container(
                    width: 230,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.02),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: isPdf ? const Color(0xFFFEF2F2) : const Color(0xFFEFF6FF),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(
                                isPdf ? Icons.picture_as_pdf_rounded : Icons.description_rounded,
                                size: 16,
                                color: isPdf ? const Color(0xFFDC2626) : const Color(0xFF2563EB),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                item["name"] ?? "Document",
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF1E293B),
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              "${item["type"]} • ${item["date"]}",
                              style: const TextStyle(fontSize: 10.5, color: Color(0xFF64748B)),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFF16A34A).withOpacity(0.12),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                item["status"] ?? "Audited",
                                style: const TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF16A34A),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
      ],
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
          _t("title"),
          style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 17, color: Color(0xFF0F172A)),
        ),
      ),
      body: SingleChildScrollView(
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        padding: EdgeInsets.fromLTRB(16, 14, 16, bottomInset + 28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildQuickTipBanner(),

            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(color: Colors.grey.shade200),
              ),
              color: Colors.white,
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                          color: const Color(0xFF2563EB).withOpacity(0.08),
                          shape: BoxShape.circle),
                      child: const Icon(Icons.document_scanner_rounded,
                          color: Color(0xFF2563EB), size: 30),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      _t("title"),
                      style: const TextStyle(
                          fontSize: 18.5, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _t("subtitle"),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          fontSize: 13.5, color: Colors.black54, height: 1.4),
                    ),
                    const SizedBox(height: 16),

                    _buildTopPreviewCard(),

                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10)),
                              side: const BorderSide(color: Color(0xFF2563EB)),
                            ),
                            onPressed: _isAnalyzing ? null : _captureFromCamera,
                            icon: const Icon(Icons.camera_alt_rounded,
                                size: 20, color: Color(0xFF2563EB)),
                            label: Text(
                              _t("camera"),
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                  color: Color(0xFF2563EB)),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10)),
                              side: BorderSide(color: Colors.grey.shade400),
                            ),
                            onPressed: _isAnalyzing ? null : _pickDocumentFile,
                            icon: const Icon(Icons.upload_file_rounded,
                                size: 20, color: Color(0xFF334155)),
                            label: Text(
                              _t("pick_file"),
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                  color: Color(0xFF334155)),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF2563EB),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10)),
                        ),
                        onPressed: _isAnalyzing ? null : _analyzeDocument,
                        icon: _isAnalyzing
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: Colors.white))
                            : const Icon(Icons.search_rounded, size: 20),
                        label: Text(
                          _isAnalyzing ? _t("auditing_btn") : _t("scan_btn"),
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 14.5),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            _buildRecentScansTray(),

            if (_errorMessage != null) ...[
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.red.shade200),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.warning_amber_rounded,
                        color: Colors.red, size: 22),
                    const SizedBox(width: 10),
                    Expanded(
                        child: Text(_errorMessage!,
                            style: const TextStyle(
                                color: Colors.red, fontSize: 14))),
                  ],
                ),
              ),
            ],

            if (_detectedDestination != null) ...[
              const SizedBox(height: 14),
              InkWell(
                onTap: () {
                  _stopSpeech();
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => TouristOSExplorerScreen(
                        language: widget.language,
                        initialCity: _detectedDestination!.split(",")[0].trim(),
                        backendUrl: widget.backendUrl,
                      ),
                    ),
                  );
                },
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFF6FF),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFBFDBFE)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.explore_rounded,
                          color: Color(0xFF2563EB), size: 22),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          "Location mapped to $_detectedDestination in TouristOS Explorer.",
                          style: const TextStyle(
                              color: Color(0xFF1E40AF),
                              fontSize: 14,
                              fontWeight: FontWeight.bold),
                        ),
                      ),
                      const Icon(Icons.arrow_forward_ios_rounded,
                          size: 16, color: Color(0xFF2563EB)),
                    ],
                  ),
                ),
              ),
            ],

            if (_analysisReport != null) ...[
              const SizedBox(height: 18),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                  boxShadow: [
                    BoxShadow(
                        color: Colors.black.withOpacity(0.03),
                        blurRadius: 10,
                        offset: const Offset(0, 4)),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Row(
                            children: [
                              const Icon(Icons.verified_rounded,
                                  color: Color(0xFF16A34A), size: 24),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  _t("forensic_report"),
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w800,
                                      fontSize: 16.5,
                                      color: Color(0xFF0F172A)),
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.copy_rounded,
                              size: 20, color: Colors.grey),
                          onPressed: () {
                            Clipboard.setData(
                                ClipboardData(text: _analysisReport!));
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text(_t("report_copied"))),
                            );
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: _isSpeaking
                            ? const Color(0xFFFEF2F2)
                            : const Color(0xFFF0FDF4),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: _isSpeaking
                              ? const Color(0xFFFCA5A5)
                              : const Color(0xFFBBF7D0),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            _isSpeaking
                                ? Icons.graphic_eq_rounded
                                : Icons.volume_up_rounded,
                            color: _isSpeaking
                                ? const Color(0xFFDC2626)
                                : const Color(0xFF16A34A),
                            size: 22,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              _isSpeaking ? _t("audio_active") : _t("audio_ready"),
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: _isSpeaking
                                    ? const Color(0xFFB91C1C)
                                    : const Color(0xFF15803D),
                              ),
                            ),
                          ),
                          if (_isSpeaking) ...[
                            ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFDC2626),
                                foregroundColor: Colors.white,
                                elevation: 0,
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 14, vertical: 8),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8)),
                              ),
                              onPressed: _stopSpeech,
                              icon: const Icon(Icons.stop_rounded, size: 18),
                              label: Text(
                                _t("stop"),
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12.5),
                              ),
                            ),
                          ] else ...[
                            ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF16A34A),
                                foregroundColor: Colors.white,
                                elevation: 0,
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 14, vertical: 8),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8)),
                              ),
                              onPressed: _startSpeech,
                              icon: const Icon(Icons.play_arrow_rounded,
                                  size: 18),
                              label: Text(
                                _t("listen"),
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12.5),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),

                    const Divider(height: 24),
                    ..._renderGrokContent(_analysisReport!),
                  ],
                ),
              ),

              if (_suggestions.isNotEmpty) ...[
                const SizedBox(height: 20),
                Text(
                  _t("directives"),
                  style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                      color: Color(0xFF0F172A)),
                ),
                const SizedBox(height: 10),
                ..._suggestions.map(
                  (s) => InkWell(
                    onTap: () => _sendQuestion(s),
                    child: Container(
                      width: double.infinity,
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.subdirectory_arrow_right_rounded,
                              size: 18, color: Color(0xFF2563EB)),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(s,
                                style: const TextStyle(
                                    fontSize: 14.5, color: Color(0xFF1E293B))),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],

              if (_chatMessages.isNotEmpty) ...[
                const SizedBox(height: 20),
                Text(
                  _t("chat_header"),
                  style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                      color: Color(0xFF0F172A)),
                ),
                const SizedBox(height: 10),
                ..._chatMessages.map((msg) {
                  final isUser = msg["sender"] == "user";
                  return Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: isUser ? const Color(0xFF2563EB) : Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: isUser
                          ? null
                          : Border.all(color: Colors.grey.shade200),
                    ),
                    child: Text(
                      msg["text"] ?? "",
                      style: TextStyle(
                        color: isUser ? Colors.white : const Color(0xFF0F172A),
                        fontSize: 15.5,
                        height: 1.5,
                      ),
                    ),
                  );
                }),
              ],

              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _chatController,
                      style: const TextStyle(fontSize: 15),
                      decoration: InputDecoration(
                        hintText: _t("chat_hint"),
                        hintStyle: const TextStyle(fontSize: 14),
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(24)),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 18, vertical: 12),
                        filled: true,
                        fillColor: Colors.white,
                      ),
                      onSubmitted: _sendQuestion,
                    ),
                  ),
                  const SizedBox(width: 10),
                  CircleAvatar(
                    backgroundColor: const Color(0xFF2563EB),
                    radius: 24,
                    child: IconButton(
                      icon: _isChatLoading
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white))
                          : const Icon(Icons.send_rounded,
                              size: 20, color: Colors.white),
                      onPressed: _isChatLoading
                          ? null
                          : () => _sendQuestion(_chatController.text),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}