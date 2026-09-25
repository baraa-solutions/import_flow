import 'dart:ffi';
import 'dart:io';

import 'package:ffi/ffi.dart';
import 'package:win32/win32.dart';

/// (pid, full image path) of every process this user may query.
/// Throws when the process list itself can't be read.
List<(int pid, String path)> listProcessImagePaths() {
  if (!Platform.isWindows) {
    throw UnsupportedError('Process listing is only implemented on Windows');
  }
  var capacity = 1024;
  while (true) {
    final pids = calloc<Uint32>(capacity);
    final needed = calloc<Uint32>();
    try {
      final bytes = capacity * sizeOf<Uint32>();
      if (EnumProcesses(pids, bytes, needed) == 0) {
        throw StateError('EnumProcesses failed (${GetLastError()})');
      }
      if (needed.value >= bytes && capacity < 1 << 16) {
        capacity *= 2; // buffer may be truncated: retry bigger
        continue;
      }
      final count = needed.value ~/ sizeOf<Uint32>();
      final result = <(int, String)>[];
      final buffer = wsalloc(32768);
      final size = calloc<Uint32>();
      try {
        for (var i = 0; i < count; i++) {
          final pid = pids[i];
          if (pid == 0) continue;
          final handle = OpenProcess(PROCESS_ACCESS_RIGHTS.PROCESS_QUERY_LIMITED_INFORMATION, FALSE, pid);
          if (handle == 0) continue; // protected / other user's process
          try {
            size.value = 32768;
            if (QueryFullProcessImageName(handle, 0, buffer, size) != 0) {
              result.add((pid, buffer.toDartString(length: size.value)));
            }
          } finally {
            CloseHandle(handle);
          }
        }
      } finally {
        free(buffer);
        free(size);
      }
      return result;
    } finally {
      free(pids);
      free(needed);
    }
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
