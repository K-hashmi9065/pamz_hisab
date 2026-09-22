import 'dart:typed_data';

import 'fl_pdf_download_stub.dart'
    if (dart.library.io) 'fl_pdf_download_io.dart'
    if (dart.library.html) 'fl_pdf_download_web.dart';

Future<String?> downloadPdf(Uint8List bytes, String fileName) =>
    downloadPdfImpl(bytes, fileName);
