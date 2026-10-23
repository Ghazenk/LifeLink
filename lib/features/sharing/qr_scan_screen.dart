import 'dart:io';

import 'package:camera/camera.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import 'package:zxing2/qrcode.dart';

import 'sharing_repository.dart';

// Decode locally. Photos are never sent to Supabase, AI, or a barcode service.
String decodeLifeLinkQr(Uint8List bytes) {
  if (bytes.length > 8 * 1024 * 1024) {
    throw const FormatException('Choose an image smaller than 8 MB.');
  }
  final png =
      bytes.length >= 8 &&
      bytes[0] == 0x89 &&
      bytes[1] == 0x50 &&
      bytes[2] == 0x4e &&
      bytes[3] == 0x47 &&
      bytes[4] == 0x0d &&
      bytes[5] == 0x0a &&
      bytes[6] == 0x1a &&
      bytes[7] == 0x0a;
  final jpeg =
      bytes.length >= 3 &&
      bytes[0] == 0xff &&
      bytes[1] == 0xd8 &&
      bytes[2] == 0xff;
  if (!png && !jpeg) {
    throw const FormatException('Choose a PNG or JPEG image.');
  }
  final decoder = img.findDecoderForData(bytes);
  final info = decoder?.startDecode(bytes);
  if (info == null || info.width * info.height > 16000000) {
    throw const FormatException('Choose a PNG/JPEG image up to 16 megapixels.');
  }
  var picture = decoder!.decodeFrame(0);
  if (picture == null) {
    throw const FormatException('Could not read this image.');
  }
  if (picture.width > 1800 || picture.height > 1800) {
    picture = img.copyResize(
      picture,
      width: picture.width >= picture.height ? 1800 : null,
      height: picture.height > picture.width ? 1800 : null,
    );
  }
  final source = RGBLuminanceSource(
    picture.width,
    picture.height,
    picture
        .convert(numChannels: 4)
        .getBytes(order: img.ChannelOrder.abgr)
        .buffer
        .asInt32List(),
  );
  try {
    return QRCodeReader().decode(BinaryBitmap(HybridBinarizer(source))).text;
  } catch (_) {
    throw const FormatException(
      'No readable QR code found. Move closer or enter the code instead.',
    );
  }
}

class QrScanScreen extends StatefulWidget {
  const QrScanScreen({super.key, required this.purpose});
  final String purpose;
  @override
  State<QrScanScreen> createState() => _QrScanScreenState();
}

class _QrScanScreenState extends State<QrScanScreen>
    with WidgetsBindingObserver {
  CameraController? _camera;
  bool _busy = false, _starting = false;
  int _generation = 0;
  String? _error;
  bool get _cameraSupported =>
      !kIsWeb && (Platform.isAndroid || Platform.isIOS);
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) {
      _generation++;
      final old = _camera;
      _camera = null;
      old?.dispose();
      if (mounted) setState(() => _starting = false);
    }
  }

  @override
  void dispose() {
    _generation++;
    WidgetsBinding.instance.removeObserver(this);
    _camera?.dispose();
    super.dispose();
  }

  Future<void> _start() async {
    if (_starting) return;
    final generation = ++_generation;
    setState(() {
      _starting = true;
      _error = null;
    });
    CameraController? controller;
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        throw const FormatException(
          'No camera available. Import an image or enter the code.',
        );
      }
      final rear = cameras.where(
        (c) => c.lensDirection == CameraLensDirection.back,
      );
      controller = CameraController(
        rear.isEmpty ? cameras.first : rear.first,
        ResolutionPreset.high,
        enableAudio: false,
      );
      await controller.initialize();
      if (!mounted || generation != _generation) {
        await controller.dispose();
        return;
      }
      setState(() => _camera = controller);
    } catch (_) {
      await controller?.dispose();
      if (mounted && generation == _generation) {
        setState(
          () => _error = 'Camera unavailable or permission denied. Enable camera access in device settings, or import a QR image.',
        );
      }
    } finally {
      if (mounted && generation == _generation) {
        setState(() => _starting = false);
      }
    }
  }

  Future<void> _read({bool capture = false}) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    XFile? photo;
    try {
      Uint8List bytes;
      if (capture) {
        photo = await _camera!.takePicture();
        if (await File(photo.path).length() > 8 * 1024 * 1024) {
          throw const FormatException('Camera image exceeds 8 MB.');
        }
        bytes = await photo.readAsBytes();
      } else {
        final selection = await FilePicker.platform.pickFiles(
          type: FileType.custom,
          allowedExtensions: ['png', 'jpg', 'jpeg'],
          withData: false,
        );
        if (selection == null) return;
        final file = selection.files.single;
        if (file.size > 8 * 1024 * 1024 || file.path == null) {
          throw const FormatException(
            'Choose a local PNG/JPEG image smaller than 8 MB.',
          );
        }
        final selected = File(file.path!);
        if (await selected.length() > 8 * 1024 * 1024) {
          throw const FormatException('Image exceeds 8 MB.');
        }
        bytes = await selected.readAsBytes();
      }
      final raw = await compute(decodeLifeLinkQr, bytes);
      final code = normalizeLifeLinkCode(raw, widget.purpose);
      if (mounted) Navigator.pop(context, code);
    } on FormatException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) {
        setState(
          () => _error = 'Could not read this QR. Try again or enter the code.',
        );
      }
    } finally {
      // Delete only the temporary image created by this camera operation.
      if (photo != null) {
        try {
          await File(photo.path).delete();
        } catch (_) {}
      }
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(
        widget.purpose == 'guardian'
            ? 'Scan patient connection'
            : 'Scan check-in',
      ),
    ),
    body: ListView(
      padding: const EdgeInsets.all(24),
      children: [
        const Text(
          'Read a LifeLink QR here. Scanning does not approve access or create a visit. Images are processed on this device.',
        ),
        const SizedBox(height: 16),
        if (_camera?.value.isInitialized == true) ...[
          AspectRatio(
            aspectRatio: _camera!.value.aspectRatio,
            child: CameraPreview(_camera!),
          ),
          FilledButton.icon(
            onPressed: _busy ? null : () => _read(capture: true),
            icon: const Icon(Icons.qr_code_scanner),
            label: const Text('Read QR in view'),
          ),
        ] else if (_cameraSupported)
          FilledButton.icon(
            onPressed: _starting ? null : _start,
            icon: const Icon(Icons.camera_alt_outlined),
            label: Text(_starting ? 'Opening camera…' : 'Open camera'),
          ),
        OutlinedButton.icon(
          onPressed: _busy ? null : () => _read(),
          icon: const Icon(Icons.image_outlined),
          label: const Text('Read QR from image'),
        ),
        if (!_cameraSupported)
          const Text(
            'On desktop, import a QR image or use the short code. Camera scanning is available on Android and iPhone.',
          ),
        if (_busy) const LinearProgressIndicator(),
        if (_error != null)
          Text(
            _error!,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
      ],
    ),
  );
}
