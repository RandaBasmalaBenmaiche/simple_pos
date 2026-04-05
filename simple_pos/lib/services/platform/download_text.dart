export 'download_text_stub.dart'
    if (dart.library.io) 'download_text_io.dart'
    if (dart.library.html) 'download_text_web.dart';
