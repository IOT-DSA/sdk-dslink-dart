part of dslink.common;

typedef DSNewPacketHandler(DSPacketStore store);
typedef DSPacketDeliveryHandler(DSPacketStore store, DSNormalPacket packet);
typedef DSAckPacketHandler(DSAckPacket packet);
typedef DSMsgPacketHandler(DSMsgPacket packet);

class DSPacketQueueMode {
  static const DSPacketQueueMode store = const DSPacketQueueMode("store");
  static const DSPacketQueueMode deliver = const DSPacketQueueMode("deliver");

  final String name;

  const DSPacketQueueMode(this.name);
}

class BinaryDataUtils {
  static List<Uint8List> splitDataChunks(Uint8List data, int chunkSize) {
    var startOffset = data.offsetInBytes;
    var d = data.lengthInBytes / chunkSize;
    var chunkCount = d.ceil();
    var lastBytes = ((d - d.floor()) * chunkSize).toInt();
    var out = new List<Uint8List>(chunkCount);

    var off = startOffset;
    for (var i = 1; i <= chunkCount; i++) {
      if (i == chunkCount) {
        out[i - 1] = data.buffer.asUint8List(off, lastBytes);
      } else {
        out[i - 1] = data.buffer.asUint8List(off, chunkSize);
        off += chunkSize;
      }
    }

    return out;
  }

  static Uint8List combineDataChunks(List<Uint8List> chunks) {
    var writer = new DSPacketWriter(bufferSize: DSNormalPacket.payloadChunkSize);
    for (Uint8List list in chunks) {
      writer.writeUint8List(list);
    }
    return writer.done();
  }
}

class DSPacketStore {
  final DSPacketQueue queue;
  final int rid;
  final List<DSNormalPacket> packets;

  DSPacketDeliveryHandler handler;

  DSPacketStore(this.queue, this.rid) : packets = <DSNormalPacket>[];

  bool _isComplete = false;
  bool get isComplete => _isComplete;

  void deliver(DSNormalPacket packet) {
    if (handler != null) {
      handler(this, packet);
    }
  }

  void store(DSNormalPacket packet) {
    packets.add(packet);

    if (!packet.isPartial) {
      _isComplete = true;
    }
  }

  Uint8List readAllPayload() {
    if (packets.length == 1) {
      return packets[0].payloadData;
    }

    var payloads = <Uint8List>[];
    for (DSNormalPacket pkt in packets) {
      if (pkt.payloadData != null) {
        payloads.add(pkt.payloadData);
      }
    }

    var full = BinaryDataUtils.combineDataChunks(payloads);

    if (full.lengthInBytes == 0) {
      return null;
    }

    return full;
  }

  DSNormalPacket formNewPacket() {
    if (packets.length == 1) {
      return packets[0];
    }

    var pkt = packets[0].clone();
    pkt.payloadData = readAllPayload();
    pkt.isPartial = false;
    return pkt;
  }

  void drop() {
    queue._queue.remove(rid);
  }
}

class DSPacketQueue {
  final DSNewPacketHandler newPacketHandler;
  final DSAckPacketHandler ackPacketHandler;
  final DSMsgPacketHandler msgPacketHandler;
  final DSPacketQueueMode mode;
  final Map<int, DSPacketStore> _queue = <int ,DSPacketStore>{};

  DSPacketQueue(
    this.mode,
    this.newPacketHandler,
    this.ackPacketHandler,
    this.msgPacketHandler);

  void handle(DSPacket packet) {
    if (packet is DSNormalPacket) {
      DSPacketStore store = _queue[packet.rid];
      if (store == null) {
        store = new DSPacketStore(this, packet.rid);
        _queue[packet.rid] = store;

        newPacketHandler(store);
      }

      if (mode == DSPacketQueueMode.deliver) {
        store.deliver(packet);
      } else {
        store.store(packet);
        store.deliver(packet);
      }
    } else if (packet is DSMsgPacket && msgPacketHandler != null) {
      msgPacketHandler(packet);
    } else if (packet is DSAckPacket && ackPacketHandler != null) {
      ackPacketHandler(packet);
    }
  }

  void handleAll(Iterable<DSPacket> pkts) {
    for (DSPacket pkt in pkts) {
      handle(pkt);
    }
  }
}

class DSPacketSide {
  static const DSPacketSide request = const DSPacketSide("request");
  static const DSPacketSide response = const DSPacketSide("response");

  final String name;

  const DSPacketSide(this.name);
}

class DSPacketMethod {
  final String name;
  final int id;

  static const DSPacketMethod subscribe = const DSPacketMethod(
    "subscribe",
    0
  );

  static const DSPacketMethod list = const DSPacketMethod(
    "list",
    1
  );

  static const DSPacketMethod invoke = const DSPacketMethod(
    "invoke",
    2
  );

  static const DSPacketMethod set = const DSPacketMethod(
    "set",
    3
  );

  static const DSPacketMethod remove = const DSPacketMethod(
    "remove",
    4
  );

  static const DSPacketMethod close = const DSPacketMethod(
    "close",
    6
  );

  static const DSPacketMethod special = const DSPacketMethod(
    "special",
    7
  );

  const DSPacketMethod(this.name, this.id);

  static DSPacketMethod decode(int id) {
    if (id == 0) {
      return subscribe;
    } else if (id == 1) {
      return list;
    } else if (id == 2) {
      return invoke;
    } else if (id == 3) {
      return set;
    } else if (id == 4) {
      return remove;
    } else if (id == 6) {
      return close;
    } else if (id == 7) {
      return special;
    }

    return null;
  }
}

class DSPacketResponseMode {
  final String name;
  final int id;

  static const DSPacketResponseMode initialize = const DSPacketResponseMode(
    "initialize",
    0
  );

  static const DSPacketResponseMode open = const DSPacketResponseMode(
    "open",
    1
  );

  static const DSPacketResponseMode closed = const DSPacketResponseMode(
    "closed",
    3
  );

  const DSPacketResponseMode(this.name, this.id);

  static DSPacketResponseMode decode(int id) {
    if (id == 0) {
      return DSPacketResponseMode.initialize;
    } else if (id == 1) {
      return DSPacketResponseMode.open;
    } else if (id == 3) {
      return DSPacketResponseMode.closed;
    }
    return null;
  }

  static DSPacketResponseMode encode(String streamStatus) {
    if (streamStatus == "initialize") {
      return DSPacketResponseMode.initialize;
    } else if (streamStatus == "open") {
      return DSPacketResponseMode.open;
    } else if (streamStatus == "closed") {
      return DSPacketResponseMode.closed;
    }
    return null;
  }
}

abstract class DSPacket {
  void writeTo(DSPacketWriter writer);

  Uint8List write([DSPacketWriter writer]) {
    if (writer == null) {
      writer = new DSPacketWriter();
    }

    writeTo(writer);

    return writer.done();
  }
}

class DSAckPacket extends DSPacket {
  int ackId;

  @override
  void writeTo(DSPacketWriter writer) {
    writer.writeUint8(0xFE);
    writer.writeUint32(ackId);
  }

  @override
  String toString() => "Ack(${ackId})";
}

class DSMsgPacket extends DSPacket {
  int ackId;

  @override
  void writeTo(DSPacketWriter writer) {
    writer.writeUint8(0xFF);
    writer.writeUint32(ackId);
  }

  @override
  String toString() => "Msg(${ackId})";
}

int _write3BitNumber(int input, int start, int number) {
  var bitFlagA = 1 << start;
  var bitFlagB = 1 << start - 1;
  var bitFlagC = 1 << start - 2;

  var out = input;

  if ((number & (1 << 0)) != 0) {
    out |= bitFlagA;
  }

  if ((number & (1 << 1)) != 0) {
    out |= bitFlagB;
  }

  if ((number & (1 << 2)) != 0) {
    out |= bitFlagC;
  }

  return out;
}

int _write2BitNumber(int input, int start, int number) {
  var bitFlagA = 1 << start;
  var bitFlagB = 1 << start - 1;

  var out = input;

  if ((number & (1 << 0)) != 0) {
    out |= bitFlagA;
  }

  if ((number & (1 << 1)) != 0) {
    out |= bitFlagB;
  }

  return out;
}

class DSNormalPacket extends DSPacket {
  static const int payloadChunkSize =
    const int.fromEnvironment(
      "dsa.packet.payload.chunkSize",
      defaultValue: 10240
    );

  bool isPartial = false;
  bool isClustered = false;
  DSPacketMethod method;
  DSPacketSide side;
  int rid;
  int updateId = 0;
  int clusterId;
  int totalSize;
  Uint8List payloadData;

  @override
  void writeTo(DSPacketWriter writer) {
    if (payloadData == null && _decodedPayload != null) {
      payloadData = pack(_decodedPayload);
    }

    var type = 0;

    if (side == DSPacketSide.response) {
      type |= 0x80;
    }

    type = _write3BitNumber(type, 6, method.id);

    if (isClustered) {
      type |= (1 << 3);
    }

    if (isPartial) {
      type |= (1 << 2);
    }

    type = handleTypeByte(type);

    writer.writeUint8(type);
    writer.writeUint32(rid);

    if (totalSize == null) {
      totalSize = 13;

      if (isClustered) {
        totalSize += 4;
      }

      if (payloadData != null) {
        totalSize += payloadData.lengthInBytes;
      }

      totalSize += calculateAddedSize();
    }

    writer.writeUint32(totalSize);

    writer.writeUint32(updateId);
    if (isClustered) {
      writer.writeUint32(clusterId);
    }
  }

  int handleTypeByte(int input) {
    return input;
  }

  int calculateAddedSize() {
    return 0;
  }

  dynamic readPayloadPackage() {
    if (_decodedPayload != null) {
      return _decodedPayload;
    }

    if (payloadData == null) {
      return null;
    }

    if (isPartial) {
      return "[Partial Data of ${payloadData.lengthInBytes} bytes]";
    }

    if (payloadData.lengthInBytes == 0) {
      return null;
    }

    return _decodedPayload = unpack(payloadData);
  }

  dynamic _decodedPayload;

  List<String> describe() {
    var pl = readPayloadPackage();

    if (pl == null) {
      pl = "none";
    }

    return [
      "Side: ${side.name}",
      "Method: ${method.name}",
      "RID: ${rid}",
      "Payload: ${pl}"
    ];
  }

  @override
  String toString() {
    return "(" + describe().join(", ") + ")";
  }

  void setPayload(input) {
    payloadData = pack(input);
    _decodedPayload = input;
  }

  bool isLargePayload() {
    if (payloadData == null || payloadData.lengthInBytes <= payloadChunkSize) {
      return false;
    }
    return true;
  }

  List<DSNormalPacket> split() {
    if (!isLargePayload()) {
      return <DSNormalPacket>[this];
    }

    var payloads = BinaryDataUtils.splitDataChunks(
      payloadData,
      payloadChunkSize
    );

    var out = <DSNormalPacket>[];

    var len = payloads.length;
    for (var i = 0; i < len; i++) {
      var data = payloads[i];
      var pkt = clone();
      pkt.payloadData = data;
      pkt.isPartial = true;
      out.add(pkt);
    }

    if (out.isNotEmpty) {
      out.last.isPartial = false;
    }

    return out;
  }

  void copyTo(DSNormalPacket pkt) {
    pkt
      ..payloadData = payloadData
      ..isPartial = isPartial
      ..isClustered = isClustered
      ..method = method
      ..totalSize = totalSize
      ..side = side
      ..clusterId = clusterId
      ..updateId = updateId
      .._decodedPayload = _decodedPayload
      ..rid = rid;
  }

  DSNormalPacket clone() {
    var pkt = new DSNormalPacket();
    copyTo(pkt);
    return pkt;
  }
}

class DSRequestPacket extends DSNormalPacket {
  int qos = 0;
  String path;

  DSRequestPacket() {
    side = DSPacketSide.request;
  }

  @override
  int handleTypeByte(int input) {
    input = _write2BitNumber(input, 1, qos);
    return input;
  }

  @override
  void writeTo(DSPacketWriter writer) {
    super.writeTo(writer);

    var pathLength = path == null ? 0 : path.length;

    writer.writeUint16(pathLength);
    if (path != null) {
      writer.writeString(path);
    }

    if (payloadData != null) {
      writer.writeUint8List(payloadData);
    }
  }

  @override
  int calculateAddedSize() {
    var total = 2;
    if (path != null) {
      total += path.length;
    }
    return total;
  }

  DSResponsePacket buildResponse() {
    var pkt = new DSResponsePacket();
    pkt.rid = rid;
    pkt.clusterId = clusterId;
    pkt.isClustered = isClustered;
    pkt.method = method;
    return pkt;
  }

  @override
  List<String> describe() {
    var list = super.describe();
    list.add("Path: ${path}");
    list.add("QOS: ${qos}");
    return list;
  }

  @override
  DSRequestPacket clone() {
    var pkt = new DSRequestPacket();
    copyTo(pkt);
    return pkt;
  }

  @override
  void copyTo(DSRequestPacket pkt) {
    super.copyTo(pkt);
    pkt
      ..path = path
      ..qos = qos;
  }
}

class DSResponsePacket extends DSNormalPacket {
  int status = 0;
  DSPacketResponseMode mode = DSPacketResponseMode.initialize;

  DSResponsePacket() {
    side = DSPacketSide.response;
  }

  @override
  int handleTypeByte(int input) {
    input = _write2BitNumber(input, 1, mode.id);
    return input;
  }

  @override
  void writeTo(DSPacketWriter writer) {
    super.writeTo(writer);

    writer.writeUint8(status);

    if (payloadData != null && status <= 127) {
      writer.writeUint8List(payloadData);
    }
  }

  @override
  int calculateAddedSize() {
    return 1;
  }

  @override
  List<String> describe() {
    var list = super.describe();
    list.add("Mode: ${mode.name}");
    list.add("Status: ${status}");
    return list;
  }

  @override
  DSResponsePacket clone() {
    var pkt = new DSResponsePacket();
    copyTo(pkt);
    return pkt;
  }

  @override
  void copyTo(DSResponsePacket pkt) {
    super.copyTo(pkt);
    pkt
      ..mode = mode
      ..status = status;
  }
}

class DSPacketWriter implements PackBuffer {
  static const int defaultBufferSize = const int.fromEnvironment(
    "dsa.protocol.writer.defaultBufferSize",
    defaultValue: 2048
  );

  final int bufferSize;

  List<Uint8List> _buffers = <Uint8List>[];
  Uint8List _buffer;
  int _len = 0;
  int _offset = 0;
  int _totalLength = 0;

  int get currentLength => _totalLength;

  DSPacketWriter({this.bufferSize: defaultBufferSize});

  void _checkBuffer() {
    if (_buffer == null) {
      _buffer = new Uint8List(bufferSize);
    }
  }

  void writeUint8(int byte) {
    if (_buffer == null) {
      _buffer = new Uint8List(bufferSize);
    }

    if (_buffer.lengthInBytes == _len) {
      _buffers.add(_buffer);
      _buffer = new Uint8List(bufferSize);
      _len = 0;
      _offset = 0;
    }

    _buffer[_offset] = byte;
    _offset++;
    _len++;
    _totalLength++;
  }

  void writeUint16(int value) {
    _checkBuffer();

    if ((_buffer.lengthInBytes - _len) < 2) {
      writeUint8((value >> 8) & 0xff);
      writeUint8(value & 0xff);
    } else {
      _buffer[_offset++] = (value >> 8) & 0xff;
      _buffer[_offset++] = value & 0xff;
      _len += 2;
      _totalLength += 2;
    }
  }

  void writeUint32(int value) {
    _checkBuffer();

    if ((_buffer.lengthInBytes - _len) < 4) {
      writeUint8((value >> 24) & 0xff);
      writeUint8((value >> 16) & 0xff);
      writeUint8((value >> 8) & 0xff);
      writeUint8(value & 0xff);
    } else {
      _buffer[_offset++] = (value >> 24) & 0xff;
      _buffer[_offset++] = (value >> 16) & 0xff;
      _buffer[_offset++] = (value >> 8) & 0xff;
      _buffer[_offset++] = value & 0xff;
      _len += 4;
      _totalLength += 4;
    }
  }

  void writeString(String input) {
    Uint8List data;

    var encoded = const Utf8Encoder().convert(input);
    if (encoded is Uint8List) {
      data = encoded;
    } else {
      data = new Uint8List.fromList(encoded);
    }

    writeUint8List(data);
  }

  void writeUint8List(Uint8List data) {
    _checkBuffer();

    var dataSize = data.lengthInBytes;

    var bufferSpace = _buffer.lengthInBytes - _len;

    if (bufferSpace < dataSize) {
      int i;
      for (i = 0; i < bufferSpace; i++) {
        _buffer[_offset++] = data[i];
      }

      _len += bufferSpace;
      _totalLength += bufferSpace;

      while(i < dataSize) {
        writeUint8(data[i++]);
      }
    } else {
      for (var i = 0; i < dataSize; i++) {
        _buffer[_offset++] = data[i];
      }

      _len += dataSize;
      _totalLength += dataSize;
    }
  }

  Uint8List read() {
    var out = new Uint8List(_totalLength);
    var off = 0;

    var bufferCount = _buffers.length;
    for (var i = 0; i < bufferCount; i++) {
      Uint8List buff = _buffers[i];

      for (var x = 0; x < buff.lengthInBytes; x++) {
        out[off] = buff[x];
        off++;
      }
    }

    if (_buffer != null) {
      for (var i = 0; i < _len; i++) {
        out[off] = _buffer[i];
        off++;
      }
    }

    return out;
  }

  Uint8List done() {
    Uint8List out = read();
    _buffers.length = 0;
    _len = 0;
    _totalLength = 0;
    _offset = 0;
    return out;
  }
}

class DSPacketReader {
  int _readUint32(Uint8List data, int offset) {
    var num = 0;
    for (var i = 0; i < 4; i++) {
      num = (num << 8) | data[offset + i];
    }
    return num;
  }

  int _readUint16(Uint8List data, int offset) {
    var num = 0;
    for (var i = 0; i < 2; i++) {
      num = (num << 8) | data[offset + i];
    }
    return num;
  }

  String _readString(Uint8List data, int offset, int length) {
    return const Utf8Decoder().convert(data, offset, offset + length);
  }

  String _readNullTerminatedString(Uint8List data, int offset) {
    var bytes = <int>[];
    var offsetB = 0;

    while (true) {
      var b = data[offset + offsetB];
      if (b == 0) {
        break;
      } else {
        bytes.add(b);
      }
      offsetB++;
    }

    offset += offsetB;

    return const Utf8Decoder().convert(bytes);
  }

  int _read2BitNumber(int input, int start) {
    var bitFlagA = 1 << start;
    var bitFlagB = 1 << start - 1;

    var number = 0;

    if ((input & bitFlagA) == bitFlagA) {
      number += 1;
    }

    if ((input & bitFlagB) == bitFlagB) {
      number += 2;
    }

    return number;
  }

  int _read3BitNumber(int input, int start) {
    var bitFlagA = 1 << start;
    var bitFlagB = 1 << start - 1;
    var bitFlagC = 1 << start - 2;

    var number = 0;
    if ((input & bitFlagA) == bitFlagA) {
      number += 1;
    }

    if ((input & bitFlagB) == bitFlagB) {
      number += 2;
    }

    if ((input & bitFlagC) == bitFlagC) {
      number += 4;
    }

    return number;
  }

  List<DSPacket> read(List<int> input, [List<DSPacket> outs, int realOffset = 0]) {
    int offset = 0;
    int totalSize = 0;

    Uint8List data;

    if (input is Uint8List) {
      data = input;
    } else {
      data = new Uint8List.fromList(input);
    }

    if (outs == null) {
      outs = <DSPacket>[];
    }

    var type = data[offset++];

    if (type == 0xFF) { // msg
      var pkt = new DSMsgPacket();
      pkt.ackId = _readUint32(data, offset);
      offset += 4;
      outs.add(pkt);
      totalSize = 5;
    } else if (type == 0xFE) { // ack
      var pkt = new DSAckPacket();
      pkt.ackId = _readUint32(data, offset);
      offset += 4;
      totalSize = 5;
      outs.add(pkt);
    } else {
      var side = (type & (1 << 7)) != 0 ?
        DSPacketSide.response :
        DSPacketSide.request;

      var method = _read3BitNumber(type, 6);

      var isClustered = (type & (1 << 3)) != 0;
      var isPartial = (type & (1 << 2)) != 0;
      var specialBits = _read2BitNumber(type, 1);

      var rid = _readUint32(data, offset);
      offset += 4;

      int clusterId;
      int updateId;

      totalSize = _readUint32(data, offset);
      offset += 4;

      updateId = _readUint32(data, offset);
      offset += 4;

      if (isClustered) {
        clusterId = _readUint32(data, offset);
        offset += 4;
      }

      void _populate(DSNormalPacket pkt) {
        pkt.side = side;
        pkt.rid = rid;
        pkt.clusterId = clusterId;
        pkt.isClustered = isClustered;
        pkt.isPartial = isPartial;
        pkt.totalSize = totalSize;
        pkt.updateId = updateId;
        pkt.method = DSPacketMethod.decode(method);
      }

      if (side == DSPacketSide.request) {
        var pkt = new DSRequestPacket();
        _populate(pkt);

        var pathLength = _readUint16(data, offset);
        offset += 2;

        String path;

        if (pathLength == 0xFFFF) {
          path = _readNullTerminatedString(data, offset);
          offset += path.codeUnits.length + 1;
        } else {
          path = _readString(data, offset, pathLength);
          offset += pathLength;
        }

        pkt.path = path;
        pkt.qos = specialBits;
        pkt.totalSize = totalSize;

        var payloadSize = totalSize - offset;

        if (payloadSize > 0) {
          pkt.payloadData = data.buffer.asUint8List(realOffset + offset, payloadSize);
        }

        outs.add(pkt);
      } else if (side == DSPacketSide.response) {
        var pkt = new DSResponsePacket();
        _populate(pkt);
        pkt.mode = DSPacketResponseMode.decode(specialBits);

        var status = data[offset];
        offset++;

        pkt.status = status;

        var payloadSize = totalSize - offset;

        if (status > 127) {
          pkt.payloadData = new Uint8List(0);
        } else {
          pkt.payloadData = data.buffer.asUint8List(realOffset + offset, payloadSize);
        }

        outs.add(pkt);
      } else {
        throw "Fail.";
        var pkt = new DSNormalPacket();
        _populate(pkt);
        outs.add(pkt);
      }
    }

    var payloadSize = totalSize - offset;

    if (data.lengthInBytes > offset + payloadSize) {
      var remainingSize = data.lengthInBytes - (offset + payloadSize);
      var remain = data.buffer.asUint8List(
        realOffset + offset + payloadSize,
        remainingSize
      );
      read(remain, outs, offset + realOffset + payloadSize);
    }

    return outs;
  }
}
