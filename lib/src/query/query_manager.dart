part of dslink.query;

class BrokerQueryManager {
  NodeProvider provider;

  BrokerQueryManager(this.provider) {}

  BrokerQueryCommand parseList(List str) {
    // TODO: implement this
    return null;
  }

  BrokerQueryCommand parseDql(String str) {
    if (str.startsWith('[')) {
      return parseList(DsJson.decode(str));
    }
    // TODO: implement full dql spec
    // this is just a temp quick parser for basic /data node query
    List<String> commands = str.split('|').map((x) => x.trim()).toList();
    if (commands.length == 2 &&
        commands[0].startsWith('list /data') &&
        commands[1].startsWith('subscribe')) {
      String path = commands[0].substring(5);
      BrokerQueryCommand listcommand = new QueryCommandList(path, this);
      listcommand = _getOrAddCommand(listcommand);
      if (listcommand == null) {
        return null;
      }
      BrokerQueryCommand subcommand = new QueryCommandSubscribe(this);
      subcommand.base = listcommand;
      subcommand = _getOrAddCommand(subcommand);
      return subcommand;
    }
    return null;
  }

  Map<String, BrokerQueryCommand> _dict = new Map<String, BrokerQueryCommand>();

  BrokerQueryCommand _getOrAddCommand(BrokerQueryCommand command) {
    String key = command.getQueryId();
    if (_dict.containsKey(key)) {
      return _dict[key];
    }
    try {
      command.init();
    } catch (err) {
      command.destroy();
      return null;
    }

    // add to base command's next
    if (command.base != null) {
      command.base.addNext(command);
    } else if (command is QueryCommandList) {
      // all list command start from root node
      command.updateFromBase([
        [provider.getNode('/'), '+']
      ]);
    }
    _dict[key] = command;
    return command;
  }
}
