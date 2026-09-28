import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

class AffiliateLauncherService {
  // Booking.com & Travelpayouts / CJ Affiliate Credentials
  static const String bookingComAid = "2420912";
  static const String travelpayoutsMarker = "774359";
  static const String cjCid = "8065032";
  static const String cjLinkPid = "";

  /// Sanitizes city/query strings by removing punctuation, extra spaces, and keywords
  /// that cause Booking.com's location resolution engine to stall or fail.
  static String sanitizeDestinationQuery(String rawCity) {
    return rawCity
        .replaceAll('-', ' ')
        .replaceAll('_', ' ')
        .replaceAll(RegExp(r'\b(City|District|Region|Area)\b', caseSensitive: false), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  /// Builds a clean, bot-resilient Booking.com search URL targeting /searchresults.html
  static String buildBookingSearchResultsUrl({
    required String city,
    String? country,
    DateTime? checkIn,
    DateTime? checkOut,
    int adults = 2,
    int children = 0,
    int rooms = 1,
    String currency = "INR",
  }) {
    final cleanCity = sanitizeDestinationQuery(city);
    final query = (country != null && country.trim().isNotEmpty && !cleanCity.toLowerCase().contains(country.toLowerCase()))
        ? "$cleanCity, ${country.trim()}"
        : cleanCity;

    final encodedQuery = Uri.encodeComponent(query);

    final effectiveCheckIn = checkIn ?? DateTime.now().add(const Duration(days: 1));
    final effectiveCheckOut = checkOut ?? effectiveCheckIn.add(const Duration(days: 2));

    final inDateStr =
        "${effectiveCheckIn.year}-${effectiveCheckIn.month.toString().padLeft(2, '0')}-${effectiveCheckIn.day.toString().padLeft(2, '0')}";
    final outDateStr =
        "${effectiveCheckOut.year}-${effectiveCheckOut.month.toString().padLeft(2, '0')}-${effectiveCheckOut.day.toString().padLeft(2, '0')}";

    // Construct the clean searchresults.html endpoint with verified parameters
    final bookingUrl = "https://www.booking.com/searchresults.html?"
        "ss=$encodedQuery"
        "&checkin=$inDateStr"
        "&checkout=$outDateStr"
        "&group_adults=$adults"
        "&group_children=$children"
        "&no_rooms=$rooms"
        "&selected_currency=$currency"
        "&aid=$bookingComAid"
        "&label=omnitouristos";

    if (cjLinkPid.isNotEmpty) {
      return "https://www.anrdoezrs.net/click-$cjLinkPid-$cjCid?url=${Uri.encodeComponent(bookingUrl)}";
    }

    return bookingUrl;
  }

  /// Launches Booking.com using a robust two-stage external intent:
  /// 1. Attempts to open the native Booking.com app if installed
  /// 2. Falls back strictly to the system browser (Chrome/Safari), bypassing 403 & blank screens
  static Future<void> launchBookingStays({
    required String city,
    String? country,
    DateTime? checkIn,
    DateTime? checkOut,
    int adults = 2,
    int children = 0,
    int rooms = 1,
    String currency = "INR",
  }) async {
    HapticFeedback.selectionClick();

    final urlString = buildBookingSearchResultsUrl(
      city: city,
      country: country,
      checkIn: checkIn,
      checkOut: checkOut,
      adults: adults,
      children: children,
      rooms: rooms,
      currency: currency,
    );

    final uri = Uri.parse(urlString);

    try {
      // 1. Try launching the official native Booking.com app if installed
      final launchedNativeApp = await launchUrl(
        uri,
        mode: LaunchMode.externalNonBrowserApplication,
      );
      if (launchedNativeApp) return;
    } catch (_) {}

    try {
      // 2. Open standard system external browser (Chrome, Samsung Internet, Safari)
      await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
    } catch (_) {
      try {
        await launchUrl(uri, mode: LaunchMode.platformDefault);
      } catch (_) {}
    }
  }
}