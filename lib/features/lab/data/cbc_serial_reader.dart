import 'dart:async';
import 'package:flutter_libserialport/flutter_libserialport.dart';

/// Service to interact with the CBC machine via Serial COM Port.
class CbcSerialReader {
  /// Returns a list of available COM ports on the system.
  List<String> getAvailablePorts() {
    return SerialPort.availablePorts;
  }

  /// Listens to the specified COM port and yields the parsed data.
  /// (Not fully implemented for a physical machine in this sprint).
  Stream<String> listenToMachine(String portName) async* {
    final port = SerialPort(portName);
    if (!port.openReadWrite()) {
      throw Exception('Failed to open port $portName: ${SerialPort.lastError}');
    }
    
    // In a real scenario, you'd use a SerialPortReader here.
    // For now, we simulate the fallback mock immediately below.
  }

  /// Mock method for sprint testing when a physical CBC machine isn't connected.
  /// Generates a delayed random CSV string mimicking standard hardware output.
  Future<Map<String, double>> mockFetch() async {
    // Simulate hardware read delay
    await Future.delayed(const Duration(seconds: 2));
    
    // e.g. "HGB:11.2,WBC:7.5,PLT:300"
    // Generating some randomized healthy/borderline ranges
    final hgb = 10.0 + (DateTime.now().millisecond % 50) / 10.0; // 10.0 - 15.0
    final wbc = 4.0 + (DateTime.now().millisecond % 60) / 10.0; // 4.0 - 10.0
    final plt = 150.0 + (DateTime.now().millisecond % 250); // 150 - 400

    return {
      'hemoglobin': double.parse(hgb.toStringAsFixed(1)),
      'wbc': double.parse(wbc.toStringAsFixed(1)),
      'platelets': double.parse(plt.toStringAsFixed(0)),
    };
  }
}
