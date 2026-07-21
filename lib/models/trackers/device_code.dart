import 'package:freezed_annotation/freezed_annotation.dart';

part 'device_code.freezed.dart';

/// Result of requesting a device code from an RFC 8628 authorization server.
///
/// The user enters [userCode] at [verificationUrl]; the app polls the token
/// endpoint with [deviceCode] every [interval] seconds until [expiresIn]
/// seconds elapse.
@freezed
sealed class DeviceCode with _$DeviceCode {
  const factory DeviceCode({
    required String deviceCode,
    required String userCode,
    required String verificationUrl,
    required int expiresIn,
    required int interval,

    /// URL with the code pre-filled (e.g. `https://trakt.tv/activate/ABC12345`)
    /// when the provider supports it. Nullable — Simkl doesn't.
    String? verificationUrlComplete,
  }) = _DeviceCode;
}

/// Discriminated event emitted by a device-code poll loop.
@freezed
sealed class DevicePollEvent with _$DevicePollEvent {
  const factory DevicePollEvent.pending() = DevicePollPending;
  const factory DevicePollEvent.slowDown() = DevicePollSlowDown;
  const factory DevicePollEvent.denied() = DevicePollDenied;
  const factory DevicePollEvent.expired() = DevicePollExpired;
  const factory DevicePollEvent.success(Map<String, dynamic> tokenResponse) = DevicePollSuccess;
}
