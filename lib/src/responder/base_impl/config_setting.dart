part of dslink.responder;

class ConfigSetting {
  final String type;
  /// need permission to read
  final int require;
  /// need permission to write;
  final int writable;
  /// default value
  final Object defaultValue;

  /// whether broker need to maintain the change of config value when ds link is offline
  // bool maintain

  ConfigSetting(this.type, {this.require: Permission.READ, this.writable: Permission.NEVER, this.defaultValue});
}
