// Stub for dart:ffi on web
class Pointer<T> {}
class Utf8 {}
class Int32 {}
class Void {}
class DynamicLibrary {
  factory DynamicLibrary.open(String path) => DynamicLibrary();
  DynamicLibrary();
  Function? lookupFunction<T, S>(String name) => null;
}
class malloc {
  static void free(dynamic ptr) {}
}
extension StringToNativeUtf8 on String {
  dynamic toNativeUtf8() => null;
}
