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

  DsResponse invoke(Map params, DsResponder responder, int rid) {
    DsResponse resp = new DsResponse(responder, rid);
    responder.addResponse(resp);
    resp.add([[1, 2]], streamStatus: DsStreamStatus.closed, columns: [{
        'name': 'v1',
        'type': 'number'
      }, {
        'name': 'v2',
        'type': 'number'
      }]);
    return resp;
  }

  DsResponse list(DsResponder responder, int rid) {
    // TODO: implement list
  }

  DsResponse removeAttribute(String name, DsResponder responder, int rid) {
    // TODO: implement removeAttribute
  }

  DsResponse removeConfig(String name, DsResponder responder, int rid) {
    // TODO: implement removeConfig
  }

  DsResponse setAttribute(String name, String value, DsResponder responder, int rid) {
    // TODO: implement setAttribute
  }

  DsResponse setConfig(String name, Object value, DsResponder responder, int rid) {
    // TODO: implement setConfig
  }

  DsResponse setValue(Object value, DsResponder responder, int rid) {
    // TODO: implement setValue
  }

  void subscribe(DsSubscribeResponse subscription, DsResponder responder) {
    // TODO: implement subscribe
  }

  void unsubscribe(DsSubscribeResponse subscription, DsResponder responder) {
    // TODO: implement unsubscribe
  }
}
