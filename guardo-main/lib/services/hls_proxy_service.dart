import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// Local HTTP proxy that serves modified HLS manifests for instant seeking.
///
/// This proxy supports Master playlists and seamlessly proxies all video/audio tracks.
/// It works by rewriting media URIs in master playlists to point back to the proxy,
/// and dynamically trimming Media playlists based on a single `seekTo` target.
class HlsProxyService {
  HttpServer? _server;
  int? _port;

  Map<String, String> _headers = {};
  String? _lastMasterUrl;

  List<Map<String, dynamic>> _videoSegments = [];
  double _timeOffset = 0;
  double _targetPlaybackTimeSec = 0;
  double _totalDuration = 0;

  bool disableSeekProxy = false;

  double get totalDuration => _totalDuration;
  double get timeOffset => _timeOffset;
  bool get isReady => _server != null;

  Future<void> start() async {
    if (_server != null) return;
    _server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    _port = _server!.port;
    debugPrint('[HlsProxy] Listening on port $_port');
    _server!.listen(_handle);
  }

  Future<void> dispose() async {
    await _server?.close(force: true);
    _server = null;
    _port = null;
    _videoSegments = [];
  }

  Future<String?> prepare(String m3u8Url, {Map<String, String>? headers}) async {
    try {
      _headers = headers ?? {};
      _timeOffset = 0;
      _targetPlaybackTimeSec = 0;
      _videoSegments = [];
      _totalDuration = 0;

      final r = await http.get(Uri.parse(m3u8Url), headers: _headers);
      if (r.statusCode != 200) return null;

      final body = r.body;
      if (!body.contains('#EXTM3U')) return null;

      _lastMasterUrl = m3u8Url;

      String videoVariantUrl = m3u8Url;
      if (body.contains('#EXT-X-STREAM-INF:')) {
        final lines = body.split(RegExp(r'\r?\n'));
        for (int i = 0; i < lines.length; i++) {
          if (lines[i].startsWith('#EXT-X-STREAM-INF:')) {
             for (int j = i + 1; j < lines.length; j++) {
                if (lines[j].isNotEmpty && !lines[j].startsWith('#')) {
                   videoVariantUrl = _abs(lines[j], m3u8Url);
                   break;
                }
             }
             break;
          }
        }
      }

      final vr = await http.get(Uri.parse(videoVariantUrl), headers: _headers);
      if (vr.statusCode == 200) {
        _parseAndBuildSegmentsList(vr.body);
      }

      if (_videoSegments.isEmpty) return null;

      debugPrint('[HlsProxy] Ready (Universal Rewrite mode): ${_videoSegments.length} segments, '
          '${_totalDuration.toStringAsFixed(1)}s');
      return freshUrl;
    } catch (e) {
      debugPrint('[HlsProxy] prepare error: $e');
      return null;
    }
  }

  double seekTo(double targetSec) {
    if (_videoSegments.isEmpty) return 0;
    int idx = 0;
    for (int i = 0; i < _videoSegments.length; i++) {
      final start = _videoSegments[i]['start'] as double;
      final dur = _videoSegments[i]['dur'] as double;
      if (start + dur > targetSec) {
        idx = i;
        break;
      }
      if (i == _videoSegments.length - 1) idx = i;
    }
    _timeOffset = _videoSegments[idx]['start'] as double;
    _targetPlaybackTimeSec = targetSec;
    debugPrint('[HlsProxy] seekTo(${targetSec.toStringAsFixed(1)}) -> seg $idx, offset ${_timeOffset.toStringAsFixed(1)}s');
    return _timeOffset;
  }

  void resetToFull() {
    _timeOffset = 0;
    _targetPlaybackTimeSec = 0;
  }

  String get freshUrl {
    if (_lastMasterUrl == null) return '';
    final enc = Uri.encodeComponent(_lastMasterUrl!);
    final ts = DateTime.now().millisecondsSinceEpoch;
    return 'http://127.0.0.1:$_port/proxy?url=$enc&t=$ts';
  }

  void _handle(HttpRequest req) async {
    try {
      if (req.uri.path == '/proxy') {
        final targetUrl = req.uri.queryParameters['url'];
        if (targetUrl == null) {
          req.response.statusCode = 404;
          await req.response.close();
          return;
        }

        final client = http.Client();
        final request = http.Request('GET', Uri.parse(targetUrl));
        request.headers.addAll(_headers);
        final r = await client.send(request);

        if (r.statusCode != 200) {
          req.response.statusCode = r.statusCode;
          await req.response.close();
          return;
        }

        req.response.headers.set('Access-Control-Allow-Origin', '*');

        // Detect if it's a playlist by looking at content-type or URL
        final isPlaylist = targetUrl.contains('.m3u8') || 
            (r.headers['content-type']?.contains('mpegurl') ?? false) ||
            targetUrl.contains('init.html') == false && targetUrl.endsWith('.html') == false; // fallback

        if (isPlaylist || r.headers['content-type']?.contains('text/plain') == true) {
          final body = await r.stream.bytesToString();
          if (body.contains('#EXT-X-STREAM-INF:')) {
            req.response.headers.contentType = ContentType('application', 'vnd.apple.mpegurl', charset: 'utf-8');
            req.response.write(_rewriteMasterPlaylist(body, targetUrl));
          } else if (body.contains('#EXTINF:')) {
            req.response.headers.contentType = ContentType('application', 'vnd.apple.mpegurl', charset: 'utf-8');
            final proxyTargetSec = disableSeekProxy ? 0.0 : _targetPlaybackTimeSec;
            req.response.write(_trimAndRewriteMediaPlaylist(body, targetUrl, proxyTargetSec));
          } else {
            req.response.write(body);
          }
        } else {
          // Binary data (video chunk)
          req.response.headers.contentType = ContentType('application', 'octet-stream');
          await r.stream.pipe(req.response);
          return; // pipe automatically closes the response
        }
        await req.response.close();
      } else {
        req.response.statusCode = 404;
        await req.response.close();
      }
    } catch (_) {}
  }

  void _parseAndBuildSegmentsList(String body) {
     final lines = body.split(RegExp(r'\r?\n'));
     _videoSegments = [];
     _totalDuration = 0;
     double cum = 0, curDur = 0;

     for (final raw in lines) {
       final line = raw.trim();
       if (line.isEmpty || line == '#EXTM3U') continue;
       if (line.startsWith('#EXTINF:')) {
         final durStr = line.substring(8).replaceAll(',', '');
         curDur = double.tryParse(durStr) ?? 0;
       } else if (!line.startsWith('#') && curDur > 0) {
         _videoSegments.add({'dur': curDur, 'start': cum});
         cum += curDur;
         curDur = 0;
       }
     }
     _totalDuration = cum;
  }

  String _rewriteMasterPlaylist(String body, String baseUrl) {
      final lines = body.split(RegExp(r'\r?\n'));
      final sb = StringBuffer();
      for (final line in lines) {
         if (line.startsWith('#EXT-X-MEDIA:')) {
            var l = line.replaceAllMapped(RegExp(r'URI="([^"]+)"'), (m) {
               final abs = _abs(m.group(1)!, baseUrl);
               return 'URI="http://127.0.0.1:$_port/proxy?url=${Uri.encodeComponent(abs)}"';
            });
            sb.writeln(l);
         } else if (!line.startsWith('#') && line.trim().isNotEmpty) {
            final abs = _abs(line.trim(), baseUrl);
            sb.writeln('http://127.0.0.1:$_port/proxy?url=${Uri.encodeComponent(abs)}');
         } else {
            sb.writeln(line);
         }
      }
      return sb.toString();
  }

  String _trimAndRewriteMediaPlaylist(String body, String baseUrl, double targetSec) {
     final lines = body.split(RegExp(r'\r?\n'));
     final sb = StringBuffer('#EXTM3U\n');
     
     List<String> headers = [];
     int startIndex = 0;
     
     List<Map<String, String>> segments = []; 
     String? currentExtInf;
     
     for (final line in lines) {
        final tline = line.trim();
        if (tline.isEmpty || tline == '#EXTM3U') continue;
        if (tline.startsWith('#EXTINF:')) {
           currentExtInf = tline;
        } else if (!tline.startsWith('#') && currentExtInf != null) {
           segments.add({'extinf': currentExtInf, 'url': tline});
           currentExtInf = null;
        } else if (tline.startsWith('#EXT-X-VERSION:') ||
            tline.startsWith('#EXT-X-TARGETDURATION:') ||
            tline.startsWith('#EXT-X-PLAYLIST-TYPE:') ||
            tline.startsWith('#EXT-X-INDEPENDENT-SEGMENTS')) {
          headers.add(tline);
        } else if (tline.startsWith('#EXT-X-MAP:')) {
          var l = tline.replaceAllMapped(RegExp(r'URI="([^"]+)"'), (m) {
             final abs = _abs(m.group(1)!, baseUrl);
             return 'URI="http://127.0.0.1:$_port/proxy?url=${Uri.encodeComponent(abs)}"';
          });
          headers.add(l);
        } else if (tline.startsWith('#EXT-X-MEDIA-SEQUENCE:')) {
          startIndex = int.tryParse(tline.substring(22)) ?? 0;
        }
     }

     int trimCount = 0;
     double cumulative = 0;
     for (int i = 0; i < segments.length; i++) {
        final durStr = segments[i]['extinf']!.substring(8).replaceAll(',', '');
        final dur = double.tryParse(durStr) ?? 0;
        if (cumulative + dur > targetSec) {
           trimCount = i; break;
        }
        cumulative += dur;
        if (i == segments.length - 1) trimCount = i;
     }

     for (final h in headers) {
       sb.writeln(h);
     }
     sb.writeln('#EXT-X-MEDIA-SEQUENCE:${startIndex + trimCount}');
     
     final exactOffset = targetSec - cumulative;
     if (exactOffset > 0) {
       sb.writeln('#EXT-X-START:TIME-OFFSET=$exactOffset,PRECISE=YES');
     }
     
     for (int i = trimCount; i < segments.length; i++) {
        sb.writeln(segments[i]['extinf']);
        final abs = _abs(segments[i]['url']!, baseUrl);
        sb.writeln('http://127.0.0.1:$_port/proxy?url=${Uri.encodeComponent(abs)}');
     }
     sb.writeln('#EXT-X-ENDLIST');
     return sb.toString();
  }

  String _abs(String url, String base) {
    if (url.startsWith('http://') || url.startsWith('https://')) return url;
    return Uri.parse(base).resolve(url).toString();
  }
}
