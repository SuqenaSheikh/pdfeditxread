import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class PdfIo {
  static Future<Directory> exportsDir() async {
    final root = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(root.path, 'folio_exports'));
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  static Future<String> writeOutput(Uint8List bytes, String fileName) async {
    final dir = await exportsDir();
    final out = File(p.join(dir.path, fileName));
    await out.writeAsBytes(bytes, flush: true);
    return out.path;
  }
}
