import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';

class StreetTranslatorScreen extends StatefulWidget {
  final String language;
  final String backendUrl;

  const StreetTranslatorScreen({
    Key? key,
    required this.language,
    this.backendUrl = "https://omni-backend-pk28.onrender.com",
  }) : super(key: key);

  @override
  State<StreetTranslatorScreen> createState() => _StreetTranslatorScreenState();
}

class _StreetTranslatorScreenState extends State<StreetTranslatorScreen> {
  late FlutterTts _flutterTts;
  late stt.SpeechToText _speech;

  bool _isSpeechInitialized = false;
  bool _isListening = false;
  String _activeListeningSide = ""; // "A" (Tourist) or "B" (Local)
  bool _isTranslating = false;
  bool _isSpeaking = false;

  // Auto-Turn Hands-Free Loop State
  bool _autoTurnMode = false;
  bool _autoTurnRunning = false;
  String _currentAutoSpeaker = "A"; // Alternates A <-> B

  // Configured Language Pair
  String _langA = "English";
  String _langB = "Tamil";

  // Live Conversation Transcript Stream
  final List<Map<String, dynamic>> _dialogueHistory = [];
  String _liveSpeechTranscript = "";

  final ImagePicker _picker = ImagePicker();
  bool _isLensScanning = false;
  bool _isLensSpeaking = false;

  final List<Map<String, String>> _languages = [
    {"label": "English", "code": "English", "iso": "en", "locale": "en_IN", "tts": "en-IN"},
    {"label": "தமிழ் (Tamil)", "code": "Tamil", "iso": "ta", "locale": "ta_IN", "tts": "ta-IN"},
    {"label": "मराठी (Marathi)", "code": "Marathi", "iso": "mr", "locale": "mr_IN", "tts": "mr-IN"},
    {"label": "हिंदी (Hindi)", "code": "Hindi", "iso": "hi", "locale": "hi_IN", "tts": "hi-IN"},
    {"label": "తెలుగు (Telugu)", "code": "Telugu", "iso": "te", "locale": "te_IN", "tts": "te-IN"},
    {"label": "ಕನ್ನಡ (Kannada)", "code": "Kannada", "iso": "kn", "locale": "kn_IN", "tts": "kn-IN"},
    {"label": "ગુજરાતી (Gujarati)", "code": "Gujarati", "iso": "gu", "locale": "gu_IN", "tts": "gu-IN"},
    {"label": "বাংলা (Bengali)", "code": "Bengali", "iso": "bn", "locale": "bn_IN", "tts": "bn-IN"},
    {"label": "മലയാളം (Malayalam)", "code": "Malayalam", "iso": "ml", "locale": "ml_IN", "tts": "ml-IN"},
    {"label": "Français (French)", "code": "French", "iso": "fr", "locale": "fr_FR", "tts": "fr-FR"},
    {"label": "Español (Spanish)", "code": "Spanish", "iso": "es", "locale": "es_ES", "tts": "es-ES"},
    {"label": "Deutsch (German)", "code": "German", "iso": "de", "locale": "de_DE", "tts": "de-DE"},
    {"label": "日本語 (Japanese)", "code": "Japanese", "iso": "ja", "locale": "ja_JP", "tts": "ja-JP"},
    {"label": "العربية (Arabic)", "code": "Arabic", "iso": "ar", "locale": "ar_SA", "tts": "ar-SA"},
  ];

  @override
  void initState() {
    super.initState();
    _initAudioEngines();

    final lower = widget.language.toLowerCase();
    if (lower.contains("tamil") || widget.language.contains("தமிழ்")) {
      _langA = "English";
      _langB = "Tamil";
    } else if (lower.contains("marathi") || widget.language.contains("मराठी")) {
      _langA = "English";
      _langB = "Marathi";
    } else if (lower.contains("hindi") || widget.language.contains("हिंदी")) {
      _langA = "English";
      _langB = "Hindi";
    } else {
      _langA = "English";
      _langB = "Tamil";
    }
  }

  Future<void> _initAudioEngines() async {
    _speech = stt.SpeechToText();
    _isSpeechInitialized = await _speech.initialize(
      onError: (_) {
        if (mounted) setState(() => _isListening = false);
      },
      onStatus: (status) {
        if (status == "done" || status == "notListening") {
          if (mounted && _isListening) {
            _onSpeechSessionCompleted();
          }
        }
      },
    );

    _flutterTts = FlutterTts();
    await _flutterTts.awaitSpeakCompletion(true);
    await _flutterTts.setVolume(1.0);
    await _flutterTts.setPitch(1.0);
    await _flutterTts.setSpeechRate(0.50);

    _flutterTts.setStartHandler(() {
      if (mounted) setState(() => _isSpeaking = true);
    });
    _flutterTts.setCompletionHandler(() {
      if (mounted) {
        setState(() => _isSpeaking = false);
        if (_autoTurnMode && _autoTurnRunning) {
          _advanceAutoTurnLoop();
        }
      }
    });
    _flutterTts.setErrorHandler((_) {
      if (mounted) setState(() => _isSpeaking = false);
    });
  }

  @override
  void dispose() {
    _speech.stop();
    _flutterTts.stop();
    super.dispose();
  }

  String _getRecognitionLocale(String langCode) {
    return _languages.firstWhere(
      (e) => e["code"] == langCode,
      orElse: () => {"locale": "en_IN"},
    )["locale"]!;
  }

  String _getTtsLocale(String langCode) {
    return _languages.firstWhere(
      (e) => e["code"] == langCode,
      orElse: () => {"tts": "en-IN"},
    )["tts"]!;
  }

  // -------------------------------------------------------------
  // HIGH-SENSITIVITY SPEECH RECOGNITION (STREAMING & CASUAL PACING)
  // -------------------------------------------------------------
  Future<void> _startListeningForSide(String side) async {
    await _flutterTts.stop();
    if (_isListening) {
      await _speech.stop();
      if (_activeListeningSide == side) {
        setState(() => _isListening = false);
        return;
      }
    }

    if (!_isSpeechInitialized) {
      _isSpeechInitialized = await _speech.initialize();
      if (!_isSpeechInitialized) return;
    }

    final activeLang = (side == "A") ? _langA : _langB;

    setState(() {
      _isListening = true;
      _activeListeningSide = side;
      _liveSpeechTranscript = "";
    });

    await _speech.listen(
      localeId: _getRecognitionLocale(activeLang),
      listenMode: stt.ListenMode.dictation,
      partialResults: true,
      listenFor: const Duration(seconds: 40),
      pauseFor: const Duration(milliseconds: 1400),
      onResult: (val) {
        if (mounted) {
          setState(() {
            _liveSpeechTranscript = val.recognizedWords;
          });
          if (val.finalResult) {
            _onSpeechSessionCompleted();
          }
        }
      },
    );
  }

  void _onSpeechSessionCompleted() async {
    final phrase = _liveSpeechTranscript.trim();
    final side = _activeListeningSide;

    setState(() {
      _isListening = false;
      _activeListeningSide = "";
    });

    if (phrase.isEmpty) {
      if (_autoTurnMode && _autoTurnRunning) {
        _advanceAutoTurnLoop();
      }
      return;
    }

    await _translateAndBroadcast(phrase, side);
  }

  Future<void> _translateAndBroadcast(String rawPhrase, String fromSide) async {
    final sourceLang = (fromSide == "A") ? _langA : _langB;
    final targetLang = (fromSide == "A") ? _langB : _langA;

    setState(() => _isTranslating = true);

    String? translatedText;

    // Backend neural translation call
    try {
      final cleanUrl = widget.backendUrl.replaceAll(RegExp(r'/+$'), '');
      final res = await http.post(
        Uri.parse("$cleanUrl/api/v1/street-voice-translate"),
        body: {
          "text": rawPhrase,
          "source_language": sourceLang,
          "target_language": targetLang,
        },
      ).timeout(const Duration(seconds: 7));

      if (res.statusCode == 200) {
        final d = jsonDecode(res.body);
        if (d["status"] == "success" && d["translation"] != null) {
          final t = d["translation"].toString().trim();
          if (t.isNotEmpty) translatedText = t;
        }
      }
    } catch (_) {}

    // Fallback translation bridge
    if (translatedText == null || translatedText.isEmpty) {
      try {
        final sIso = _languages.firstWhere((e) => e["code"] == sourceLang)["iso"] ?? "en";
        final tIso = _languages.firstWhere((e) => e["code"] == targetLang)["iso"] ?? "ta";
        final fbUrl = Uri.parse(
          "https://translate.googleapis.com/translate_a/single?client=gtx&sl=$sIso&tl=$tIso&dt=t&q=${Uri.encodeComponent(rawPhrase)}",
        );
        final fbRes = await http.get(fbUrl).timeout(const Duration(seconds: 5));
        if (fbRes.statusCode == 200) {
          final List parsed = jsonDecode(fbRes.body);
          final buffer = StringBuffer();
          for (var part in parsed[0]) {
            if (part[0] != null) buffer.write(part[0]);
          }
          final fbT = buffer.toString().trim();
          if (fbT.isNotEmpty) translatedText = fbT;
        }
      } catch (_) {}
    }

    final finalResult = translatedText ?? "Translation error. Check connection.";

    if (mounted) {
      setState(() {
        _isTranslating = false;
        _dialogueHistory.add({
          "from_side": fromSide,
          "source_lang": sourceLang,
          "target_lang": targetLang,
          "original": rawPhrase,
          "translated": finalResult,
          "timestamp": DateTime.now(),
        });
      });
    }

    if (finalResult.isNotEmpty && !finalResult.contains("error")) {
      await _playTts(finalResult, targetLang);
    } else if (_autoTurnMode && _autoTurnRunning) {
      _advanceAutoTurnLoop();
    }
  }

  Future<void> _playTts(String text, String languageCode) async {
    try {
      await _flutterTts.stop();
      await _flutterTts.setLanguage(_getTtsLocale(languageCode));
      await _flutterTts.setVolume(1.0);
      await _flutterTts.setSpeechRate(0.48);
      await _flutterTts.speak(text);
    } catch (_) {}
  }

  // -------------------------------------------------------------
  // CONTINUOUS DUAL HANDS-FREE TABLE INTERPRETER LOOP
  // -------------------------------------------------------------
  void _toggleAutoTurnMode(bool value) {
    setState(() {
      _autoTurnMode = value;
      if (!_autoTurnMode) {
        _autoTurnRunning = false;
        _speech.stop();
        _flutterTts.stop();
        _isListening = false;
      }
    });
  }

  void _startAutoTurnLoop() {
    setState(() {
      _autoTurnRunning = true;
      _currentAutoSpeaker = "A";
    });
    _startListeningForSide("A");
  }

  void _stopAutoTurnLoop() {
    setState(() {
      _autoTurnRunning = false;
      _speech.stop();
      _flutterTts.stop();
      _isListening = false;
    });
  }

  void _advanceAutoTurnLoop() {
    if (!_autoTurnRunning || !mounted) return;

    Future.delayed(const Duration(milliseconds: 700), () {
      if (!_autoTurnRunning || !mounted) return;
      final nextSpeaker = (_currentAutoSpeaker == "A") ? "B" : "A";
      setState(() => _currentAutoSpeaker = nextSpeaker);
      _startListeningForSide(nextSpeaker);
    });
  }

  // -------------------------------------------------------------
  // STREET LENS OCR & TRANSLATION ENGINE (WITH SPEAK / MUTE BUTTONS)
  // -------------------------------------------------------------
  Future<void> _launchStreetLens() async {
    try {
      final XFile? photo = await _picker.pickImage(
        source: ImageSource.camera,
        maxWidth: 1400,
        maxHeight: 1400,
        imageQuality: 88,
      );
      if (photo == null) return;

      setState(() => _isLensScanning = true);

      final cleanUrl = widget.backendUrl.replaceAll(RegExp(r'/+$'), '');
      final req = http.MultipartRequest("POST", Uri.parse("$cleanUrl/api/v1/street-lens"));
      req.fields["target_language"] = _langA;
      req.files.add(await http.MultipartFile.fromPath("file", photo.path));

      final streamedRes = await req.send().timeout(const Duration(seconds: 25));
      final res = await http.Response.fromStream(streamedRes);

      if (mounted) setState(() => _isLensScanning = false);

      if (res.statusCode == 200) {
        final d = jsonDecode(res.body);
        final answer = d["interpretation"]?.toString() ?? "Could not interpret signboard.";
        _showLensResultSheet(answer, File(photo.path));
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Street Lens failed to reach vision cluster.")),
        );
      }
    } catch (e) {
      if (mounted) setState(() => _isLensScanning = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Camera Lens notice: $e")),
      );
    }
  }

  void _showLensResultSheet(String interpretation, File imageFile) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            return Padding(
              padding: EdgeInsets.fromLTRB(20, 16, 20, MediaQuery.of(ctx).padding.bottom + 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: const Color(0xFFCBD5E1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: const [
                          Icon(Icons.camera_alt_rounded, color: Color(0xFF2563EB), size: 22),
                          SizedBox(width: 8),
                          Text(
                            "Street Lens Translation",
                            style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: Color(0xFF0F172A)),
                          ),
                        ],
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded),
                        onPressed: () {
                          _flutterTts.stop();
                          Navigator.pop(ctx);
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: SizedBox(
                      height: 140,
                      width: double.infinity,
                      child: Image.file(imageFile, fit: BoxFit.cover),
                    ),
                  ),
                  const SizedBox(height: 14),
                  SelectableText(
                    interpretation,
                    style: const TextStyle(fontSize: 14.5, color: Color(0xFF1E293B), height: 1.45),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      // Speak Button
                      Expanded(
                        child: SizedBox(
                          height: 46,
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF2563EB),
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            onPressed: () async {
                              setSheetState(() => _isLensSpeaking = true);
                              await _playTts(interpretation, _langA);
                              if (mounted) setSheetState(() => _isLensSpeaking = false);
                            },
                            icon: const Icon(Icons.volume_up_rounded, size: 18),
                            label: const Text("Speak Aloud", style: TextStyle(fontWeight: FontWeight.bold)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      // Mute / Stop Button
                      SizedBox(
                        height: 46,
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFFDC2626),
                            side: const BorderSide(color: Color(0xFFFCA5A5)),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          onPressed: () async {
                            await _flutterTts.stop();
                            if (mounted) setSheetState(() => _isLensSpeaking = false);
                          },
                          icon: const Icon(Icons.volume_off_rounded, size: 18),
                          label: const Text("Mute", style: TextStyle(fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _swapLanguages() {
    setState(() {
      final temp = _langA;
      _langA = _langB;
      _langB = temp;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        titleSpacing: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Color(0xFF0F172A), size: 24),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          "Street Lens & Voice",
          style: TextStyle(fontWeight: FontWeight.w900, fontSize: 17, color: Color(0xFF0F172A)),
        ),
        actions: [
          IconButton(
            icon: _isLensScanning
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.camera_alt_rounded, color: Color(0xFF2563EB), size: 24),
            tooltip: "Scan Sign / Menu",
            onPressed: _isLensScanning ? null : _launchStreetLens,
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          // Language Selection Header & Auto-Turn Toggle
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Side A Dropdown (Tourist)
                    DropdownButton<String>(
                      value: _langA,
                      underline: const SizedBox.shrink(),
                      style: const TextStyle(fontWeight: FontWeight.w900, color: Color(0xFF2563EB), fontSize: 14),
                      items: _languages.map((l) {
                        return DropdownMenuItem<String>(value: l["code"], child: Text(l["label"]!));
                      }).toList(),
                      onChanged: (val) {
                        if (val != null && val != _langB) setState(() => _langA = val);
                      },
                    ),
                    IconButton(
                      icon: const Icon(Icons.swap_horiz_rounded, color: Color(0xFF64748B), size: 24),
                      onPressed: _swapLanguages,
                    ),
                    // Side B Dropdown (Local)
                    DropdownButton<String>(
                      value: _langB,
                      underline: const SizedBox.shrink(),
                      style: const TextStyle(fontWeight: FontWeight.w900, color: Color(0xFF059669), fontSize: 14),
                      items: _languages.map((l) {
                        return DropdownMenuItem<String>(value: l["code"], child: Text(l["label"]!));
                      }).toList(),
                      onChanged: (val) {
                        if (val != null && val != _langA) setState(() => _langB = val);
                      },
                    ),
                  ],
                ),
                const Divider(height: 10, color: Color(0xFFF1F5F9)),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: const [
                        Icon(Icons.loop_rounded, size: 18, color: Color(0xFF64748B)),
                        SizedBox(width: 6),
                        Text(
                          "Continuous Hands-Free Mode",
                          style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: Color(0xFF334155)),
                        ),
                      ],
                    ),
                    Switch.adaptive(
                      value: _autoTurnMode,
                      activeColor: const Color(0xFF2563EB),
                      onChanged: _toggleAutoTurnMode,
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Live Listening State Banner
          if (_isListening || _isTranslating || _isSpeaking)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: _activeListeningSide == "A" ? const Color(0xFFEFF6FF) : const Color(0xFFECFDF5),
              child: Row(
                children: [
                  SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: _activeListeningSide == "A" ? const Color(0xFF2563EB) : const Color(0xFF059669),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _isTranslating
                          ? "Translating phrase..."
                          : _isSpeaking
                              ? "Speaking aloud..."
                              : "Listening to ${_activeListeningSide == "A" ? _langA : _langB}...",
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.bold,
                        color: _activeListeningSide == "A" ? const Color(0xFF1E40AF) : const Color(0xFF065F46),
                      ),
                    ),
                  ),
                  if (_liveSpeechTranscript.isNotEmpty)
                    Text(
                      "\"${_liveSpeechTranscript.length > 25 ? '${_liveSpeechTranscript.substring(0, 25)}...' : _liveSpeechTranscript}\"",
                      style: const TextStyle(fontSize: 12.0, fontStyle: FontStyle.italic, color: Color(0xFF475569)),
                    ),
                ],
              ),
            ),

          // Conversation Transcript Stream
          Expanded(
            child: _dialogueHistory.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: const BoxDecoration(
                            color: Color(0xFFEFF6FF),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.record_voice_over_rounded, size: 36, color: Color(0xFF2563EB)),
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          "Direct Voice-to-Voice Interpretation",
                          style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: Color(0xFF0F172A)),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          "Tourist speaks in $_langA, local responds in $_langB.\nContinuous mode automatically translates and alternates turns seamlessly.",
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 12.5, color: Color(0xFF64748B)),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    itemCount: _dialogueHistory.length,
                    itemBuilder: (ctx, i) {
                      final item = _dialogueHistory[i];
                      final isSideA = item["from_side"] == "A";

                      return Align(
                        alignment: isSideA ? Alignment.centerLeft : Alignment.centerRight,
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.85),
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: isSideA ? Colors.white : const Color(0xFFF0FDF4),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: isSideA ? const Color(0xFFBFDBFE) : const Color(0xFFBBF7D0),
                            ),
                            boxShadow: [
                              BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 6, offset: const Offset(0, 2)),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    "${item["source_lang"]} ➔ ${item["target_lang"]}",
                                    style: TextStyle(
                                      fontWeight: FontWeight.w800,
                                      fontSize: 11,
                                      color: isSideA ? const Color(0xFF2563EB) : const Color(0xFF059669),
                                    ),
                                  ),
                                  InkWell(
                                    onTap: () => _playTts(item["translated"], item["target_lang"]),
                                    child: const Icon(Icons.volume_up_rounded, size: 18, color: Color(0xFF64748B)),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Text(
                                item["original"],
                                style: const TextStyle(fontSize: 13.5, color: Color(0xFF64748B)),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                item["translated"],
                                style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),

          // Bottom Push-to-Talk or Continuous Trigger Bar
          Container(
            padding: EdgeInsets.fromLTRB(16, 12, 16, MediaQuery.of(context).padding.bottom + 12),
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
            ),
            child: _autoTurnMode
                ? SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _autoTurnRunning ? const Color(0xFFDC2626) : const Color(0xFF2563EB),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        elevation: 0,
                      ),
                      onPressed: _autoTurnRunning ? _stopAutoTurnLoop : _startAutoTurnLoop,
                      icon: Icon(_autoTurnRunning ? Icons.pause_circle_rounded : Icons.play_circle_filled_rounded, size: 22),
                      label: Text(
                        _autoTurnRunning ? "Pause Hands-Free Session" : "Start Hands-Free Session",
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14.5),
                      ),
                    ),
                  )
                : Row(
                    children: [
                      // Tourist Mic Button (Side A)
                      Expanded(
                        child: SizedBox(
                          height: 52,
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: (_isListening && _activeListeningSide == "A")
                                  ? const Color(0xFFDC2626)
                                  : const Color(0xFF2563EB),
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                              elevation: 0,
                            ),
                            onPressed: () => _startListeningForSide("A"),
                            icon: Icon((_isListening && _activeListeningSide == "A") ? Icons.stop_rounded : Icons.mic_rounded, size: 20),
                            label: Text(
                              (_isListening && _activeListeningSide == "A") ? "Stop" : _langA,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      // Local Speaker Mic Button (Side B)
                      Expanded(
                        child: SizedBox(
                          height: 52,
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: (_isListening && _activeListeningSide == "B")
                                  ? const Color(0xFFDC2626)
                                  : const Color(0xFF059669),
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                              elevation: 0,
                            ),
                            onPressed: () => _startListeningForSide("B"),
                            icon: Icon((_isListening && _activeListeningSide == "B") ? Icons.stop_rounded : Icons.mic_rounded, size: 20),
                            label: Text(
                              (_isListening && _activeListeningSide == "B") ? "Stop" : _langB,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}