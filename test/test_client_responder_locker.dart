import 'package:dslink/http_client.dart';
import 'package:dslink/src/crypto/pk.dart';
import 'package:dslink/responder.dart';

void main() {
  PrivateKey key = new PrivateKey.loadFromString('t5YRKgaZyhXNNberpciIoYzz3S1isttspwc4QQhiaVk BJ403K-ND1Eau8UJA7stsYI2hdgiOKhNVDItwg7sS6MfG2iSRGqM2UodSF0mb8GbD8s2OAukQ03DFLULw72bklo');

  SimpleNodeProvider nodeProvider = new SimpleNodeProvider();

    Map openLocker(String path, Map params) {
      nodeProvider.updateValue('${path}ed', true);
      return {"value":"a"};
    }

    Map openLocker2(String path, Map params) {
      if (params['value'] is bool) {
        nodeProvider.updateValue('${path}ed', params['value']);
      }
      
      return {"value":"a"};
    }
    
    nodeProvider.registerFunction('openLocker', openLocker);
    nodeProvider.registerFunction('changeLocker', openLocker2);
    nodeProvider.init({
      'locker1': {
        r'$is':'locker',
        'open': { // an action to open the door
          r'$invokable': 'read',
          r'$function': 'openLocker'
        },
        'opened': { // the open status value
          r'$type': 'bool',
          '?value': false
        }
      },
      'locker2': {
        r'$is':'locker',
        'open': { // an action to open the door
          r'$invokable': 'read',
          r'$params':[{"name":"value","type":"bool"}],
          r'$function': 'changeLocker'
          
        },
        'opened': { // the open status value
          r'$type': 'bool',
          '?value': false
        }
      }
    });
    
//    // add locker at runtime
//    nodeProvider.addNode('/locker3', {
//        r'$is':'locker',
//        'open': { // an action to open the door
//          r'$invokable': 'read',
//          r'$params':[{"name":"value","type":"bool"}],
//          r'$function': 'openLocker'
//          
//        },
//        'opened': { // the open status value
//          r'$type': 'bool',
//          '?value': false
//        }
//      });
//    
    var link = new HttpClientLink('http://localhost:8080/conn', 'locker-', key, isResponder: true, nodeProvider: nodeProvider)..connect();
}
