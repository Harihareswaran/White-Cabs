import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;

class StorageService {
  Future<String> saveImage(File image, String folder) async {
    final directory = await getApplicationDocumentsDirectory();
    final imagePath = path.join(directory.path, folder, path.basename(image.path));
    await Directory(path.dirname(imagePath)).create(recursive: true);
    await image.copy(imagePath);
    return imagePath;
  }
}