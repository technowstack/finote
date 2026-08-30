import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart' as plugin;
import 'package:permission_handler/permission_handler.dart' as permission;

import '../domain/receipt_image.dart';

class DeviceReceiptImagePicker implements ReceiptImagePicker {
  DeviceReceiptImagePicker({plugin.ImagePicker? picker})
    : _picker = picker ?? plugin.ImagePicker();

  final plugin.ImagePicker _picker;

  @override
  Future<ReceiptImage?> pick(ReceiptImageOrigin origin) async {
    if (origin == ReceiptImageOrigin.camera) await _requireCameraPermission();

    try {
      final file = await _picker.pickImage(
        source: origin == ReceiptImageOrigin.camera
            ? plugin.ImageSource.camera
            : plugin.ImageSource.gallery,
      );
      if (file == null) return null;

      final localFile = File(file.path);
      if (!await localFile.exists() || await localFile.length() == 0) {
        throw const ReceiptImageFailure(
          ReceiptImageFailureReason.unreadableImage,
        );
      }
      return ReceiptImage(
        path: file.path,
        name: file.name,
        mimeType: file.mimeType,
        origin: origin,
        isTemporary: origin == ReceiptImageOrigin.camera,
      );
    } on ReceiptImageFailure {
      rethrow;
    } on PlatformException {
      throw ReceiptImageFailure(
        origin == ReceiptImageOrigin.camera
            ? ReceiptImageFailureReason.cameraUnavailable
            : ReceiptImageFailureReason.unreadableImage,
      );
    } catch (_) {
      throw ReceiptImageFailure(
        origin == ReceiptImageOrigin.camera
            ? ReceiptImageFailureReason.cameraUnavailable
            : ReceiptImageFailureReason.unreadableImage,
      );
    }
  }

  Future<void> _requireCameraPermission() async {
    final status = await permission.Permission.camera.request();
    if (status.isGranted || status.isLimited) return;
    throw ReceiptImageFailure(
      status.isPermanentlyDenied || status.isRestricted
          ? ReceiptImageFailureReason.permissionPermanentlyDenied
          : ReceiptImageFailureReason.permissionDenied,
    );
  }

  @override
  Future<void> discard(ReceiptImage image) async {
    if (!image.isTemporary) return;
    try {
      final file = File(image.path);
      if (await file.exists()) await file.delete();
    } catch (_) {
      // Best-effort cleanup of an image-picker cache file.
    }
  }

  @override
  Future<bool> openSettings() => permission.openAppSettings();
}

final receiptImagePickerProvider = Provider<ReceiptImagePicker>(
  (ref) => DeviceReceiptImagePicker(),
);
