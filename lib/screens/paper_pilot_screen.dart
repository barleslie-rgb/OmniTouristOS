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
import 'package:printing/printing.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import '../widgets/metallic_embossed_button.dart';

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

class _PaperPilotScreenState extends State<PaperPilotScreen> with WidgetsBindingObserver {
  final GlobalKey _reportRepaintKey = GlobalKey();
  final ScrollController _scrollController = ScrollController();

  late String _activeLanguage;

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

  final TextEditingController _chatController = TextEditingController();
  final List<Map<String, String>> _chatMessages = [];
  bool _isChatLoading = false;

  static FlutterTts? _activeTtsInstance;
  late FlutterTts _flutterTts;
  bool _isSpeaking = false;
  bool _isMuted = false;
  List<dynamic> _availableTtsVoices = [];

  late stt.SpeechToText _speech;
  bool _isListening = false;
  String _spokenWordsBuffer = "";

  final ImagePicker _imagePicker = ImagePicker();
  List<Map<String, dynamic>> _recentScans = [];
  static const String _scansStorageKey = "paper_pilot_recent_scans_v5";

  final List<Map<String, String>> _supportedLanguages = [
    {"name": "Marathi (मराठी)", "locale": "mr-IN", "group": "Indian Regional"},
    {"name": "Hindi (हिंदी)", "locale": "hi-IN", "group": "Indian Regional"},
    {"name": "Gujarati (ગુજરાતી)", "locale": "gu-IN", "group": "Indian Regional"},
    {"name": "Tamil (தமிழ்)", "locale": "ta-IN", "group": "Indian Regional"},
    {"name": "Telugu (తెలుగు)", "locale": "te-IN", "group": "Indian Regional"},
    {"name": "Bengali (বাংলা)", "locale": "bn-IN", "group": "Indian Regional"},
    {"name": "Kannada (ಕನ್ನಡ)", "locale": "kn-IN", "group": "Indian Regional"},
    {"name": "Malayalam (മലയാളം)", "locale": "ml-IN", "group": "Indian Regional"},
    {"name": "Punjabi (ਪੰਜਾਬੀ)", "locale": "pa-IN", "group": "Indian Regional"},
    {"name": "Odia (ଓଡ଼ିଆ)", "locale": "or-IN", "group": "Indian Regional"},
    {"name": "Urdu (اردو)", "locale": "ur-IN", "group": "Indian & Middle East"},
    {"name": "English", "locale": "en-IN", "group": "Global"},
    {"name": "Arabic (العربية)", "locale": "ar-SA", "group": "Middle East"},
    {"name": "Persian (فارسی)", "locale": "fa-IR", "group": "Middle East"},
    {"name": "Turkish (Türkçe)", "locale": "tr-TR", "group": "Middle East"},
    {"name": "French (Français)", "locale": "fr-FR", "group": "European"},
    {"name": "German (Deutsch)", "locale": "de-DE", "group": "European"},
    {"name": "Spanish (Español)", "locale": "es-ES", "group": "European"},
    {"name": "Italian (Italiano)", "locale": "it-IT", "group": "European"},
    {"name": "Portuguese (Português)", "locale": "pt-PT", "group": "European"},
    {"name": "Russian (Русский)", "locale": "ru-RU", "group": "European"},
    {"name": "Japanese (日本語)", "locale": "ja-JP", "group": "Asian"},
    {"name": "Korean (한국어)", "locale": "ko-KR", "group": "Asian"},
    {"name": "Chinese (Simplified 中文)", "locale": "zh-CN", "group": "Asian"},
    {"name": "Thai (ไทย)", "locale": "th-TH", "group": "Asian"},
    {"name": "Vietnamese (Tiếng Việt)", "locale": "vi-VN", "group": "Asian"},
  ];

  static void globalStopTts() {
    try {
      _activeTtsInstance?.stop();
    } catch (_) {}
  }

  @override
  void initState() {
    super.initState();
    _activeLanguage = widget.language;
    WidgetsBinding.instance.addObserver(this);
    _initTts();
    _speech = stt.SpeechToText();
    _loadPersistedScans();

    _chatMessages.add({
      "sender": "ai",
      "text": "Hello! I am Paper Pilot, your Grok-style document auditor and warm AI companion.\n\n"
          "Upload or photograph any file (PDF, Excel, Word, video, audio, image) for a clean summary, or ask me any question directly."
    });
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

    final newRecord = {
      "id": DateTime.now().millisecondsSinceEpoch.toString(),
      "name": fileName,
      "type": "Grok Summary",
      "date": dateFormatted,
      "report": report,
      "detected_destination": destination,
      "suggestions": directives ?? [],
      "status": "Audited",
    };

    setState(() {
      _recentScans.removeWhere((item) => item["name"] == fileName);
      _recentScans.insert(0, newRecord);
      if (_recentScans.length > 25) {
        _recentScans = _recentScans.sublist(0, 25);
      }
    });

    await prefs.setString(_scansStorageKey, jsonEncode(_recentScans));
  }

  Future<void> _clearAllRecentScans() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_scansStorageKey);
    setState(() => _recentScans.clear());
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Audit history cleared.")),
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

  Future<void> _initTts() async {
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

    try {
      final voices = await _flutterTts.getVoices;
      if (voices is List) _availableTtsVoices = voices;
    } catch (_) {}
  }

  String _resolveLanguageLocaleTag(String langName) {
    for (var l in _supportedLanguages) {
      if (langName.toLowerCase().contains(l["name"]!.toLowerCase().split(' ').first)) {
        return l["locale"]!;
      }
    }
    return "en-IN";
  }

  Future<void> _applyWarmVoice(String localeTag) async {
    await _flutterTts.setLanguage(localeTag);
    await _flutterTts.setPitch(0.85);
    await _flutterTts.setSpeechRate(0.50);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _stopSpeech();
    _stopListening();
    _chatController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _stopSpeech() async {
    try {
      await _flutterTts.stop();
    } catch (_) {}
    if (mounted) setState(() => _isSpeaking = false);
  }

  Future<void> _speakText(String rawText) async {
    if (_isMuted || rawText.trim().isEmpty) return;
    await _stopSpeech();
    final locale = _resolveLanguageLocaleTag(_activeLanguage);
    await _applyWarmVoice(locale);

    final cleanText = rawText
        .replaceAll(RegExp(r'[*#_`|]'), '')
        .trim();

    if (mounted) setState(() => _isSpeaking = true);
    await _flutterTts.speak(cleanText);
  }

  Future<void> _toggleVoiceInput() async {
    _stopSpeech();

    if (_isListening) {
      await _stopListening();
      if (_spokenWordsBuffer.trim().isNotEmpty) {
        _sendQuestion(_spokenWordsBuffer.trim());
      }
      return;
    }

    final available = await _speech.initialize(
      onError: (val) {
        if (mounted) setState(() => _isListening = false);
      },
      onStatus: (status) {
        if (status == "done" || status == "notListening") {
          if (mounted && _isListening) {
            setState(() => _isListening = false);
            if (_spokenWordsBuffer.trim().isNotEmpty) {
              _sendQuestion(_spokenWordsBuffer.trim());
            }
          }
        }
      },
    );

    if (available) {
      HapticFeedback.heavyImpact();
      final localeTag = _resolveLanguageLocaleTag(_activeLanguage);
      setState(() {
        _isListening = true;
        _spokenWordsBuffer = "";
      });

      _speech.listen(
        localeId: localeTag,
        listenFor: const Duration(seconds: 30),
        pauseFor: const Duration(seconds: 3),
        onResult: (val) {
          setState(() {
            _spokenWordsBuffer = val.recognizedWords;
            _chatController.text = val.recognizedWords;
          });
        },
      );
    }
  }

  Future<void> _stopListening() async {
    if (_isListening) {
      await _speech.stop();
      if (mounted) setState(() => _isListening = false);
    }
  }

  void _showLanguageSelectionDialog() {
    _stopSpeech();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: const [
            Icon(Icons.translate_rounded, color: Color(0xFF2563EB), size: 22),
            SizedBox(width: 8),
            Text("Select Language", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
          ],
        ),
        content: SizedBox(
          width: double.maxFinite,
          height: 380,
          child: ListView.separated(
            itemCount: _supportedLanguages.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, i) {
              final lang = _supportedLanguages[i];
              final isSel = _activeLanguage == lang["name"];

              return ListTile(
                dense: true,
                title: Text(
                  lang["name"]!,
                  style: TextStyle(
                    fontWeight: isSel ? FontWeight.w900 : FontWeight.bold,
                    color: isSel ? const Color(0xFF2563EB) : const Color(0xFF1E293B),
                  ),
                ),
                subtitle: Text(lang["group"]!, style: const TextStyle(fontSize: 10, color: Color(0xFF64748B))),
                trailing: isSel ? const Icon(Icons.check_circle_rounded, color: Color(0xFF2563EB), size: 18) : null,
                onTap: () {
                  setState(() => _activeLanguage = lang["name"]!);
                  Navigator.pop(ctx);
                  if (_analysisReport != null && (_fileBytes != null || _selectedFile != null)) {
                    _analyzeDocument();
                  }
                },
              );
            },
          ),
        ),
      ),
    );
  }

  Future<void> _captureFromCamera() async {
    _stopSpeech();
    try {
      final XFile? photo = await _imagePicker.pickImage(
        source: ImageSource.camera,
        maxWidth: 1800,
        maxHeight: 1800,
        imageQuality: 92,
      );

      if (photo != null) {
        final bytes = await photo.readAsBytes();
        setState(() {
          _selectedFile = File(photo.path);
          _fileBytes = bytes;
          _selectedFileName = "Camera_${DateTime.now().millisecondsSinceEpoch}.jpg";
          _selectedFileSize = bytes.length;
          _isImageFile = true;
          _errorMessage = null;
        });
      }
    } catch (e) {
      setState(() => _errorMessage = "Camera capture error: $e");
    }
  }

  Future<void> _pickDocumentFile() async {
    _stopSpeech();
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.any,
        withData: true,
      );

      if (result != null && result.files.isNotEmpty) {
        final picked = result.files.first;
        final ext = (picked.extension ?? "").toLowerCase();
        final isImg = ['jpg', 'jpeg', 'png', 'webp'].contains(ext);

        Uint8List? bytes = picked.bytes;
        File? nativeFile;

        if (picked.path != null) {
          nativeFile = File(picked.path!);
          if (bytes == null || bytes.isEmpty) {
            bytes = await nativeFile.readAsBytes();
          }
        }

        setState(() {
          _selectedFileName = picked.name;
          _selectedFileSize = bytes?.length ?? picked.size;
          _fileBytes = bytes;
          _selectedFile = nativeFile;
          _isImageFile = isImg;
          _errorMessage = null;
        });
      }
    } catch (e) {
      setState(() => _errorMessage = "Document selection error: $e");
    }
  }

  Future<void> _analyzeDocument() async {
    _stopSpeech();
    if (_fileBytes == null && _selectedFile == null) {
      setState(() => _errorMessage = "Please select or capture a file first.");
      return;
    }

    setState(() {
      _isAnalyzing = true;
      _errorMessage = null;
      _analysisReport = null;
      _detectedDestination = null;
      _suggestions.clear();
    });

    try {
      final cleanBaseUrl = widget.backendUrl.replaceAll(RegExp(r'/+$'), '');
      final uri = Uri.parse("$cleanBaseUrl/api/v1/analyze-document");

      var request = http.MultipartRequest("POST", uri);
      request.fields["target_language"] = _activeLanguage;

      if (_fileBytes != null && _fileBytes!.isNotEmpty) {
        request.files.add(
          http.MultipartFile.fromBytes('file', _fileBytes!, filename: _selectedFileName ?? "document.pdf"),
        );
      } else if (_selectedFile != null) {
        request.files.add(
          await http.MultipartFile.fromPath('file', _selectedFile!.path, filename: _selectedFileName ?? "document.pdf"),
        );
      }

      final streamedResponse = await request.send().timeout(const Duration(seconds: 60));
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data["status"] == "success") {
          final resData = data["data"] ?? {};
          final reportText = resData["actionable_advisory"] ?? data["raw_text"] ?? "Analysis complete.";
          final detectedDest = resData["detected_destination"];
          final directives = List<String>.from(resData["suggestions"] ?? []);

          setState(() {
            _analysisReport = reportText;
            _detectedDestination = detectedDest;
            _suggestions = directives;
            _chatMessages.add({
              "sender": "ai",
              "text": "✓ Completed Grok-style audit for **$_selectedFileName** in **$_activeLanguage**.\n\nReview the summary above or ask me any follow-up queries below."
            });
          });

          await _saveScannedDocumentRecord(
            fileName: _selectedFileName ?? "Audited_Document",
            report: reportText,
            destination: detectedDest,
            directives: directives,
          );

          if (!_isMuted) {
            _speakText(reportText);
          }
        } else {
          setState(() => _errorMessage = data["message"] ?? "Analysis failed.");
        }
      } else {
        setState(() => _errorMessage = "Server error code: ${response.statusCode}");
      }
    } catch (e) {
      setState(() => _errorMessage = "Audit connection error: $e");
    } finally {
      if (mounted) setState(() => _isAnalyzing = false);
    }
  }

  Future<void> _sendQuestion(String query) async {
    _stopSpeech();
    _stopListening();
    final userQ = query.trim();
    if (userQ.isEmpty) return;
    _chatController.clear();

    setState(() {
      _chatMessages.add({"sender": "user", "text": userQ});
      _isChatLoading = true;
    });

    _scrollToBottom();

    try {
      final cleanBaseUrl = widget.backendUrl.replaceAll(RegExp(r'/+$'), '');
      final res = await http.post(
        Uri.parse("$cleanBaseUrl/api/v1/ask-question"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "question": userQ,
          "target_language": _activeLanguage,
          "active_document_context": _analysisReport ?? "",
        }),
      ).timeout(const Duration(seconds: 25));

      if (res.statusCode == 200) {
        final d = jsonDecode(res.body);
        final reply = d["answer"] ?? d["reply"] ?? "Understood.";
        setState(() {
          _chatMessages.add({"sender": "ai", "text": reply});
        });
        if (!_isMuted) {
          _speakText(reply);
        }
      } else {
        setState(() {
          _chatMessages.add({"sender": "ai", "text": "Server responded with error ${res.statusCode}."});
        });
      }
    } catch (e) {
      setState(() {
        _chatMessages.add({"sender": "ai", "text": "Connection timeout. Please retry."});
      });
    } finally {
      if (mounted) setState(() => _isChatLoading = false);
      _scrollToBottom();
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _openExportSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(20, 16, 20, 24 + MediaQuery.of(ctx).padding.bottom),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 44,
                height: 4,
                decoration: BoxDecoration(color: const Color(0xFFCBD5E1), borderRadius: BorderRadius.circular(4)),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              "Export & Share Summary",
              style: TextStyle(fontWeight: FontWeight.w900, fontSize: 17, color: Color(0xFF0F172A)),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: MetallicEmbossedButton(
                    label: "PRINT",
                    icon: Icons.print_rounded,
                    variant: MetallicVariant.cobaltBlue,
                    height: 42,
                    fontSize: 12,
                    onPressed: () {
                      Navigator.pop(ctx);
                      _printDirectly();
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: MetallicEmbossedButton(
                    label: "SHARE PDF",
                    icon: Icons.picture_as_pdf_rounded,
                    variant: MetallicVariant.crimsonRed,
                    height: 42,
                    fontSize: 11.5,
                    onPressed: () {
                      Navigator.pop(ctx);
                      _exportPdfFile();
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<pw.Font> _resolvePdfFont() async {
    try {
      final lowerLang = _activeLanguage.toLowerCase();
      if (lowerLang.contains("marathi") || lowerLang.contains("मराठी")) {
        return await PdfGoogleFonts.tiroDevanagariMarathiRegular();
      } else if (lowerLang.contains("hindi") || lowerLang.contains("हिंदी")) {
        return await PdfGoogleFonts.notoSansDevanagariRegular();
      } else if (lowerLang.contains("arabic") || lowerLang.contains("urdu")) {
        return await PdfGoogleFonts.notoSansArabicRegular();
      }
      return await PdfGoogleFonts.robotoRegular();
    } catch (_) {
      return pw.Font.helvetica();
    }
  }

  Future<Uint8List> _generateCompletePdf() async {
    final pdf = pw.Document();
    final cleanReport = _analysisReport ?? "No active summary.";
    final pw.Font unicodeFont = await _resolvePdfFont();
    final pw.ThemeData theme = pw.ThemeData.withFont(base: unicodeFont, fontFallback: [unicodeFont]);

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        theme: theme,
        build: (pw.Context ctx) => [
          pw.Header(
            level: 0,
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text("Paper Pilot • Grok-Style Summary",
                    style: pw.TextStyle(fontSize: 15, fontWeight: pw.FontWeight.bold, color: PdfColors.blue900)),
                pw.Text(DateTime.now().toString().split(" ")[0], style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
              ],
            ),
          ),
          pw.SizedBox(height: 8),
          pw.Text("File: ${_selectedFileName ?? 'Document'}", style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold)),
          pw.Text("Language: $_activeLanguage", style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
          pw.Divider(thickness: 1.2, color: PdfColors.blueGrey200),
          pw.SizedBox(height: 10),
          pw.Paragraph(
            text: cleanReport.replaceAll(RegExp(r'[*#_`|]'), ''),
            style: const pw.TextStyle(fontSize: 10, lineSpacing: 1.8),
          ),
        ],
      ),
    );

    return pdf.save();
  }

  Future<void> _printDirectly() async {
    try {
      final bytes = await _generateCompletePdf();
      await Printing.layoutPdf(onLayout: (_) => bytes, name: 'PaperPilot_Summary.pdf');
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Print error: $e")));
    }
  }

  Future<void> _exportPdfFile() async {
    try {
      final bytes = await _generateCompletePdf();
      final dir = await getTemporaryDirectory();
      final file = File("${dir.path}/PaperPilot_Summary_${DateTime.now().millisecondsSinceEpoch}.pdf");
      await file.writeAsBytes(bytes);
      await Share.shareXFiles([XFile(file.path)], text: "Document Summary: ${_selectedFileName ?? 'Doc'}");
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("PDF Share Error: $e")));
    }
  }

  Widget _buildRecentScansTray() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: const [
                Icon(Icons.history_rounded, size: 16, color: Color(0xFF2563EB)),
                SizedBox(width: 6),
                Text("Recent Audited Files", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13.5, color: Color(0xFF0F172A))),
              ],
            ),
            if (_recentScans.isNotEmpty)
              TextButton(
                onPressed: _clearAllRecentScans,
                style: TextButton.styleFrom(padding: EdgeInsets.zero, visualDensity: VisualDensity.compact),
                child: const Text("Clear History", style: TextStyle(color: Color(0xFFDC2626), fontSize: 11, fontWeight: FontWeight.bold)),
              ),
          ],
        ),
        const SizedBox(height: 8),
        if (_recentScans.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFFE2E8F0))),
            child: const Text("No recent audited documents. Scanned files will be preserved here.", style: TextStyle(fontSize: 11.5, color: Color(0xFF64748B))),
          )
        else
          SizedBox(
            height: 84,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _recentScans.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, i) {
                final item = _recentScans[i];
                return InkWell(
                  onTap: () => _restoreHistoricalScan(item),
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    width: 220,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                      boxShadow: [
                        BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 4, offset: const Offset(0, 2)),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(5),
                              decoration: BoxDecoration(color: const Color(0xFFEFF6FF), borderRadius: BorderRadius.circular(6)),
                              child: const Icon(Icons.description_rounded, size: 14, color: Color(0xFF2563EB)),
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                item["name"] ?? "Document",
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11.5, color: Color(0xFF0F172A)),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text("${item["type"]} • ${item["date"]}", style: const TextStyle(fontSize: 9.5, color: Color(0xFF64748B))),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                              decoration: BoxDecoration(color: const Color(0xFFDCFCE7), borderRadius: BorderRadius.circular(4)),
                              child: const Text("Audited", style: TextStyle(fontSize: 8.5, fontWeight: FontWeight.bold, color: Color(0xFF166534))),
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

  Widget _buildTopAttachmentBanner() {
    if (_selectedFileName == null) return const SizedBox.shrink();
    final sizeKb = (_selectedFileSize / 1024).toStringAsFixed(1);
    final ext = _selectedFileName!.split('.').last.toUpperCase();

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFEFF6FF),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFBFDBFE)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: const Color(0xFFDBEAFE), borderRadius: BorderRadius.circular(10)),
            child: const Icon(Icons.insert_drive_file_rounded, color: Color(0xFF2563EB), size: 24),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _selectedFileName!,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5, color: Color(0xFF0F172A)),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text("$ext • $sizeKb KB • Ready for Grok Audit", style: const TextStyle(fontSize: 11, color: Color(0xFF64748B), fontWeight: FontWeight.w600)),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close_rounded, size: 18, color: Color(0xFF64748B)),
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

  List<Widget> _renderGrokStyleSummary(String rawText) {
    final List<Widget> widgets = [];
    final lines = rawText.split("\n");

    for (int i = 0; i < lines.length; i++) {
      final line = lines[i].trim();
      if (line.isEmpty) continue;

      if (line.startsWith("#")) {
        final title = line.replaceAll(RegExp(r'^#+\s*'), '').replaceAll("**", "");
        widgets.add(
          Padding(
            padding: const EdgeInsets.only(top: 14, bottom: 6),
            child: Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15.5, color: Color(0xFF1E3A8A)),
            ),
          ),
        );
        continue;
      }

      widgets.add(
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Text(
            line.replaceAll("**", ""),
            style: const TextStyle(fontSize: 13.5, color: Color(0xFF334155), height: 1.45),
          ),
        ),
      );
    }

    return widgets;
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final systemNavInset = MediaQuery.of(context).padding.bottom;
    final topPadding = MediaQuery.of(context).padding.top;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(kToolbarHeight),
        child: Container(
          color: Colors.white,
          padding: EdgeInsets.only(top: topPadding),
          child: AppBar(
            elevation: 0,
            scrolledUnderElevation: 0,
            backgroundColor: Colors.white,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_rounded, color: Color(0xFF0F172A), size: 24),
              onPressed: () => Navigator.of(context).pop(),
            ),
            titleSpacing: 0,
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Paper Pilot",
                  style: TextStyle(fontWeight: FontWeight.w900, fontSize: 15.5, color: Color(0xFF0F172A)),
                ),
                InkWell(
                  onTap: _showLanguageSelectionDialog,
                  child: Row(
                    children: [
                      Text(_activeLanguage, style: const TextStyle(fontSize: 11, color: Color(0xFF2563EB), fontWeight: FontWeight.bold)),
                      const Icon(Icons.arrow_drop_down_rounded, size: 16, color: Color(0xFF2563EB)),
                    ],
                  ),
                ),
              ],
            ),
            actions: [
              IconButton(
                tooltip: _isMuted ? "Unmute Audio" : "Mute Audio",
                icon: Icon(
                  _isMuted ? Icons.volume_off_rounded : Icons.volume_up_rounded,
                  color: _isMuted ? const Color(0xFF94A3B8) : const Color(0xFF16A34A),
                  size: 22,
                ),
                onPressed: () {
                  setState(() => _isMuted = !_isMuted);
                  if (_isMuted) _stopSpeech();
                },
              ),
              IconButton(
                tooltip: "Export & Share Summary",
                icon: const Icon(Icons.share_rounded, color: Color(0xFF2563EB), size: 20),
                onPressed: _openExportSheet,
              ),
            ],
          ),
        ),
      ),
      body: SafeArea(
        top: false,
        bottom: false,
        child: Column(
          children: [
            if (_isSpeaking) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                color: const Color(0xFFEFF6FF),
                child: Row(
                  children: [
                    const Icon(Icons.graphic_eq_rounded, color: Color(0xFF2563EB), size: 18),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text("Audio reader active...", style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: Color(0xFF1D4ED8))),
                    ),
                    ElevatedButton.icon(
                      style: EdgeButton.styleFrom(
                        backgroundColor: const Color(0xFF2563EB),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                        elevation: 0,
                      ),
                      icon: const Icon(Icons.stop_rounded, size: 14),
                      label: const Text("STOP", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                      onPressed: _stopSpeech,
                    ),
                  ],
                ),
              ),
            ],

            Expanded(
              child: SingleChildScrollView(
                controller: _scrollController,
                padding: EdgeInsets.fromLTRB(16, 16, 16, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildTopAttachmentBanner(),

                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                        boxShadow: [
                          BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 8, offset: const Offset(0, 3)),
                        ],
                      ),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: MetallicEmbossedButton(
                                  label: "Camera",
                                  icon: Icons.camera_alt_rounded,
                                  variant: MetallicVariant.cobaltBlue,
                                  height: 42,
                                  fontSize: 12.5,
                                  onPressed: _isAnalyzing ? null : _captureFromCamera,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: MetallicEmbossedButton(
                                  label: "Pick Any File",
                                  icon: Icons.upload_file_rounded,
                                  variant: MetallicVariant.titaniumSilver,
                                  height: 42,
                                  fontSize: 12,
                                  onPressed: _isAnalyzing ? null : _pickDocumentFile,
                                ),
                              ),
                            ],
                          ),
                          if (_selectedFileName != null) ...[
                            const SizedBox(height: 10),
                            MetallicEmbossedButton(
                              label: _isAnalyzing ? "AUDITING..." : "AUDIT FILE (GROK STYLE)",
                              icon: Icons.bolt_rounded,
                              variant: MetallicVariant.emeraldGreen,
                              isFullWidth: true,
                              height: 44,
                              fontSize: 13,
                              onPressed: _isAnalyzing ? null : _analyzeDocument,
                            ),
                          ],
                        ],
                      ),
                    ),

                    const SizedBox(height: 14),
                    _buildRecentScansTray(),

                    if (_errorMessage != null) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(color: const Color(0xFFFEF2F2), borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFFFCA5A5))),
                        child: Row(
                          children: [
                            const Icon(Icons.warning_amber_rounded, color: Color(0xFFDC2626), size: 20),
                            const SizedBox(width: 8),
                            Expanded(child: Text(_errorMessage!, style: const TextStyle(color: Color(0xFFB91C1C), fontSize: 12.5))),
                          ],
                        ),
                      ),
                    ],

                    if (_analysisReport != null) ...[
                      const SizedBox(height: 16),
                      RepaintBoundary(
                        key: _reportRepaintKey,
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(18),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Row(
                                    children: const [
                                      Icon(Icons.auto_awesome_rounded, color: Color(0xFF2563EB), size: 20),
                                      SizedBox(width: 8),
                                      Text("Grok-Style Document Audit", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 14, color: Color(0xFF0F172A))),
                                    ],
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.share_rounded, size: 18, color: Color(0xFF2563EB)),
                                    onPressed: _openExportSheet,
                                  ),
                                ],
                              ),
                              const Divider(height: 20),
                              ..._renderGrokStyleSummary(_analysisReport!),
                            ],
                          ),
                        ),
                      ),
                    ],

                    const SizedBox(height: 18),
                    const Text("Dialogue & Persistent Companion", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 14.5, color: Color(0xFF0F172A))),
                    const SizedBox(height: 8),

                    ..._chatMessages.map((msg) {
                      final isUser = msg["sender"] == "user";
                      final text = msg["text"] ?? "";

                      return Align(
                        alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.90),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: isUser ? const Color(0xFF2563EB) : Colors.white,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: isUser ? const Color(0xFF1D4ED8) : const Color(0xFFE2E8F0)),
                          ),
                          child: Text(
                            text,
                            style: TextStyle(color: isUser ? Colors.white : const Color(0xFF0F172A), fontSize: 13.5, height:.4),
                          ),
                        ),
                      );
                    }).toList(),

                    if (_isChatLoading) ...[
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Row(
                          children: const [
                            SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF2563EB))),
                            SizedBox(width: 8),
                            Text("Thinking...", style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),

            Container(
              padding: EdgeInsets.fromLTRB(
                14,
                10,
                14,
                bottomInset > 0 ? bottomInset + 10 : (systemNavInset > 0 ? systemNavInset + 12 : 16),
              ),
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _chatController,
                      style: const TextStyle(fontSize: 14.5),
                      decoration: InputDecoration(
                        hintText: _isListening ? "Listening in $_activeLanguage..." : "Ask anything about file or yourself...",
                        hintStyle: TextStyle(
                          fontSize: 12.5,
                          color: _isListening ? const Color(0xFFDC2626) : const Color(0xFF94A3B8),
                        ),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(24)),
                        filled: true,
                        fillColor: const Color(0xFFF8FAFC),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        isDense: const isDense = true,
                      ),
                      onSubmitted: _sendQuestion,
                    ),
                  ),
                  const SizedBox(width: 6),
                  CircleAvatar(
                    backgroundColor: _isListening ? const Color(0xFFDC2626) : const Color(0xFFEFF6FF),
                    radius: 20,
                    child: IconButton(
                      icon: Icon(_isListening ? Icons.mic_rounded : Icons.mic_none_rounded, color: _isListening ? Colors.white : const Color(0xFF2563EB), size: 20),
                      onPressed: _toggleVoiceInput,
                    ),
                  ),
                  const SizedBox(width: 6),
                  CircleAvatar(
                    backgroundColor: const Color(0xFF2563EB),
                    radius: 20,
                    child: IconButton(
                      icon: const Icon(Icons.arrow_upward_rounded, size: 20, color: Colors.white),
                      onPressed: () => _sendQuestion(_chatController.text),
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