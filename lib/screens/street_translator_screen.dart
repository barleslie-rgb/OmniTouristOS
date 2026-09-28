import 'dart:async';
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
  String _activeListeningSide = ""; // "A" or "B"
  bool _isTranslating = false;
  bool _isSpeaking = false;
  String? _statusError;

  bool _isFemaleVoice = false;
  List<dynamic> _ttsVoices = [];

  String _langA = "Marathi";
  String _langB = "Hindi";

  final List<Map<String, dynamic>> _dialogueHistory = [];
  String _liveSpeechTranscript = "";
  bool _isProcessingSession = false;

  final ImagePicker _picker = ImagePicker();
  bool _isLensScanning = false;
  bool _isLensSpeaking = false;

  final List<Map<String, String>> _languages = [
    {"label": "मराठी (Marathi)", "code": "Marathi", "iso": "mr", "locale": "mr_IN", "tts": "mr-IN"},
    {"label": "हिंदी (Hindi)", "code": "Hindi", "iso": "hi", "locale": "hi_IN", "tts": "hi-IN"},
    {"label": "English", "code": "English", "iso": "en", "locale": "en_IN", "tts": "en-US"},
    {"label": "ગુજરાતી (Gujarati)", "code": "Gujarati", "iso": "gu", "locale": "gu_IN", "tts": "gu-IN"},
    {"label": "தமிழ் (Tamil)", "code": "Tamil", "iso": "ta", "locale": "ta_IN", "tts": "ta-IN"},
    {"label": "తెలుగు (Telugu)", "code": "Telugu", "iso": "te", "locale": "te_IN", "tts": "te-IN"},
    {"label": "ಕನ್ನಡ (Kannada)", "code": "Kannada", "iso": "kn", "locale": "kn_IN", "tts": "kn-IN"},
    {"label": "বাংলা (Bengali)", "code": "Bengali", "iso": "bn", "locale": "bn_IN", "tts": "bn-IN"},
    {"label": "മലയാളം (Malayalam)", "code": "Malayalam", "iso": "ml", "locale": "ml_IN", "tts": "ml-IN"},
    {"label": "ਪੰਜਾਬੀ (Punjabi)", "code": "Punjabi", "iso": "pa", "locale": "pa_IN", "tts": "pa-IN"},
    {"label": "اردو (Urdu)", "code": "Urdu", "iso": "ur", "locale": "ur_PK", "tts": "ur-PK"},
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
    if (lower.contains("hindi") || widget.language.contains("हिंदी")) {
      _langA = "Marathi";
      _langB = "Hindi";
    } else if (lower.contains("english")) {
      _langA = "English";
      _langB = "Hindi";
    } else {
      _langA = "Marathi";
      _langB = "Hindi";
    }
  }

  Future<void> _initAudioEngines() async {
    _speech = stt.SpeechToText();
    try {
      _isSpeechInitialized = await _speech.initialize(
        onError: (e) {
          if (mounted) {
            setState(() {
              _isListening = false;
              if (e.errorMsg != "error_no_match") {
                _statusError = "Microphone notice: ${e.errorMsg}";
              }
            });
          }
        },
        onStatus: (status) {
          if (status == "done" || status == "notListening") {
            if (mounted && _isListening && !_isProcessingSession) {
              _handleSpeechCompletion();
            }
          }
        },
      );
    } catch (_) {
      _isSpeechInitialized = false;
    }

    _flutterTts = FlutterTts();
    try {
      final voices = await _flutterTts.getVoices;
      if (voices is List && voices.isNotEmpty) {
        _ttsVoices = voices;
      }
    } catch (_) {}

    _flutterTts.setStartHandler(() {
      if (mounted) setState(() => _isSpeaking = true);
    });
    _flutterTts.setCompletionHandler(() {
      if (mounted) setState(() => _isSpeaking = false);
    });
    _flutterTts.setCancelHandler(() {
      if (mounted) setState(() => _isSpeaking = false);
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
      orElse: () => {"locale": "mr_IN"},
    )["locale"]!;
  }

  String _getTtsLocale(String langCode) {
    return _languages.firstWhere(
      (e) => e["code"] == langCode,
      orElse: () => {"tts": "mr-IN"},
    )["tts"]!;
  }

  String _getIso(String langCode) {
    return _languages.firstWhere(
      (e) => e["code"] == langCode,
      orElse: () => {"iso": "mr"},
    )["iso"]!;
  }

  Future<void> _applyVoiceProfile(String locale) async {
    if (_ttsVoices.isEmpty) {
      try {
        final voices = await _flutterTts.getVoices;
        if (voices is List) _ttsVoices = voices;
      } catch (_) {}
    }

    await _flutterTts.setLanguage(locale);

    if (_ttsVoices.isNotEmpty) {
      try {
        final prefix = locale.split(RegExp(r'[-_]')).first.toLowerCase();
        final matches = _ttsVoices.where((v) {
          final l = (v["locale"] ?? "").toString().toLowerCase();
          return l.contains(prefix);
        }).toList();

        Map<dynamic, dynamic>? chosen;
        for (var v in matches) {
          final name = (v["name"] ?? "").toString().toLowerCase();
          if (!_isFemaleVoice) {
            if (name.contains("male") || name.contains("man") || name.contains("#m") || name.contains("-m-") || name.contains("iom")) {
              chosen = v as Map<dynamic, dynamic>;
              break;
            }
          } else {
            if (name.contains("female") || name.contains("woman") || name.contains("#f") || name.contains("-f-") || name.contains("sfg")) {
              chosen = v as Map<dynamic, dynamic>;
              break;
            }
          }
        }

        if (chosen != null) {
          await _flutterTts.setVoice({
            "name": chosen["name"].toString(),
            "locale": chosen["locale"].toString(),
          });
        }
      } catch (_) {}
    }

    if (_isFemaleVoice) {
      await _flutterTts.setPitch(1.18);
      await _flutterTts.setSpeechRate(0.48);
    } else {
      await _flutterTts.setPitch(0.60);
      await _flutterTts.setSpeechRate(0.46);
    }
  }

  Future<void> _startListeningForSide(String side) async {
    await _flutterTts.stop();

    if (_isListening) {
      await _speech.stop();
      if (_activeListeningSide == side) {
        setState(() {
          _isListening = false;
          _activeListeningSide = "";
        });
        return;
      }
    }

    if (!_isSpeechInitialized) {
      _isSpeechInitialized = await _speech.initialize();
      if (!_isSpeechInitialized) {
        setState(() => _statusError = "Microphone permission required.");
        return;
      }
    }

    final activeLang = (side == "A") ? _langA : _langB;
    final locale = _getRecognitionLocale(activeLang);

    HapticFeedback.mediumImpact();

    setState(() {
      _isListening = true;
      _isProcessingSession = false;
      _activeListeningSide = side;
      _liveSpeechTranscript = "";
      _statusError = null;
    });

    try {
      await _speech.listen(
        localeId: locale,
        listenMode: stt.ListenMode.dictation,
        partialResults: true,
        listenFor: const Duration(seconds: 40),
        pauseFor: const Duration(seconds: 3),
        onResult: (val) {
          if (mounted) {
            setState(() {
              _liveSpeechTranscript = val.recognizedWords;
            });
            if (val.finalResult && !_isProcessingSession) {
              _handleSpeechCompletion();
            }
          }
        },
      );
    } catch (e) {
      setState(() {
        _isListening = false;
        _statusError = "Listening error: $e";
      });
    }
  }

  void _handleSpeechCompletion() async {
    if (_isProcessingSession) return;
    _isProcessingSession = true;

    final phrase = _liveSpeechTranscript.trim();
    final side = _activeListeningSide;

    await _speech.stop();

    setState(() {
      _isListening = false;
      _activeListeningSide = "";
    });

    if (phrase.isEmpty) {
      _isProcessingSession = false;
      return;
    }

    await _translateAndBroadcast(phrase, side);
    _isProcessingSession = false;
  }

  Future<void> _translateAndBroadcast(String rawPhrase, String fromSide) async {
    final sourceLang = (fromSide == "A") ? _langA : _langB;
    final targetLang = (fromSide == "A") ? _langB : _langA;

    setState(() {
      _isTranslating = true;
      _statusError = null;
    });

    String? translatedText;

    // 1. Direct High-Accuracy Neural Translation
    try {
      final sIso = _getIso(sourceLang);
      final tIso = _getIso(targetLang);
      final url = Uri.parse(
        "https://translate.googleapis.com/translate_a/single?client=gtx&sl=$sIso&tl=$tIso&dt=t&q=${Uri.encodeComponent(rawPhrase)}",
      );
      final res = await http.get(url).timeout(const Duration(seconds: 7));
      if (res.statusCode == 200) {
        final List parsed = jsonDecode(res.body);
        final buffer = StringBuffer();
        for (var part in parsed[0]) {
          if (part[0] != null) buffer.write(part[0]);
        }
        final out = buffer.toString().trim();
        if (out.isNotEmpty) translatedText = out;
      }
    } catch (_) {}

    // 2. Server Cluster Fallback
    if (translatedText == null || translatedText.isEmpty) {
      try {
        final cleanUrl = widget.backendUrl.replaceAll(RegExp(r'/+$'), '');
        final res = await http.post(
          Uri.parse("$cleanUrl/api/v1/street-voice-translate"),
          body: {
            "text": rawPhrase,
            "source_language": sourceLang,
            "target_language": targetLang,
          },
        ).timeout(const Duration(seconds: 8));

        if (res.statusCode == 200) {
          final d = jsonDecode(res.body);
          if (d["translation"] != null) {
            translatedText = d["translation"].toString().trim();
          }
        }
      } catch (_) {}
    }

    final finalResult = translatedText ?? rawPhrase;

    if (mounted) {
      setState(() {
        _isTranslating = false;
        _dialogueHistory.insert(0, {
          "from_side": fromSide,
          "source_lang": sourceLang,
          "target_lang": targetLang,
          "original": rawPhrase,
          "translated": finalResult,
          "timestamp": DateTime.now(),
        });
      });
    }

    if (finalResult.isNotEmpty) {
      await _playTts(finalResult, targetLang);
    }
  }

  Future<void> _playTts(String text, String languageCode) async {
    try {
      await _flutterTts.stop();
      final locale = _getTtsLocale(languageCode);
      await _applyVoiceProfile(locale);
      await _flutterTts.speak(text);
    } catch (_) {
      if (mounted) setState(() => _isSpeaking = false);
    }
  }

  void _swapLanguages() {
    HapticFeedback.selectionClick();
    setState(() {
      final temp = _langA;
      _langA = _langB;
      _langB = temp;
    });
  }

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
          const SnackBar(content: Text("Street Lens could not process signboard.")),
        );
      }
    } catch (e) {
      if (mounted) setState(() => _isLensScanning = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Camera Lens notice: $e")));
    }
  }

  void _showLensResultSheet(String interpretation, File imageFile) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            final bottomInset = MediaQuery.of(ctx).padding.bottom;
            final keyboardInset = MediaQuery.of(ctx).viewInsets.bottom;
            return Padding(
              padding: EdgeInsets.fromLTRB(20, 16, 20, keyboardInset > 0 ? keyboardInset + 16 : bottomInset + 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(width: 40, height: 4, decoration: BoxDecoration(color: const Color(0xFFCBD5E1), borderRadius: BorderRadius.circular(4))),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: const [
                          Icon(Icons.camera_alt_rounded, color: Color(0xFF2563EB), size: 20),
                          SizedBox(width: 8),
                          Text("Signboard Translation", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: Color(0xFF0F172A))),
                        ],
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded, size: 20),
                        onPressed: () {
                          _flutterTts.stop();
                          Navigator.pop(ctx);
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: SizedBox(
                      height: 140,
                      width: double.infinity,
                      child: Image.file(imageFile, fit: BoxFit.cover),
                    ),
                  ),
                  const SizedBox(height: 14),
                  SelectableText(
                    interpretation,
                    style: const TextStyle(fontSize: 14.5, color: Color(0xFF1E293B), height: 1.4),
                  ),
                  const SizedBox(height: 16),
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
                      onPressed: () async {
                        setSheetState(() => _isLensSpeaking = true);
                        await _playTts(interpretation, _langA);
                        if (mounted) setSheetState(() => _isLensSpeaking = false);
                      },
                      icon: const Icon(Icons.volume_up_rounded, size: 18),
                      label: Text(_isLensSpeaking ? "Speaking Aloud..." : "Speak Aloud", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    ),
                  ),
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
    final topInset = MediaQuery.of(context).padding.top;
    final bottomInset = MediaQuery.of(context).padding.bottom;

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
            // Luxury Dissolve Header ($y = 0$)
            Container(
              padding: EdgeInsets.fromLTRB(16, topInset + 6, 16, 12),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                border: Border(
                  bottom: BorderSide(color: const Color(0xFFE2E8F0).withOpacity(0.6), width: 0.6),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      InkWell(
                        onTap: () {
                          _speech.stop();
                          _flutterTts.stop();
                          Navigator.of(context).pop();
                        },
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
                          children: const [
                            Text(
                              "VOICE INTERPRETER & LENS",
                              style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Color(0xFF64748B), letterSpacing: 0.5),
                            ),
                            Text(
                              "Direct Two-Way Dialogue",
                              style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: Color(0xFF0F172A)),
                            ),
                          ],
                        ),
                      ),
                      // Male vs Female Voice Profile Toggle
                      IconButton(
                        tooltip: _isFemaleVoice ? "Voice: Female" : "Voice: Male (Acoustic)",
                        icon: Icon(
                          _isFemaleVoice ? Icons.female_rounded : Icons.male_rounded,
                          color: _isFemaleVoice ? const Color(0xFFEC4899) : const Color(0xFF2563EB),
                          size: 24,
                        ),
                        onPressed: () {
                          HapticFeedback.selectionClick();
                          setState(() => _isFemaleVoice = !_isFemaleVoice);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              duration: const Duration(seconds: 1),
                              content: Text(_isFemaleVoice ? "Voice Profile: Female" : "Voice Profile: Male (Deep Acoustic)"),
                            ),
                          );
                        },
                      ),
                      // Street Lens Button
                      InkWell(
                        onTap: _isLensScanning ? null : _launchStreetLens,
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEFF6FF),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFFBFDBFE), width: 0.6),
                          ),
                          child: Row(
                            children: [
                              if (_isLensScanning)
                                const SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF2563EB)))
                              else
                                const Icon(Icons.camera_alt_rounded, size: 14, color: Color(0xFF2563EB)),
                              const SizedBox(width: 5),
                              const Text("Lens", style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: Color(0xFF1E40AF))),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 14),

                  // Soft-Surface Language Pairing Hub
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFE2E8F0), width: 0.6),
                      boxShadow: [
                        BoxShadow(color: Colors.black.withOpacity(0.015), blurRadius: 6, offset: const Offset(0, 2)),
                      ],
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              value: _langA,
                              isExpanded: true,
                              style: const TextStyle(fontWeight: FontWeight.w900, color: Color(0xFF2563EB), fontSize: 13.5),
                              items: _languages.map((l) {
                                return DropdownMenuItem<String>(value: l["code"], child: Text(l["label"]!, overflow: TextOverflow.ellipsis));
                              }).toList(),
                              onChanged: (val) {
                                if (val != null && val != _langB) setState(() => _langA = val);
                              },
                            ),
                          ),
                        ),
                        InkWell(
                          onTap: _swapLanguages,
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            padding: const EdgeInsets.all(7),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF1F5F9),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.swap_horiz_rounded, color: Color(0xFF475569), size: 18),
                          ),
                        ),
                        Expanded(
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              value: _langB,
                              isExpanded: true,
                              alignment: Alignment.centerRight,
                              style: const TextStyle(fontWeight: FontWeight.w900, color: Color(0xFF0F172A), fontSize: 13.5),
                              items: _languages.map((l) {
                                return DropdownMenuItem<String>(value: l["code"], child: Text(l["label"]!, overflow: TextOverflow.ellipsis));
                              }).toList(),
                              onChanged: (val) {
                                if (val != null && val != _langA) setState(() => _langB = val);
                              },
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            if (_statusError != null)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                color: const Color(0xFFFEF2F2),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline_rounded, size: 15, color: Color(0xFFDC2626)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(_statusError!, style: const TextStyle(fontSize: 11.5, color: Color(0xFFDC2626), fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              ),

            // Live Speech / Translation Processing Strip
            if (_isListening || _isTranslating || _isSpeaking)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                color: const Color(0xFFEFF6FF),
                child: Row(
                  children: [
                    const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF2563EB)),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _isTranslating
                            ? "Translating accurately..."
                            : _isSpeaking
                                ? "Speaking response aloud..."
                                : "Listening to ${_activeListeningSide == "A" ? _langA : _langB}...",
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF1E40AF)),
                      ),
                    ),
                    if (_liveSpeechTranscript.isNotEmpty)
                      Flexible(
                        child: Text(
                          "\"${_liveSpeechTranscript.length > 20 ? '${_liveSpeechTranscript.substring(0, 20)}...' : _liveSpeechTranscript}\"",
                          style: const TextStyle(fontSize: 11.5, fontStyle: FontStyle.italic, color: Color(0xFF64748B)),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                ),
              ),

            // Dialogue Conversation Stream
            Expanded(
              child: _dialogueHistory.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(32),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(18),
                              decoration: const BoxDecoration(color: Color(0xFFEFF6FF), shape: BoxShape.circle),
                              child: const Icon(Icons.record_voice_over_rounded, size: 38, color: Color(0xFF2563EB)),
                            ),
                            const SizedBox(height: 16),
                            const Text(
                              "Tap Below to Speak",
                              style: TextStyle(fontWeight: FontWeight.w900, fontSize: 17, color: Color(0xFF0F172A)),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              "Tap '$_langA' to speak your message.\nTap '$_langB' when the local person is responding.",
                              textAlign: TextAlign.center,
                              style: const TextStyle(fontSize: 13, color: Color(0xFF64748B), height: 1.4),
                            ),
                          ],
                        ),
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                      itemCount: _dialogueHistory.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                      itemBuilder: (ctx, i) {
                        final item = _dialogueHistory[i];
                        final isSideA = item["from_side"] == "A";

                        return Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: isSideA ? const Color(0xFFBFDBFE) : const Color(0xFFE2E8F0),
                              width: 0.6,
                            ),
                            boxShadow: [
                              BoxShadow(color: Colors.black.withOpacity(0.015), blurRadius: 6, offset: const Offset(0, 2)),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: isSideA ? const Color(0xFFEFF6FF) : const Color(0xFFF1F5F9),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      "${item["source_lang"]} ➔ ${item["target_lang"]}",
                                      style: TextStyle(
                                        fontWeight: FontWeight.w800,
                                        fontSize: 10.5,
                                        color: isSideA ? const Color(0xFF2563EB) : const Color(0xFF334155),
                                      ),
                                    ),
                                  ),
                                  Row(
                                    children: [
                                      IconButton(
                                        padding: EdgeInsets.zero,
                                        constraints: const BoxConstraints(),
                                        icon: const Icon(Icons.volume_up_rounded, size: 18, color: Color(0xFF2563EB)),
                                        onPressed: () => _playTts(item["translated"], item["target_lang"]),
                                      ),
                                      const SizedBox(width: 10),
                                      IconButton(
                                        padding: EdgeInsets.zero,
                                        constraints: const BoxConstraints(),
                                        icon: const Icon(Icons.copy_rounded, size: 16, color: Color(0xFF64748B)),
                                        onPressed: () {
                                          Clipboard.setData(ClipboardData(text: item["translated"]));
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            const SnackBar(duration: Duration(seconds: 1), content: Text("Copied translation to clipboard")),
                                          );
                                        },
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(
                                item["original"],
                                style: const TextStyle(fontSize: 13, color: Color(0xFF64748B)),
                              ),
                              const SizedBox(height: 4),
                              SelectableText(
                                item["translated"],
                                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: Color(0xFF0F172A), height: 1.3),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
            ),

            // Standardized Bottom Cockpit (Matched Height 46, Brand Theme)
            Container(
              padding: EdgeInsets.fromLTRB(16, 10, 16, bottomInset > 0 ? bottomInset + 8 : 14),
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(top: BorderSide(color: Color(0xFFE2E8F0), width: 0.6)),
              ),
              child: Row(
                children: [
                  // Side A Button (Tourist Speaker)
                  Expanded(
                    child: SizedBox(
                      height: 46,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: (_isListening && _activeListeningSide == "A")
                              ? const Color(0xFFDC2626)
                              : const Color(0xFF2563EB),
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                        onPressed: () => _startListeningForSide("A"),
                        icon: Icon((_isListening && _activeListeningSide == "A") ? Icons.stop_rounded : Icons.mic_rounded, size: 18),
                        label: Text(
                          (_isListening && _activeListeningSide == "A") ? "Stop" : "Speak $_langA",
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  // Side B Button (Local Speaker)
                  Expanded(
                    child: SizedBox(
                      height: 46,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: (_isListening && _activeListeningSide == "B")
                              ? const Color(0xFFDC2626)
                              : const Color(0xFF0F172A),
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                        onPressed: () => _startListeningForSide("B"),
                        icon: Icon((_isListening && _activeListeningSide == "B") ? Icons.stop_rounded : Icons.mic_rounded, size: 18),
                        label: Text(
                          (_isListening && _activeListeningSide == "B") ? "Stop" : "Speak $_langB",
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
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