import 'dart:io';
import 'package:dslink/ds_http_server.dart';

void main() {
  // load certificate
  String certPath = Platform.script.resolve('certs').toFilePath();
  SecureSocket.initialize(database: certPath, password: 'mypassword');
  // start the server
  new DsHttpServer.start(InternetAddress.ANY_IP_V4, certificateName: "self signed for dart");
}
