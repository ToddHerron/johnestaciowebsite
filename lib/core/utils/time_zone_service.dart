import 'package:flutter/foundation.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

/// Initializes and provides helpers for working with IANA time zones.
///
/// We store performance instants in UTC, but display them in the performance
/// location's time zone (DST-safe).
class TimeZoneService {
  TimeZoneService._();

  /// Legacy cutoff: performances strictly before this instant should be shown
  /// as if they were in Edmonton MST (fixed -07:00, no DST) in public views.
  static final DateTime legacyEdmontonMstCutoffUtc = DateTime.utc(2026, 3, 24);

  static bool _initialized = false;

  static Future<void> ensureInitialized() async {
    if (_initialized) return;
    try {
      tzdata.initializeTimeZones();
      _initialized = true;
    } catch (e) {
      debugPrint('TimeZoneService initialization failed: $e');
      // We intentionally do not rethrow; app should still function with
      // fallback "device local" formatting.
    }
  }

  static bool get isInitialized => _initialized;

  static List<String> get allTimeZoneIds {
    if (!_initialized) return const [];
    final ids = tz.timeZoneDatabase.locations.keys.toList()..sort();
    return ids;
  }

  static tz.Location? tryGetLocation(String? timeZoneId) {
    if (!_initialized) return null;
    final id = (timeZoneId ?? '').trim();
    if (id.isEmpty) return null;
    try {
      return tz.getLocation(id);
    } catch (e) {
      debugPrint('Unknown time zone id "$id": $e');
      return null;
    }
  }

  /// Converts a UTC instant to a wall-clock time in [timeZoneId].
  ///
  /// Falls back to device local time if the time zone database is unavailable.
  static DateTime toZonedLocal(DateTime utcInstant, String? timeZoneId) {
    final utc = utcInstant.isUtc ? utcInstant : utcInstant.toUtc();
    final loc = tryGetLocation(timeZoneId);
    if (loc == null) return utc;
    return tz.TZDateTime.from(utc, loc);
  }

  /// Converts a UTC instant to the wall-clock time we want to show on public
  /// pages.
  ///
  /// Rule:
  /// - If the performance instant is before [legacyEdmontonMstCutoffUtc], show
  ///   it in a fixed Edmonton MST offset (no DST).
  /// - Otherwise, show it in the performance's IANA [timeZoneId].
  static DateTime toPublicZonedLocal(DateTime utcInstant, String? timeZoneId) {
    final utc = utcInstant.isUtc ? utcInstant : utcInstant.toUtc();
    if (utc.isBefore(legacyEdmontonMstCutoffUtc)) {
      // Fixed offset location (no DST). In the tz database, Etc/GMT+7 is UTC-7.
      final fixedLoc = tryGetLocation('Etc/GMT+7');
      if (fixedLoc != null) return tz.TZDateTime.from(utc, fixedLoc);
      // Fallback if tz DB isn't initialized.
      return utc.add(const Duration(hours: -7));
    }
    return toZonedLocal(utc, timeZoneId);
  }

  /// Interprets [localDateTime] as a wall-clock time in [timeZoneId], and
  /// returns the corresponding UTC instant.
  static DateTime wallClockToUtc(DateTime localDateTime, String timeZoneId) {
    final loc = tryGetLocation(timeZoneId);
    if (loc == null) return localDateTime.toUtc();
    final tzLocal = tz.TZDateTime(loc, localDateTime.year, localDateTime.month, localDateTime.day, localDateTime.hour,
        localDateTime.minute, localDateTime.second, localDateTime.millisecond, localDateTime.microsecond);
    return tzLocal.toUtc();
  }

  /// A pragmatic set of suggestions based on venue/city/region/country.
  ///
  /// This is not a full geocoding solution; it’s a best-effort UX improvement.
  static List<String> suggestTimeZoneIds({
    required String venueName,
    required String city,
    required String region,
    required String country,
  }) {
    if (!_initialized) return const [];
    final hay = '${venueName.trim()} ${city.trim()} ${region.trim()} ${country.trim()}'.toLowerCase();

    String? pick;
    // Canada
    if (hay.contains('toronto') || hay.contains('ontario') || hay.contains('ottawa') || hay.contains('montreal')) {
      pick = 'America/Toronto';
    } else if (hay.contains('vancouver') || hay.contains('british columbia') || hay.contains(' bc')) {
      pick = 'America/Vancouver';
    } else if (hay.contains('calgary') || hay.contains('alberta') || hay.contains(' ab')) {
      pick = 'America/Edmonton';
    }

    // USA
    pick ??= (hay.contains('new york') || hay.contains('boston') || hay.contains('washington') || hay.contains('miami'))
        ? 'America/New_York'
        : null;
    pick ??= (hay.contains('chicago') || hay.contains('dallas') || hay.contains('houston')) ? 'America/Chicago' : null;
    pick ??= (hay.contains('denver') || hay.contains('salt lake') || hay.contains('utah')) ? 'America/Denver' : null;
    pick ??= (hay.contains('los angeles') || hay.contains('la ') || hay.contains('san francisco') || hay.contains('seattle'))
        ? 'America/Los_Angeles'
        : null;

    // Europe
    pick ??= (hay.contains('london') || hay.contains('uk') || hay.contains('england')) ? 'Europe/London' : null;
    pick ??= (hay.contains('paris')) ? 'Europe/Paris' : null;
    pick ??= (hay.contains('berlin')) ? 'Europe/Berlin' : null;
    pick ??= (hay.contains('vienna')) ? 'Europe/Vienna' : null;
    pick ??= (hay.contains('rome')) ? 'Europe/Rome' : null;
    pick ??= (hay.contains('madrid')) ? 'Europe/Madrid' : null;
    pick ??= (hay.contains('lisbon')) ? 'Europe/Lisbon' : null;

    // Asia / Oceania
    pick ??= (hay.contains('tokyo')) ? 'Asia/Tokyo' : null;
    pick ??= (hay.contains('seoul')) ? 'Asia/Seoul' : null;
    pick ??= (hay.contains('beijing') || hay.contains('shanghai')) ? 'Asia/Shanghai' : null;
    pick ??= (hay.contains('hong kong')) ? 'Asia/Hong_Kong' : null;
    pick ??= (hay.contains('singapore')) ? 'Asia/Singapore' : null;
    pick ??= (hay.contains('sydney')) ? 'Australia/Sydney' : null;
    pick ??= (hay.contains('melbourne')) ? 'Australia/Melbourne' : null;
    pick ??= (hay.contains('brisbane')) ? 'Australia/Brisbane' : null;
    pick ??= (hay.contains('perth')) ? 'Australia/Perth' : null;
    pick ??= (hay.contains('auckland')) ? 'Pacific/Auckland' : null;

    if (pick == null) return const [];
    // Include a couple of commonly-confused alternatives when relevant.
    if (pick.startsWith('America/')) {
      return [pick, 'America/New_York', 'America/Chicago', 'America/Denver', 'America/Los_Angeles'].toSet().toList();
    }
    if (pick.startsWith('Europe/')) {
      return [pick, 'Europe/London', 'Europe/Paris', 'Europe/Berlin'].toSet().toList();
    }
    return [pick];
  }
}
