import 'package:json_annotation/json_annotation.dart';

part 'mpv_config_models.g.dart';

@JsonSerializable()
class MpvPreset {
  final String name;
  final String text;
  final DateTime createdAt;

  const MpvPreset({required this.name, required this.text, required this.createdAt});

  factory MpvPreset.fromJson(Map<String, dynamic> json) => _$MpvPresetFromJson(json);

  Map<String, dynamic> toJson() => _$MpvPresetToJson(this);
}
