// ignore_for_file: camel_case_types

/// Stub for dart:js context to allow compilation on mobile/desktop
class JsContext {
  dynamic operator [](dynamic key) => _stubObject;
  void operator []=(dynamic key, dynamic value) {}
  bool hasProperty(String key) => false;
  dynamic callMethod(String method, [List? args]) => null;
}

final context = JsContext();

final _stubObject = JsObject();

class JsObject {
  bool hasProperty(String key) => false;
  dynamic operator [](dynamic key) => null;
}

/// Stub for allowInterop to allow compilation on mobile/desktop
dynamic allowInterop<F extends Function>(F f) => f;
