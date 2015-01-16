import 'dart:io';
import 'package:dslink/http_server.dart';
import 'package:dslink/responder.dart';
import 'package:dslink/common.dart';
void main() {
  // load certificate
  String certPath = Platform.script.resolve('certs').toFilePath();
  SecureSocket.initialize(database: certPath, password: 'mypassword');
  // start the server
  new DsHttpServer.start(InternetAddress.ANY_IP_V4, //
  certificateName: "self signed for dart", //
  nodeProvider: new TestNodeProvider());
}

class TestNodeProvider extends NodeProvider {
  TestNode onlyNode = new TestNode('/');
  ResponderNode getNode(String path) {
    return onlyNode;
  }
}
class TestNode extends ResponderNode {
  TestNode(String path) : super(path);


  bool get exists => true;

  Response invoke(Map params, Responder responder, Response response) {
    responder.updateReponse(response, [[1, 2]], status: StreamStatus.closed, columns: [{
        'name': 'v1',
        'type': 'number'
      }, {
        'name': 'v2',
        'type': 'number'
      }]);
    return response;
  }

  Response list(Responder responder, Response response) {
    return response;
  }

  Response removeAttribute(String name, Responder responder, Response response) {
    return response;
  }

  Response removeConfig(String name, Responder responder, Response response) {
    return response;
  }

  Response setAttribute(String name, String value, Responder responder, Response response) {
    return response;
  }

  Response setConfig(String name, Object value, Responder responder, Response response) {
    return response;
  }

  Response setValue(Object value, Responder responder, Response response) {
    return response;
  }

  void subscribe(SubscribeResponse subscription, Responder responder) {
    // TODO: implement subscribe
  }

  void unsubscribe(SubscribeResponse subscription, Responder responder) {
    // TODO: implement unsubscribe
  }
}
