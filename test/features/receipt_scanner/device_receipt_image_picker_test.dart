import 'dart:io';

import 'package:finote/features/receipt_scanner/data/device_receipt_image_picker.dart';
import 'package:finote/features/receipt_scanner/domain/receipt_image.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'discard deletes camera cache but leaves gallery source untouched',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'finote_receipt_',
      );
      addTearDown(() => directory.delete(recursive: true));
      final cameraFile = await File('${directory.path}/camera.jpg')
          .writeAsString('camera');
      final galleryFile = await File('${directory.path}/gallery.jpg')
          .writeAsString('gallery');
      final picker = DeviceReceiptImagePicker();

      await picker.discard(
        ReceiptImage(
          path: cameraFile.path,
          name: 'camera.jpg',
          origin: ReceiptImageOrigin.camera,
          isTemporary: true,
        ),
      );
      await picker.discard(
        ReceiptImage(
          path: galleryFile.path,
          name: 'gallery.jpg',
          origin: ReceiptImageOrigin.gallery,
          isTemporary: false,
        ),
      );

      expect(cameraFile.existsSync(), isFalse);
      expect(galleryFile.existsSync(), isTrue);
    },
  );
}
