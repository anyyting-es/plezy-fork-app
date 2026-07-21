import 'package:json_annotation/json_annotation.dart';

part 'trakt_user.g.dart';

/// Minimal Trakt user info parsed from `GET /users/settings`.
@JsonSerializable(createToJson: false)
class TraktUser {
  final String username;
  final String? name;

  const TraktUser({required this.username, this.name});

  factory TraktUser.fromJson(Map<String, dynamic> json) {
    final user = json['user'] as Map<String, dynamic>?;
    if (user == null) {
      throw const FormatException('Trakt /users/settings response missing "user" field');
    }
    return _$TraktUserFromJson(user);
  }
}
