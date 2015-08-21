part of dslink.utils;

class BinaryData {
  /// used when only partial data is received
  /// don't merge them before it's finished
  List<ByteData> mergingList;

  ByteData bytes;
  BinaryData(ByteData bytes) {
    this.bytes = bytes;
  }
  BinaryData.fromList(List<int> list) {
    bytes = ByteDataUtil.fromList(list);
  }
}

class BinaryInCache {
  Map<String, BinaryData> caches = new Map<String, BinaryData>();
  ByteData fetchData(String id) {
    BinaryData data = caches[id];
    if (data != null && data.bytes != null) {
      caches.remove(id);
      return data.bytes;
    }
    return null;
  }

  void receiveData(List<int> inputList) {
    Uint8List input;
    if (inputList is Uint8List) {
      input = inputList;
    } else {
      input = new Uint8List.fromList(inputList);
    }
    // TODO error handling
    ByteData bytedata = new ByteData.view(
        input.buffer, input.offsetInBytes, input.lengthInBytes);
    int headerSize = bytedata.getUint32(0);
    int count = headerSize ~/ 9;
    for (int i = 0; i < headerSize; i += 9) {
      int start = bytedata.getUint32(i);
      int end;
      if (i < headerSize - 9) {
        end = bytedata.getUint32(i + 9);
      } else {
        end = input.length;
      }
      ByteData bytes =
          input.buffer.asByteData(start + input.offsetInBytes, end - start);
      String id = bytedata.getUint32(i + 4).toString();
      bool finished = bytedata.getUint8(i + 8) == 0;
      BinaryData data = caches[id];
      if (data == null) {
        // create new binary data
        data = new BinaryData(null);
        if (finished) {
          data.bytes = bytes;
        } else {
          data.mergingList = [bytes];
        }
        caches[id] = data;
      } else {
        // merge partial data
        if (data.mergingList != null) {
          data.mergingList.add(bytes);
        } else {
          // this shouldn't happen!
          data.mergingList = [bytes];
        }
        if (finished) {
          data.bytes = ByteDataUtil.mergeBytes(data.mergingList);
          data.mergingList = null;
        }
      }
    }
  }
}

class BinaryOutCache {
  int id = 0;
  Map<int, BinaryData> caches = new Map<int, BinaryData>();
  bool get hasData {
    return !caches.isEmpty;
  }

  int addBinaryData(ByteData data) {
    int newId = ++id;
    caches[newId] = new BinaryData(data);
    return newId;
  }

  Uint8List export() {
    //TODO send partial data;
    int count = 0;
    int totalLength = 0;
    caches.forEach((int id, BinaryData data) {
      ++count;
      totalLength += data.bytes.lengthInBytes;
    });
    int headpos = 0;
    int datapos = count * 9;
    Uint8List output = new Uint8List(totalLength + datapos);
    ByteData bytedata = new ByteData.view(output.buffer);
    List idToRemove = [];
    caches.forEach((int id, BinaryData data) {
      bytedata.setUint32(headpos, datapos);
      bytedata.setUint32(headpos + 4, id);
//      if (partial) {
//        bytedata.setUint8(headpos + 8, 1);
//      } else {
      idToRemove.add(id);
//      }
      output.setAll(headpos + 9, ByteDataUtil.toUint8List(data.bytes));
      headpos += 9;
      datapos += data.bytes.lengthInBytes;
    });
    for (int id in idToRemove) {
      caches.remove(id);
    }
    return output;
  }
}

abstract class DsJson {
  static DsJson instance = new DsJsonCodecImpl();

  static String encode(Object val, {bool pretty: false}) {
    return instance.encodeJson(val, pretty: pretty);
  }

  static Object decode(String str) {
    return instance.decodeJson(str);
  }

  static String encodeFrame(Object val, BinaryOutCache cache,
      {bool pretty: false}) {
    return instance.encodeJsonFrame(val, cache, pretty: pretty);
  }

  static Object decodeFrame(String str, BinaryInCache cache) {
    return instance.decodeJsonFrame(str, cache);
  }

  String encodeJson(Object val, {bool pretty: false});
  Object decodeJson(String str);

  String encodeJsonFrame(Object val, BinaryOutCache cache,
      {bool pretty: false});
  Object decodeJsonFrame(String str, BinaryInCache cache);
}

class DsJsonCodecImpl implements DsJson {
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
    if (pretty) {
      if (_prettyEncoder == null) {
        _prettyEncoder =
            encoder = new JsonEncoder.withIndent("  ", _safeEncoder);
      } else {
        encoder = _prettyEncoder;
      }
    }
    return encoder.convert(val);
  }

  JsonDecoder _unsafeDecoder;

  Object decodeJsonFrame(String str, BinaryInCache cache) {
    _currentBinaryInCache = cache;

    if (_unsafeDecoder == null) {
      _unsafeDecoder = new JsonDecoder(_reviver);
    }

    var result = _unsafeDecoder.convert(str);
    _currentBinaryInCache = null;
    return result;
  }

  BinaryInCache _currentBinaryInCache;
  BinaryOutCache _currentBinaryOutCache;

  dynamic _reviver(key, value) {
    if (value is String && value.startsWith('\u001Bbytes,')) {
      return _currentBinaryInCache.fetchData(value.substring(7));
    }
    return value;
  }

  dynamic _encoder(value) {
    if (value is ByteData) {
      int id = _currentBinaryOutCache.addBinaryData(value);
      return '\u001Bbytes,$id';
    }
    return null;
  }

  String encodeJsonFrame(Object val, BinaryOutCache cache,
      {bool pretty: false}) {

    _currentBinaryOutCache = cache;

    JsonEncoder c;

    if (pretty) {
      if (_unsafePrettyEncoder == null) {
        _unsafePrettyEncoder = new JsonEncoder.withIndent('  ', _encoder);
      }
      c = _unsafePrettyEncoder;
    } else {
      if (_unsafeEncoder == null) {
        _unsafeEncoder = new JsonEncoder(_encoder);
      }
      c = _unsafeEncoder;
    }

    var result = c.convert(val);
    _currentBinaryOutCache = null;
    return result;
  }

  JsonEncoder _unsafeEncoder;
  JsonEncoder _unsafePrettyEncoder;
}
