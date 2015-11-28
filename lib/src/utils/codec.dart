part of dslink.utils;

class BinaryData {
  /// used when only partial data is received
  /// don"t merge them before it's finished
  List<ByteData> mergingList;

  ByteData bytes;

  BinaryData(ByteData bytes) {
    this.bytes = bytes;
  }

  BinaryData.fromList(List<int> list) {
    bytes = ByteDataUtil.fromList(list);
  }
}

abstract class DsCodec {
  static final Map<String, DsCodec> _codecs = {
    "json": DsJson.instance,
    "msgpack": DsMsgPackCodecImpl.instance
  };

  static final DsCodec defaultCodec = DsJson.instance as DsCodec;

  static void register(String name, DsCodec codec) {
    if (name != null && codec != null) {
      _codecs[name] = codec;
    }
  }

  static DsCodec getCodec(String name) {
    DsCodec rslt = _codecs[name];
    if (rslt == null) {
      return defaultCodec;
    }
    return rslt;
  }

  Object _blankData;

  Object get blankData {
    if (_blankData == null) {
      _blankData = encodeFrame({});
    }
    return _blankData;
  }

  /// output String or List<int>
  Object encodeFrame(Map val);

  /// input can be String or List<int>
  Map decodeStringFrame(String input);

  Map decodeBinaryFrame(List<int> input);
}

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

class DsJsonCodecImpl extends DsCodec implements DsJson {
  static dynamic _safeEncoder(value) {
    return null;
  }

  JsonEncoder encoder = new JsonEncoder(_safeEncoder);

  JsonDecoder decoder = new JsonDecoder();
  JsonEncoder _prettyEncoder;

  Object decodeJson(String str) {
    return decoder.convert(str);
  }

  String encodeJson(Object val, {bool pretty: false}) {
    JsonEncoder e = encoder;
    if (pretty) {
      if (_prettyEncoder == null) {
        _prettyEncoder =
            encoder = new JsonEncoder.withIndent("  ", _safeEncoder);
      }
      e = _prettyEncoder;
    }
    return e.convert(val);
  }

  JsonDecoder _unsafeDecoder;

  Map decodeBinaryFrame(List<int> bytes) {
    return decodeStringFrame(const Utf8Decoder().convert(bytes));
  }

  Map decodeStringFrame(String str) {
    if (_reviver == null) {
      _reviver = (key, value) {
        if (value is String && value.startsWith("\u001Bbytes:")) {
          try {
            return ByteDataUtil.fromUint8List(
                Base64.decode(value.substring(7)));
          } catch (err) {
            return null;
          }
        }
        return value;
      };
    }

    if (_unsafeDecoder == null) {
      _unsafeDecoder = new JsonDecoder(_reviver);
    }

    var result = _unsafeDecoder.convert(str);
    return result;
  }

  Function _reviver;
  Function _encoder;

  Object encodeFrame(Object val) {
    if (_encoder == null) {
      _encoder = (value) {
        if (value is ByteData) {
          return "\u001Bbytes:${Base64.encode(
              ByteDataUtil.toUint8List(value))}";
        }
        return null;
      };
    }

    JsonEncoder c;

    if (_unsafeEncoder == null) {
      _unsafeEncoder = new JsonEncoder(_encoder);
    }
    c = _unsafeEncoder;

    var result = c.convert(val);
    return result;
  }

  JsonEncoder _unsafeEncoder;
}

class DsMsgPackCodecImpl extends DsCodec {
  static DsMsgPackCodecImpl instance = new DsMsgPackCodecImpl();

  Map decodeBinaryFrame(List<int> input) {
    Uint8List data = ByteDataUtil.list2Uint8List(input);
    if (_unpacker == null) {
      _unpacker = new Unpacker(data.buffer, data.offsetInBytes);
    } else {
      _unpacker.reset(data.buffer);
      _unpacker.offset = data.offsetInBytes;
    }
    Object rslt = _unpacker.unpack();
    if (rslt is Map) {
      return rslt;
    }
    _unpacker.data = null;
    return {};
  }

  Unpacker _unpacker;

  Map decodeStringFrame(String input) {
    // not supported
    return {};
  }

  Object encodeFrame(Map val) {
    return pack(val);
  }
}
