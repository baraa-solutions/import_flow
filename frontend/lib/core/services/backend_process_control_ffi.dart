import 'dart:ffi';
import 'dart:io';

import 'package:ffi/ffi.dart';
import 'package:win32/win32.dart';

// Toolhelp32 is not bound by package:win32 5.x; minimal bindings here.
const int _th32csSnapProcess = 0x00000002;

final class _ProcessEntry32W extends Struct {
  @Uint32()
  external int dwSize;
  @Uint32()
  external int cntUsage;
  @Uint32()
  external int th32ProcessID;
  @IntPtr()
  external int th32DefaultHeapID;
  @Uint32()
  external int th32ModuleID;
  @Uint32()
  external int cntThreads;
  @Uint32()
  external int th32ParentProcessID;
  @Int32()
  external int pcPriClassBase;
  @Uint32()
  external int dwFlags;
  @Array(MAX_PATH)
  external Array<Uint16> szExeFile;
}

final _kernel32 = DynamicLibrary.open('kernel32.dll');

final _createToolhelp32Snapshot = _kernel32.lookupFunction<
    IntPtr Function(Uint32 dwFlags, Uint32 th32ProcessID),
    int Function(int dwFlags, int th32ProcessID)>('CreateToolhelp32Snapshot');

final _process32FirstW = _kernel32.lookupFunction<
    Int32 Function(IntPtr hSnapshot, Pointer<_ProcessEntry32W> lppe),
    int Function(int hSnapshot, Pointer<_ProcessEntry32W> lppe)>('Process32FirstW');

final _process32NextW = _kernel32.lookupFunction<
    Int32 Function(IntPtr hSnapshot, Pointer<_ProcessEntry32W> lppe),
    int Function(int hSnapshot, Pointer<_ProcessEntry32W> lppe)>('Process32NextW');

String _exeName(_ProcessEntry32W entry) {
  final codes = <int>[];
  for (var i = 0; i < MAX_PATH; i++) {
    final c = entry.szExeFile[i];
    if (c == 0) break;
    codes.add(c);
  }
  return String.fromCharCodes(codes);
}

/// (pid, full image path) of the processes whose image name is [imageName]
/// (case-insensitive). Only those are opened to read the full path; a process
/// that can't be opened (other user / protected) is skipped. Throws when the
/// process snapshot itself can't be taken.
List<(int pid, String path)> listProcessImagePaths(String imageName) {
  if (!Platform.isWindows) {
    throw UnsupportedError('Process listing is only implemented on Windows');
  }
  final wanted = imageName.toLowerCase();
  final snapshot = _createToolhelp32Snapshot(_th32csSnapProcess, 0);
  if (snapshot == INVALID_HANDLE_VALUE || snapshot == 0) {
    throw StateError('CreateToolhelp32Snapshot failed (${GetLastError()})');
  }
  final entry = calloc<_ProcessEntry32W>();
  final buffer = wsalloc(32768);
  final size = calloc<Uint32>();
  final result = <(int, String)>[];
  try {
    entry.ref.dwSize = sizeOf<_ProcessEntry32W>();
    var ok = _process32FirstW(snapshot, entry);
    while (ok != 0) {
      final pid = entry.ref.th32ProcessID;
      if (pid != 0 && _exeName(entry.ref).toLowerCase() == wanted) {
        final handle = OpenProcess(
            PROCESS_ACCESS_RIGHTS.PROCESS_QUERY_LIMITED_INFORMATION, FALSE, pid);
        if (handle != 0) {
          try {
            size.value = 32768;
            if (QueryFullProcessImageName(handle, 0, buffer, size) != 0) {
              result.add((pid, buffer.toDartString(length: size.value)));
            }
          } finally {
            CloseHandle(handle);
          }
        }
      }
      ok = _process32NextW(snapshot, entry);
    }
    return result;
  } finally {
    free(entry);
    free(buffer);
    free(size);
    CloseHandle(snapshot);
  }
}

/// Forcefully ends [pid]. Returns false if it can't be opened or terminated.
bool terminateProcessById(int pid) {
  if (!Platform.isWindows) return false;
  final handle = OpenProcess(PROCESS_ACCESS_RIGHTS.PROCESS_TERMINATE, FALSE, pid);
  if (handle == 0) return false;
  try {
    return TerminateProcess(handle, 1) != 0;
  } finally {
    CloseHandle(handle);
  }
}
