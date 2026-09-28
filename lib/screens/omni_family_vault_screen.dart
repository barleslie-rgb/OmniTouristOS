import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/trip_state_service.dart';

class OmniFamilyVaultScreen extends StatefulWidget {
  final String language;
  final String backendUrl;

  const OmniFamilyVaultScreen({
    Key? key,
    required this.language,
    this.backendUrl = "https://omni-backend-pk28.onrender.com",
  }) : super(key: key);

  @override
  State<OmniFamilyVaultScreen> createState() => _OmniFamilyVaultScreenState();
}

class _OmniFamilyVaultScreenState extends State<OmniFamilyVaultScreen> {
  List<Map<String, String>> _familyMembers = [
    {"name": "Self", "role": "Primary"},
    {"name": "Spouse", "role": "Spouse"},
    {"name": "Aarav", "role": "Child"},
  ];
  String _activeMember = "Self";

  Map<String, List<Map<String, dynamic>>> _vaultData = {};
  List<Map<String, dynamic>> _bookmarkedPlaces = [];
  bool _isLoading = true;
  bool _isExporting = false;

  final List<String> _documentCategories = [
    "Passport",
    "Aadhaar Card",
    "PAN Card",
    "National ID",
    "Driver's License",
    "Visa",
    "Flight Ticket",
    "Train Ticket",
    "Cruise Ticket",
    "Hotel Booking",
    "Health / Travel Insurance",
    "Other Important Document",
  ];

  @override
  void initState() {
    super.initState();
    _loadVaultData();
  }

  Future<void> _loadVaultData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final membersRaw = prefs.getString("vault_family_profiles_v2");
      if (membersRaw != null && membersRaw.isNotEmpty) {
        final List decodedMembers = jsonDecode(membersRaw);
        _familyMembers = decodedMembers
            .map((m) => {
                  "name": (m["name"] ?? "").toString(),
                  "role": (m["role"] ?? "Family").toString(),
                })
            .toList();
      } else {
        final legacyMembers = prefs.getStringList("vault_members");
        if (legacyMembers != null && legacyMembers.isNotEmpty) {
          _familyMembers = legacyMembers.map((m) {
            String role = "Family";
            final lower = m.toLowerCase();
            if (lower.contains("self")) role = "Primary";
            if (lower.contains("spouse") || lower.contains("wife") || lower.contains("husband")) role = "Spouse";
            if (lower.contains("child") || lower.contains("kid") || lower.contains("son") || lower.contains("daughter")) role = "Child";
            if (lower.contains("father") || lower.contains("mother") || lower.contains("parent")) role = "Parent";
            return {"name": m, "role": role};
          }).toList();
        }
      }

      if (!_familyMembers.any((m) => m["name"] == _activeMember) && _familyMembers.isNotEmpty) {
        _activeMember = _familyMembers.first["name"]!;
      }

      final rawData = prefs.getString("vault_documents_data");
      if (rawData != null && rawData.isNotEmpty) {
        final decoded = jsonDecode(rawData) as Map<String, dynamic>;
        _vaultData = decoded.map((k, v) => MapEntry(k, List<Map<String, dynamic>>.from(v)));
      } else {
        _vaultData = {
          "Self": [
            {
              "id": "DOC-101",
              "category": "Passport",
              "name": "Traveler Self",
              "number": "Z6482105",
              "expiry": "2031-09-03",
              "country": "India",
              "imagePaths": <String>[],
            },
            {
              "id": "DOC-102",
              "category": "Aadhaar Card",
              "name": "Traveler Self",
              "number": "[Redacted ID]",
              "expiry": "Lifetime",
              "country": "India",
              "imagePaths": <String>[],
            }
          ]
        };
      }

      final bookmarks = await TripStateService.getVaultBookmarks();
      _bookmarkedPlaces = bookmarks;
    } catch (_) {}
    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _saveVaultData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString("vault_family_profiles_v2", jsonEncode(_familyMembers));
      await prefs.setStringList("vault_members", _familyMembers.map((m) => m["name"]!).toList());
      await prefs.setString("vault_documents_data", jsonEncode(_vaultData));
    } catch (_) {}
  }

  Future<void> _deleteBookmark(String id) async {
    await TripStateService.deleteVaultBookmark(id);
    _loadVaultData();
  }

  Future<void> _launchMaps(String mapsUrl, String venueName) async {
    final uri = mapsUrl.isNotEmpty
        ? Uri.parse(mapsUrl)
        : Uri.parse("https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent(venueName)}");
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {}
  }

  void _addFamilyMemberDialog() {
    final nameCtrl = TextEditingController();
    String selectedRole = "Child";

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text("Add Family Member Profile", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: nameCtrl,
                decoration: InputDecoration(
                  labelText: "Full Name or Label",
                  hintText: "e.g. Aarav, Anaya, Father",
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  isDense: true,
                ),
                autofocus: true,
              ),
              const SizedBox(height: 14),
              const Text("Relationship / Role", style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: Color(0xFF64748B))),
              const SizedBox(height: 6),
              DropdownButtonFormField<String>(
                value: selectedRole,
                decoration: InputDecoration(
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                ),
                items: const [
                  DropdownMenuItem(value: "Child", child: Text("👶 Child")),
                  DropdownMenuItem(value: "Spouse", child: Text("👩 Spouse / Partner")),
                  DropdownMenuItem(value: "Parent", child: Text("👵 Parent / Elder")),
                  DropdownMenuItem(value: "Self", child: Text("👨 Primary (Self)")),
                  DropdownMenuItem(value: "Other", child: Text("👤 Companion")),
                ],
                onChanged: (val) {
                  if (val != null) setDialogState(() => selectedRole = val);
                },
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2563EB),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: () {
                final newName = nameCtrl.text.trim();
                if (newName.isNotEmpty && !_familyMembers.any((m) => m["name"] == newName)) {
                  setState(() {
                    _familyMembers.add({"name": newName, "role": selectedRole});
                    _activeMember = newName;
                    if (!_vaultData.containsKey(newName)) {
                      _vaultData[newName] = [];
                    }
                  });
                  _saveVaultData();
                }
                Navigator.pop(ctx);
              },
              child: const Text("Create Profile"),
            ),
          ],
        ),
      ),
    );
  }

  void _deleteFamilyMember(String memberName) {
    if (_familyMembers.length <= 1) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("At least one profile must remain.")));
      return;
    }
    setState(() {
      _familyMembers.removeWhere((m) => m["name"] == memberName);
      _vaultData.remove(memberName);
      _activeMember = _familyMembers.first["name"]!;
    });
    _saveVaultData();
  }

  Future<void> _initiateDocumentUpload() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        allowMultiple: true,
        type: FileType.custom,
        allowedExtensions: ['jpg', 'jpeg', 'png', 'pdf', 'webp'],
      );

      if (result == null || result.files.isEmpty) return;

      final appDir = await getApplicationDocumentsDirectory();
      final List<String> savedPaths = [];

      for (var f in result.files) {
        if (f.path != null) {
          final fileExt = f.extension ?? 'jpg';
          final fileName = "Vault_${DateTime.now().millisecondsSinceEpoch}_${savedPaths.length}.$fileExt";
          final destination = "${appDir.path}/$fileName";
          final copied = await File(f.path!).copy(destination);
          savedPaths.add(copied.path);
        }
      }

      if (savedPaths.isEmpty || !mounted) return;

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => DocumentReviewScreen(
            initialPaths: savedPaths,
            member: _activeMember,
            categories: _documentCategories,
            onConfirmed: (newDocData) {
              setState(() {
                if (!_vaultData.containsKey(_activeMember)) {
                  _vaultData[_activeMember] = [];
                }
                _vaultData[_activeMember]!.insert(0, newDocData);
              });
              _saveVaultData();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  backgroundColor: const Color(0xFF16A34A),
                  content: Text("✓ ${newDocData['category']} secured in $_activeMember's profile!"),
                ),
              );
            },
          ),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Upload error: $e")));
    }
  }

  void _deleteDocument(int index) {
    setState(() {
      _vaultData[_activeMember]?.removeAt(index);
    });
    _saveVaultData();
  }

  void _openSingleDocumentInspection(Map<String, dynamic> doc) {
    final List<Map<String, dynamic>> singleList = [
      {
        ...doc,
        "ownerMember": _activeMember,
      }
    ];

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AirportPresentationDeck(deck: singleList),
      ),
    );
  }

  void _openAirportMasterDeck() {
    final List<Map<String, dynamic>> presentationDeck = [];
    for (var member in _familyMembers) {
      final memberName = member["name"]!;
      final docs = _vaultData[memberName] ?? [];
      for (var doc in docs) {
        presentationDeck.add({
          ...doc,
          "ownerMember": memberName,
        });
      }
    }

    if (presentationDeck.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("No credentials registered in the vault to present.")),
      );
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AirportPresentationDeck(deck: presentationDeck),
      ),
    );
  }

  void _showExportFormatDialog() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(20, 20, 20, 24 + MediaQuery.of(ctx).padding.bottom),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.picture_as_pdf_rounded, color: Color(0xFF2563EB), size: 22),
                SizedBox(width: 8),
                Text("Export Family Dossier", style: TextStyle(fontSize: 16.5, fontWeight: FontWeight.w900, color: Color(0xFF0F172A))),
              ],
            ),
            const SizedBox(height: 6),
            const Text(
              "Select your preferred format to compile all registered credentials across your travel party.",
              style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
            ),
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              height: 46,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFDC2626),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                onPressed: () {
                  Navigator.pop(ctx);
                  _processDossierExport("pdf");
                },
                icon: const Icon(Icons.picture_as_pdf_rounded, size: 18),
                label: const Text("EXPORT AS PDF (.PDF)", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5)),
              ),
            ),
            const SizedBox(height: 10),
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
                onPressed: () {
                  Navigator.pop(ctx);
                  _processDossierExport("docx");
                },
                icon: const Icon(Icons.description_rounded, size: 18),
                label: const Text("EXPORT AS WORD (.DOCX)", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _processDossierExport(String format) async {
    setState(() => _isExporting = true);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("Compiling full ${format.toUpperCase()} dossier...")),
    );

    try {
      final StringBuffer sb = StringBuffer();
      sb.writeln("OMNI TOURISTOS - FAMILY TRAVEL VAULT MASTER DOSSIER");
      sb.writeln("Generated: ${DateTime.now().toIso8601String().substring(0, 19).replaceAll('T', ' ')} UTC");
      sb.writeln("Total Profiles: ${_familyMembers.length}");
      sb.writeln("------------------------------------------------------------\n");

      for (var member in _familyMembers) {
        final memberName = member["name"]!;
        final docs = _vaultData[memberName] ?? [];
        sb.writeln("TRAVELER PROFILE: ${memberName.toUpperCase()} (${member['role']}) - ${docs.length} Documents");
        if (docs.isEmpty) {
          sb.writeln("  [No documents recorded]\n");
          continue;
        }

        for (int i = 0; i < docs.length; i++) {
          final d = docs[i];
          final paths = (d["imagePaths"] as List<dynamic>?) ?? [];
          sb.writeln("  ${i + 1}. [${d['category']}]");
          sb.writeln("     • Full Legal Name: ${d['name']}");
          sb.writeln("     • Document Number: ${d['number']}");
          sb.writeln("     • Validity Status / Expiry: ${d['expiry']}");
          sb.writeln("     • Issuing Country / Authority: ${d['country']}");
          sb.writeln("     • Attached Pages: ${paths.length} page(s)");
          sb.writeln("");
        }
        sb.writeln("------------------------------------------------------------\n");
      }

      final endpoint = format == "pdf" ? "/api/v1/export-pdf" : "/api/v1/export-docx";
      final response = await http.post(
        Uri.parse("${widget.backendUrl}$endpoint"),
        body: {
          "title": "Omni Family Travel Vault Dossier",
          "content": sb.toString(),
        },
      ).timeout(const Duration(seconds: 25));

      if (response.statusCode == 200) {
        final resData = jsonDecode(response.body);
        final downloadUrl = resData["download_url"] as String;
        final fileName = resData["file_name"] as String;

        final fileRes = await http.get(Uri.parse(downloadUrl));
        if (fileRes.statusCode == 200) {
          final Uint8List bytes = fileRes.bodyBytes;

          Directory? targetDir;
          if (Platform.isAndroid) {
            targetDir = Directory("/storage/emulated/0/Download");
            if (!await targetDir.exists()) {
              targetDir = await getExternalStorageDirectory();
            }
          } else {
            targetDir = await getApplicationDocumentsDirectory();
          }

          final savePath = "${targetDir!.path}/$fileName";
          final localFile = File(savePath);
          await localFile.writeAsBytes(bytes);

          if (!mounted) return;

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: const Color(0xFF16A34A),
              content: Text("✓ $fileName saved to Downloads!"),
            ),
          );
          Share.shareXFiles([XFile(savePath)], text: "Omni Family Vault Dossier ($fileName)");
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Export notice: $e")));
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  Widget _buildValidityBadge(String? expiry) {
    if (expiry == null || expiry.isEmpty || expiry.toLowerCase().contains("lifetime") || expiry.toLowerCase().contains("permanent")) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: const [
          Icon(Icons.check_circle_rounded, size: 13, color: Color(0xFF16A34A)),
          SizedBox(width: 4),
          Text("Valid: Lifetime", style: TextStyle(fontSize: 10.5, color: Color(0xFF16A34A), fontWeight: FontWeight.bold)),
        ],
      );
    }

    try {
      final expDate = DateTime.parse(expiry);
      final daysLeft = expDate.difference(DateTime.now()).inDays;

      if (daysLeft < 0) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: const [
            Icon(Icons.error_rounded, size: 13, color: Colors.red),
            SizedBox(width: 4),
            Text("EXPIRED", style: TextStyle(fontSize: 10.5, color: Colors.red, fontWeight: FontWeight.bold)),
          ],
        );
      } else {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.check_circle_rounded, size: 13, color: Color(0xFF16A34A)),
            const SizedBox(width: 4),
            Text("Valid: $expiry", style: const TextStyle(fontSize: 10.5, color: Color(0xFF16A34A), fontWeight: FontWeight.bold)),
          ],
        );
      }
    } catch (_) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.check_circle_rounded, size: 13, color: Color(0xFF16A34A)),
          const SizedBox(width: 4),
          Text("Valid: $expiry", style: const TextStyle(fontSize: 10.5, color: Color(0xFF16A34A), fontWeight: FontWeight.bold)),
        ],
      );
    }
  }

  Widget _buildDocumentThumbnail(Map<String, dynamic> doc) {
    final List<dynamic> paths = (doc["imagePaths"] as List<dynamic>?) ?? [];
    if (paths.isNotEmpty && File(paths.first.toString()).existsSync()) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Image.file(
          File(paths.first.toString()),
          width: 90,
          height: 105,
          fit: BoxFit.cover,
        ),
      );
    }

    final cat = (doc["category"] ?? "").toString().toLowerCase();

    if (cat.contains("passport")) {
      return Container(
        width: 90,
        height: 105,
        decoration: BoxDecoration(
          color: const Color(0xFF0C1E3D),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFD4AF37), width: 1.2),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              children: const [
                Text(
                  "भारत गणराज्य",
                  style: TextStyle(color: Color(0xFFD4AF37), fontSize: 7, fontWeight: FontWeight.bold),
                ),
                Text(
                  "REPUBLIC OF INDIA",
                  style: TextStyle(color: Color(0xFFD4AF37), fontSize: 5.5, letterSpacing: 0.5, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const Icon(Icons.account_balance_rounded, color: Color(0xFFD4AF37), size: 26),
            Column(
              children: const [
                Text(
                  "पासपोर्ट / PASSPORT",
                  style: TextStyle(color: Color(0xFFD4AF37), fontSize: 6.5, fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 2),
                Icon(Icons.sim_card_outlined, color: Color(0xFFD4AF37), size: 10),
              ],
            ),
          ],
        ),
      );
    }

    if (cat.contains("aadhaar") || cat.contains("adhar")) {
      return Container(
        width: 90,
        height: 105,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFCBD5E1), width: 1.2),
        ),
        child: Column(
          children: [
            Container(
              height: 4,
              decoration: const BoxDecoration(
                borderRadius: BorderRadius.vertical(top: Radius.circular(10)),
                gradient: LinearGradient(
                  colors: [Color(0xFFFF9933), Colors.white, Color(0xFF138808)],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(4.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: const [
                      Icon(Icons.shield_outlined, color: Color(0xFFDC2626), size: 12),
                      Text("भारत सरकार", style: TextStyle(fontSize: 6, fontWeight: FontWeight.bold)),
                      Icon(Icons.qr_code_2_rounded, size: 12, color: Colors.black87),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Container(
                        width: 20,
                        height: 26,
                        decoration: BoxDecoration(
                          color: const Color(0xFFE2E8F0),
                          borderRadius: BorderRadius.circular(3),
                        ),
                        child: const Icon(Icons.person_rounded, size: 15, color: Color(0xFF64748B)),
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(height: 4, width: 32, color: const Color(0xFFCBD5E1)),
                            const SizedBox(height: 3),
                            Container(height: 3, width: 22, color: const Color(0xFFE2E8F0)),
                            const SizedBox(height: 3),
                            Container(height: 3, width: 28, color: const Color(0xFFE2E8F0)),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  const Center(
                    child: Text(
                      "मेरा आधार, मेरी पहचान",
                      style: TextStyle(fontSize: 5.5, color: Color(0xFFDC2626), fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      width: 90,
      height: 105,
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF94A3B8), width: 1.2),
      ),
      padding: const EdgeInsets.all(6),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Icon(_getCategoryIcon(cat), size: 14, color: const Color(0xFF2563EB)),
              const Text("IDENTITY CARD", style: TextStyle(fontSize: 6, fontWeight: FontWeight.bold)),
            ],
          ),
          const Icon(Icons.credit_card_rounded, size: 28, color: Color(0xFF2563EB)),
          Text(
            doc["category"] ?? "Document",
            style: const TextStyle(fontSize: 7, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentDocs = _vaultData[_activeMember] ?? [];
    final activeMemberObj = _familyMembers.firstWhere(
      (m) => m["name"] == _activeMember,
      orElse: () => {"name": _activeMember, "role": "Family"},
    );

    final double topInset = MediaQuery.of(context).padding.top;
    final double bottomInset = MediaQuery.of(context).padding.bottom;

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
            // Luxury Borderless Header ($y = 0$)
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
                      children: const [
                        Text("CREDENTIAL REPOSITORY", style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Color(0xFF64748B), letterSpacing: 0.5)),
                        Text("Family Travel Vault", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: Color(0xFF0F172A))),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: "Export Master Dossier",
                    icon: const Icon(Icons.cloud_download_rounded, color: Color(0xFF2563EB), size: 22),
                    onPressed: _showExportFormatDialog,
                  ),
                ],
              ),
            ),

            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator(color: Color(0xFF2563EB)))
                  : Stack(
                      children: [
                        RefreshIndicator(
                          onRefresh: _loadVaultData,
                          color: const Color(0xFF2563EB),
                          child: ListView(
                            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                            children: [
                              // Family Member Profiles Carousel
                              SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                child: Row(
                                  children: [
                                    ..._familyMembers.map((m) {
                                      final name = m["name"]!;
                                      final role = m["role"]!;
                                      final isSel = _activeMember == name;

                                      IconData roleIcon = Icons.person_rounded;
                                      Color roleColor = const Color(0xFF2563EB);
                                      if (role == "Child") {
                                        roleIcon = Icons.child_care_rounded;
                                        roleColor = const Color(0xFFEA580C);
                                      } else if (role == "Spouse") {
                                        roleIcon = Icons.favorite_rounded;
                                        roleColor = const Color(0xFFE11D48);
                                      } else if (role == "Parent") {
                                        roleIcon = Icons.elderly_rounded;
                                        roleColor = const Color(0xFF0D9488);
                                      }

                                      return Padding(
                                        padding: const EdgeInsets.only(right: 8),
                                        child: InkWell(
                                          borderRadius: BorderRadius.circular(20),
                                          onTap: () => setState(() => _activeMember = name),
                                          child: AnimatedContainer(
                                            duration: const Duration(milliseconds: 200),
                                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                                            decoration: BoxDecoration(
                                              color: isSel ? const Color(0xFF2563EB) : Colors.white,
                                              borderRadius: BorderRadius.circular(20),
                                              border: Border.all(
                                                color: isSel ? const Color(0xFF2563EB) : const Color(0xFFE2E8F0),
                                                width: 0.8,
                                              ),
                                              boxShadow: isSel
                                                  ? [
                                                      BoxShadow(
                                                        color: const Color(0xFF2563EB).withOpacity(0.25),
                                                        blurRadius: 6,
                                                        offset: const Offset(0, 2),
                                                      ),
                                                    ]
                                                  : null,
                                            ),
                                            child: Row(
                                              children: [
                                                Icon(roleIcon, size: 15, color: isSel ? Colors.white : roleColor),
                                                const SizedBox(width: 6),
                                                Text(
                                                  name,
                                                  style: TextStyle(
                                                    color: isSel ? Colors.white : const Color(0xFF1E293B),
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 12.5,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      );
                                    }).toList(),
                                    InkWell(
                                      onTap: _addFamilyMemberDialog,
                                      borderRadius: BorderRadius.circular(20),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                                        decoration: BoxDecoration(
                                          borderRadius: BorderRadius.circular(20),
                                          border: Border.all(color: const Color(0xFFE2E8F0), width: 0.8),
                                          color: Colors.white,
                                        ),
                                        child: Row(
                                          children: const [
                                            Icon(Icons.add_rounded, size: 16, color: Color(0xFF2563EB)),
                                            SizedBox(width: 4),
                                            Text(
                                              "Add Profile",
                                              style: TextStyle(
                                                fontSize: 12,
                                                fontWeight: FontWeight.bold,
                                                color: Color(0xFF2563EB),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                              const SizedBox(height: 12),

                              // Offline Sandboxing & Export Trigger Banner
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF0FDF4),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: const Color(0xFFBBF7D0), width: 0.6),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(Icons.check_circle_rounded, size: 18, color: Color(0xFF16A34A)),
                                    const SizedBox(width: 10),
                                    const Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            "Offline Encrypted Sandboxing",
                                            style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: Color(0xFF166534)),
                                          ),
                                          Text(
                                            "Your documents stay safe on this device.",
                                            style: TextStyle(fontSize: 10, color: Color(0xFF15803D)),
                                          ),
                                        ],
                                      ),
                                    ),
                                    InkWell(
                                      onTap: _showExportFormatDialog,
                                      child: Row(
                                        children: const [
                                          Icon(Icons.cloud_download_rounded, size: 16, color: Color(0xFF2563EB)),
                                          SizedBox(width: 4),
                                          Text(
                                            "Export Dossier",
                                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF2563EB)),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                              const SizedBox(height: 12),

                              // Airport Presentation Deck Hero Banner
                              InkWell(
                                onTap: _openAirportMasterDeck,
                                borderRadius: BorderRadius.circular(20),
                                child: Container(
                                  height: 115,
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(20),
                                    image: const DecorationImage(
                                      image: NetworkImage("https://images.unsplash.com/photo-1542296332-2e4473faf563?auto=format&fit=crop&w=1000&q=80"),
                                      fit: BoxFit.cover,
                                    ),
                                  ),
                                  child: Container(
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(20),
                                      gradient: LinearGradient(
                                        colors: [
                                          Colors.black.withOpacity(0.85),
                                          Colors.black.withOpacity(0.35),
                                        ],
                                        begin: Alignment.centerLeft,
                                        end: Alignment.centerRight,
                                      ),
                                    ),
                                    padding: const EdgeInsets.all(16),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: const [
                                            Text(
                                              "Airport & Hotel Presentation Deck",
                                              style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 14.5),
                                            ),
                                            SizedBox(height: 2),
                                            Text(
                                              "Pinch-to-zoom multi-page view for authorities.",
                                              style: TextStyle(color: Colors.white70, fontSize: 11),
                                            ),
                                          ],
                                        ),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: Colors.white,
                                            borderRadius: BorderRadius.circular(16),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: const [
                                              Text(
                                                "Open Deck",
                                                style: TextStyle(color: Color(0xFF0F172A), fontSize: 11, fontWeight: FontWeight.bold),
                                              ),
                                              SizedBox(width: 4),
                                              Icon(Icons.arrow_forward_rounded, size: 12, color: Color(0xFF0F172A)),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),

                              const SizedBox(height: 16),

                              // Section Header Row
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    "Documents for $_activeMember (${currentDocs.length})",
                                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: Color(0xFF0F172A)),
                                  ),
                                  if (_activeMember != "Self")
                                    InkWell(
                                      onTap: () => _deleteFamilyMember(_activeMember),
                                      child: const Text("Delete Profile", style: TextStyle(color: Color(0xFFDC2626), fontSize: 11.5, fontWeight: FontWeight.bold)),
                                    ),
                                ],
                              ),

                              const SizedBox(height: 10),

                              if (currentDocs.isEmpty)
                                Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 36),
                                  child: Center(
                                    child: Column(
                                      children: [
                                        Icon(Icons.folder_open_rounded, size: 44, color: Colors.grey.shade400),
                                        const SizedBox(height: 8),
                                        Text(
                                          "No documents saved yet for $_activeMember (${activeMemberObj['role']})",
                                          style: const TextStyle(color: Colors.grey, fontWeight: FontWeight.bold, fontSize: 12.5),
                                        ),
                                        const SizedBox(height: 2),
                                        const Text("Tap '+ Add Document' below to register credentials.", style: TextStyle(color: Colors.grey, fontSize: 11)),
                                      ],
                                    ),
                                  ),
                                )
                              else ...[
                                for (int i = 0; i < currentDocs.length; i++)
                                  _buildVisualDocumentCard(currentDocs[i], i),
                              ],

                              if (_bookmarkedPlaces.isNotEmpty) ...[
                                const SizedBox(height: 16),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Row(
                                      children: [
                                        const Icon(Icons.bookmark_rounded, color: Color(0xFF059669), size: 18),
                                        const SizedBox(width: 6),
                                        Text(
                                          "Saved Places & Venues (${_bookmarkedPlaces.length})",
                                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                                        ),
                                      ],
                                    ),
                                    Text(
                                      "From Guide Chat",
                                      style: TextStyle(fontSize: 11, color: Colors.grey.shade600, fontWeight: FontWeight.w600),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                ..._bookmarkedPlaces.map((place) => _buildBookmarkedPlaceCard(place)).toList(),
                              ],
                            ],
                          ),
                        ),
                        if (_isExporting)
                          Container(
                            color: Colors.black54,
                            child: const Center(
                              child: Card(
                                child: Padding(
                                  padding: EdgeInsets.all(20),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      CircularProgressIndicator(color: Color(0xFF2563EB)),
                                      SizedBox(height: 14),
                                      Text("Compiling Master Dossier...", style: TextStyle(fontWeight: FontWeight.bold)),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
            ),
          ],
        ),
        bottomNavigationBar: Container(
          padding: EdgeInsets.fromLTRB(16, 8, 16, bottomInset > 0 ? bottomInset + 8 : 14),
          decoration: const BoxDecoration(
            color: Colors.white,
            border: Border(top: BorderSide(color: Color(0xFFE2E8F0), width: 0.6)),
          ),
          child: SizedBox(
            width: double.infinity,
            height: 46,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2563EB),
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              icon: const Icon(Icons.add_photo_alternate_rounded, size: 18),
              label: Text(
                "ADD DOCUMENT TO ${_activeMember.toUpperCase()}",
                style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, letterSpacing: 0.5),
              ),
              onPressed: _initiateDocumentUpload,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildVisualDocumentCard(Map<String, dynamic> doc, int index) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0), width: 0.6),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.015),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () => _openSingleDocumentInspection(doc),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildDocumentThumbnail(doc),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              doc["category"] ?? "Document",
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF0F172A),
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          PopupMenuButton<String>(
                            padding: EdgeInsets.zero,
                            icon: const Icon(Icons.more_vert_rounded, size: 18, color: Color(0xFF64748B)),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            onSelected: (val) {
                              if (val == "inspect") {
                                _openSingleDocumentInspection(doc);
                              } else if (val == "copy") {
                                Clipboard.setData(ClipboardData(text: doc["number"] ?? ""));
                                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Document number copied.")));
                              } else if (val == "delete") {
                                _deleteDocument(index);
                              }
                            },
                            itemBuilder: (context) => [
                              const PopupMenuItem(value: "inspect", child: Text("Inspect / Zoom", style: TextStyle(fontSize: 12.5))),
                              const PopupMenuItem(value: "copy", child: Text("Copy Number", style: TextStyle(fontSize: 12.5))),
                              const PopupMenuItem(value: "delete", child: Text("Delete", style: TextStyle(color: Color(0xFFDC2626), fontSize: 12.5))),
                            ],
                          ),
                        ],
                      ),
                      Text(
                        "Holder: ${doc['name']}",
                        style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B), fontWeight: FontWeight.w500),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Text(
                            doc["number"] ?? "XXXX XXXX XXXX",
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              fontFamily: "monospace",
                              color: Color(0xFF0F172A),
                              letterSpacing: 0.8,
                            ),
                          ),
                          const SizedBox(width: 6),
                          InkWell(
                            onTap: () {
                              Clipboard.setData(ClipboardData(text: doc["number"] ?? ""));
                              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Copied!")));
                            },
                            child: const Icon(Icons.copy_rounded, size: 12, color: Color(0xFF94A3B8)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          _buildValidityBadge(doc['expiry']),
                          const SizedBox(width: 8),
                          Text(
                            "|  Issuing: ${doc['country']}",
                            style: const TextStyle(fontSize: 10.5, color: Color(0xFF64748B), fontWeight: FontWeight.w500),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBookmarkedPlaceCard(Map<String, dynamic> place) {
    final name = place["name"] ?? "Venue";
    final category = place["category"] ?? "Recommendation";
    final area = place["area"] ?? "";
    final mapsUrl = place["maps_url"] ?? "";
    final id = place["id"] ?? "";

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0), width: 0.6),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.015), blurRadius: 6, offset: const Offset(0, 2)),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFF059669).withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.restaurant_rounded, color: Color(0xFF059669), size: 16),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                  const SizedBox(height: 2),
                  Text("$category • $area", style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.navigation_rounded, color: Color(0xFF2563EB), size: 18),
              tooltip: "Navigate",
              onPressed: () => _launchMaps(mapsUrl, name),
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline_rounded, color: Colors.grey, size: 18),
              tooltip: "Remove Bookmark",
              onPressed: () => _deleteBookmark(id),
            ),
          ],
        ),
      ),
    );
  }

  IconData _getCategoryIcon(String? cat) {
    final c = (cat ?? "").toLowerCase();
    if (c.contains("aadhaar") || c.contains("national")) return Icons.badge_rounded;
    if (c.contains("pan")) return Icons.credit_card_rounded;
    if (c.contains("passport")) return Icons.menu_book_rounded;
    if (c.contains("visa")) return Icons.airplane_ticket_rounded;
    if (c.contains("driver")) return Icons.directions_car_rounded;
    if (c.contains("health") || c.contains("insurance")) return Icons.health_and_safety_rounded;
    if (c.contains("hotel") || c.contains("stay")) return Icons.hotel_rounded;
    if (c.contains("ticket") || c.contains("flight") || c.contains("train") || c.contains("cruise")) return Icons.confirmation_number_rounded;
    return Icons.description_rounded;
  }
}

// -------------------------------------------------------------
// MULTI-PAGE REVIEW & CONFIRMATION SCREEN
// -------------------------------------------------------------
class DocumentReviewScreen extends StatefulWidget {
  final List<String> initialPaths;
  final String member;
  final List<String> categories;
  final Function(Map<String, dynamic>) onConfirmed;

  const DocumentReviewScreen({
    Key? key,
    required this.initialPaths,
    required this.member,
    required this.categories,
    required this.onConfirmed,
  }) : super(key: key);

  @override
  State<DocumentReviewScreen> createState() => _DocumentReviewScreenState();
}

class _DocumentReviewScreenState extends State<DocumentReviewScreen> {
  late List<String> _pagePaths;
  int _activePageIndex = 0;
  late String _selectedCategory;

  final TextEditingController _nameCtrl = TextEditingController();
  final TextEditingController _numberCtrl = TextEditingController();
  final TextEditingController _countryCtrl = TextEditingController(text: "India");
  final TextEditingController _expiryCtrl = TextEditingController(text: "2031-09-03");

  @override
  void initState() {
    super.initState();
    _pagePaths = List<String>.from(widget.initialPaths);
    _selectedCategory = widget.categories.first;
    _nameCtrl.text = "Traveler ${widget.member}";
    if (_selectedCategory == "Aadhaar Card") {
      _numberCtrl.text = "[Redacted ID]";
      _expiryCtrl.text = "Lifetime";
    } else if (_selectedCategory == "PAN Card") {
      _numberCtrl.text = "ABCDE1234F";
      _expiryCtrl.text = "Permanent";
    }
  }

  Future<void> _appendMorePages() async {
    final result = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      type: FileType.custom,
      allowedExtensions: ['jpg', 'jpeg', 'png', 'pdf', 'webp'],
    );
    if (result == null || result.files.isEmpty) return;

    final appDir = await getApplicationDocumentsDirectory();
    for (var f in result.files) {
      if (f.path != null) {
        final ext = f.extension ?? 'jpg';
        final fileName = "Vault_Page_${DateTime.now().millisecondsSinceEpoch}_${_pagePaths.length}.$ext";
        final copied = await File(f.path!).copy("${appDir.path}/$fileName");
        setState(() => _pagePaths.add(copied.path));
      }
    }
  }

  void _removePage(int index) {
    if (_pagePaths.length <= 1) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("A document must have at least 1 page.")));
      return;
    }
    setState(() {
      _pagePaths.removeAt(index);
      if (_activePageIndex >= _pagePaths.length) {
        _activePageIndex = _pagePaths.length - 1;
      }
    });
  }

  String _getPageLabel(int index, int total) {
    if (total == 1) return "Single Page Document";
    if (index == 0) return "Front Cover / Bio Page";
    if (index == 1 && total == 2) return "Back Cover / Page 2";
    if (index == total - 1 && total > 2) return "Back Cover / Page $total";
    return "Page ${index + 1}";
  }

  @override
  Widget build(BuildContext context) {
    final currentPath = _pagePaths[_activePageIndex];

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: const Color(0xFFF8FAFC),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Color(0xFF0F172A), size: 24),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          "Review Credentials (${widget.member})",
          style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: Color(0xFF0F172A)),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.check_rounded, color: Color(0xFF16A34A), size: 26),
            onPressed: _saveAndConfirm,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(16, 12, 16, 24 + MediaQuery.of(context).padding.bottom),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              height: 250,
              width: double.infinity,
              decoration: BoxDecoration(color: Colors.black, borderRadius: BorderRadius.circular(16)),
              clipBehavior: Clip.antiAlias,
              child: Stack(
                children: [
                  InteractiveViewer(
                    minScale: 0.8,
                    maxScale: 6.0,
                    child: Center(
                      child: Image.file(File(currentPath), fit: BoxFit.contain),
                    ),
                  ),
                  Positioned(
                    top: 8,
                    left: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(color: const Color(0xFF2563EB), borderRadius: BorderRadius.circular(6)),
                      child: Text(
                        _getPageLabel(_activePageIndex, _pagePaths.length),
                        style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: 8,
                    right: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(color: Colors.black.withOpacity(0.7), borderRadius: BorderRadius.circular(6)),
                      child: const Row(
                        children: [
                          Icon(Icons.zoom_in_rounded, color: Colors.white, size: 12),
                          SizedBox(width: 4),
                          Text("Pinch 6x Max Zoom", style: TextStyle(color: Colors.white, fontSize: 10)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text("Document Pages (${_pagePaths.length})", style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold)),
                TextButton.icon(
                  onPressed: _appendMorePages,
                  icon: const Icon(Icons.add_photo_alternate_rounded, size: 15),
                  label: const Text("+ Add Page", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
            SizedBox(
              height: 76,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: _pagePaths.length,
                itemBuilder: (ctx, i) {
                  final isSelected = _activePageIndex == i;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: Stack(
                      children: [
                        InkWell(
                          onTap: () => setState(() => _activePageIndex = i),
                          child: Container(
                            decoration: BoxDecoration(
                              border: Border.all(color: isSelected ? const Color(0xFF2563EB) : Colors.grey.shade300, width: isSelected ? 2 : 1),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Stack(
                                children: [
                                  Image.file(File(_pagePaths[i]), height: 74, width: 74, fit: BoxFit.cover),
                                  Positioned(
                                    bottom: 0,
                                    left: 0,
                                    right: 0,
                                    child: Container(
                                      color: Colors.black54,
                                      padding: const EdgeInsets.symmetric(vertical: 2),
                                      child: Text(
                                        i == 0 ? "Front" : (i == _pagePaths.length - 1 && _pagePaths.length > 1 ? "Back" : "P.${i + 1}"),
                                        textAlign: TextAlign.center,
                                        style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        if (_pagePaths.length > 1)
                          Positioned(
                            top: 2,
                            right: 2,
                            child: InkWell(
                              onTap: () => _removePage(i),
                              child: Container(
                                padding: const EdgeInsets.all(2),
                                decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                                child: const Icon(Icons.close, size: 10, color: Colors.white),
                              ),
                            ),
                          ),
                      ],
                    ),
                  );
                },
              ),
            ),
            const Divider(height: 24),

            const Text("Document Specifications", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5)),
            const SizedBox(height: 10),

            DropdownButtonFormField<String>(
              value: _selectedCategory,
              decoration: InputDecoration(
                labelText: "Document Category",
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                isDense: true,
              ),
              items: widget.categories.map((c) => DropdownMenuItem(value: c, child: Text(c, style: const TextStyle(fontSize: 12.5)))).toList(),
              onChanged: (val) {
                if (val != null) {
                  setState(() {
                    _selectedCategory = val;
                    if (val == "Aadhaar Card") {
                      _expiryCtrl.text = "Lifetime";
                    } else if (val == "PAN Card") {
                      _expiryCtrl.text = "Permanent";
                    }
                  });
                }
              },
            ),
            const SizedBox(height: 12),

            TextField(
              controller: _nameCtrl,
              decoration: InputDecoration(
                labelText: "Full Legal Name on Document",
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                isDense: true,
              ),
            ),
            const SizedBox(height: 12),

            TextField(
              controller: _numberCtrl,
              decoration: InputDecoration(
                labelText: "Document / Serial Number",
                hintText: _selectedCategory == "Aadhaar Card" ? "12 Digit ID" : "e.g. Passport or PAN number",
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                isDense: true,
              ),
            ),
            const SizedBox(height: 12),

            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _countryCtrl,
                    decoration: InputDecoration(
                      labelText: "Issuing Country",
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      isDense: true,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: _expiryCtrl,
                    decoration: InputDecoration(
                      labelText: "Expiry Date (YYYY-MM-DD)",
                      hintText: "e.g. 2032-05-14",
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      isDense: true,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

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
                onPressed: _saveAndConfirm,
                icon: const Icon(Icons.verified_user_rounded, size: 18),
                label: Text(
                  "SECURE ${_pagePaths.length} PAGE(S) TO ${widget.member.toUpperCase()}'S VAULT",
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _saveAndConfirm() {
    final docData = {
      "id": "DOC-${DateTime.now().millisecondsSinceEpoch % 9999}",
      "category": _selectedCategory,
      "name": _nameCtrl.text.trim(),
      "number": _numberCtrl.text.trim(),
      "country": _countryCtrl.text.trim(),
      "expiry": _expiryCtrl.text.trim(),
      "imagePaths": _pagePaths,
    };

    widget.onConfirmed(docData);
    Navigator.pop(context);
  }
}

// -------------------------------------------------------------
// AIRPORT & PROFILE INSPECTION DECK (6x Max Zoom)
// -------------------------------------------------------------
class AirportPresentationDeck extends StatefulWidget {
  final List<Map<String, dynamic>> deck;

  const AirportPresentationDeck({
    Key? key,
    required this.deck,
  }) : super(key: key);

  @override
  State<AirportPresentationDeck> createState() => _AirportPresentationDeckState();
}

class _AirportPresentationDeckState extends State<AirportPresentationDeck> {
  final PageController _pageCtrl = PageController();
  int _currentIndex = 0;
  int _subPageIndex = 0;

  Widget _buildFullInspectorGraphic(Map<String, dynamic> item) {
    final cat = (item["category"] ?? "").toString().toLowerCase();

    if (cat.contains("passport")) {
      return Container(
        width: 250,
        height: 350,
        decoration: BoxDecoration(
          color: const Color(0xFF0C1E3D),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFFD4AF37), width: 2),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.5),
              blurRadius: 16,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              children: const [
                Text("भारत गणराज्य", style: TextStyle(color: Color(0xFFD4AF37), fontSize: 16, fontWeight: FontWeight.bold)),
                SizedBox(height: 4),
                Text("REPUBLIC OF INDIA", style: TextStyle(color: Color(0xFFD4AF37), fontSize: 13, letterSpacing: 1.5, fontWeight: FontWeight.bold)),
              ],
            ),
            const Icon(Icons.account_balance_rounded, color: Color(0xFFD4AF37), size: 76),
            Column(
              children: [
                const Text("पासपोर्ट / PASSPORT", style: TextStyle(color: Color(0xFFD4AF37), fontSize: 14, fontWeight: FontWeight.bold)),
                const SizedBox(height: 10),
                Text(
                  item["number"] ?? "",
                  style: const TextStyle(color: Color(0xFFD4AF37), fontSize: 18, letterSpacing: 2, fontFamily: "monospace", fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                const Icon(Icons.sim_card_outlined, color: Color(0xFFD4AF37), size: 24),
              ],
            ),
          ],
        ),
      );
    }

    if (cat.contains("aadhaar") || cat.contains("adhar")) {
      return Container(
        width: 280,
        height: 360,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFFCBD5E1), width: 2),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.4),
              blurRadius: 16,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          children: [
            Container(
              height: 10,
              decoration: const BoxDecoration(
                borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
                gradient: LinearGradient(
                  colors: [Color(0xFFFF9933), Colors.white, Color(0xFF138808)],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: const [
                      Icon(Icons.shield_outlined, color: Color(0xFFDC2626), size: 24),
                      Text("भारत सरकार\nGOVERNMENT OF INDIA", textAlign: TextAlign.center, style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold)),
                      Icon(Icons.qr_code_2_rounded, size: 28, color: Colors.black87),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Container(
                        width: 60,
                        height: 75,
                        decoration: BoxDecoration(
                          color: const Color(0xFFE2E8F0),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.person_rounded, size: 40, color: Color(0xFF64748B)),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(item["name"] ?? "Traveler", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                            const SizedBox(height: 4),
                            Text("DOB / Expiry: ${item['expiry']}", style: const TextStyle(fontSize: 11, color: Colors.black54)),
                            const SizedBox(height: 4),
                            Text("Country: ${item['country']}", style: const TextStyle(fontSize: 11, color: Colors.black54)),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 30),
                  Center(
                    child: Text(
                      item["number"] ?? "XXXX - XXXX - XXXX",
                      style: const TextStyle(fontSize: 17, letterSpacing: 2, fontWeight: FontWeight.bold, fontFamily: "monospace"),
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Center(
                    child: Text(
                      "मेरा आधार, मेरी पहचान",
                      style: TextStyle(fontSize: 12, color: Color(0xFFDC2626), fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      width: 280,
      height: 340,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.grey.shade900,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white24),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.credit_card_rounded, size: 64, color: Color(0xFF2563EB)),
          const SizedBox(height: 16),
          Text(item["category"] ?? "Document", style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          Text(item["name"] ?? "", style: const TextStyle(color: Colors.white70)),
          const SizedBox(height: 16),
          Text(
            item["number"] ?? "",
            style: const TextStyle(color: Colors.amber, fontSize: 18, letterSpacing: 1.5, fontWeight: FontWeight.bold, fontFamily: "monospace"),
          ),
          const SizedBox(height: 10),
          Text("Valid: ${item['expiry']}", style: const TextStyle(color: Colors.greenAccent, fontSize: 13)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentDoc = widget.deck[_currentIndex];
    final List<dynamic> paths = (currentDoc["imagePaths"] as List<dynamic>?) ?? [];
    final bottomInset = MediaQuery.of(context).padding.bottom;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Colors.white, size: 24),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          "Inspection (${_currentIndex + 1}/${widget.deck.length})",
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.share_rounded),
            tooltip: "Share Document",
            onPressed: () {
              if (paths.isNotEmpty && File(paths[_subPageIndex].toString()).existsSync()) {
                Share.shareXFiles([XFile(paths[_subPageIndex].toString())], text: "${currentDoc['category']} - ${currentDoc['name']}");
              } else {
                Share.share("${currentDoc['category']}: ${currentDoc['number']} (Holder: ${currentDoc['name']})");
              }
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                  decoration: BoxDecoration(color: const Color(0xFF2563EB), borderRadius: BorderRadius.circular(20)),
                  child: Text(
                    "${currentDoc['ownerMember'].toUpperCase()} • ${currentDoc['category']}",
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                  ),
                ),
                if (paths.length > 1)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(color: Colors.amber.shade700, borderRadius: BorderRadius.circular(14)),
                    child: Text(
                      "Page ${_subPageIndex + 1} of ${paths.length}",
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11),
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: PageView.builder(
              controller: _pageCtrl,
              itemCount: widget.deck.length,
              onPageChanged: (i) => setState(() {
                _currentIndex = i;
                _subPageIndex = 0;
              }),
              itemBuilder: (ctx, i) {
                final item = widget.deck[i];
                final List<dynamic> docPaths = (item["imagePaths"] as List<dynamic>?) ?? [];

                if (docPaths.isEmpty) {
                  return InteractiveViewer(
                    minScale: 0.8,
                    maxScale: 6.0,
                    child: Center(
                      child: _buildFullInspectorGraphic(item),
                    ),
                  );
                }

                final activeImg = docPaths[_subPageIndex].toString();
                return InteractiveViewer(
                  minScale: 0.8,
                  maxScale: 6.0,
                  child: Center(
                    child: Image.file(File(activeImg), fit: BoxFit.contain),
                  ),
                );
              },
            ),
          ),
          if (paths.length > 1)
            Container(
              height: 60,
              padding: const EdgeInsets.symmetric(vertical: 4),
              color: Colors.black,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: paths.length,
                itemBuilder: (ctx, pIdx) {
                  final isSel = _subPageIndex == pIdx;
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    child: InkWell(
                      onTap: () => setState(() => _subPageIndex = pIdx),
                      child: Container(
                        decoration: BoxDecoration(
                          border: Border.all(color: isSel ? Colors.amber : Colors.white24, width: isSel ? 2 : 1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: Image.file(File(paths[pIdx].toString()), height: 50, width: 75, fit: BoxFit.cover),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          Container(
            padding: EdgeInsets.fromLTRB(20, 10, 20, 16 + (bottomInset > 0 ? bottomInset : 8)),
            color: const Color(0xFF0F172A),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      currentDoc["name"] ?? "Traveler",
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      "Number: ${currentDoc['number']}",
                      style: const TextStyle(color: Colors.amber, fontSize: 13, fontFamily: "monospace"),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(color: Colors.white10, borderRadius: BorderRadius.circular(6)),
                  child: const Row(
                    children: [
                      Icon(Icons.zoom_in_rounded, color: Colors.white70, size: 14),
                      SizedBox(width: 4),
                      Text("Pinch 6x Max", style: TextStyle(color: Colors.white70, fontSize: 11)),
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