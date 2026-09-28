import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:flutter_tts/flutter_tts.dart';

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

  static const Map<String, Map<String, String>> _dict = {
    "English": {
      "header_title": "Omni Concierge & Guide",
      "header_subtitle": "Conversational travel planner, verified stays, & local insider advice",
      "chip_plan": "🗺️ Plan a Trip",
      "chip_season": "☀️ Weather & Best Months",
      "chip_scams": "⚠️ Scams & Safety Warnings",
      "chip_food": "🍲 Local Dishes & Hidden Gems",
      "chip_hotels": "🏨 Curated Stays",
      "chip_transit": "🚇 Transit Passes & Routes",
      "hint_text": "Ask your travel guide anything...",
      "typing_prefix": "Guide Assistant is reasoning...",
      "copy_text": "Copy",
      "listen_text": "Listen",
      "stop_text": "Stop",
      "copied_notice": "Text copied to clipboard!",
      "export_header": "Export Active Intelligence Dossier",
      "btn_pdf": "DOWNLOAD PDF",
      "btn_docx": "DOWNLOAD DOC",
      "btn_share": "SHARE",
      "initial_greeting": "Hey there! I am your personal Omni TouristOS Travel Concierge. Where are we heading, or how can I help you explore today?",
    },
    "Marathi": {
      "header_title": "ओम्नी ट्रॅव्हल कॉन्सिअर्ज",
      "header_subtitle": "संभाषणयुक्त प्रवास नियोजन व स्थानिक मार्गदर्शन",
      "chip_plan": "🗺️ सहलीचे नियोजन करा",
      "chip_season": "☀️ सर्वोत्तम महिने व हवामान",
      "chip_scams": "⚠️ फसवणूक व सुरक्षितता इशारे",
      "chip_food": "🍲 स्थानिक खाद्यसंस्कृती",
      "chip_hotels": "🏨 उत्तम हॉटेल्स",
      "chip_transit": "🚇 वाहतूक व मेट्रो पासेस",
      "hint_text": "आपल्या गाईडला काहीही विचारा...",
      "typing_prefix": "गाईड विचार करत आहे...",
      "copy_text": "कॉपी करा",
      "listen_text": "ऐका",
      "stop_text": "थांबवा",
      "copied_notice": "मजकूर क्लिपबोर्डवर कॉपी केला!",
      "export_header": "तयार केलेला आराखडा डाऊनलोड करा",
      "btn_pdf": "PDF डाऊनलोड करा",
      "btn_docx": "DOC डाऊनलोड करा",
      "btn_share": "शेअर करा",
      "initial_greeting": "नमस्कार! मी आपला वैयक्तिक ओम्नी टूरिस्ट मार्गदर्शक आहे. आपण कोणत्या शहराची सहल आखत आहात?",
    },
    "Hindi": {
      "header_title": "ओम्नी ट्रेवल गाइड",
      "header_subtitle": "संवादात्मक यात्रा योजना, सुरक्षा अलर्ट्स व स्थानीय सुझाव",
      "chip_plan": "🗺️ नई ट्रिप प्लान करें",
      "chip_season": "☀️ सबसे अच्छा मौसम",
      "chip_scams": "⚠️ स्कैम अलर्ट्स व सुरक्षा",
      "chip_food": "🍲 स्थानीय प्रसिद्ध भोजन",
      "chip_hotels": "🏨 बेहतरीन होटल्स",
      "chip_transit": "🚇 लोकल ट्रांसपोर्ट व पासेज",
      "hint_text": "अपने गाइड से कुछ भी पूछें...",
      "typing_prefix": "गाइड विश्लेषण कर रहा है...",
      "copy_text": "कॉपी करें",
      "listen_text": "सुनें",
      "stop_text": "रोकें",
      "copied_notice": "टेक्स्ट क्लिपबोर्ड पर कॉपी किया गया!",
      "export_header": "यात्रा रिपोर्ट डाउनलोड करें",
      "btn_pdf": "PDF डाउनलोड करें",
      "btn_docx": "DOC डाउनलोड करें",
      "btn_share": "शेयर करें",
      "initial_greeting": "नमस्ते! मैं आपका पर्सनल ओम्नी टूरिस्टओएस ट्रेवल गाइड हूँ। आप किस शहर की यात्रा प्लान करना चाहते हैं?",
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

    _messages.add({
      "role": "assistant",
      "text": _t("initial_greeting"),
      "has_document": false,
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
    _flutterTts.setErrorHandler((msg) {
      if (mounted) setState(() => _currentlySpeakingIndex = null);
    });
  }

  @override
  void dispose() {
    _flutterTts.stop();
    _speech.stop();
    _msgCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  Future<void> _toggleListening() async {
    if (_isListening) {
      await _speech.stop();
      if (mounted) setState(() => _isListening = false);
      return;
    }

    final available = await _speech.initialize(
      onError: (val) {
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
      if (lang.contains("marathi") || lang.contains("मराठी")) {
        localeId = "mr_IN";
      } else if (lang.contains("hindi") || lang.contains("हिंदी")) {
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
    if (l.contains("marathi") || l.contains("मराठी")) {
      langTag = "mr-IN";
    } else if (l.contains("hindi") || l.contains("हिंदी")) {
      langTag = "hi-IN";
    }

    await _flutterTts.setLanguage(langTag);
    await _flutterTts.setPitch(1.0);
    await _flutterTts.setSpeechRate(0.5);

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
        content: Text(_t("copied_notice"),
            style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
      ),
    );
  }

  String _findLatestItineraryText() {
    for (int i = _messages.length - 1; i >= 0; i--) {
      final msg = _messages[i];
      if (msg["role"] == "assistant") {
        final text = (msg["text"] ?? "").toString();
        if (text.length > 80 &&
            !text.startsWith("Here is your formatted") &&
            !text.startsWith("Hey there! I am your personal")) {
          return text;
        }
      }
    }
    return _messages.isNotEmpty ? (_messages.last["text"] ?? "") : "";
  }

  Future<void> _sendMessage(String text) async {
    final cleanText = text.trim();
    if (cleanText.isEmpty) return;

    if (_isListening) {
      await _speech.stop();
      setState(() => _isListening = false);
    }

    final lower = cleanText.toLowerCase();

    // Instant local greeting evaluation
    final greetings = ["hello", "hi", "hey", "namaste", "hola", "greetings", "good morning", "good afternoon", "good evening", "hii", "helo"];
    if (greetings.contains(lower.replaceAll(RegExp(r'[?!.,]'), ''))) {
      setState(() {
        _messages.add({"role": "user", "text": cleanText, "has_document": false});
      });
      _msgCtrl.clear();
      _scrollToBottom();

      String localGreeting = "Hello! Welcome to Omni TouristOS. Which destination would you like to explore or plan today?";
      final l = widget.language.toLowerCase();
      if (l.contains("marathi") || l.contains("मराठी")) {
        localGreeting = "नमस्कार! ओम्नी टूरिस्टओएस मध्ये आपले स्वागत आहे. मी आपली काय मदत करू शकतो?";
      } else if (l.contains("hindi") || l.contains("हिंदी")) {
        localGreeting = "नमस्ते! ओम्नी टूरिस्टओएस में आपका स्वागत है। मैं आपकी यात्रा योजना में कैसे मदद कर सकता हूँ?";
      }

      await Future.delayed(const Duration(milliseconds: 150));
      if (mounted) {
        setState(() {
          _messages.add({"role": "assistant", "text": localGreeting, "has_document": false});
        });
        _scrollToBottom();
      }
      return;
    }

    final isExportRequest = lower.contains("pdf") ||
        lower.contains("doc") ||
        lower.contains("word") ||
        lower.contains("convert") ||
        lower.contains("download");

    setState(() {
      _messages.add({
        "role": "user",
        "text": cleanText,
        "has_document": false,
      });
      _isTyping = true;
    });
    _msgCtrl.clear();
    _scrollToBottom();

    if (isExportRequest) {
      final latestItinerary = _findLatestItineraryText();
      if (latestItinerary.isNotEmpty) {
        await Future.delayed(const Duration(milliseconds: 300));
        if (lower.contains("pdf")) {
          _generateAndDownloadPdf(latestItinerary, autoShare: false);
        } else if (lower.contains("doc") || lower.contains("word")) {
          _generateAndDownloadDoc(latestItinerary, autoShare: false);
        }

        if (mounted) {
          setState(() {
            _messages.add({
              "role": "assistant",
              "text": "Here is your formatted travel dossier ready for download and sharing.\n\n"
                  "Tap the **DOWNLOAD PDF** or **DOWNLOAD DOC** buttons below to save or forward your complete itinerary file.",
              "has_document": true,
              "export_source_text": latestItinerary,
            });
            _isTyping = false;
          });
          _scrollToBottom();
        }
        return;
      }
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
        }),
      ).timeout(const Duration(seconds: 90));

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
      generatedAnswer = "### 📍 Connection Notice\n\n"
          "The cloud assistant encountered a delay. Please try resending your inquiry.";
    }

    final bool autoDoc = hasDoc ||
        generatedAnswer.contains("Day 1") ||
        generatedAnswer.contains("Day 2") ||
        generatedAnswer.contains("### Day");

    if (mounted) {
      setState(() {
        _messages.add({
          "role": "assistant",
          "text": generatedAnswer,
          "has_document": autoDoc,
          "export_source_text": generatedAnswer,
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

  Future<String?> _generateAndDownloadPdf(String textContent, {bool autoShare = false}) async {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Formatting & generating PDF document...")),
    );

    try {
      final doc = pw.Document();
      final cleanLines = textContent.split('\n');

      doc.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(32),
          header: (pw.Context context) {
            return pw.Container(
              padding: const pw.EdgeInsets.only(bottom: 8),
              margin: const pw.EdgeInsets.only(bottom: 16),
              decoration: const pw.BoxDecoration(
                border: pw.Border(bottom: pw.BorderSide(width: 1, color: PdfColors.grey300)),
              ),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text("TouristOS Travel Intelligence Dossier",
                      style: pw.TextStyle(
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.blue800,
                          fontSize: 10)),
                  pw.Text(DateTime.now().toIso8601String().substring(0, 10),
                      style: const pw.TextStyle(color: PdfColors.grey700, fontSize: 10)),
                ],
              ),
            );
          },
          build: (pw.Context context) {
            final List<pw.Widget> pdfContent = [];

            for (String line in cleanLines) {
              final trimmed = line.trim();
              if (trimmed.isEmpty) {
                pdfContent.add(pw.SizedBox(height: 6));
                continue;
              }

              if (trimmed.startsWith("### ")) {
                pdfContent.add(
                  pw.Padding(
                    padding: const pw.EdgeInsets.only(top: 10, bottom: 4),
                    child: pw.Text(
                      trimmed.replaceFirst("### ", ""),
                      style: pw.TextStyle(
                          fontSize: 14,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.blue900),
                    ),
                  ),
                );
              } else if (trimmed.startsWith("## ")) {
                pdfContent.add(
                  pw.Padding(
                    padding: const pw.EdgeInsets.only(top: 14, bottom: 6),
                    child: pw.Text(
                      trimmed.replaceFirst("## ", ""),
                      style: pw.TextStyle(
                          fontSize: 16,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.black),
                    ),
                  ),
                );
              } else {
                final sanitized = trimmed.replaceAll("**", "");
                pdfContent.add(
                  pw.Padding(
                    padding: const pw.EdgeInsets.only(bottom: 3),
                    child: pw.Text(sanitized,
                        style: const pw.TextStyle(fontSize: 10.5, lineSpacing: 2)),
                  ),
                );
              }
            }

            return pdfContent;
          },
        ),
      );

      final pdfBytes = await doc.save();
      final fileName = "${widget.activeCity.replaceAll(' ', '_')}_Itinerary.pdf";

      Directory? targetDir;
      if (Platform.isAndroid) {
        targetDir = Directory("/storage/emulated/0/Download");
        if (!await targetDir.exists()) {
          targetDir = await getExternalStorageDirectory();
        }
      } else {
        targetDir = await getApplicationDocumentsDirectory();
      }

      final filePath = "${targetDir!.path}/$fileName";
      final file = File(filePath);
      await file.writeAsBytes(pdfBytes);

      if (autoShare) {
        Share.shareXFiles([XFile(filePath)], text: "TouristOS Itinerary: $fileName");
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFF16A34A),
            duration: const Duration(seconds: 5),
            content: Text("✓ PDF Saved to Downloads:\n$fileName"),
            action: SnackBarAction(
              label: "SHARE",
              textColor: Colors.white,
              onPressed: () {
                Share.shareXFiles([XFile(filePath)], text: "TouristOS Dossier: $fileName");
              },
            ),
          ),
        );
      }
      return filePath;
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("PDF generation notice: $e")),
        );
      }
      return null;
    }
  }

  Future<String?> _generateAndDownloadDoc(String textContent, {bool autoShare = false}) async {
    try {
      final fileName = "${widget.activeCity.replaceAll(' ', '_')}_Itinerary.doc";
      final htmlContent = """
      <html xmlns:o='urn:schemas-microsoft-com:office:office' xmlns:w='urn:schemas-microsoft-com:office:word' xmlns='http://www.w3.org/TR/REC-html40'>
      <head><title>$fileName</title>
      <style>
        body { font-family: 'Segoe UI', Arial, sans-serif; font-size: 11pt; line-height: 1.5; color: #0F172A; }
        h2 { color: #1E3A8A; font-size: 16pt; border-bottom: 2px solid #2563EB; padding-bottom: 4px; }
        h3 { color: #1E40AF; font-size: 13pt; margin-top: 14px; }
        p { margin: 6px 0; }
        .footer { font-size: 9pt; color: #64748B; margin-top: 30px; border-top: 1px solid #CBD5E1; padding-top: 8px; }
      </style>
      </head>
      <body>
        <h2>TouristOS Travel Intelligence: ${widget.activeCity}</h2>
        ${textContent.replaceAll('\n', '<br/>').replaceAll('**', '<b>').replaceAll('### ', '<h3>').replaceAll('## ', '<h2>')}
        <div class='footer'>Generated by TouristOS Guide Assistant • ${DateTime.now().toString()}</div>
      </body>
      </html>
      """;

      Directory? targetDir;
      if (Platform.isAndroid) {
        targetDir = Directory("/storage/emulated/0/Download");
        if (!await targetDir.exists()) {
          targetDir = await getExternalStorageDirectory();
        }
      } else {
        targetDir = await getApplicationDocumentsDirectory();
      }

      final filePath = "${targetDir!.path}/$fileName";
      final file = File(filePath);
      await file.writeAsString(htmlContent);

      if (autoShare) {
        Share.shareXFiles([XFile(filePath)], text: "TouristOS Document: $fileName");
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFF2563EB),
            duration: const Duration(seconds: 5),
            content: Text("✓ DOC Saved to Downloads:\n$fileName"),
            action: SnackBarAction(
              label: "SHARE",
              textColor: Colors.white,
              onPressed: () {
                Share.shareXFiles([XFile(filePath)], text: "TouristOS Document: $fileName");
              },
            ),
          ),
        );
      }
      return filePath;
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Document generation notice: $e")),
        );
      }
      return null;
    }
  }

  Widget _renderConciergeTypography(String text, bool isUser) {
    if (isUser) {
      return SelectableText(
        text,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 15.0,
          fontWeight: FontWeight.w500,
          letterSpacing: 0.1,
          height: 1.45,
        ),
      );
    }

    final lines = text.split("\n");
    final List<Widget> renderedWidgets = [];

    for (String line in lines) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) {
        renderedWidgets.add(const SizedBox(height: 8));
        continue;
      }

      if (trimmed.startsWith("### ")) {
        renderedWidgets.add(
          Padding(
            padding: const EdgeInsets.only(top: 14, bottom: 6),
            child: SelectableText(
              trimmed.replaceFirst("### ", ""),
              style: const TextStyle(
                fontSize: 17.0,
                fontWeight: FontWeight.w900,
                color: Color(0xFF0F172A),
                letterSpacing: -0.3,
              ),
            ),
          ),
        );
      } else if (trimmed.startsWith("## ")) {
        renderedWidgets.add(
          Padding(
            padding: const EdgeInsets.only(top: 16, bottom: 8),
            child: SelectableText(
              trimmed.replaceFirst("## ", ""),
              style: const TextStyle(
                fontSize: 18.5,
                fontWeight: FontWeight.w900,
                color: Color(0xFF1E3A8A),
                letterSpacing: -0.4,
              ),
            ),
          ),
        );
      } else if (trimmed.startsWith("• ") ||
          trimmed.startsWith("* ") ||
          RegExp(r'^\d+\.\s').hasMatch(trimmed)) {
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
                fontSize: 14.5,
                height: 1.55,
              ),
            ),
          );
        }

        renderedWidgets.add(
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 6),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("• ",
                    style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF2563EB))),
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
                fontSize: 14.5,
                height: 1.55,
              ),
            ),
          );
        }

        renderedWidgets.add(
          Padding(
            padding: const EdgeInsets.only(bottom: 5),
            child: SelectableText.rich(TextSpan(children: spans)),
          ),
        );
      }
    }

    return SelectionArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: renderedWidgets,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    final double bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final double systemNavInset = MediaQuery.of(context).padding.bottom;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Color(0xFF0F172A), size: 24),
          onPressed: () => Navigator.of(context).pop(),
        ),
        titleSpacing: 0,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                color: const Color(0xFFEFF6FF),
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFFBFDBFE)),
              ),
              child: const Icon(Icons.support_agent_rounded, size: 20, color: Color(0xFF2563EB)),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    _t("header_title"),
                    style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 15.0,
                      color: Color(0xFF0F172A),
                      letterSpacing: -0.2,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 1),
                  Text(
                    _t("header_subtitle"),
                    style: const TextStyle(fontSize: 11.0, color: Color(0xFF64748B)),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      body: SafeArea(
        top: false,
        bottom: false,
        child: Column(
          children: [
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                children: [
                  ActionChip(
                    backgroundColor: const Color(0xFFEFF6FF),
                    side: const BorderSide(color: Color(0xFFBFDBFE)),
                    label: Text(_t("chip_plan"),
                        style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1D4ED8))),
                    onPressed: () => _sendMessage(
                        "I'd like to plan a trip to ${widget.activeCity}. Can you guide me?"),
                  ),
                  const SizedBox(width: 6),
                  ActionChip(
                    backgroundColor: Colors.white,
                    side: const BorderSide(color: Color(0xFFE2E8F0)),
                    label: Text(_t("chip_season"),
                        style: const TextStyle(fontSize: 12, color: Color(0xFF334155))),
                    onPressed: () => _sendMessage(
                        "What is the best season and month to visit ${widget.activeCity}, and what is the typical temperature?"),
                  ),
                  const SizedBox(width: 6),
                  ActionChip(
                    backgroundColor: Colors.white,
                    side: const BorderSide(color: Color(0xFFE2E8F0)),
                    label: Text(_t("chip_scams"),
                        style: const TextStyle(fontSize: 12, color: Color(0xFF334155))),
                    onPressed: () => _sendMessage(
                        "What tourist scams, safety warnings, or taxi traps should I watch out for in ${widget.activeCity}?"),
                  ),
                  const SizedBox(width: 6),
                  ActionChip(
                    backgroundColor: Colors.white,
                    side: const BorderSide(color: Color(0xFFE2E8F0)),
                    label: Text(_t("chip_food"),
                        style: const TextStyle(fontSize: 12, color: Color(0xFF334155))),
                    onPressed: () => _sendMessage(
                        "What are the most famous local dishes and iconic budget eateries in ${widget.activeCity}?"),
                  ),
                  const SizedBox(width: 6),
                  ActionChip(
                    backgroundColor: Colors.white,
                    side: const BorderSide(color: Color(0xFFE2E8F0)),
                    label: Text(_t("chip_hotels"),
                        style: const TextStyle(fontSize: 12, color: Color(0xFF334155))),
                    onPressed: () => _sendMessage(
                        "Recommend safe hotels in ${widget.activeCity} categorised by Budget, Mid-Range, and Luxury tiers."),
                  ),
                  const SizedBox(width: 6),
                  ActionChip(
                    backgroundColor: Colors.white,
                    side: const BorderSide(color: Color(0xFFE2E8F0)),
                    label: Text(_t("chip_transit"),
                        style: const TextStyle(fontSize: 12, color: Color(0xFF334155))),
                    onPressed: () => _sendMessage(
                        "Explain local transit options, train passes, and navigation hacks for ${widget.activeCity}."),
                  ),
                ],
              ),
            ),

            Expanded(
              child: ListView.builder(
                controller: _scrollCtrl,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                itemCount: _messages.length,
                itemBuilder: (ctx, i) {
                  final msg = _messages[i];
                  final isUser = msg["role"] == "user";
                  final hasDoc = msg["has_document"] == true;
                  final docSource = msg["export_source_text"] ?? msg["text"] ?? "";
                  final isSpeaking = _currentlySpeakingIndex == i;

                  return Align(
                    alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 14),
                      constraints: BoxConstraints(
                          maxWidth: MediaQuery.of(context).size.width * 0.92),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: isUser ? const Color(0xFF2563EB) : Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isUser ? const Color(0xFF1D4ED8) : const Color(0xFFE2E8F0),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.04),
                            blurRadius: 8,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _renderConciergeTypography(msg["text"], isUser),
                          if (!isUser) ...[
                            const SizedBox(height: 12),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                InkWell(
                                  onTap: () => _toggleTts(i, msg["text"]),
                                  borderRadius: BorderRadius.circular(6),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                                    decoration: BoxDecoration(
                                      color: isSpeaking ? const Color(0xFFFEE2E2) : const Color(0xFFEFF6FF),
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(
                                          color: isSpeaking ? const Color(0xFFFCA5A5) : const Color(0xFFBFDBFE)),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          isSpeaking ? Icons.stop_circle_rounded : Icons.volume_up_rounded,
                                          size: 13,
                                          color: isSpeaking ? const Color(0xFFDC2626) : const Color(0xFF2563EB),
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          isSpeaking ? _t("stop_text") : _t("listen_text"),
                                          style: TextStyle(
                                            fontSize: 11.0,
                                            color: isSpeaking ? const Color(0xFFDC2626) : const Color(0xFF2563EB),
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                InkWell(
                                  onTap: () => _copyToClipboard(msg["text"]),
                                  borderRadius: BorderRadius.circular(6),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFF1F5F9),
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(color: const Color(0xFFE2E8F0)),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(Icons.copy_rounded, size: 12, color: Color(0xFF64748B)),
                                        const SizedBox(width: 4),
                                        Text(
                                          _t("copy_text"),
                                          style: const TextStyle(
                                              fontSize: 11.0,
                                              color: Color(0xFF64748B),
                                              fontWeight: FontWeight.bold),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                          if (hasDoc && !isUser) ...[
                            const SizedBox(height: 14),
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF8FAFC),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: const Color(0xFFE2E8F0)),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      const Icon(Icons.download_for_offline_rounded,
                                          color: Color(0xFF2563EB), size: 18),
                                      const SizedBox(width: 8),
                                      Text(
                                        _t("export_header"),
                                        style: const TextStyle(
                                            fontWeight: FontWeight.w900,
                                            fontSize: 13.0,
                                            color: Color(0xFF0F172A)),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 10),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: ElevatedButton.icon(
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: const Color(0xFFDC2626),
                                            foregroundColor: Colors.white,
                                            padding: const EdgeInsets.symmetric(vertical: 11),
                                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                            elevation: 0,
                                          ),
                                          onPressed: () => _generateAndDownloadPdf(docSource, autoShare: false),
                                          icon: const Icon(Icons.picture_as_pdf_rounded, size: 15),
                                          label: Text(_t("btn_pdf"),
                                              style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold)),
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      Expanded(
                                        child: ElevatedButton.icon(
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: const Color(0xFF2563EB),
                                            foregroundColor: Colors.white,
                                            padding: const EdgeInsets.symmetric(vertical: 11),
                                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                            elevation: 0,
                                          ),
                                          onPressed: () => _generateAndDownloadDoc(docSource, autoShare: false),
                                          icon: const Icon(Icons.description_rounded, size: 15),
                                          label: Text(_t("btn_docx"),
                                              style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold)),
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      ElevatedButton.icon(
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: const Color(0xFF16A34A),
                                          foregroundColor: Colors.white,
                                          padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 10),
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                          elevation: 0,
                                        ),
                                        onPressed: () => _generateAndDownloadPdf(docSource, autoShare: true),
                                        icon: const Icon(Icons.share_rounded, size: 15),
                                        label: Text(_t("btn_share"),
                                            style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold)),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
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
                    const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Color(0xFF2563EB))),
                    const SizedBox(width: 8),
                    Text(_t("typing_prefix"),
                        style: const TextStyle(
                            fontSize: 12.0,
                            color: Color(0xFF64748B),
                            fontWeight: FontWeight.w500)),
                  ],
                ),
              ),

            Container(
              padding: EdgeInsets.fromLTRB(
                14,
                10,
                14,
                bottomInset > 0 ? bottomInset + 10 : systemNavInset + 12,
              ),
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _msgCtrl,
                      style: const TextStyle(fontSize: 15.0, color: Color(0xFF0F172A)),
                      decoration: InputDecoration(
                        hintText: _isListening ? "Listening... speak now..." : _t("hint_text"),
                        hintStyle: TextStyle(
                          fontSize: 13.0,
                          color: _isListening ? const Color(0xFFDC2626) : const Color(0xFF94A3B8),
                          fontWeight: _isListening ? FontWeight.bold : FontWeight.normal,
                        ),
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(24),
                            borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide(
                              color: _isListening ? const Color(0xFFEF4444) : const Color(0xFFE2E8F0)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: const BorderSide(color: Color(0xFF2563EB), width: 1.5),
                        ),
                        filled: true,
                        fillColor: _isListening ? const Color(0xFFFEF2F2) : const Color(0xFFF8FAFC),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                        isDense: true,
                      ),
                      onSubmitted: _sendMessage,
                    ),
                  ),
                  const SizedBox(width: 6),
                  CircleAvatar(
                    backgroundColor: _isListening ? const Color(0xFFDC2626) : const Color(0xFFEFF6FF),
                    radius: 20,
                    child: IconButton(
                      icon: Icon(
                        _isListening ? Icons.mic : Icons.mic_none_rounded,
                        size: 20,
                        color: _isListening ? Colors.white : const Color(0xFF2563EB),
                      ),
                      onPressed: _toggleListening,
                    ),
                  ),
                  const SizedBox(width: 6),
                  CircleAvatar(
                    backgroundColor: const Color(0xFF2563EB),
                    radius: 20,
                    child: IconButton(
                      icon: const Icon(Icons.arrow_upward_rounded, size: 20, color: Colors.white),
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