import '../models/app_models.dart';

abstract class VideoProvider {
  /// The internal identifier of the provider (e.g. 'extension', 'sudatchi')
  String get id;

  /// The display name of the provider
  String get name;

  /// Fetches episode list for a given anime.
  /// Implementations might use anilistId, slug, or romajiTitle depending on their API.
  Future<AnimeDetailsResult> getDetails({
    required int anilistId,
    required String slug,
    required String romajiTitle,
    required String englishTitle,
    int? anidbId,
  });

  /// Fetches streams for a specific episode.
  /// [episodeId] is the provider-specific payload string stored in EpisodeInfo.id.
  Future<List<StreamLink>> getStreams(String episodeId, {String overrideType = 'sub'});
}
