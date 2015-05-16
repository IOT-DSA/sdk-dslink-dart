library dslink.test.common.base64;

import "dart:convert";

import "package:test/test.dart";
import "package:dslink/utils.dart" show Base64;

void main() {
  group("Base64", base64Tests);
}

void base64Tests() {
  test("successfully encodes and decodes the bytes of 'Hello World'", () {
    var encoded = Base64.encode(UTF8.encode("Hello World"));
    var decoded = UTF8.decode(Base64.decode(encoded));
    expect(decoded, equals("Hello World"));
  });

  test("successfully encodes and decodes the string 'Hello World'", () {
    var encoded = Base64.encodeString("Hello World");
    var decoded = Base64.decodeString(encoded);
    expect(decoded, equals("Hello World"));
  });
}
