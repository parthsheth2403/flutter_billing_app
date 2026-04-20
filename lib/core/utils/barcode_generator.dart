class BarcodeGenerator {
  static String generateProductBarcode(Set<String> existingBarcodes) {
    final now = DateTime.now().millisecondsSinceEpoch;
    var serial = (now % 10000000000).toInt();

    for (var attempt = 0; attempt < 1000; attempt++) {
      final base = '29${serial.toString().padLeft(10, '0')}';
      final barcode = _withChecksum(base);

      if (!existingBarcodes.contains(barcode)) {
        return barcode;
      }

      serial = (serial + 1) % 10000000000;
    }

    throw StateError('Unable to generate a unique barcode');
  }

  static String _withChecksum(String value) {
    if (value.length != 12) {
      throw ArgumentError('EAN-13 base must be 12 digits long');
    }

    var sum = 0;
    for (var index = 0; index < value.length; index++) {
      final digit = int.parse(value[index]);
      sum += index.isEven ? digit : digit * 3;
    }

    final checksum = (10 - (sum % 10)) % 10;
    return '$value$checksum';
  }
}
