import 'dart:io';
import 'package:dslink/server.dart';
import 'package:dslink/broker.dart';
import 'package:dslink/client.dart';

void main(List<String> args) {
  // load certificate
  String certPath = Platform.script.resolve('certs').toFilePath();
  SecureSocket.initialize(database: certPath, password: 'mypassword');

  // start the server
  var broker = new BrokerNodeProvider();
  var server = new DsHttpServer.start(InternetAddress.ANY_IP_V4, httpPort:8080,
      certificateName: "self signed for dart", nodeProvider: broker, linkManager: broker);
  
  if (args.contains('--broker') || args.contains('-b')) {
    new LinkProvider(args, 'broker-', nodeProvider:broker).connect();
  }
}
