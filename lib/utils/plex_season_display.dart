import '../media/media_item.dart';
import 'json_utils.dart';

const _plexFlattenSeasonsShow = 0;
const _plexFlattenSeasonsHide = 1;
const _plexFlattenSeasonsSingleSeason = 2;

bool shouldShowPlexEpisodesDirectly({
  required MediaItem show,
  required List<MediaItem> seasons,
  required Map<String, dynamic> libraryPrefs,
}) {
  final showOverride = flexibleInt(show.raw?['flattenSeasons']);
  if (showOverride == _plexFlattenSeasonsHide) return true;
  if (showOverride == _plexFlattenSeasonsShow) return false;

  if (flexibleBool(show.raw?['skipChildren'])) return true;

  final libraryFlattenSeasons = flexibleInt(libraryPrefs['flattenSeasons']);
  return libraryFlattenSeasons == _plexFlattenSeasonsHide ||
      seasons.isEmpty ||
      (libraryFlattenSeasons == _plexFlattenSeasonsSingleSeason && seasons.length == 1);
}
