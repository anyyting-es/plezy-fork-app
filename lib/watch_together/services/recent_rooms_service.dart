import 'dart:convert';

import 'package:json_annotation/json_annotation.dart';

import '../../services/settings_service.dart';
import '../models/watch_session.dart';

part 'recent_rooms_service.g.dart';

@JsonSerializable(includeIfNull: false)
class RecentRoom {
  final String code;
  final String? name;
  @JsonKey(fromJson: _dateTimeFromMillis, toJson: _dateTimeToMillis)
  final DateTime lastUsed;
  @JsonKey(fromJson: _controlModeFromIndex, toJson: _controlModeToIndex)
  final ControlMode? controlMode;

  const RecentRoom({required this.code, this.name, required this.lastUsed, this.controlMode});

  Map<String, dynamic> toJson() => _$RecentRoomToJson(this);

  factory RecentRoom.fromJson(Map<String, dynamic> json) => _$RecentRoomFromJson(json);

  RecentRoom copyWith({
    String? code,
    String? name,
    DateTime? lastUsed,
    ControlMode? controlMode,
    bool clearName = false,
  }) => RecentRoom(
    code: code ?? this.code,
    name: clearName ? null : (name ?? this.name),
    lastUsed: lastUsed ?? this.lastUsed,
    controlMode: controlMode ?? this.controlMode,
  );
}

DateTime _dateTimeFromMillis(int value) => DateTime.fromMillisecondsSinceEpoch(value);

int _dateTimeToMillis(DateTime value) => value.millisecondsSinceEpoch;

ControlMode? _controlModeFromIndex(int? index) {
  if (index == null || index < 0 || index >= ControlMode.values.length) return null;
  return ControlMode.values[index];
}

int? _controlModeToIndex(ControlMode? value) => value?.index;

class RecentRoomsService {
  static const int _maxRooms = 20;

  static List<RecentRoom> getRecentRooms() {
    final json = SettingsService.instanceOrNull?.read(SettingsService.recentRooms);
    if (json == null) return [];
    try {
      final list = jsonDecode(json) as List<dynamic>;
      final rooms = list.map((e) => RecentRoom.fromJson(e as Map<String, dynamic>)).toList();
      rooms.sort((a, b) => b.lastUsed.compareTo(a.lastUsed));
      return rooms;
    } catch (_) {
      return [];
    }
  }

  static Future<void> _save(List<RecentRoom> rooms) async {
    rooms.sort((a, b) => b.lastUsed.compareTo(a.lastUsed));
    if (rooms.length > _maxRooms) rooms.removeRange(_maxRooms, rooms.length);
    await SettingsService.instanceOrNull?.write(
      SettingsService.recentRooms,
      jsonEncode(rooms.map((r) => r.toJson()).toList()),
    );
  }

  static Future<void> addOrUpdateRoom(String code, {String? name, ControlMode? controlMode}) async {
    final rooms = getRecentRooms();
    final index = rooms.indexWhere((r) => r.code == code);
    if (index >= 0) {
      rooms[index] = rooms[index].copyWith(
        lastUsed: DateTime.now(),
        name: name ?? rooms[index].name,
        controlMode: controlMode,
      );
    } else {
      rooms.add(RecentRoom(code: code, name: name, lastUsed: DateTime.now(), controlMode: controlMode));
    }
    await _save(rooms);
  }

  static Future<void> removeRoom(String code) async {
    final rooms = getRecentRooms();
    rooms.removeWhere((r) => r.code == code);
    await _save(rooms);
  }

  static Future<void> renameRoom(String code, String? name) async {
    final rooms = getRecentRooms();
    final index = rooms.indexWhere((r) => r.code == code);
    if (index >= 0) {
      rooms[index] = rooms[index].copyWith(name: name, clearName: name == null);
      await _save(rooms);
    }
  }
}
