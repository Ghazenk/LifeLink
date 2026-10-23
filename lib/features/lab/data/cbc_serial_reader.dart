/// Hardware integration requires a validated parser for the clinic's analyzer.
/// Never substitute simulated measurements in a clinical workflow.
class CbcSerialReader {
  Stream<String> listenToMachine(String portName) => Stream.error(
    UnsupportedError(
      'Machine integration is not configured. Enter verified readings manually.',
    ),
  );
}
