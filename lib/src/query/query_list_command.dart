part of dslink.query;

class _ListNodeMatch {
  static const int MATCHED = 1;
  static const int NOMATCH = 0;
  static const int MATCHPOST = 3;
  static const int NOMATCHPOST = 2;

  String prefix;
  String postfix;

  /// true for * and false for ?
  bool multiple = false;
  bool invalid = false;
  String body;
  _ListNodeMatch(String str) {
    if (str == '') {
      // only valid for root node
      return;
    }
    List strs;
    if (str.contains('?')) {
      strs = str.split('?');
    } else if (str.contains('*')) {
      strs = str.split('*');
      multiple = true;
    }
    if (strs != null) {
      if (strs.length != 2) {
        throw 'invalid path "$str"';
      }
      if (strs[0] != '') {
        prefix = strs[0];
      }
      if (strs[1] != '') {
        postfix = strs[1];
      }
    } else {
      body = str;
    }
  }
  int match(String str, bool checkPre) {
    if (body != null) {
      if (str == body) {
        return MATCHED;
      } else {
        return NOMATCH;
      }
    } else {
      if (checkPre && prefix != null && !str.startsWith(prefix)) {
        return NOMATCH;
      }
      if (multiple) {
        if (postfix == null || str.endsWith(postfix)) {
          return MATCHPOST;
        } else {
          return NOMATCHPOST;
        }
      } else {
        if (postfix != null && !str.startsWith(postfix)) {
          return NOMATCH;
        }
        return MATCHED;
      }
    }
  }
}

class _ListingNode {
  QueryCommandList command;
  List<_ListNodeMatch> parsedpath;

  /// negtive value in the pos means partial matched already
  Set<int> matchedPos = new Set<int>();
  LocalNode node;

  StreamSubscription listener;

  _ListingNode(this.command, this.node, this.parsedpath) {}

  void addMatchPos(int n) {
    if (!matchedPos.contains(n)) {
      matchedPos.add(n);
      int absn = n.abs();
      if (absn == parsedpath.length) {
        selfMatch = true;
      } else if (absn < parsedpath.length) {
        if (listener == null) {
          listener = node.listStream.listen(onList);
        }
        node.children.forEach((String name, LocalNode node) {
          checkChild(name, node, n);
        });
      }
    }
  }

  bool _selfMatch = false;
  void set selfMatch(bool val) {
    if (_selfMatch != val) {
      _selfMatch = val;
      if (_selfMatch) {
        command.updateRow([node, '+']);
      } else {
        command.updateRow([node, '-']);
      }
    }
  }

  void onList(String str) {
    if (str.startsWith('@') || str.startsWith(r'$')) {
      return;
    }
    LocalNode child = node.children[str];
    if (child == null) {
      deleteChild(str);
    } else {
      for (int pos in matchedPos) {
        checkChild(str, child, pos);
      }
    }
  }

  void checkChild(String name, LocalNode child, int pos) {
    int abspos = pos.abs();
    if (abspos >= parsedpath.length) {
      return;
    }
    bool checkpre = pos > 0;
    int match = parsedpath[abspos].match(name, checkpre);
    if (match > 0) {
      _ListingNode childListing = command._dict[child.path];
      if (childListing == null) {
        childListing = new _ListingNode(command, child, parsedpath);
        command._dict[child.path] = childListing;
      }
      if (match == _ListNodeMatch.MATCHED) {
        childListing.addMatchPos(abspos + 1);
      } else if (match == _ListNodeMatch.NOMATCHPOST) {
        childListing.addMatchPos(-abspos);
      } else if (match == _ListNodeMatch.MATCHPOST) {
        childListing.addMatchPos(-abspos);
        childListing.addMatchPos(abspos + 1);
      }
    }
  }

  void deleteChild(String name) {
    String path = '${node.path}/$name';
    _ListingNode childListing = command._dict[path];
    if (childListing != null) {
      childListing.selfMatch = false;
      childListing.destroy();
      command._dict.remove(childListing.node.path);
    }
  }

  void destroy() {
    if (listener != null) {
      listener.cancel();
    }
  }
}

class QueryCommandList extends BrokerQueryCommand {
  List<String> rawpath;
  List<_ListNodeMatch> parsedpath;
  QueryCommandList(Object path, BrokerQueryManager manager) : super(manager) {
    if (path is String) {
      rawpath = path.split('/');
    } else if (path is List) {
      rawpath = path;
    }
  }
  void init() {
    parsedpath = new List<_ListNodeMatch>(rawpath.length);
    for (int i = 0; i < rawpath.length; ++i) {
      parsedpath[i] = new _ListNodeMatch(rawpath[i]);
    }
  }

  Map<String, _ListingNode> _dict = new Map<String, _ListingNode>();

  Set<String> _changes = new Set<String>();

  bool _pending = false;
  void updateRow(List row) {
    for (var next in nexts) {
      next.updateFromBase([row]);
    }
  }

  void addNext(BrokerQueryCommand next) {
    super.addNext(next);
    List rows = [];
    _dict.forEach((String path, _ListingNode listing) {
      if (listing._selfMatch) {
        rows.add([listing.node, '+']);
      }
    });
    next.updateFromBase(rows);
  }

  void updateFromBase(List updates) {
    for (List data in updates) {
      if (data[0] is LocalNode) {
        LocalNode node = data[0];
        if (data[1] == '+') {
          if (_dict.containsKey(node.path)) {
            print('not implemented');
          } else {
            _ListingNode listing = new _ListingNode(this, node, parsedpath);
            _dict[node.path] = listing;
            listing.addMatchPos(1);
          }
        } else if (data[1] == '-') {
          print('not implemented');
        }
      }
    }
  }

  String toString() {
    return 'list ${rawpath.join("/")}';
  }

  void destroy() {
    super.destroy();
    _dict.forEach((String key, _ListingNode listing) {
      listing.destroy();
    });
  }
}
