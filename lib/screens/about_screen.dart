import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class AboutFeaturesScreen extends StatelessWidget {
  const AboutFeaturesScreen({Key? key}) : super(key: key);

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
            // Borderless Luxury Header ($y = 0$)
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
                        Text(
                          "SYSTEM MANIFEST & SPECS",
                          style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Color(0xFF64748B), letterSpacing: 0.5),
                        ),
                        Text(
                          "About Omni TouristOS",
                          style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: Color(0xFF0F172A)),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(16, 12, 16, bottomInset > 0 ? bottomInset + 16 : 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // System Overview Card
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF0F172A), Color(0xFF1E3A8A)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: const Color(0xFF334155), width: 0.6),
                        boxShadow: [
                          BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 4)),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(color: Colors.white.withOpacity(0.12), shape: BoxShape.circle),
                            child: const Icon(Icons.travel_explore_rounded, color: Colors.white, size: 24),
                          ),
                          const SizedBox(height: 14),
                          const Text(
                            "Omni TouristOS",
                            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 22, letterSpacing: -0.5),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            "Intelligent Travel & Civic Operating System",
                            style: TextStyle(color: Color(0xFF93C5FD), fontSize: 12.5, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 10),
                          const Text(
                            "Omni TouristOS unifies live transit telemetry, real-time AI street translation, multimodal booking channels, and forensic land document auditing into a single offline-resilient sandbox.",
                            style: TextStyle(color: Colors.white70, fontSize: 12, height: 1.45),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),

                    const Padding(
                      padding: EdgeInsets.only(left: 4, bottom: 8),
                      child: Text(
                        "SYSTEM MODULES & ARCHITECTURE",
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF64748B), letterSpacing: 0.6),
                      ),
                    ),

                    // 1. Offline Emergency Lifelines
                    _buildFeatureCard(
                      icon: Icons.emergency_rounded,
                      iconColor: const Color(0xFFDC2626),
                      badge: "CORE SAFETY",
                      badgeColor: const Color(0xFFDC2626),
                      title: "Offline Emergency Lifelines & SOS",
                      description:
                          "Operates 100% offline without mobile data. Delivers instant 1-tap phone dialing (tel:) to regional trauma hospitals, city police headquarters, 24h emergency pharmacies, and Women Safety Cells with automatic city-switching (Vasai-Virar, Mumbai, Palghar).",
                    ),

                    // 2. Community Hidden Gems
                    _buildFeatureCard(
                      icon: Icons.diamond_rounded,
                      iconColor: const Color(0xFF7C3AED),
                      badge: "HYPERLOCAL",
                      badgeColor: const Color(0xFF7C3AED),
                      title: "Community Hidden Gems",
                      description:
                          "Crowdsourced off-the-beaten-path discovery. Uncovers quiet coastal coves, uncommercialized historical ruins, forest waterfall trails, and generational food spots with GPS-verified turn-by-turn routes.",
                    ),

                    // 3. Paper Pilot
                    _buildFeatureCard(
                      icon: Icons.document_scanner_rounded,
                      iconColor: const Color(0xFF0D9488),
                      badge: "AI AUDIT",
                      badgeColor: const Color(0xFF0D9488),
                      title: "Paper Pilot: Legal & Heritage Auditor",
                      description:
                          "Dual-engine forensic auditor. Detects land fraud in 7/12 Satbara, mutation entries, and sale deeds (tagging loans and court stays with red alerts). Also deciphers ancient stone inscriptions, copper plates, and archival scripts.",
                    ),

                    // 4. Street Interpreter & Lens
                    _buildFeatureCard(
                      icon: Icons.record_voice_over_rounded,
                      iconColor: const Color(0xFF2563EB),
                      badge: "LIVE SPEECH",
                      badgeColor: const Color(0xFF2563EB),
                      title: "Street Interpreter & Lens",
                      description:
                          "Walkie-talkie style conversational voice interpretation across 16+ languages with natural acoustic voice playback. Includes Street Lens camera vision to decode signs, menus, warnings, and transit directions.",
                    ),

                    // 5. Destination Explorer & Stays
                    _buildFeatureCard(
                      icon: Icons.explore_rounded,
                      iconColor: const Color(0xFF059669),
                      badge: "EXPLORATION",
                      badgeColor: const Color(0xFF059669),
                      title: "Destination Explorer & Verified Sights",
                      description:
                          "Curated verified bastions, beaches, and shrines per destination with entry fees and timings. Includes local verified hotels and resorts pre-priced in native Rupees (₹ INR) with one-tap Google Maps navigation and Booking.com reservations.",
                    ),

                    // 6. Flights & Stays Hub
                    _buildFeatureCard(
                      icon: Icons.flight_takeoff_rounded,
                      iconColor: const Color(0xFF1D4ED8),
                      badge: "TRANSIT",
                      badgeColor: const Color(0xFF1D4ED8),
                      title: "Flights & Stays Hub",
                      description:
                          "Direct comparison engine calculating passenger fares in local currency. Pre-fills Aviasales and Booking.com search queries with your exact dates, route, and guest allocations in the external native browser.",
                    ),

                    // 7. Cockpit Dashboard & AR Radar
                    _buildFeatureCard(
                      icon: Icons.radar_rounded,
                      iconColor: const Color(0xFF0284C7),
                      badge: "TELEMETRY",
                      badgeColor: const Color(0xFF0284C7),
                      title: "Cockpit Dashboard & Motion Radar",
                      description:
                          "Real-time weather telemetry, day/night transitions, live itinerary milestones, digital geofenced passport stamps, and hardware-accelerated transit motion tracking.",
                    ),

                    // 8. Expense Ledger & Bullion Tracker
                    _buildFeatureCard(
                      icon: Icons.account_balance_wallet_rounded,
                      iconColor: const Color(0xFFD97706),
                      badge: "FINANCE",
                      badgeColor: const Color(0xFFD97706),
                      title: "Quick Spend Ledger & Bullion Rates",
                      description:
                          "Rapid category-based expense logging (Dining, Transit, Gear) with daily running tallies and live 24K/22K gold and silver rates scraped from domestic spot benchmarks.",
                    ),

                    const SizedBox(height: 20),

                    Center(
                      child: Column(
                        children: const [
                          Text("Omni TouristOS • Version 86.0.0", style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: Color(0xFF64748B))),
                          SizedBox(height: 3),
                          Text("Engineered for Travelers, Citizens & Heritage Explorers", style: TextStyle(fontSize: 10.5, color: Color(0xFF94A3B8))),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFeatureCard({
    required IconData icon,
    required Color iconColor,
    required String badge,
    required Color badgeColor,
    required String title,
    required String description,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0), width: 0.6),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.015), blurRadius: 6, offset: const Offset(0, 2)),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: iconColor.withOpacity(0.12), shape: BoxShape.circle),
            child: Icon(icon, color: iconColor, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13.5, color: Color(0xFF0F172A)),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(color: badgeColor.withOpacity(0.1), borderRadius: BorderRadius.circular(6)),
                      child: Text(badge, style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, color: badgeColor)),
                    ),
                  ],
                ),
                const SizedBox(height: 5),
                Text(
                  description,
                  style: const TextStyle(fontSize: 11.5, color: Color(0xFF475569), height: 1.4),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}