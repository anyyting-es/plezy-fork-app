import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import 'package:app_links/app_links.dart';
import 'package:flutter/foundation.dart';

import 'storage_service.dart';

class AnilistService {
  static const _clientId = '34991';
  static const _clientSecret = 'nJLD57Nt9XSv1uC3F2GsiM6jjrMPb80PSJOxipsh';
  static const _redirectUri = 'aniting://';
  static const _authUrl = 'https://anilist.co/api/v2/oauth/authorize';
  static const _tokenUrl = 'https://anilist.co/api/v2/oauth/token';
  static const _graphqlUrl = 'https://graphql.anilist.co';

  final _storage = StorageService.instance;
  final _appLinks = AppLinks();
  StreamSubscription<Uri>? _linkSubscription;

  String? _accessToken;
  final userNotifier = ValueNotifier<Map<String, dynamic>?>(null);

  AnilistService._();
  static final AnilistService instance = AnilistService._();

  Future<void> init() async {
    _accessToken = await _storage.getAnilistToken();
    if (_accessToken != null) {
      await fetchViewer();
    }
    _linkSubscription = _appLinks.uriLinkStream.listen((uri) {
      _handleCallback(uri);
    });
  }

  void dispose() {
    _linkSubscription?.cancel();
    userNotifier.dispose();
  }

  bool get isAuthenticated => _accessToken != null;
  Map<String, dynamic>? get user => userNotifier.value;

  Future<void> login() async {
    final url = Uri.parse('$_authUrl?client_id=$_clientId&response_type=code&redirect_uri=${Uri.encodeComponent(_redirectUri)}');
    print('AniList login attempt: $url');
    try {
      final launched = await launchUrl(url, mode: LaunchMode.externalApplication);
      print('AniList login launched: $launched');
    } catch (e) {
      print('AniList login error: $e');
    }
  }

  Future<void> logout() async {
    _accessToken = null;
    userNotifier.value = null;
    await _storage.setAnilistToken(null);
  }

  Future<void> _handleCallback(Uri uri) async {
    print('AniList callback received: $uri');
    if (uri.scheme == 'aniting') {
      final code = uri.queryParameters['code'];
      if (code != null) {
        print('AniList code found: $code');
        await _exchangeCodeForToken(code);
      }
    }
  }

  Future<void> _exchangeCodeForToken(String code) async {
    try {
      final response = await http.post(
        Uri.parse(_tokenUrl),
        headers: {'Accept': 'application/json'},
        body: {
          'grant_type': 'authorization_code',
          'client_id': _clientId,
          'client_secret': _clientSecret,
          'redirect_uri': _redirectUri,
          'code': code,
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        _accessToken = data['access_token'];
        await _storage.setAnilistToken(_accessToken);
        await fetchViewer();
      }
    } catch (e) {
      print('Error exchanging AniList code: $e');
    }
  }

  Future<Map<String, dynamic>?> fetchViewer() async {
    if (_accessToken == null) return null;

    const query = '''
      query {
        Viewer {
          id
          name
          avatar { large }
          bannerImage
          statistics {
            anime { count minutesWatched }
            manga { count chaptersRead }
          }
        }
      }
    ''';

    try {
      final response = await http.post(
        Uri.parse(_graphqlUrl),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'Authorization': 'Bearer $_accessToken',
        },
        body: jsonEncode({'query': query}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final userData = data['data']?['Viewer'];
        userNotifier.value = userData;
        return userData;
      } else if (response.statusCode == 401) {
        await logout();
      }
    } catch (e) {
      print('Error fetching AniList viewer: $e');
    }
    return null;
  }
}
