import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'destination_catalog_view.dart';
import 'flight_booking_view.dart';

class TravelHubScreen extends StatefulWidget {
  final String language;
  final String activeCity;
  final String activeState;
  final String activeCountry;
  final String backendUrl;
  final int initialTabIndex; // 0 for Destinations, 1 for Flights

  const TravelHubScreen({
    Key? key,
    required this.language,
    this.activeCity = "Vasai-Virar",
    this.activeState = "Maharashtra",
    this.activeCountry = "India",
    this.backendUrl = "https://omni-backend-pk28.onrender.com",
    this.initialTabIndex = 0,
  }) : super(key: key);

  @override
  State<TravelHubScreen> createState() => _TravelHubScreenState();
}

class _TravelHubScreenState extends State<TravelHubScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late String _destinationCityForFlights;

  @override
  void initState() {
    super.initState();
    _destinationCityForFlights = "Singapore";
    _tabController = TabController(
      length: 2,
      vsync: this,
      initialIndex: widget.initialTabIndex,
    );

    _tabController.addListener(() {
      if (_tabController.indexIsChanging) {
        HapticFeedback.selectionClick();
      }
    });
  }
@override
void dispose() {
  // ... controller disposes
  super.dispose();
}

void _switchToFlightsWithTargetCity(String targetCity) {
    setState(() {
      _destinationCityForFlights = targetCity;
    });
    _tabController.animateTo(1);
  }

  @override
  Widget build(BuildContext context) {
    final topInset = MediaQuery.of(context).padding.top;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light,
        systemNavigationBarColor: Colors.transparent,
        systemNavigationBarIconBrightness: Brightness.dark,
      ),
      child: Scaffold(
        backgroundColor: const Color(0xFFF8FAFC),
        body: Column(
          children: [
            // Luxury Canvas Header ($y = 0$)
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
                        onTap: () => Navigator.of(context).pop(),
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFFE2E8F0), width: 0.6),
                            boxShadow: [
                              BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 4, offset: const Offset(0, 1)),
                            ],
                          ),
                          child: const Icon(Icons.arrow_back_rounded, color: Color(0xFF0F172A), size: 20),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              "DESTINATIONS & TRANSIT",
                              style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: Color(0xFF64748B), letterSpacing: 0.5),
                            ),
                            const SizedBox(height: 1),
                            Text(
                              "${widget.activeCity}, ${widget.activeCountry}",
                              style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: Color(0xFF0F172A)),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEFF6FF),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFBFDBFE), width: 0.6),
                        ),
                        child: Row(
                          children: const [
                            Icon(Icons.explore_rounded, color: Color(0xFF2563EB), size: 13),
                            SizedBox(width: 5),
                            Text("Active Hub", style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF1E40AF))),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  // Master Tab Switcher: Destinations vs Flights & Stays
                  Container(
                    padding: const EdgeInsets.all(3.5),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE2E8F0).withOpacity(0.8),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: TabBar(
                      controller: _tabController,
                      indicator: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        color: Colors.white,
                        boxShadow: [
                          BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 6, offset: const Offset(0, 2)),
                        ],
                      ),
                      labelColor: const Color(0xFF2563EB),
                      unselectedLabelColor: const Color(0xFF64748B),
                      labelStyle: const TextStyle(fontWeight: FontWeight.w900, fontSize: 12.5),
                      unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12.5),
                      tabs: const [
                        Tab(
                          height: 36,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.near_me_rounded, size: 15),
                              SizedBox(width: 6),
                              Text("Destinations Explorer"),
                            ],
                          ),
                        ),
                        Tab(
                          height: 36,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.flight_takeoff_rounded, size: 15),
                              SizedBox(width: 6),
                              Text("Flights & Hubs"),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Tab Bar View Body
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  DestinationCatalogView(
                    language: widget.language,
                    activeCity: widget.activeCity,
                    activeState: widget.activeState,
                    activeCountry: widget.activeCountry,
                    backendUrl: widget.backendUrl,
                    onSelectDestinationForFlights: _switchToFlightsWithTargetCity,
                  ),
                  FlightBookingView(
                    language: widget.language,
                    activeOriginCity: widget.activeCity,
                    initialDestinationCity: _destinationCityForFlights,
                    backendUrl: widget.backendUrl,
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