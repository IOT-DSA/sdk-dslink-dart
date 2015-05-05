part of dslink.broker;

class RemoteRequester extends Requester {
  final RemoteLinkManager _linkManager;

  RemoteRequester(RemoteLinkManager cache)
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
