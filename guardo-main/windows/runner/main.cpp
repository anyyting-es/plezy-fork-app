#include <flutter/dart_project.h>
#include <flutter/flutter_view_controller.h>
#include <windows.h>

#include <fcntl.h>
#include <io.h>
#include <cstdio>
#include <string>
#include <thread>

#include <bitsdojo_window_windows/bitsdojo_window_plugin.h>

#include "flutter_window.h"
#include "utils.h"

namespace {

void StartFilteredStream(DWORD std_handle_id) {
  HANDLE original_handle = ::GetStdHandle(std_handle_id);
  if (original_handle == INVALID_HANDLE_VALUE || original_handle == nullptr) {
    return;
  }

  SECURITY_ATTRIBUTES sa{};
  sa.nLength = sizeof(SECURITY_ATTRIBUTES);
  sa.bInheritHandle = TRUE;

  HANDLE pipe_read = nullptr;
  HANDLE pipe_write = nullptr;
  if (!::CreatePipe(&pipe_read, &pipe_write, &sa, 0)) {
    return;
  }

  if (!::SetStdHandle(std_handle_id, pipe_write)) {
    ::CloseHandle(pipe_read);
    ::CloseHandle(pipe_write);
    return;
  }

  const int fd = _open_osfhandle(reinterpret_cast<intptr_t>(pipe_write), _O_TEXT);
  if (fd >= 0) {
    FILE* redirected = _fdopen(fd, "w");
    if (redirected != nullptr) {
      if (std_handle_id == STD_ERROR_HANDLE) {
        *stderr = *redirected;
        setvbuf(stderr, nullptr, _IONBF, 0);
      } else if (std_handle_id == STD_OUTPUT_HANDLE) {
        *stdout = *redirected;
        setvbuf(stdout, nullptr, _IONBF, 0);
      }
    }
  }

  std::thread([pipe_read, original_handle]() {
    constexpr DWORD kBufferSize = 4096;
    char buffer[kBufferSize];
    std::string pending;
    DWORD bytes_read = 0;

    auto flush_line = [&](const std::string& line) {
      const bool is_axtree_spam =
          line.find("accessibility_bridge.cc") != std::string::npos &&
          line.find("Failed to update ui::AXTree") != std::string::npos;
      if (is_axtree_spam) {
        return;
      }

      DWORD bytes_written = 0;
      ::WriteFile(original_handle, line.data(), static_cast<DWORD>(line.size()),
                  &bytes_written, nullptr);
    };

    while (::ReadFile(pipe_read, buffer, kBufferSize, &bytes_read, nullptr) && bytes_read > 0) {
      pending.append(buffer, bytes_read);
      size_t pos = 0;
      while ((pos = pending.find('\n')) != std::string::npos) {
        std::string line = pending.substr(0, pos + 1);
        pending.erase(0, pos + 1);
        flush_line(line);
      }
    }

    if (!pending.empty()) {
      flush_line(pending);
    }

    ::CloseHandle(pipe_read);
  }).detach();
}

void StartFilteredConsoleStreams() {
  StartFilteredStream(STD_ERROR_HANDLE);
  StartFilteredStream(STD_OUTPUT_HANDLE);
}

}  // namespace

int APIENTRY wWinMain(_In_ HINSTANCE instance, _In_opt_ HINSTANCE prev,
                      _In_ wchar_t *command_line, _In_ int show_command) {
  // Attach to console when present (e.g., 'flutter run') or create a
  // new console when running with a debugger.
  if (!::AttachConsole(ATTACH_PARENT_PROCESS) && ::IsDebuggerPresent()) {
    CreateAndAttachConsole();
  }
  StartFilteredConsoleStreams();

  // Initialize COM, so that it is available for use in the library and/or
  // plugins.
  ::CoInitializeEx(nullptr, COINIT_APARTMENTTHREADED);

  flutter::DartProject project(L"data");

  std::vector<std::string> command_line_arguments =
      GetCommandLineArguments();

  project.set_dart_entrypoint_arguments(std::move(command_line_arguments));

  FlutterWindow window(project);
  bitsdojo_window_configure(BDW_CUSTOM_FRAME | BDW_HIDE_ON_STARTUP);
  Win32Window::Point origin(10, 10);
  Win32Window::Size size(1280, 720);
  if (!window.Create(L"anityng", origin, size)) {
    return EXIT_FAILURE;
  }
  window.SetQuitOnClose(true);

  ::MSG msg;
  while (::GetMessage(&msg, nullptr, 0, 0)) {
    ::TranslateMessage(&msg);
    ::DispatchMessage(&msg);
  }

  ::CoUninitialize();
  return EXIT_SUCCESS;
}
