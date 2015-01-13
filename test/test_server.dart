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

class TestNodeProvider extends DsNodeProvider {
  TestNode onlyNode = new TestNode('/');
  DsRespNode getNode(String path) {
    return onlyNode;
  }
}
class TestNode extends DsRespNode {
  TestNode(String path) : super(path);


  bool get exists => true;

  DsResponse invoke(Map params, DsResponder responder, DsResponse response) {
    responder.updateReponse(response, [[1, 2]], status: DsStreamStatus.closed, columns: [{
        'name': 'v1',
        'type': 'number'
      }, {
        'name': 'v2',
        'type': 'number'
      }]);
    return response;
  }

  DsResponse list(DsResponder responder, DsResponse response) {
    return response;
  }

  DsResponse removeAttribute(String name, DsResponder responder, DsResponse response) {
    return response;
  }

  DsResponse removeConfig(String name, DsResponder responder, DsResponse response) {
    return response;
  }

  DsResponse setAttribute(String name, String value, DsResponder responder, DsResponse response) {
    return response;
  }

  DsResponse setConfig(String name, Object value, DsResponder responder, DsResponse response) {
    return response;
  }

  DsResponse setValue(Object value, DsResponder responder, DsResponse response) {
    return response;
  }

  void subscribe(DsSubscribeResponse subscription, DsResponder responder) {
    // TODO: implement subscribe
  }

  void unsubscribe(DsSubscribeResponse subscription, DsResponder responder) {
    // TODO: implement unsubscribe
  }
}
