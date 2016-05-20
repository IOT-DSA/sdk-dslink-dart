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

class DSPacketStore {
  final int rid;
  final List<DSNormalPacket> packets;

  DSPacketDeliveryHandler handler;

  DSPacketStore(this.rid) : packets = <DSNormalPacket>[];

  void deliver(DSNormalPacket packet) {
    if (handler != null) {
      handler(this, packet);
    }
  }

  void store(DSNormalPacket packet) {
    packets.add(packet);
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
        store = new DSPacketStore(packet.rid);
        _queue[packet.rid] = store;

        newPacketHandler(store);
      }

      if (mode == DSPacketQueueMode.deliver) {
        store.deliver(packet);
      } else {
        store.deliver(packet);
        store.store(packet);
      }
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

abstract class DSPacket {}

class DSMsgPacket extends DSPacket {
  int ackId;
}

class DSAckPacket extends DSPacket {
  int ackId;
}

class DSNormalPacket extends DSPacket {
  bool isPartial = false;
  bool isClustered = false;
  DSPacketMethod method;
  DSPacketSide side;
  int rid;
  int size;
  int updateId;
  int clusterId;
  int totalSize;
  Uint8List payload;
}

class DSRequestPacket extends DSNormalPacket {
  int qos;
  String path;
}

class DSResponsePacket extends DSNormalPacket {
  int status;
}

class DSProtocolParser {
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

  DSPacket parse(List<int> input) {
    int offset = 0;

    Uint8List data;

    if (input is Uint8List) {
      data = input;
    } else {
      data = new Uint8List.fromList(input);
    }

    var type = data[offset++];

    if (type == 0xFE) { // msg
      var pkt = new DSMsgPacket();
      pkt.ackId = _readUint32(data, offset);
      offset += 4;
      return pkt;
    } else if (type == 0xFF) {
      var pkt = new DSAckPacket();
      pkt.ackId = _readUint32(data, offset);
      offset += 4;
      return pkt;
    }

    var side = (type & 0x80) == 0x80 ?
      DSPacketSide.request :
      DSPacketSide.response;
    var method = type & 0x70;
    var isClustered = (type & 0x08) == 0x08;
    var isPartial = (type & 0x04) == 0x04;
    var specialBits = type & 0x03;

    var rid = _readUint32(data, offset);
    offset += 4;

    int clusterId;
    int totalSize;

    if (isPartial) { // Handle Partials
      totalSize = _readUint32(data, offset);
      offset += 4;
    }

    var updateId = _readUint32(data, offset);
    offset += 4;

    if (isClustered) {
      clusterId = _readUint32(data, offset);
      offset += 4;
    }

    void _populate(DSNormalPacket pkt) {
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
      pkt.payload = data.buffer.asUint8List(offset);
      return pkt;
    } else if (side == DSPacketSide.response) {
      var pkt = new DSResponsePacket();
      _populate(pkt);

      var status = data[offset];
      offset++;

      pkt.status = status;

      if (status > 127) {
        pkt.payload = new Uint8List(0);
        pkt.payload = data.buffer.asUint8List(offset);
      } else {
        pkt.payload = data.buffer.asUint8List(offset);
      }

      return pkt;
    } else {
      var pkt = new DSNormalPacket();
      _populate(pkt);
      return pkt;
    }
  }
}
