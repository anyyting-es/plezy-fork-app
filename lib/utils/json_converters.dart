import 'package:json_annotation/json_annotation.dart';

/// Maps an enum value to/from its `int` index. Useful for compact wire formats
/// (e.g. companion-remote commands) where the over-the-wire size matters and
/// new enum cases are always appended.
///
/// Out-of-range indices on the wire fall back to [_fallback] instead of
/// throwing — important for forward-compat with newer clients sending
/// commands the host doesn't yet understand.
class IndexedEnumConverter<T extends Enum> implements JsonConverter<T, int> {
  const IndexedEnumConverter(this._values, this._fallback);

  final List<T> _values;
  final T _fallback;

  @override
  T fromJson(int json) => json >= 0 && json < _values.length ? _values[json] : _fallback;

  @override
  int toJson(T object) => object.index;
}
