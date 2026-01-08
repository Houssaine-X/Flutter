// Stub file for web platform - tflite_flutter is not supported on web
// This file is imported when dart.library.html is available (web platform)

class InterpreterOptions {
  int? threads;
}

class Interpreter {
  static Future<Interpreter> fromAsset(String path, {InterpreterOptions? options}) async {
    throw UnsupportedError('TFLite is not supported on web platform');
  }
  
  void run(dynamic input, dynamic output) {
    throw UnsupportedError('TFLite is not supported on web platform');
  }
  
  dynamic getInputTensor(int index) {
    throw UnsupportedError('TFLite is not supported on web platform');
  }
  
  dynamic getOutputTensor(int index) {
    throw UnsupportedError('TFLite is not supported on web platform');
  }
  
  void close() {}
}
