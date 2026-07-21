import 'dart:ffi' if (dart.library.html) '../stubs/ffi_stub.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

/// Lightweight Win32 FFI helper for true borderless fullscreen on Windows.
/// No extra packages needed — just dart:ffi + user32.dll.

final _u = kIsWeb ? null : DynamicLibrary.open('user32.dll');

final _getForegroundWindow = kIsWeb 
    ? () => 0 
    : _u!.lookupFunction<IntPtr Function(), int Function()>('GetForegroundWindow');

final _getWindowLong = kIsWeb 
    ? (int h, int l) => 0 
    : _u!.lookupFunction<Int32 Function(IntPtr, Int32), int Function(int, int)>('GetWindowLongW');

final _setWindowLong = kIsWeb 
    ? (int h, int l, int s) => 0 
    : _u!.lookupFunction<Int32 Function(IntPtr, Int32, Int32), int Function(int, int, int)>('SetWindowLongW');

final _setWindowPos = kIsWeb 
    ? (int h, int z, int x, int y, int cx, int cy, int f) => 0 
    : _u!.lookupFunction<IntPtr Function(IntPtr, IntPtr, Int32, Int32, Int32, Int32, Uint32), int Function(int, int, int, int, int, int, int)>('SetWindowPos');

final _getSystemMetrics = kIsWeb 
    ? (int m) => 0 
    : _u!.lookupFunction<Int32 Function(Int32), int Function(int)>('GetSystemMetrics');

final _showWindow = kIsWeb 
    ? (int h, int s) => 0 
    : _u!.lookupFunction<Int32 Function(IntPtr, Int32), int Function(int, int)>('ShowWindow');

final _isZoomed = kIsWeb 
    ? (int h) => 0 
    : _u!.lookupFunction<Int32 Function(IntPtr), int Function(int)>('IsZoomed');

// Win32 constants
const _gwlStyle = -16;
const _wsOverlappedWindow = 0x00CF0000;
const _swpFrameChanged = 0x0020;
const _swpNoZOrder = 0x0004;
const _smCxScreen = 0;
const _smCyScreen = 1;
const _hwndTop = 0;
const _swRestore = 9;

int _savedStyle = 0;

/// Returns true if the window is currently maximized.
bool isMaximized() => _isZoomed(_getForegroundWindow()) != 0;

/// Enter true borderless fullscreen — hides title bar, covers taskbar.
void enterFullscreen() {
  final hwnd = _getForegroundWindow();
  
  // ANTI-GLITCH TRICK: If maximized, restore it first.
  // This prevents Windows from showing the "Windows 7 style" frame
  // when we remove the borders.
  if (isMaximized()) {
    _showWindow(hwnd, _swRestore);
  }

  _savedStyle = _getWindowLong(hwnd, _gwlStyle);
  // Remove the standard window chrome bits
  _setWindowLong(hwnd, _gwlStyle, _savedStyle & ~_wsOverlappedWindow);
  
  // Cover entire screen
  final cx = _getSystemMetrics(_smCxScreen);
  final cy = _getSystemMetrics(_smCyScreen);
  _setWindowPos(hwnd, _hwndTop, 0, 0, cx, cy, _swpFrameChanged);
}

/// Restore the window style and frame after entering fullscreen.
void restoreStyle() {
  final hwnd = _getForegroundWindow();
  if (_savedStyle != 0) {
    _setWindowLong(hwnd, _gwlStyle, _savedStyle);
    // Trigger a frame change so bitsdojo_window can take over management again
    // SWP_NOSIZE | SWP_NOMOVE = 0x0001 | 0x0002
    _setWindowPos(hwnd, _hwndTop, 0, 0, 0, 0, _swpFrameChanged | _swpNoZOrder | 0x0001 | 0x0002);
    _savedStyle = 0;
  }
}
