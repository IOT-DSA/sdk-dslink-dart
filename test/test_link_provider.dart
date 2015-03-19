import 'package:dslink/client.dart';


main(List<String> args){
  if (args.length == 0) {
    // for debugging
    args = ['-b','localhost:8080/conn'];
  }
  Map defaultNodes = {
    'add': {
      r'$invokable': 'read',
      r'$function': 'addNode',
      r'$lastNum':0
    }
  };
  LinkProvider link;
  
  link = new LinkProvider(args, 'quicklink-', defaultNodes:defaultNodes);
  if (link.link == null) {
    // initialization failed
    return;
  }
  
  var addNode = link.provider.getNode('/add');
  var rootNode = link.provider.getNode('/');
  int lastNum = addNode.configs[r'$lastNum'];
  
  link.registerFunctions({
    'addNode':(String path, Map params){
      addNode.configs[r'$lastNum'] = ++lastNum;
      
      String nodeName = '/node_$lastNum';
      link.provider.addNode(nodeName, {
        'remove': { // an action to delete the node
          r'$invokable': 'read',
          r'$function': 'removeNode'
        }
      });
      link.save(); // save json 
    },
    'removeNode':(String path, Map params){
      List p = path.split('/')..removeLast();
      String parentPath = p.join('/');
      link.provider.removeNode(parentPath);
      link.save();
    }
  });
  
  link.connect();
}