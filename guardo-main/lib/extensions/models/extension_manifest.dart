class ExtensionManifest {
  final String id;
  final String name;
  final String version;
  final String type;
  final String lang;
  final String language;
  final String description;
  final String author;
  final String icon;
  final String website;
  final String readme;
  final String notes;
  final String manifestUri;
  final String baseUrl;
  final String iconUrl;
  final String scriptUrl;
  final String payload;
  final String payloadUri;

  ExtensionManifest({
    required this.id,
    required this.name,
    required this.version,
    required this.type,
    this.lang = 'en',
    this.language = 'javascript',
    this.description = '',
    this.author = '',
    this.icon = '',
    this.website = '',
    this.readme = '',
    this.notes = '',
    this.manifestUri = '',
    this.baseUrl = '',
    this.iconUrl = '',
    this.scriptUrl = '',
    this.payload = '',
    this.payloadUri = '',
  });

  factory ExtensionManifest.fromJson(Map<String, dynamic> json) {
    return ExtensionManifest(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      version: json['version'] ?? '1.0.0',
      type: json['type'] ?? 'anime',
      lang: json['lang'] ?? 'en',
      language: json['language'] ?? 'javascript',
      description: json['description'] ?? '',
      author: json['author'] ?? '',
      icon: json['icon'] ?? '',
      website: json['website'] ?? '',
      readme: json['readme'] ?? '',
      notes: json['notes'] ?? '',
      manifestUri: json['manifestURI'] ?? json['manifestUri'] ?? '',
      baseUrl: json['baseUrl'] ?? '',
      iconUrl: json['iconUrl'] ?? '',
      scriptUrl: json['scriptUrl'] ?? '',
      payload: json['payload'] ?? '',
      payloadUri: json['payloadURI'] ?? json['payloadUri'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'version': version,
      'type': type,
      'lang': lang,
      'language': language,
      'description': description,
      'author': author,
      'icon': icon,
      'website': website,
      'readme': readme,
      'notes': notes,
      'manifestURI': manifestUri,
      'baseUrl': baseUrl,
      'iconUrl': iconUrl,
      'scriptUrl': scriptUrl,
      'payload': payload,
      'payloadURI': payloadUri,
    };
  }
}
