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
