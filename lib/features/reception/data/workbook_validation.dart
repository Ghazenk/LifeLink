import 'dart:convert';
import 'dart:typed_data';

/// Inspect ZIP metadata before the Excel parser allocates decompressed data.
/// The file stays local; only validated row fields are sent to the server.
void validateImportWorkbook(Uint8List bytes) {
  if (bytes.length < 22 || bytes.length > 5 * 1024 * 1024) {
    throw const FormatException('Use an XLSX workbook smaller than 5 MB.');
  }
  final data = ByteData.sublistView(bytes);
  int u16(int at) => data.getUint16(at, Endian.little);
  int u32(int at) => data.getUint32(at, Endian.little);
  if (u32(0) != 0x04034b50) {
    throw const FormatException('This is not an XLSX workbook.');
  }
  var end = -1;
  for (var i = bytes.length - 22; i >= 0 && i >= bytes.length - 65557; i--) {
    if (u32(i) == 0x06054b50 && i + 22 + u16(i + 20) == bytes.length) {
      end = i;
      break;
    }
  }
  if (end < 0 || u16(end + 4) != 0 || u16(end + 6) != 0) {
    throw const FormatException('Invalid or multi-part XLSX workbook.');
  }
  final count = u16(end + 10);
  final directorySize = u32(end + 12);
  var cursor = u32(end + 16);
  if (count < 3 || count > 100 || cursor + directorySize != end) {
    throw const FormatException('Workbook has too many parts or is malformed.');
  }
  var uncompressed = 0;
  var hasWorkbook = false;
  for (var n = 0; n < count; n++) {
    if (cursor + 46 > end || u32(cursor) != 0x02014b50) {
      throw const FormatException('Invalid workbook archive.');
    }
    final flags = u16(cursor + 8);
    final method = u16(cursor + 10);
    final size = u32(cursor + 24);
    final nameLength = u16(cursor + 28);
    final extraLength = u16(cursor + 30);
    final commentLength = u16(cursor + 32);
    final next = cursor + 46 + nameLength + extraLength + commentLength;
    if (next > end || flags & 1 != 0 || (method != 0 && method != 8)) {
      throw const FormatException('Encrypted or invalid workbook archive.');
    }
    final name = utf8.decode(
      bytes.sublist(cursor + 46, cursor + 46 + nameLength),
    );
    if (name.contains('..') ||
        name.startsWith('/') ||
        name.contains('\\') ||
        name.contains(':') ||
        name.contains('\u0000') ||
        name.endsWith('.bin') ||
        name.startsWith('xl/externalLinks/')) {
      throw const FormatException('Workbook contains an unsafe part.');
    }
    if (name == 'xl/workbook.xml') hasWorkbook = true;
    uncompressed += size;
    if (uncompressed > 16 * 1024 * 1024) {
      throw const FormatException('Workbook expands beyond 16 MB.');
    }
    cursor = next;
  }
  if (cursor != end || !hasWorkbook) {
    throw const FormatException('This is not a valid XLSX workbook.');
  }
}
