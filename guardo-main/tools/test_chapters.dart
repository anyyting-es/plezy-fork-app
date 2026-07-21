import 'package:media_kit/media_kit.dart';
import 'dart:io';

void main() async {
  MediaKit.ensureInitialized();
  
  final player = Player();
  await player.open(Media('https://test-streams.mux.dev/x36xhzz/x36xhzz.m3u8')); // just a dummy, real video would be better
  // wait a bit
  await Future.delayed(Duration(seconds: 3));
  
  try {
    // MediaKit hides the raw mpv property getter, but we can try to use reflection or check if there's any undocumented map
    print("Player state properties:");
    print(player.state.toString());
  } catch (e) {
    print(e);
  }
  exit(0);
}
