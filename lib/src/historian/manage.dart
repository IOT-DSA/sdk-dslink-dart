part of dslink.historian;

class CreateWatchGroupNode extends SimpleNode {
  CreateWatchGroupNode(String path) : super(path, _link.provider);

  @override
  onInvoke(Map<String, dynamic> params) async {
    String name = params["Name"];
    String realName = NodeNamer.createName(name);

    var p = new Path(path);

    _link.addNode("${p.parentPath}/${realName}", {
      r"$is": "watchGroup",
      r"$name": name
    });
    _link.save();
  }
}

class AddDatabaseNode extends SimpleNode {
  AddDatabaseNode(String path) : super(path, _link.provider);

  @override
  onInvoke(Map<String, dynamic> params) async {
    String name = params["Name"];
    String realName = NodeNamer.createName(name);

    _link.addNode("/${realName}", {
      r"$is": "database",
      r"$name": name,
      r"$$db_config": params
    });
    _link.save();
  }
}

class AddWatchPathNode extends SimpleNode {
  AddWatchPathNode(String path) : super(path);

  @override
  onInvoke(Map<String, dynamic> params) async {
    String wp = params["Path"];
    String rp = NodeNamer.createName(wp);
    var p = new Path(path);
    var targetPath = "${p.parentPath}/${rp}";
    var node = await _link.requester.getRemoteNode(wp);
    _link.addNode(targetPath, {
      r"$name": wp,
      r"$path": wp,
      r"$is": "watchPath",
      r"$type": node.configs[r"$type"]
    });

    _link.save();
  }
}

class PurgePathNode extends SimpleNode {
  PurgePathNode(String path) : super(path);

  @override
  onInvoke(Map<String, dynamic> params) async {
    TimeRange tr = parseTimeRange(params["timeRange"]);
    if (tr == null) {
      return;
    }

    WatchPathNode watchPathNode = _link[new Path(path).parentPath];
    await watchPathNode.group.db.database.purgePath(
      watchPathNode.group._watchName,
      watchPathNode.valuePath,
      tr
    );
  }
}

class PurgeGroupNode extends SimpleNode {
  PurgeGroupNode(String path) : super(path);

  @override
  onInvoke(Map<String, dynamic> params) async {
    TimeRange tr = parseTimeRange(params["timeRange"]);
    if (tr == null) {
      return;
    }

    WatchGroupNode watchGroupNode = _link[new Path(path).parentPath];
    await watchGroupNode.db.database.purgeGroup(
      watchGroupNode._watchName,
      tr
    );
  }
}
