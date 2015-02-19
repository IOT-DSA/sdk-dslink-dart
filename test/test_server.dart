import 'dart:io';
import 'package:dslink/http_server.dart';
import 'package:dslink/broker.dart';

void main() {
  // load certificate
  String certPath = Platform.script.resolve('certs').toFilePath();
  SecureSocket.initialize(database: certPath, password: 'mypassword');

  // start the server
  var broker = new BrokerNodeProvider();
  var server = new DsHttpServer.start(InternetAddress.ANY_IP_V4,
      certificateName: "self signed for dart", nodeProvider: broker, linkManager: broker);
}
