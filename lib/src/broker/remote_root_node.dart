part of dslink.broker;


// TODO, implement special configs and attribute merging
class RemoteLinkRootNode extends RemoteLinkNode implements LocalNodeImpl{
  RemoteLinkRootNode(
      String path, String remotePath, RemoteLinkManager linkManager)
      : super(path, remotePath, linkManager);

  bool get loaded => true;

  // TODO does this need parentNode?
  LocalNode parentNode;
  
  ListController createListController(Requester requester) {
   return new RemoteLinkRootListController(this, requester);
  }
  
  int getPermission(Responder responder) {
    PermissionList ps = permissions;
// TODO deal with node mixin
//    if (ps == null && mixins != null) {
//      for (var node in mixins) {
//        if ((node as LocalNode).permissions != null) {
//          ps = (node as LocalNode).permissions;
//          break;
//        }
//      }
//    }
    if (ps != null) {
      return ps.getPermission(responder);
    }
    if (parentNode != null) {
      return parentNode.getPermission(responder);
    }
    // TODO default permission should be NONE
    return Permission.WRITE;
  }
  
  Response setAttribute(
      String name, String value, Responder responder, Response response) {
    if (getPermission(responder) >= Permission.WRITE) {
      if (!attributes.containsKey(name) || attributes[name] != value) {
        attributes[name] = value;
        updateList(name);
      }
      return response..close();
    } else {
      return response..close(DSError.PERMISSION_DENIED);
    }
  }

  Response removeAttribute(
      String name, Responder responder, Response response) {
    if (getPermission(responder) >= Permission.WRITE) {
      if (attributes.containsKey(name)) {
        attributes.remove(name);
        updateList(name);
      }
      return response..close();
    } else {
      return response..close(DSError.PERMISSION_DENIED);
    }
  }

  Response setConfig(
      String name, Object value, Responder responder, Response response) {
    var config = Configs.getConfig(name, profile);
    return response..close(config.setConfig(value, this, responder));
  }

  Response removeConfig(String name, Responder responder, Response response) {
    var config = Configs.getConfig(name, profile);
    return response..close(config.removeConfig(this, responder));
  }
  
  void load(Map m, NodeProviderImpl provider) {
    m.forEach((String name, Object value){
      if (name.startsWith(r'$')) {
         configs[name] = value;
       } else if (name.startsWith('@')) {
         attributes[name] = value;
       } 
    });
  }
  Map serialize(bool withChildren) {
    Map rslt = {};
    configs.forEach((String name, Object val){
      rslt[name] = val;
    });
    attributes.forEach((String name, String val){
      rslt[name] = val;
    });
    return rslt;
  }

  PermissionList permissions;

  void updateList(String name, [int permission = Permission.READ]) {
    listChangeController.add(name);
  }
}

class RemoteLinkRootListController extends ListController {
  RemoteLinkRootListController(RemoteNode node, Requester requester) : super(node, requester);
  
  
  void onUpdate(String streamStatus, List updates, List columns,
       [DSError error]) {
     // TODO implement error handling
     if (updates != null) {
       for (Object update in updates) {
         String name;
         Object value;
         bool removed = false;
         if (update is Map) {
           if (update['name'] is String) {
             name = update['name'];
           } else {
             continue; // invalid response
           }
           if (update['change'] == 'remove') {
             removed = true;
           } else {
             value = update['value'];
           }
         } else if (update is List) {
           if (update.length > 0 && update[0] is String) {
             name = update[0];
             if (update.length > 1) {
               value = update[1];
             }
           } else {
             continue; // invalid response
           }
         } else {
           continue; // invalid response
         }
         if (name.startsWith(r'$')) {
          // ignore
         } else if (name.startsWith('@')) {
          // ignore
         } else {
           changes.add(name);
           if (removed) {
             node.children.remove(name);
           } else if (value is Map) {
             // TODO, also wait for children $is
             node.children[name] =
                 requester.nodeCache.updateRemoteChildNode(node, name, value);
           }
         }
       }
       if (request.streamStatus != StreamStatus.initialize) {
         node.listed = true;
       }
       onDefUpdated();
     }
   }
  
}