library dslink.test.common.base64;

import "dart:convert";

import "package:test/test.dart";
import "package:dslink/utils.dart" show Base64;

import "package:dslink/convert_consts.dart";

void main() {
  group("Base64", base64Tests);
}

const Map<String, String> inputs = const {
  "Hello World": "SGVsbG8gV29ybGQ",
  "Goodbye World": "R29vZGJ5ZSBXb3JsZA"
};

void base64Tests() {
  test("successfully encodes and decodes strings", () {
    for (var key in inputs.keys) {
      var encoded = Base64.encodeString(key);
      expect(encoded, equals(inputs[key]));
      var decoded = Base64.decodeString(inputs[key]);
      expect(decoded, equals(key));
    }
  });

  test("successfully encodes and decodes bytes", () {
    for (var key in inputs.keys) {
      var encoded = Base64.encode(UTF8.encode(key));
      expect(encoded, equals(inputs[key]));
      var decoded = UTF8.decode(Base64.decode(inputs[key]));
      expect(decoded, equals(key));
    }
  });
}
