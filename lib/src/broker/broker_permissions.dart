part of dslink.broker;

class BrokerPermissions implements IPermissionManager {
  
  int getPermission(String path, Responder resp) {
    return Permission.CONFIG;
  }
}