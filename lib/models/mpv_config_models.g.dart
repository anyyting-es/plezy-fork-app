// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'mpv_config_models.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

MpvPreset _$MpvPresetFromJson(Map<String, dynamic> json) => MpvPreset(
  name: json['name'] as String,
  text: json['text'] as String,
  createdAt: DateTime.parse(json['createdAt'] as String),
);

Map<String, dynamic> _$MpvPresetToJson(MpvPreset instance) => <String, dynamic>{
  'name': instance.name,
  'text': instance.text,
  'createdAt': instance.createdAt.toIso8601String(),
};
