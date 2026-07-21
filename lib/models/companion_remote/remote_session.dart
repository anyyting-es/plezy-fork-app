import 'package:freezed_annotation/freezed_annotation.dart';

part 'remote_session.freezed.dart';

enum RemoteSessionRole { host, remote }

enum RemoteSessionStatus { disconnected, connecting, connected, reconnecting, error }

@freezed
sealed class RemoteDevice with _$RemoteDevice {
  const factory RemoteDevice({
    required String id,
    required String name,
    required String platform,
    required DateTime connectedAt,
    @Default(<String, bool>{}) Map<String, bool> capabilities,
  }) = _RemoteDevice;
}

@freezed
sealed class RemoteSession with _$RemoteSession {
  const RemoteSession._();

  const factory RemoteSession({
    required RemoteSessionRole role,
    @Default(RemoteSessionStatus.disconnected) RemoteSessionStatus status,
    RemoteDevice? connectedDevice,
    required DateTime createdAt,
    String? errorMessage,
  }) = _RemoteSession;

  bool get isConnected => status == RemoteSessionStatus.connected;
  bool get isHost => role == RemoteSessionRole.host;
  bool get isRemote => role == RemoteSessionRole.remote;
}
