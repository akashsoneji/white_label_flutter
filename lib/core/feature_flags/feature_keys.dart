class FeatureKeys {
  FeatureKeys._();

  static const String pmam = 'pmam';

  // ✅ NEW: Master toggle for the single-socket `/ws/stream` path.
  // Per-brand overrides live in `assets/brands/<brand>/brand.yaml` under
  // `featureFlags.unifiedStreamSocket`.
  static const String unifiedStreamSocket = 'unifiedStreamSocket';

  // After this many consecutive auth failures on /ws/stream, the
  // adapter flips to legacy sockets for the rest of the session.
  static const int unifiedStreamFailureThreshold = 3;
}
