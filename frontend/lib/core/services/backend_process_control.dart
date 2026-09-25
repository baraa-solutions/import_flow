// Native process helpers for the backend launcher.
//
// Windows desktop uses Win32 (EnumProcesses + QueryFullProcessImageName /
// TerminateProcess): no child process, so no console flash. Web gets a stub.
export 'backend_process_control_stub.dart'
    if (dart.library.ffi) 'backend_process_control_ffi.dart';
