import 'package:freezed_annotation/freezed_annotation.dart';

part 'media_sort.freezed.dart';
part 'media_sort.g.dart';

@freezed
sealed class MediaSort with _$MediaSort {
  const MediaSort._();

  const factory MediaSort({required String key, String? descKey, required String title, String? defaultDirection}) =
      _MediaSort;

  factory MediaSort.fromJson(Map<String, dynamic> json) => _$MediaSortFromJson(json);

  String getSortKey({bool descending = false}) {
    if (!descending) {
      return key;
    }

    return descKey ?? '$key:desc';
  }

  bool get isDefaultDescending {
    return defaultDirection?.toLowerCase() == 'desc';
  }
}
