import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({Key? key}) : super(key: key);

  Future<void> _launchUrl(String urlString) async {
    final uri = Uri.parse(urlString);
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: const Color(0xFF2563EB).withOpacity(0.12),
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFF2563EB).withOpacity(0.25)),
              ),
              child: const Icon(
                Icons.travel_explore_rounded,
                size: 52,
                color: Color(0xFF2563EB),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              "Omni TouristOS",
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w900,
                color: Color(0xFF0F172A),
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFFEFF6FF),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFBFDBFE)),
              ),
              child: const Text(
                "Version 83.0.0 (Production Release)",
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1E40AF),
                ),
              ),
            ),
            const SizedBox(height: 14),
            const Text(
              "The comprehensive travel operating system engineered for seamless navigation, forensic document audits, live street voice translation, and safety lifelines.",
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: Color(0xFF64748B), height: 1.4),
            ),
            const SizedBox(height: 24),

            // Feature Highlights Card
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFFE2E8F0)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.02),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "Integrated OS Engines",
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(height: 12),
                  _buildFeatureRow(Icons.radar_rounded, const Color(0xFF0284C7), "AR Landmark Radar", "Augmented visual heads-up directional pointers"),
                  const Divider(height: 16, color: Color(0xFFF1F5F9)),
                  _buildFeatureRow(Icons.record_voice_over_rounded, const Color(0xFF2563EB), "Street Voice & Lens", "Sub-300ms translation & camera signboard OCR"),
                  const Divider(height: 16, color: Color(0xFFF1F5F9)),
                  _buildFeatureRow(Icons.price_check_rounded, const Color(0xFFD97706), "Bargain Pal", "Street market haggling meter & native audio phrases"),
                  const Divider(height: 16, color: Color(0xFFF1F5F9)),
                  _buildFeatureRow(Icons.verified_rounded, const Color(0xFF9333EA), "Passport Stamp Book", "Verified location badges and travel achievements"),
                  const Divider(height: 16, color: Color(0xFFF1F5F9)),
                  _buildFeatureRow(Icons.security_rounded, const Color(0xFFDC2626), "Emergency Lifelines", "Location-specific one-tap emergency responder dialing"),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Developer & Governance Card
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Column(
                children: [
                  Row(
                    children: const [
                      Icon(Icons.verified_user_rounded, color: Color(0xFF16A34A), size: 20),
                      SizedBox(width: 8),
                      Text(
                        "Governance & Security",
                        style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: Color(0xFF0F172A)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    "All travel vouchers and document scans are processed in an ephemeral sandbox. No private credentials or personal records are shared with third-party aggregators.",
                    style: TextStyle(fontSize: 12, color: Color(0xFF64748B), height: 1.35),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Support & Feedback
            TextButton.icon(
              onPressed: () => _launchUrl("mailto:support@touristos.app"),
              icon: const Icon(Icons.mail_outline_rounded, size: 18, color: Color(0xFF2563EB)),
              label: const Text(
                "Contact Engineering & Support",
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF2563EB)),
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              "© 2026 Omni TouristOS Cloud Infrastructure",
              style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFeatureRow(IconData icon, Color color, String title, String desc) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(color: color.withOpacity(0.1), shape: BoxShape.circle),
          child: Icon(icon, color: color, size: 18),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF0F172A))),
              Text(desc, style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B))),
            ],
          ),
        ),
      ],
    );
  }
}