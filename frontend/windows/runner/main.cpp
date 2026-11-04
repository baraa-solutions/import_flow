#include <flutter/dart_project.h>
#include <flutter/flutter_view_controller.h>
#include <windows.h>

#include "flutter_window.h"
#include "utils.h"

#include <string>

namespace {

// One frontend per Windows session. A second frontend.exe used to start a second
// engine against the same backend; closing it killed the backend under the first
// window. The OS releases the mutex when the process ends (crash included).
constexpr const wchar_t kSingleInstanceMutexName[] =
    L"Local\\SorourLogisticsFrontend";
// Same class name as kWindowClassName in win32_window.cpp.
constexpr const wchar_t kRunnerWindowClassName[] = L"FLUTTER_RUNNER_WIN32_WINDOW";

std::wstring ProcessImagePath(DWORD pid) {
  std::wstring path;
  HANDLE process =
      ::OpenProcess(PROCESS_QUERY_LIMITED_INFORMATION, FALSE, pid);
  if (process == nullptr) {
    return path;
  }
  wchar_t buffer[MAX_PATH * 4];
  DWORD size = static_cast<DWORD>(sizeof(buffer) / sizeof(buffer[0]));
  if (::QueryFullProcessImageNameW(process, 0, buffer, &size)) {
    path.assign(buffer, size);
  }
  ::CloseHandle(process);
  return path;
}

struct FindWindowState {
  std::wstring own_path;
  DWORD own_pid;
  HWND found;
};

// The runner window of another process started from exactly this executable
// (the class name alone is shared by every Flutter app).
BOOL CALLBACK FindRunningInstanceWindow(HWND hwnd, LPARAM lparam) {
  auto* state = reinterpret_cast<FindWindowState*>(lparam);
  wchar_t class_name[64] = {};
  if (::GetClassNameW(hwnd, class_name, 64) == 0 ||
      ::wcscmp(class_name, kRunnerWindowClassName) != 0) {
    return TRUE;
  }
  DWORD pid = 0;
  ::GetWindowThreadProcessId(hwnd, &pid);
  if (pid == 0 || pid == state->own_pid) {
    return TRUE;
  }
  if (::CompareStringOrdinal(ProcessImagePath(pid).c_str(), -1,
                             state->own_path.c_str(), -1,
                             TRUE) != CSTR_EQUAL) {
    return TRUE;
  }
  state->found = hwnd;
  return FALSE;
}

// Restores and focuses the already running window. Does nothing when that
// instance has no window yet (still starting) or the window is still hidden.
void ActivateRunningInstance() {
  // Resolved the same way as the other process's path (subst / mapped drives).
  const DWORD own_pid = ::GetCurrentProcessId();
  FindWindowState state{ProcessImagePath(own_pid), own_pid, nullptr};
  if (state.own_path.empty()) {
    return;
  }
  ::EnumWindows(FindRunningInstanceWindow, reinterpret_cast<LPARAM>(&state));
  if (state.found == nullptr) {
    return;
  }
  if (::IsIconic(state.found)) {
    ::ShowWindow(state.found, SW_RESTORE);
  } else if (!::IsWindowVisible(state.found)) {
    return;
  }
  ::SetForegroundWindow(state.found);
}

}  // namespace

int APIENTRY wWinMain(_In_ HINSTANCE instance, _In_opt_ HINSTANCE prev,
                      _In_ wchar_t *command_line, _In_ int show_command) {
  // Single instance (release/profile builds only, so a dev `flutter run` still
  // starts next to an installed copy). If another frontend already runs, bring
  // its window to the front and exit without starting an engine or a backend.
  HANDLE single_instance_mutex = nullptr;
#ifndef _DEBUG
  single_instance_mutex =
      ::CreateMutexW(nullptr, FALSE, kSingleInstanceMutexName);
  if (single_instance_mutex != nullptr &&
      ::GetLastError() == ERROR_ALREADY_EXISTS) {
    ActivateRunningInstance();
    ::CloseHandle(single_instance_mutex);
    return EXIT_SUCCESS;
  }
#endif
  // Attach to console when present (e.g., 'flutter run') or create a
  // new console when running with a debugger.
  if (!::AttachConsole(ATTACH_PARENT_PROCESS) && ::IsDebuggerPresent()) {
    CreateAndAttachConsole();
  }

  // Initialize COM, so that it is available for use in the library and/or
  // plugins.
  ::CoInitializeEx(nullptr, COINIT_APARTMENTTHREADED);

  flutter::DartProject project(L"data");

  std::vector<std::string> command_line_arguments =
      GetCommandLineArguments();

  project.set_dart_entrypoint_arguments(std::move(command_line_arguments));

  FlutterWindow window(project);
  Win32Window::Point origin(10, 10);
  Win32Window::Size size(1366, 768);
  if (!window.Create(L"Sorour Logistics ERP (v2.5.0)", origin, size)) {
    return EXIT_FAILURE;
  }
  window.SetQuitOnClose(true);

  ::MSG msg;
  while (::GetMessage(&msg, nullptr, 0, 0)) {
    ::TranslateMessage(&msg);
    ::DispatchMessage(&msg);
  }

  ::CoUninitialize();
  if (single_instance_mutex != nullptr) {
    ::CloseHandle(single_instance_mutex);
  }
  return EXIT_SUCCESS;
}
