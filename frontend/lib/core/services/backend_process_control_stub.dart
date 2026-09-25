/// Web / unsupported platforms: the launcher is disabled there, so these are
/// never called.
List<(int pid, String path)> listProcessImagePaths(String imageName) =>
    throw UnsupportedError('Process listing is not supported on this platform');

bool terminateProcessById(int pid) =>
    throw UnsupportedError('Process termination is not supported on this platform');
