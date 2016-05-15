part of dslink.historian;

class PublishValueAction extends SimpleNode {
  PublishValueAction(String path) : super(path);

  @override
  onInvoke(Map<String, dynamic> params) {
    var inputPath = params["Path"];
    dynamic val = params["Value"];
    String ts = params["Timestamp"];

    if (ts == null) {
      ts = ValueUpdate.getTs();
    }

    if (inputPath is! String) {
      throw "Path not provided.";
    }

    Path p = new Path(path);
    String tp = p
      .parent
      .child(NodeNamer.createName(inputPath))
      .path;
    SimpleNode node = _link[tp];

    WatchPathNode pn;
    if (node is! WatchPathNode) {
      pn = _link.addNode(tp, {
        r"$name": inputPath,
        r"$is": "watchPath",
        r"$publish": true,
        r"$type": "dynamic",
        r"$path": inputPath
      });
      _link.save();
    } else {
      pn = node;
    }

    pn.doUpdate(new ValueUpdate(val, ts: ts));
  }
}
