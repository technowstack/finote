enum ReceiptImageOrigin { camera, gallery }

class ReceiptImage {
  const ReceiptImage({
    required this.path,
    required this.name,
    required this.origin,
    required this.isTemporary,
    this.mimeType,
  });

  final String path;
  final String name;
  final ReceiptImageOrigin origin;
  final bool isTemporary;
  final String? mimeType;
}

abstract interface class ReceiptImagePicker {
  Future<ReceiptImage?> pick(ReceiptImageOrigin origin);
  Future<void> discard(ReceiptImage image);
  Future<bool> openSettings();
}

enum ReceiptImageFailureReason {
  permissionDenied,
  permissionPermanentlyDenied,
  cameraUnavailable,
  unreadableImage,
}

class ReceiptImageFailure implements Exception {
  const ReceiptImageFailure(this.reason);

  final ReceiptImageFailureReason reason;
}
