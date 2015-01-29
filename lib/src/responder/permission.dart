part of dslink.responder;

class Permission {

  static const List<String> names = const ['none', 'read', 'write', 'config', 'never'];

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
}

class PermissionList {
  Map<String, int> idMatchs = {};
  Map<String, int> groupMatchs = {};
  int defaultPermission = Permission.NONE;
  void updatePermissions(List data){
    idMatchs.clear();
    groupMatchs.clear();
    for (Object obj in data) {
      if (obj is Map) {
        
      }
    }
  }
  int getPermission(Responder responder) {
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
