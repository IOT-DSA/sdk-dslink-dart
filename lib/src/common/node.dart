part of dslink.common;

/// Base Class for any and all nodes in the SDK.
/// If you are writing a link, please look at the [dslink.responder.SimpleNode] class.
class Node {
  static String getDisplayName(String nameOrPath) {
    if (nameOrPath.contains('/')) {
      List names = nameOrPath.split('/');
      nameOrPath = names.removeLast();
      while (nameOrPath == '' && !names.isEmpty) {
        nameOrPath = names.removeLast();
      }
    }

    if (nameOrPath.contains('%')) {
      nameOrPath = UriComponentDecoder.decode(nameOrPath);
    }

    return nameOrPath;
  }

  /// This node's profile.
  Node profile;

  /// Node Attributes
  Map<String, Object> attributes = {};

  /// same as attributes for local node
  /// but different on remote node
  Object getOverideAttributes(String attr) {
    return attributes[attr];
  }

  Node();

  /// Get an Attribute
  Object getAttribute(String name) {
    if (attributes.containsKey(name)) {
      return attributes[name];
    }

    if (profile != null && profile.attributes.containsKey(name)) {
      return profile.attributes[name];
    }
    return null;
  }

  /// Node Configs
  Map<String, Object> configs = {r'$is': 'node'};

  /// Get a Config
  Object getConfig(String name) {
    if (configs.containsKey(name)) {
      return configs[name];
    }

    if (profile != null && profile.configs.containsKey(name)) {
      return profile.configs[name];
    }
    return null;
  }

  /// Node Children
  /// Map of Child Name to Child Node
  Map<String, Node> children = {};

  /// Adds a child to this node.
  void addChild(String name, Node node) {
    children[name] = node;
  }

  /// Remove a child from this node.
  /// [input] can be either an instance of [Node] or a [String].
  String removeChild(dynamic input) {
    if (input is String) {
      children.remove(getChild(input));
      return input;
    } else if (input is Node) {
      children.remove(input);
    } else {
      throw new Exception("Invalid Input");
    }
    return null;
  }

  /// Get a Child Node
  Node getChild(String name) {
    if (children.containsKey(name)) {
      return children[name];
    }

    if (profile != null && profile.children.containsKey(name)) {
      return profile.children[name];
    }
    return null;
  }

  /// Get a property of this node.
  /// If [name] starts with '$', this will fetch a config.
  /// If [name] starts with a '@', this will fetch an attribute.
  /// Otherwise this will fetch a child.
  Object get(String name) {
    if (name.startsWith(r'$')) {
      return getConfig(name);
    }
    if (name.startsWith('@')) {
      return getAttribute(name);
    }
    return getChild(name);
  }


  /// Iterates over all the children of this node and passes them to the specified [callback].
  void forEachChild(void callback(String name, Node node)) {
    children.forEach(callback);
    if (profile != null) {
      profile.children.forEach((String str, Node n) {
        if (!children.containsKey(str)) {
          callback(str, n);
        }
      });
    }
  }

  void forEachConfig(void callback(String name, Object value)) {
    configs.forEach(callback);
    if (profile != null) {
      profile.configs.forEach((String str, Object val) {
        if (!configs.containsKey(str)) {
          callback(str, val);
        }
      });
    }
  }

  void forEachAttribute(void callback(String name, Object value)) {
    attributes.forEach(callback);
    if (profile != null) {
      profile.attributes.forEach((String str, Object val) {
        if (!attributes.containsKey(str)) {
          callback(str, val);
        }
      });
    }
  }

  /// Gets a map for the data that will be listed in the parent node's children property.
  Map<String, dynamic> getSimpleMap() {
    var rslt = <String, dynamic>{};
    if (configs.containsKey(r'$is')) {
      rslt[r'$is'] = configs[r'$is'];
    }
    if (configs.containsKey(r'$type')) {
      rslt[r'$type'] = configs[r'$type'];
    }
    if (configs.containsKey(r'$name')) {
      rslt[r'$name'] = configs[r'$name'];
    }
    if (configs.containsKey(r'$invokable')) {
      rslt[r'$invokable'] = configs[r'$invokable'];
    }
    if (configs.containsKey(r'$writable')) {
      rslt[r'$writable'] = configs[r'$writable'];
    }

    // TODO(rick): add permission of current requester
    return rslt;
  }
}

/// Utility class for node and config/attribute paths.
class Path {
  /// Regular Expression for invalid characters in paths.
  static final RegExp invalidChar = new RegExp(r'[\\\?\*|"<>]');

  /// Regular Expression for invalid characters in names.
  static final RegExp invalidNameChar = new RegExp(r'[\/\\\?\*|"<>]');

  static Path getValidPath(Object path, [String basePath]) {
    if (path is String) {
      Path p = new Path(path);
      if (p.valid) {
        return p..mergeBasePath(basePath);
      }
    }
    return null;
  }

  static Path getValidNodePath(Object path, [String basePath]) {
    if (path is String) {
      Path p = new Path(path);
      if (p.valid && p.isNode) {
        return p..mergeBasePath(basePath);
      }
    }
    return null;
  }

  static Path getValidAttributePath(Object path, [String basePath]) {
    if (path is String) {
      Path p = new Path(path);
      if (p.valid && p.isAttribute) {
        return p..mergeBasePath(basePath);
      }
    }
    return null;
  }

  static Path getValidConfigPath(Object path, [String basePath]) {
    if (path is String) {
      Path p = new Path(path);
      if (p.valid && p.isConfig) {
        return p..mergeBasePath(basePath);
      }
    }
    return null;
  }

  /// Real Path
  String path;

  /// Real Parent Path
  String parentPath;

  /// Get the parent of this path.
  Path get parent => new Path(parentPath);

  /// Get a child of this path.
  Path child(String name) =>
      new Path(
          (path.endsWith("/") ? path.substring(0, path.length - 1) : path) +
              "/" +
              (name.startsWith("/") ? name.substring(1) : name));

  /// The name of this path.
  /// This is the last component of the path.
  /// For the root node, this is '/'
  String name;

  /// If this path is invalid, this will be false. Otherwise this will be true.
  bool valid = true;

  Path(this.path) {
    _parse();
  }

  void _parse() {
    if (path == '' || path.contains(invalidChar) || path.contains('//')) {
      valid = false;
    }
    if (path == '/') {
      valid = true;
      name = '/';
      parentPath = '';
      return;
    }
    if (path.endsWith('/')) {
      path = path.substring(0, path.length - 1);
    }
    int pos = path.lastIndexOf('/');
    if (pos < 0) {
      name = path;
      parentPath = '';
    } else if (pos == 0) {
      parentPath = '/';
      name = path.substring(1);
    } else {
      parentPath = path.substring(0, pos);
      name = path.substring(pos + 1);
      if (parentPath.contains(r'/$') || parentPath.contains('/@')) {
        // parent path can't be attribute or config
        valid = false;
      }
    }
  }

  /// Is this an absolute path?
  bool get isAbsolute {
    return name == '/' || parentPath.startsWith('/');
  }

  /// Is this the root path?
  bool get isRoot {
    return name == '/';
  }

  /// Is this a config?
  bool get isConfig {
    return name.startsWith(r'$');
  }

  /// Is this an attribute?
  bool get isAttribute {
    return name.startsWith(r'@');
  }

  /// Is this a node?
  bool get isNode {
    return !name.startsWith(r'@') && !name.startsWith(r'$');
  }

  /// Merges the [base] path with this path.
  void mergeBasePath(String base, [bool force = false]) {
    if (base == null) {
      return;
    }

    if (!isAbsolute) {
      if (parentPath == '') {
        parentPath = base;
      } else {
        parentPath = '$base/$parentPath';
      }
      path = '$parentPath/$name';
    } else if (force) {
      // apply base path on a absolute path
      if (name == '') {
        // map the root path
        path = base;
        _parse();
      } else {
        parentPath = '$base$parentPath';
        path = '$parentPath/$name';
      }
    }
  }
}
