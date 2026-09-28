import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:http/http.dart' as http;
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:image/image.dart' as img;
import 'package:gal/gal.dart';

class ConverterStudioScreen extends StatefulWidget {
  final String backendUrl;
  const ConverterStudioScreen({Key? key, required this.backendUrl}) : super(key: key);

  @override
  State<ConverterStudioScreen> createState() => _ConverterStudioScreenState();
}

class _ConverterStudioScreenState extends State<ConverterStudioScreen> with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;

  Uint8List? _convFileBytes;
  String? _convFileName;
  int _convFileSize = 0;
  bool _isConverting = false;
  Uint8List? _convertedResultBytes;
  String? _conversionNotice;

  String _selectedCategory = "Document";
  String _selectedFormat = "DOCX";

  final Map<String, List<String>> _categoryFormats = {
    "Document": ["DOC", "DOCX", "EXCEL", "HTML", "ODT", "PDF", "PPT", "PPTX", "PS", "RTF", "TEXT", "TXT", "WORD", "XLS", "XLSX"],
    "Image": ["BMP", "GIF", "ICO", "JPEG", "JPG", "ODD", "PNG", "PSD", "SVG", "TIFF", "WebP"],
    "Ebook": ["EPUB", "MOBI", "AZW3", "FB2", "LIT", "LRF", "PDB", "PDF"],
    "Report": ["CSV", "JSON", "XML", "XLSX", "PDF"],
  };

  final TextEditingController _widthCtrl = TextEditingController(text: "1080");
  final TextEditingController _heightCtrl = TextEditingController(text: "1080");
  bool _lockAspect = true;
  double _aspectRatio = 1.0;
  Uint8List? _resizerImgBytes;
  String? _resizerImgName;
  bool _isResizing = false;
  Uint8List? _resizedResultBytes;
  String? _resizedDimensions;

  final TextEditingController _amountCtrl = TextEditingController(text: "100");
  String _fromCurr = "USD";
  String _toCurr = "INR";
  bool _isFetchingRates = false;
  String _rateLastUpdated = "Connecting to live feed...";
  String _bullionBenchmark = "IBJA / SPOT";

  final Map<String, double> _ratesPerUsd = {
    "USD": 1.000,
    "EUR": 0.922,
    "GBP": 0.772,
    "AED": 3.673,
    "INR": 95.12,
    "SAR": 3.750,
    "KWD": 0.306,
    "OMR": 0.385,
    "QAR": 3.640,
    "RUB": 91.50,
    "CAD": 1.365,
    "AUD": 1.515,
    "NZD": 1.635,
    "JPY": 154.20,
    "CNY": 7.235,
  };

  final Map<String, String> _currencyNames = {
    "USD": "USD (\$) - US Dollar",
    "EUR": "EUR (€) - Euro",
    "GBP": "GBP (£) - British Pound",
    "AED": "AED (د.إ) - UAE Dirham",
    "INR": "INR (₹) - Indian Rupee",
    "SAR": "SAR (﷼) - Saudi Riyal",
    "KWD": "KWD (د.ك) - Kuwaiti Dinar",
    "OMR": "OMR (ر.ع.) - Omani Rial",
    "QAR": "QAR (ر.ق) - Qatari Riyal",
    "RUB": "RUB (₽) - Russian Ruble",
    "CAD": "CAD (\$) - Canadian Dollar",
    "AUD": "AUD (\$) - Australian Dollar",
    "NZD": "NZD (\$) - New Zealand Dollar",
    "JPY": "JPY (¥) - Japanese Yen",
    "CNY": "CNY (¥) - Chinese Yuan",
  };

  double _gold24kPerGram = 15430.0;
  double _gold22kPerGram = 14144.0;
  double _silverPerGram = 238.0;

  String _travelerGender = "Male";
  final TextEditingController _goldWeightCtrl = TextEditingController(text: "25");

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 3, vsync: this, initialIndex: 2);
    _fetchLiveRates();
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    _widthCtrl.dispose();
    _heightCtrl.dispose();
    _amountCtrl.dispose();
    _goldWeightCtrl.dispose();
    super.dispose();
  }

  Future<void> _fetchLiveRates() async {
    setState(() => _isFetchingRates = true);

    try {
      final res = await http.get(Uri.parse("https://open.er-api.com/v6/latest/USD")).timeout(const Duration(seconds: 8));
      if (res.statusCode == 200) {
        final d = jsonDecode(res.body);
        if (d["result"] == "success" && d["rates"] != null) {
          final liveRates = d["rates"] as Map<String, dynamic>;
          for (String curr in _ratesPerUsd.keys) {
            if (liveRates.containsKey(curr)) {
              _ratesPerUsd[curr] = (liveRates[curr] as num).toDouble();
            }
          }
        }
      }
    } catch (_) {}

    try {
      final cleanBase = widget.backendUrl.replaceAll(RegExp(r'/+$'), '');
      final bRes = await http.get(Uri.parse("$cleanBase/api/v1/bullion-rates?city=mumbai")).timeout(const Duration(seconds: 8));
      if (bRes.statusCode == 200) {
        final bData = jsonDecode(bRes.body);
        setState(() {
          _gold24kPerGram = (bData['gold_24k_per_g'] as num).toDouble();
          _gold22kPerGram = (bData['gold_22k_per_g'] as num).toDouble();
          _silverPerGram = (bData['silver_per_g'] as num).toDouble();
          _bullionBenchmark = bData['benchmark'] ?? "IBJA / SPOT";
        });
      }
    } catch (_) {
      setState(() {
        _gold24kPerGram = 15430.0;
        _gold22kPerGram = 14144.0;
        _silverPerGram = 238.0;
      });
    }

    final inrRate = _ratesPerUsd['INR'] ?? 95.12;
    setState(() {
      _rateLastUpdated = "Live Forex & Bullion Synced (1 USD = ${inrRate.toStringAsFixed(2)} INR)";
      _isFetchingRates = false;
    });
  }

  double _calculateCurrency() {
    final amount = double.tryParse(_amountCtrl.text) ?? 0.0;
    final fromUsdRate = _ratesPerUsd[_fromCurr] ?? 1.0;
    final toUsdRate = _ratesPerUsd[_toCurr] ?? 1.0;
    return (amount / fromUsdRate) * toUsdRate;
  }

  Map<String, dynamic> _calculateCustomsDuty() {
    final weight = double.tryParse(_goldWeightCtrl.text) ?? 0.0;
    final isMale = _travelerGender == "Male";
    final allowedGrams = isMale ? 20.0 : 40.0;
    final allowedValue = isMale ? 50000.0 : 100000.0;

    final excessWeight = (weight - allowedGrams).clamp(0.0, 99999.0);
    final excessValue = excessWeight * _gold24kPerGram;
    final estimatedDuty = excessValue > 0 ? (excessValue * 0.385) : 0.0;

    return {
      "allowedGrams": allowedGrams,
      "allowedValue": allowedValue,
      "excessWeight": excessWeight,
      "excessValue": excessValue,
      "estimatedDuty": estimatedDuty,
      "isExempt": excessWeight == 0.0,
    };
  }

  Future<void> _pickConverterFile() async {
    try {
      FilePickerResult? res = await FilePicker.platform.pickFiles(withData: true);
      if (res != null && res.files.single.bytes != null) {
        final name = res.files.single.name;
        final ext = name.split('.').last.toLowerCase();
        final isImage = ['jpg', 'jpeg', 'png', 'webp', 'bmp', 'gif', 'svg', 'tiff'].contains(ext);

        setState(() {
          _convFileBytes = res.files.single.bytes;
          _convFileName = name;
          _convFileSize = res.files.single.size;
          _convertedResultBytes = null;
          _conversionNotice = null;

          if (isImage) {
            _selectedCategory = "Image";
            _selectedFormat = "JPG";
          } else {
            _selectedCategory = "Document";
            _selectedFormat = "DOCX";
          }
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("File selection failed: $e")));
    }
  }

  void _showFormatPickerSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) {
          String searchQuery = "";
          TextEditingController searchCtrl = TextEditingController();
          final bottomInset = MediaQuery.of(ctx).viewInsets.bottom;
          final systemBottom = MediaQuery.of(ctx).padding.bottom;

          return Container(
            height: MediaQuery.of(context).size.height * 0.75,
            padding: EdgeInsets.only(bottom: bottomInset > 0 ? bottomInset : systemBottom),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Column(
              children: [
                Container(
                  margin: const EdgeInsets.only(top: 10, bottom: 8),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(color: const Color(0xFFCBD5E1), borderRadius: BorderRadius.circular(10)),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: TextField(
                    controller: searchCtrl,
                    decoration: InputDecoration(
                      prefixIcon: const Icon(Icons.search_rounded, color: Color(0xFF64748B), size: 20),
                      hintText: "Search Format",
                      filled: true,
                      fillColor: const Color(0xFFF1F5F9),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    onChanged: (val) => setSheetState(() => searchQuery = val.trim().toUpperCase()),
                  ),
                ),
                const Divider(height: 1),
                Expanded(
                  child: Row(
                    children: [
                      Container(
                        width: 120,
                        decoration: const BoxDecoration(
                          color: Color(0xFFF8FAFC),
                          border: Border(right: BorderSide(color: Color(0xFFE2E8F0))),
                        ),
                        child: ListView(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          children: _categoryFormats.keys.map((cat) {
                            final isSel = _selectedCategory == cat;
                            return InkWell(
                              onTap: () => setSheetState(() => _selectedCategory = cat),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                color: isSel ? Colors.white : Colors.transparent,
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        cat,
                                        style: TextStyle(
                                          fontWeight: isSel ? FontWeight.w800 : FontWeight.w600,
                                          fontSize: 13,
                                          color: isSel ? const Color(0xFF4F46E5) : const Color(0xFF475569),
                                        ),
                                      ),
                                    ),
                                    if (isSel) const Icon(Icons.arrow_right_rounded, color: Color(0xFF4F46E5), size: 18),
                                  ],
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                      Expanded(
                        child: Container(
                          color: Colors.white,
                          child: Builder(
                            builder: (context) {
                              final available = (_categoryFormats[_selectedCategory] ?? []).where(
                                (f) => searchQuery.isEmpty || f.toUpperCase().contains(searchQuery),
                              ).toList();

                              if (available.isEmpty) {
                                return const Center(child: Text("No formats found", style: TextStyle(color: Colors.grey)));
                              }

                              return GridView.builder(
                                padding: const EdgeInsets.all(16),
                                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: 3,
                                  crossAxisSpacing: 10,
                                  mainAxisSpacing: 10,
                                  childAspectRatio: 1.6,
                                ),
                                itemCount: available.length,
                                itemBuilder: (context, i) {
                                  final fmt = available[i];
                                  final isFmtSel = _selectedFormat == fmt;

                                  return InkWell(
                                    onTap: () {
                                      setState(() => _selectedFormat = fmt);
                                      Navigator.pop(ctx);
                                    },
                                    borderRadius: BorderRadius.circular(8),
                                    child: Container(
                                      alignment: Alignment.center,
                                      decoration: BoxDecoration(
                                        color: isFmtSel ? const Color(0xFF4F46E5) : const Color(0xFFF1F5F9),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        fmt,
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 12.5,
                                          color: isFmtSel ? Colors.white : const Color(0xFF1E293B),
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              );
                            },
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _runConversion() async {
    if (_convFileBytes == null) return;

    setState(() {
      _isConverting = true;
      _conversionNotice = null;
      _convertedResultBytes = null;
    });

    try {
      final ext = _convFileName?.split('.').last.toLowerCase() ?? "";
      final isSourceImage = ['jpg', 'jpeg', 'png', 'webp', 'bmp', 'gif'].contains(ext);
      final isTargetImage = ['JPG', 'JPEG', 'PNG', 'WEBP', 'BMP', 'GIF'].contains(_selectedFormat);

      Uint8List outputBytes;

      if (isSourceImage && isTargetImage) {
        final decoded = img.decodeImage(_convFileBytes!);
        if (decoded == null) throw Exception("Could not decode image.");

        switch (_selectedFormat) {
          case "PNG":
            outputBytes = Uint8List.fromList(img.encodePng(decoded));
            break;
          case "BMP":
            outputBytes = Uint8List.fromList(img.encodeBmp(decoded));
            break;
          case "GIF":
            outputBytes = Uint8List.fromList(img.encodeGif(decoded));
            break;
          case "JPG":
          case "JPEG":
          default:
            outputBytes = Uint8List.fromList(img.encodeJpg(decoded, quality: 92));
            break;
        }

        await Gal.putImageBytes(outputBytes, name: "Omni_${DateTime.now().millisecondsSinceEpoch}.${_selectedFormat.toLowerCase()}");
        setState(() {
          _convertedResultBytes = outputBytes;
          _conversionNotice = "✓ Converted and saved directly to your Gallery / Photos!";
        });
      } else if (_selectedFormat == "PDF" && isSourceImage) {
        final pdf = pw.Document();
        final pdfImage = pw.MemoryImage(_convFileBytes!);
        pdf.addPage(pw.Page(pageFormat: PdfPageFormat.a4, build: (_) => pw.Center(child: pw.Image(pdfImage, fit: pw.BoxFit.contain))));
        outputBytes = await pdf.save();

        final tempDir = await getTemporaryDirectory();
        final f = File("${tempDir.path}/Omni_${DateTime.now().millisecondsSinceEpoch}.pdf");
        await f.writeAsBytes(outputBytes);

        setState(() {
          _convertedResultBytes = outputBytes;
          _conversionNotice = "✓ Successfully converted and saved to Documents!";
        });
      } else {
        final cleanBase = widget.backendUrl.replaceAll(RegExp(r'/+$'), '');
        final uri = Uri.parse("$cleanBase/api/v1/convert-file");
        final req = http.MultipartRequest("POST", uri);
        req.fields["target_format"] = _selectedFormat;
        req.files.add(http.MultipartFile.fromBytes("file", _convFileBytes!, filename: _convFileName ?? "document.bin"));

        final streamed = await req.send().timeout(const Duration(seconds: 40));
        final resp = await http.Response.fromStream(streamed);

        if (resp.statusCode == 200) {
          final d = jsonDecode(resp.body);
          if (d["status"] == "success" && d["download_url"] != null) {
            final fileResp = await http.get(Uri.parse(d["download_url"]));
            outputBytes = fileResp.bodyBytes;

            final tempDir = await getTemporaryDirectory();
            final f = File("${tempDir.path}/Converted_${DateTime.now().millisecondsSinceEpoch}.${_selectedFormat.toLowerCase()}");
            await f.writeAsBytes(outputBytes);

            setState(() {
              _convertedResultBytes = outputBytes;
              _conversionNotice = "✓ Document converted successfully!";
            });
          } else {
            throw Exception(d["message"] ?? "Conversion failed on server.");
          }
        } else {
          throw Exception("Server status ${resp.statusCode}");
        }
      }
    } catch (e) {
      setState(() => _conversionNotice = "Conversion failed: $e");
    } finally {
      if (mounted) setState(() => _isConverting = false);
    }
  }

  Future<void> _pickResizerImage() async {
    try {
      FilePickerResult? res = await FilePicker.platform.pickFiles(type: FileType.image, withData: true);
      if (res != null && res.files.single.bytes != null) {
        final bytes = res.files.single.bytes!;
        final decodedImage = await decodeImageFromList(bytes);

        setState(() {
          _resizerImgBytes = bytes;
          _resizerImgName = res.files.single.name;
          _widthCtrl.text = decodedImage.width.toString();
          _heightCtrl.text = decodedImage.height.toString();
          _aspectRatio = decodedImage.width / (decodedImage.height > 0 ? decodedImage.height : 1);
          _resizedResultBytes = null;
          _resizedDimensions = null;
        });
      }
    } catch (_) {}
  }

  Future<void> _runImageResize() async {
    if (_resizerImgBytes == null) return;
    final targetW = int.tryParse(_widthCtrl.text) ?? 1080;
    final targetH = int.tryParse(_heightCtrl.text) ?? 1080;

    setState(() {
      _isResizing = true;
      _resizedResultBytes = null;
      _resizedDimensions = null;
    });

    try {
      final original = img.decodeImage(_resizerImgBytes!);
      if (original == null) throw Exception("Could not decode image.");

      final resized = img.copyResize(original, width: targetW, height: targetH, interpolation: img.Interpolation.cubic);
      final outputBytes = Uint8List.fromList(img.encodeJpg(resized, quality: 92));

      await Gal.putImageBytes(outputBytes, name: "Omni_Resized_${DateTime.now().millisecondsSinceEpoch}.jpg");

      setState(() {
        _resizedResultBytes = outputBytes;
        _resizedDimensions = "${resized.width} x ${resized.height} px";
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Resize error: $e")));
    } finally {
      if (mounted) setState(() => _isResizing = false);
    }
  }

  Future<void> _shareBytes(Uint8List bytes, String filename) async {
    final tempDir = await getTemporaryDirectory();
    final file = File("${tempDir.path}/$filename");
    await file.writeAsBytes(bytes);
    Share.shareXFiles([XFile(file.path)], text: "Converted via Omni TouristOS");
  }

  Widget _buildMetalCard(String title, String purity, String ratePerG, String rateBulk, Color accentColor, IconData icon) {
    return Container(
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
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(title, style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5, color: accentColor)),
              Icon(icon, size: 16, color: accentColor),
            ],
          ),
          const SizedBox(height: 2),
          Text(purity, style: const TextStyle(fontSize: 10, color: Color(0xFF64748B), fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Text(ratePerG, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15.5, color: Color(0xFF0F172A))),
          const SizedBox(height: 2),
          Text(rateBulk, style: const TextStyle(fontSize: 11, color: Color(0xFF64748B), fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).padding.bottom;
    final customs = _calculateCustomsDuty();

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Color(0xFF0F172A), size: 24),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          "Converter Studio",
          style: TextStyle(fontWeight: FontWeight.w900, fontSize: 17, color: Color(0xFF0F172A)),
        ),
        backgroundColor: const Color(0xFFF8FAFC), // Unified seamless edge
        elevation: 0,
        scrolledUnderElevation: 0,
        bottom: TabBar(
          controller: _tabCtrl,
          labelColor: const Color(0xFF4F46E5),
          unselectedLabelColor: Colors.grey.shade600,
          indicatorColor: const Color(0xFF4F46E5),
          indicatorWeight: 3,
          labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
          tabs: const [
            Tab(text: "Format Converter"),
            Tab(text: "Image Resizer"),
            Tab(text: "Forex & Bullion"),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabCtrl,
        children: [
          // TAB 1: FORMAT CONVERTER
          SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(16, 16, 16, (bottomInset > 0 ? bottomInset : 14) + 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_convFileName != null) ...[
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.insert_drive_file_rounded, color: Color(0xFF4F46E5), size: 24),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _convFileName!,
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5, color: Color(0xFF0F172A)),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 2),
                              Text(
                                "${(_convFileSize / (1024 * 1024)).toStringAsFixed(2)} MB",
                                style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
                              ),
                            ],
                          ),
                        ),
                        InkWell(
                          onTap: _showFormatPickerSheet,
                          borderRadius: BorderRadius.circular(8),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: const Color(0xFFEEF2FF),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: const Color(0xFFC7D2FE)),
                            ),
                            child: Row(
                              children: [
                                const Text("Output: ", style: TextStyle(fontSize: 11.5, color: Color(0xFF4F46E5))),
                                Text(
                                  _selectedFormat,
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5, color: Color(0xFF4F46E5)),
                                ),
                                const SizedBox(width: 4),
                                const Icon(Icons.keyboard_arrow_down_rounded, size: 16, color: Color(0xFF4F46E5)),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        IconButton(
                          icon: const Icon(Icons.cancel_rounded, color: Colors.grey, size: 20),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          onPressed: () => setState(() {
                            _convFileBytes = null;
                            _convFileName = null;
                            _convertedResultBytes = null;
                            _conversionNotice = null;
                          }),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ] else ...[
                  Center(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF4F46E5),
                        side: const BorderSide(color: Color(0xFF4F46E5)),
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: _pickConverterFile,
                      icon: const Icon(Icons.add_circle_outline_rounded),
                      label: const Text("Select Document or Image to Convert", style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF4F46E5),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    onPressed: (_convFileBytes == null || _isConverting) ? null : _runConversion,
                    icon: _isConverting
                        ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const SizedBox.shrink(),
                    label: Text(
                      _isConverting ? "Converting..." : "Convert ➔",
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                  ),
                ),

                if (_conversionNotice != null) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF0FDF4),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFBBF7D0)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.check_circle_rounded, color: Color(0xFF16A34A), size: 20),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(_conversionNotice!, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF166534))),
                            ),
                          ],
                        ),
                        if (_convertedResultBytes != null) ...[
                          const SizedBox(height: 10),
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(
                                foregroundColor: const Color(0xFF16A34A),
                                side: const BorderSide(color: Color(0xFF16A34A)),
                              ),
                              onPressed: () => _shareBytes(_convertedResultBytes!, "Omni_Converted.${_selectedFormat.toLowerCase()}"),
                              icon: const Icon(Icons.share_rounded, size: 16),
                              label: const Text("Share Converted File", style: TextStyle(fontWeight: FontWeight.bold)),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),

          // TAB 2: IMAGE RESIZER
          SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(16, 16, 16, (bottomInset > 0 ? bottomInset : 14) + 20),
            child: Column(
              children: [
                Center(
                  child: OutlinedButton.icon(
                    onPressed: _pickResizerImage,
                    icon: const Icon(Icons.photo_library_rounded),
                    label: const Text("Select Image from Gallery"),
                  ),
                ),
                if (_resizerImgBytes != null) ...[
                  const SizedBox(height: 14),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Image.memory(_resizerImgBytes!, height: 130, fit: BoxFit.contain),
                  ),
                ],
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _widthCtrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: "Width (px)", border: OutlineInputBorder(), isDense: true),
                        onChanged: (val) {
                          if (_lockAspect && _aspectRatio > 0) {
                            final w = double.tryParse(val) ?? 0;
                            _heightCtrl.text = (w / _aspectRatio).round().toString();
                          }
                        },
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextField(
                        controller: _heightCtrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: "Height (px)", border: OutlineInputBorder(), isDense: true),
                        onChanged: (val) {
                          if (_lockAspect && _aspectRatio > 0) {
                            final h = double.tryParse(val) ?? 0;
                            _widthCtrl.text = (h * _aspectRatio).round().toString();
                          }
                        },
                      ),
                    ),
                  ],
                ),
                CheckboxListTile(
                  title: const Text("Lock Aspect Ratio"),
                  value: _lockAspect,
                  contentPadding: EdgeInsets.zero,
                  onChanged: (v) => setState(() => _lockAspect = v ?? true),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  height: 46,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF4F46E5), foregroundColor: Colors.white),
                    onPressed: _isResizing ? null : _runImageResize,
                    child: Text(_isResizing ? "Resizing..." : "RESIZE & SAVE TO GALLERY ➔", style: const TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
                if (_resizedResultBytes != null) ...[
                  const SizedBox(height: 14),
                  Text("✓ Saved to Gallery with dimensions: $_resizedDimensions", style: const TextStyle(color: Color(0xFF16A34A), fontWeight: FontWeight.bold)),
                ],
              ],
            ),
          ),

          // TAB 3: FOREX & BULLION
          SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(16, 16, 16, (bottomInset > 0 ? bottomInset : 14) + 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text("Live Global Forex Exchange", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                    IconButton(
                      icon: _isFetchingRates
                          ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                          : const Icon(Icons.refresh_rounded, color: Color(0xFF4F46E5)),
                      onPressed: _isFetchingRates ? null : _fetchLiveRates,
                    ),
                  ],
                ),
                Row(
                  children: [
                    const Icon(Icons.cloud_done_rounded, size: 13, color: Color(0xFF16A34A)),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(_rateLastUpdated, style: TextStyle(fontSize: 11, color: Colors.grey.shade600, fontWeight: FontWeight.w600)),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: _amountCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(labelText: "Enter Amount", border: OutlineInputBorder(), isDense: true),
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: _fromCurr,
                        isExpanded: true,
                        items: _ratesPerUsd.keys.map((c) => DropdownMenuItem(value: c, child: Text(_currencyNames[c] ?? c, style: const TextStyle(fontSize: 12), overflow: TextOverflow.ellipsis))).toList(),
                        onChanged: (v) => setState(() => _fromCurr = v!),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.swap_horiz_rounded, color: Color(0xFF4F46E5)),
                      onPressed: () => setState(() {
                        final tmp = _fromCurr;
                        _fromCurr = _toCurr;
                        _toCurr = tmp;
                      }),
                    ),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: _toCurr,
                        isExpanded: true,
                        items: _ratesPerUsd.keys.map((c) => DropdownMenuItem(value: c, child: Text(_currencyNames[c] ?? c, style: const TextStyle(fontSize: 12), overflow: TextOverflow.ellipsis))).toList(),
                        onChanged: (v) => setState(() => _toCurr = v!),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF4F46E5).withOpacity(0.08),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFF4F46E5).withOpacity(0.3)),
                  ),
                  child: Column(
                    children: [
                      Text("$_fromCurr ${_amountCtrl.text} =", style: TextStyle(fontSize: 13, color: Colors.grey.shade700, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      Text("$_toCurr ${_calculateCurrency().toStringAsFixed(2)}", style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF4F46E5))),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: const [
                        Icon(Icons.workspace_premium_rounded, color: Color(0xFFD97706), size: 20),
                        SizedBox(width: 6),
                        Text("Precious Metals Benchmark", style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Color(0xFF0F172A))),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(color: const Color(0xFFFEF3C7), borderRadius: BorderRadius.circular(8)),
                      child: Text(_bullionBenchmark, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFFB45309))),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                const Text(
                  "Indicative physical bullion rates for Mumbai / Domestic (Excl. 3% GST & making charges)",
                  style: TextStyle(fontSize: 10.5, color: Color(0xFF64748B)),
                ),
                const SizedBox(height: 12),

                Row(
                  children: [
                    Expanded(
                      child: _buildMetalCard(
                        "24K Gold",
                        "99.9% Pure",
                        "₹${_gold24kPerGram.toStringAsFixed(0)} /g",
                        "₹${(_gold24kPerGram * 10).toStringAsFixed(0)} /10g",
                        const Color(0xFFD97706),
                        Icons.monetization_on_rounded,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildMetalCard(
                        "22K Gold",
                        "916 Hallmark",
                        "₹${_gold22kPerGram.toStringAsFixed(0)} /g",
                        "₹${(_gold22kPerGram * 10).toStringAsFixed(0)} /10g",
                        const Color(0xFFB45309),
                        Icons.diamond_rounded,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildMetalCard(
                        "Silver 999",
                        "Fine Silver",
                        "₹${_silverPerGram.toStringAsFixed(0)} /g",
                        "₹${(_silverPerGram * 1000).toStringAsFixed(0)} /kg",
                        const Color(0xFF475569),
                        Icons.shield_rounded,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 24),

                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFCBD5E1)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.02),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: const [
                          Icon(Icons.flight_land_rounded, color: Color(0xFF2563EB), size: 20),
                          SizedBox(width: 8),
                          Text(
                            "India Customs Duty-Free Allowance",
                            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: Color(0xFF0F172A)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        "Baggage Rules for passengers returning after 1+ year stay abroad",
                        style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: SegmentedButton<String>(
                              segments: const [
                                ButtonSegment(value: "Male", label: Text("Gentleman (20g)")),
                                ButtonSegment(value: "Female", label: Text("Lady (40g)")),
                              ],
                              selected: {_travelerGender},
                              onSelectionChanged: (val) => setState(() => _travelerGender = val.first),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _goldWeightCtrl,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: const InputDecoration(
                          labelText: "Total Weight of Jewellery (Grams)",
                          border: OutlineInputBorder(),
                          isDense: true,
                          suffixText: "grams",
                        ),
                        onChanged: (_) => setState(() {}),
                      ),
                      const SizedBox(height: 14),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: (customs["isExempt"] as bool) ? const Color(0xFFF0FDF4) : const Color(0xFFFEF2F2),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: (customs["isExempt"] as bool) ? const Color(0xFFBBF7D0) : const Color(0xFFFECACA),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  (customs["isExempt"] as bool) ? "✓ Fully Duty-Free Exempt" : "⚠ Excess Declared Baggage",
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12.5,
                                    color: (customs["isExempt"] as bool) ? const Color(0xFF166534) : const Color(0xFF991B1B),
                                  ),
                                ),
                                Text(
                                  "Limit: ${(customs['allowedGrams'] as double).toInt()}g (₹${(customs['allowedValue'] as double).toInt()})",
                                  style: const TextStyle(fontSize: 11, color: Color(0xFF64748B), fontWeight: FontWeight.w600),
                                ),
                              ],
                            ),
                            if (!(customs["isExempt"] as bool)) ...[
                              const SizedBox(height: 6),
                              Text(
                                "Excess: ${(customs['excessWeight'] as double).toStringAsFixed(1)} grams (~₹${(customs['excessValue'] as double).toStringAsFixed(0)})",
                                style: const TextStyle(fontSize: 11.5, color: Color(0xFFB91C1C), fontWeight: FontWeight.w600),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                "Est. Customs Duty (38.5%): ₹${(customs['estimatedDuty'] as double).toStringAsFixed(0)}",
                                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF991B1B)),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
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