// Stub for dart:io on web
class Platform {
  static bool isWindows = false;
  static bool isAndroid = false;
  static bool isIOS = false;
  static bool isLinux = false;
  static bool isMacOS = false;
  static String pathSeparator = '/';
  static String resolvedExecutable = '';
}
class Directory {
  final String path;
  Directory(this.path);
  static Directory get current => Directory('');
  Future<bool> exists() async => false;
  Future<void> create({bool recursive = false}) async {}
  Directory get parent => Directory('');
  Stream<FileSystemEntity> list({bool recursive = false, bool followLinks = true}) => const Stream.empty();
}
abstract class FileSystemEntity {
  String get path;
}
class File extends FileSystemEntity {
  @override
  final String path;
  File(this.path);
  Future<bool> exists() async => false;
  Future<void> writeAsString(String content) async {}
  Future<String> readAsString() async => '';
}
class Process {
  static Future<ProcessResult> run(String command, List<String> args) async => ProcessResult(0, 0, '', '');
  static Future<Process> start(String exe, List<String> args, {dynamic mode}) async => throw UnimplementedError();
  void kill() {}
  Stream<List<int>> get stdout => const Stream.empty();
  Stream<List<int>> get stderr => const Stream.empty();
}
class ProcessResult {
  final int exitCode;
  final dynamic pid;
  final dynamic stdout;
  final dynamic stderr;
  ProcessResult(this.pid, this.exitCode, this.stdout, this.stderr);
}
enum ProcessStartMode { detachedWithStdio }
