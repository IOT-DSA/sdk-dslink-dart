part of dslink.historian;

historianMain(List<String> args, String name, HistorianAdapter adapter) async {
  _historian = adapter;

  _link = new LinkProvider(
    args,
    "${name}-",
    isRequester: true,
    autoInitialize: false,
    nodes: {
      "addDatabase": {
        r"$name": "Add Database",
        r"$invokable": "write",
        r"$params": <Map<String, dynamic>>[
          {
            "name": "Name",
            "type": "string",
            "placeholder": "HistoryData"
          }
        ]..addAll(adapter.getCreateDatabaseParameters()),
        r"$is": "addDatabase"
      }
    },
    profiles: {
      "createWatchGroup": (String path) => new CreateWatchGroupNode(path),
      "addDatabase": (String path) => new AddDatabaseNode(path),
      "addWatchPath": (String path) => new AddWatchPathNode(path),
      "watchGroup": (String path) => new WatchGroupNode(path),
      "watchPath": (String path) => new WatchPathNode(path),
      "database": (String path) => new DatabaseNode(path),
      "delete": (String path) => new DeleteActionNode.forParent(
        path, _link.provider as MutableNodeProvider, onDelete: () {
        _link.save();
      }),
      "purgePath": (String path) => new PurgePathNode(path),
      "purgeGroup": (String path) => new PurgeGroupNode(path),
      "publishValue": (String path) => new PublishValueAction(path)
    },
    encodePrettyJson: true
  );
  _link.init();
  _link.connect();
}
