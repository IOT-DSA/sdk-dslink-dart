part of dslink.responder;

abstract class IPermissionManager {
  int getPermission(String path, Responder resp);
}

class DummyPermissionManager implements IPermissionManager {
  int getPermission(String path, Responder resp) {
    return Permission.CONFIG;
  }
}
