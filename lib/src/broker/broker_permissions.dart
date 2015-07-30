part of dslink.broker;

class PermissionPair {
  String group;
  int permission;
  PermissionPair(this.group, this.permission);
}


class BrokerNodePermission {
  List<PermissionPair> permissionList;
  Map<String, int> idPermissions;
  int defaultPermission = Permission.NEVER;
  int getPermission (Iterator<String> paths, Responder responder, int permission) {
    // find permission for id;
    if (idPermissions != null && idPermissions.containsKey(responder.reqId)) {
      return idPermissions[responder.reqId];
    }
    // find permission for group
    if (permissionList != null) {
      if (responder.groups.length == 1) {
        // optimize for single group
        String group = responder.groups[0];
        for (var pair in permissionList) {
          if (pair.group == group) {
            return pair.permission;
          }
        }
      } else if (responder.groups.length > 1) {
        var groups = responder.groups;
        for (var pair in permissionList) {
          if (groups.contains(pair.group)) {
            return pair.permission;
          }
        }
      }
    }
    if (defaultPermission != Permission.NEVER) {
      return defaultPermission;
    }
    return permission;
  }

  void loadPermission(List l) {
    if (l != null && l.length > 0) {
      defaultPermission = Permission.NEVER;
      if (permissionList == null) {
        permissionList = new List<PermissionPair>();
      } else {
        permissionList.clear;
      }
      if (idPermissions == null) {
        idPermissions = new Map<String, int>();
      } else {
        idPermissions.clear;
      }
      for (var pair in l) {
        if (pair is List && pair.length == 2 && pair[0] is String && pair[1] is String) {
          String key = pair[0];
          String p = pair[1];
          int pint = Permission.parse(p);
          if (pint == Permission.NEVER) { // invalid permission
            continue;
          }
          if (key == 'default') {
            defaultPermission = pint;
          } else if (key.length < 43 || key.contains(':')) {
            // group permission
            permissionList.add(new PermissionPair(key, pint));
          } else {
            // id
            idPermissions[key] = pint;
          }
        }
      }
      if (permissionList.isEmpty) {
        permissionList = null;
      }
      if (idPermissions.isEmpty) {
        idPermissions = null;
      }
    } else {
      permissionList = null;
      idPermissions = null;
    }
  }
  List serializePermission() {
    if (defaultPermission == Permission.NEVER && idPermissions == null && permissionList == null) {
      return null;
    }
    List rslt = [];
    if (permissionList != null) {
      for (var pair in permissionList) {
        rslt.add([pair.group, Permission.names[pair.permission]]);
      }
    }
    if (idPermissions != null) {
      idPermissions.forEach((String id, int p) {
        rslt.add([id, Permission.names[p]]);
      });
    }
    if (defaultPermission == Permission.NEVER) {
      rslt.add(['default', Permission.names[defaultPermission]]);
    }
    return rslt;
  }
}


class VirtualNodePermission extends BrokerNodePermission {
  Map<String, VirtualNodePermission> children = new Map<String, VirtualNodePermission>();
  int getPermission (Iterator<String> paths, Responder responder, int permission) {
    permission = super.getPermission(paths, responder, permission);
    if (permission == Permission.CONFIG) {
      return Permission.CONFIG;
    }
    if (paths.moveNext()) {
      String name = paths.current;
      if (children.containsKey(name)) {
        return children[name].getPermission(paths, responder, permission);
      }
    }
    return permission;
  }

  void load(Map m) {
    m.forEach((String name, Object value) {
      if (value is Map) {
        children[name] = new VirtualNodePermission() ..load(value);
      }
    });
    if (m['?permissions'] is List) {
      loadPermission(m['?permissions']);
    }
  }

  Map serialize() {
    Map rslt = {};
    children.forEach((String name, VirtualNodePermission val) {
      rslt[name] = val.serialize();
    });
    List permissionData = this.serializePermission();
    if (permissionData != null) {
      rslt['?permissions'] = permissionData;
    }
    return rslt;
  }

}

class BrokerPermissions implements IPermissionManager {
  BrokerNodePermission root;

  BrokerPermissions() {
  }
  int getPermission(String path, Responder resp) {
    if (root != null) {
      return root.getPermission(path.split('/').iterator, resp, Permission.NONE);
    }
    return Permission.CONFIG;
  }
}
