import '../../models/app_models.dart';
import '../models/extension_manifest.dart';

/// Interfaz base para todas las extensiones modulares de la aplicación.
abstract class ExtensionBase {
  final ExtensionManifest manifest;

  ExtensionBase(this.manifest);

  /// Inicializa la extensión (carga el JS, etc)
  Future<void> initialize();

  /// Busca contenido (Anime, Manga, etc) dado un query
  Future<List<SearchResult>> search(String query);

  /// Obtiene los detalles y capítulos/episodios de un ítem particular
  Future<AnimeDetailsResult> getDetails(String idOrUrl);

  /// Obtiene los links de stream y calidad dado el id o url del episodio
  Future<List<StreamLink>> extractVideos(String episodeIdOrUrl);
  
  /// Limpia los recursos (Javascript Runtime, etc)  
  void dispose();
}
