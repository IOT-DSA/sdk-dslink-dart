part of dslink.broker;

class RemoteRequester extends Requester implements IRemoteRequester {
  final RemoteLinkManager _linkManager;

  String responderPath;
  
  RemoteRequester(RemoteLinkManager cache, this.responderPath)
      : super(cache),
        _linkManager = cache;

  void onDisconnected() {
    _linkManager.disconnected = ValueUpdate.getTs();
    super.onDisconnected();
  }

  void onReconnected() {
    _linkManager.disconnected = null;
    super.onReconnected();
  }
}
