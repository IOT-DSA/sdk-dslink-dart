/// DSA Broker Implementation
library dslink.broker;

import 'client.dart' show LinkProvider;
import 'responder.dart';
import 'requester.dart';
import 'common.dart';
import 'server.dart';
import 'dart:async';
import 'utils.dart';
import 'dart:io';
import 'dart:convert';
import 'src/http/websocket_conn.dart';

part 'src/broker/broker_node_provider.dart';
part 'src/broker/broker_node.dart';
part 'src/broker/remote_node.dart';
part 'src/broker/remote_root_node.dart';
part 'src/broker/remote_requester.dart';
part 'src/broker/broker_discovery.dart';
part 'src/broker/broker_permissions.dart';
part 'src/broker/broker_alias.dart';
part 'src/broker/user_node.dart';
part 'src/broker/trace_node.dart';

part 'src/http/server_websocket.dart';
part 'src/http/server_link.dart';
part 'src/http/server.dart';

Future<DsHttpServer> startBrokerServer(int port, {bool persist: true}) async {
  var broker = new BrokerNodeProvider();
  broker.shouldSaveFiles = persist;
  var server = new DsHttpServer.start(
      "0.0.0.0",
      httpPort: port,
      linkManager: broker,
      nodeProvider: broker
  );
  await server.onServerReady;
  return server;
}
