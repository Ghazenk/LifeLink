import 'dart:typed_data';

import 'package:excel/excel.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifelink/features/reception/data/workbook_validation.dart';
import 'package:lifelink/features/reception/data/reception_repository.dart';
import 'package:lifelink/features/sharing/qr_scan_screen.dart';

void main() {
  test('reception import rejects non-workbooks and oversized archives', () {
    expect(
      () => validateImportWorkbook(Uint8List.fromList([1, 2, 3])),
      throwsFormatException,
    );
    expect(
      () => validateImportWorkbook(Uint8List(5 * 1024 * 1024 + 1)),
      throwsFormatException,
    );
    final disguisedZip = Uint8List(22);
    ByteData.sublistView(disguisedZip).setUint32(0, 0x04034b50, Endian.little);
    expect(() => validateImportWorkbook(disguisedZip), throwsFormatException);
  });

  test('reception import accepts an ordinary generated XLSX archive', () {
    final workbook = Excel.createExcel().encode();
    expect(workbook, isNotNull);
    expect(
      () => validateImportWorkbook(Uint8List.fromList(workbook!)),
      returnsNormally,
    );
  });

  test('QR import rejects a non-PNG/JPEG image before decoding', () {
    expect(
      () => decodeLifeLinkQr(Uint8List.fromList([0x47, 0x49, 0x46, 0x38])),
      throwsFormatException,
    );
  });

  test('reception search cannot alter PostgREST filter grammar', () {
    expect(sanitizedReceptionSearch('  Ali-123  '), 'Ali-123');
    expect(
      () => sanitizedReceptionSearch('Ali),phone.ilike.*'),
      throwsFormatException,
    );
    expect(
      () => sanitizedReceptionSearch("' OR 1=1 --"),
      throwsFormatException,
    );
    expect(() => sanitizedReceptionSearch('A' * 81), throwsArgumentError);
  });
}
