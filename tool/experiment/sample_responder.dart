library dslink.test.sampleresponder;

import 'package:dslink/responder.dart';
import 'package:dslink/common.dart';
import 'dart:async';

class TestNodeProvider extends NodeProvider {
  TestNode onlyNode = new TestNode('/');

  LocalNode getNode(String path) {
    return onlyNode;
  }
}

class TestNode extends LocalNodeImpl {
  TestNode(String path) : super(path) {
    new Timer.periodic(const Duration(seconds: 5), updateTime);
    configs[r'$is'] = 'node';
    configs[r'$test'] = 'hello world';
    this.permissions = new PermissionList()..updatePermissions([{
            'group': 'default',
            'permission': 'write'
          }]);
  }

  int count = 0;

  void updateTime(Timer t) {
    updateValue(count++);
  }

  bool get exists => true;

  @override
  InvokeResponse invoke(Map params, Responder responder, InvokeResponse response, [int maxPermission]) {
    response.updateStream([[1, 2]], streamStatus: StreamStatus.closed, columns: [{
        'name': 'v1',
        'type': 'number'
      }, {
        'name': 'v2',
        'type': 'number'
      }]);
    return response;
  }
}
