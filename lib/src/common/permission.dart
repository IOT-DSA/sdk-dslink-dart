part of dslink.common;

class Permission {
  /// now allowed to do anything
  static const int NONE = 0;
  /// read node
  static const int READ = 1;
  /// write attribute and value
  static const int WRITE = 2;
  /// config the node
  static const int CONFIG = 3;
  /// something that can never happen
  static const int NEVER = 4;

  static const List<String> names = const [
    'none',
    'read',
    'write',
    'config',
    'never'
  ];

  static const Map<String, int> nameParser = const {
    'none': NONE,
    'read': READ,
    'write': WRITE,
    'config': CONFIG,
    'never': NEVER
  };
  
  static int parse(Object obj, [int defaultVal = NEVER]) {
    if (obj is String && nameParser.containsKey(obj)) {
      return nameParser[obj];
    }
    return defaultVal;
  }
}

class PermissionList {
  Map<String, int> idMatchs = {};
  Map<String, int> groupMatchs = {};
  int defaultPermission = Permission.NONE;

  void updatePermissions(List data) {
    idMatchs.clear();
    groupMatchs.clear();
    defaultPermission = Permission.NONE;
    for (Object obj in data) {
      if (obj is Map) {
        if (obj['id'] is String) {
          idMatchs[obj['id']] = Permission.nameParser[obj['permission']];
        } else if (obj['group'] is String) {
          if (obj['group'] == 'default') {
            defaultPermission = Permission.nameParser[obj['permission']];
          } else {
            groupMatchs[obj['group']] =
                Permission.nameParser[obj['permission']];
          }
        }
      }
    }
  }

  int getPermission(Responder responder) {
    // TODO Permission temp workaround before user permission is implemented
    return Permission.CONFIG;
    if (idMatchs.containsKey(responder.reqId)) {
      return idMatchs[responder.reqId];
    }

    int rslt = Permission.NEVER;
    for (String group in responder.groups) {
      if (groupMatchs.containsKey(group)) {
        int v = groupMatchs[group];
        if (v < rslt) {
          // choose the lowest permission from all matched group
          rslt = v;
        }
      }
    }

    if (rslt == Permission.NEVER) {
      return defaultPermission;
    }
    return rslt;
  }
}
