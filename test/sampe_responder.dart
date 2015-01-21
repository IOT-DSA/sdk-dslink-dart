library dslink.test.sampleresponder;

import 'package:dslink/responder.dart';
import 'package:dslink/common.dart';
import 'dart:async';

class TestNodeProvider extends NodeProvider {
  TestNode onlyNode = new TestNode('/');
  ResponderNode getNode(String path) {
    return onlyNode;
  }
}

class TestNode extends ResponderNode {
  TestNode(String path) : super(path) {
    new Timer.periodic(const Duration(seconds: 5), updateTime);
    configs[r'$is'] = 'node';
    configs[r'$test'] = 'hello world';
  }

  int count = 0;
  void updateTime(Timer t) {
    valueController.add(new ValueUpdate(count++, (new DateTime.now()).toUtc().toIso8601String()));
  }

  bool get exists => true;

  InvokeResponse invoke(Map params, Responder responder, InvokeResponse response) {
    response.updateStream([[1, 2]], streamStatus: StreamStatus.closed, columns: [{
        'name': 'v1',
        'type': 'number'
      }, {
        'name': 'v2',
        'type': 'number'
      }]);
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


}