part of dslink.utils;

abstract class DsJson {
  static DsJson instance = new DsJsonCodecImpl();

  static String encode(Object val, {bool pretty: false}) {
    return instance.encodeJson(val, pretty: pretty);
  }

  static Object decode(String str) {
    return instance.decodeJson(str);
  }

  String encodeJson(Object val, {bool pretty: false});
  Object decodeJson(String str);
}

class DsJsonCodecImpl implements DsJson {
  JsonDecoder decoder = new JsonDecoder();

  @override
  Object decodeJson(String str) {
    return decoder.convert(str);
  }

  @override
  String encodeJson(Object val, {bool pretty: false}) {
    var encoder = JSON.encoder;
    if (pretty) {
      if (_prettyEncoder == null) {
        _prettyEncoder = encoder = new JsonEncoder.withIndent("  ");
      } else {
        encoder = _prettyEncoder;
      }
    }
    return encoder.convert(val);
  }

  JsonEncoder _prettyEncoder;
}
