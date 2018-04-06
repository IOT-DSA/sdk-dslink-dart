library dslink.broker_discovery;

import "dart:async";
import "dart:convert";
import "dart:io";

class BrokerDiscoveryClient {
  RawDatagramSocket _socket;

  BrokerDiscoveryClient();

  Future init([bool broadcast = false]) async {
    _socket = await RawDatagramSocket.bind("0.0.0.0", broadcast ? 1900 : 0);

    _socket.multicastHops = 10;
    _socket.broadcastEnabled = true;
    _socket.listen((RawSocketEvent event) {
      if (event == RawSocketEvent.READ) {
        var packet = _socket.receive();
        _socket.writeEventsEnabled = true;

        if (packet == null) {
          return;
        }

        var data = utf8.decode(packet.data);
        _onMessage(packet, data);
      } else if (event == RawSocketEvent.CLOSED) {
        if (!_brokerController.isClosed) {
          _brokerController.close();
        }
      }
    });

    _socket.writeEventsEnabled = true;

    var interfaces = await NetworkInterface.list();
    try {
      for (var interface in interfaces) {
        _socket.joinMulticast(new InternetAddress("239.255.255.230"), interface);
      }
    } catch (e) {
      _socket.joinMulticast(new InternetAddress("239.255.255.230"));
    }
  }

  Stream<String> discover({Duration timeout: const Duration(seconds: 5)}) {
    _send("DISCOVER", "239.255.255.230", 1900);
    Stream<String> stream = _brokerController.stream;
    new Future.delayed(timeout, () {
      close();
    });
    return stream;
  }

  void _send(String content, String address, int port) {
    _socket.send(UTF8.encode(content), new InternetAddress(address), port);
  }

  Stream<BrokerDiscoverRequest> get requests => _discoverController.stream;

  void _onMessage(Datagram packet, String msg) {
    var parts = msg.split(" ");
    var type = parts[0];
    var argument = parts.skip(1).join(" ");

    if (type == "BROKER") {
      _brokerController.add(argument);
    } else if (type == "DISCOVER") {
      _discoverController.add(new BrokerDiscoverRequest(this, packet));
    }
  }

  StreamController<BrokerDiscoverRequest> _discoverController =
      new StreamController.broadcast();
  StreamController<String> _brokerController = new StreamController.broadcast();

  void close() {
    _socket.close();
  }
}

class BrokerDiscoverRequest {
  final BrokerDiscoveryClient client;
  final Datagram packet;

  BrokerDiscoverRequest(this.client, this.packet);

  void reply(String url) {
    client._send("BROKER ${url}", packet.address.address, packet.port);
  }
}
