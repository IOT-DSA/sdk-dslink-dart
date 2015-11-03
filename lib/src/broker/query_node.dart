part of dslink.broker;

class BrokerQueryNode extends BrokerStaticNode {
  BrokerQueryManager _manager;

  BrokerQueryNode(String path, BrokerNodeProvider provider)
    : super(path, provider) {
    _manager = new BrokerQueryManager(provider);
    configs[r'$name'] = 'Query';
    configs[r'$invokable'] = 'config';
    configs[r'$result'] = 'stream';
    configs[r'$params'] = [
      {
        'name': 'query',
        'type': 'string',
        'editor': 'textarea'
      }
    ];
  }

  InvokeResponse invoke(Map params, Responder responder,
    InvokeResponse response, Node parentNode,
    [int maxPermission = Permission.CONFIG]) {
    Object query = params['query'];
    BrokerQueryCommand command;
    if (query is String) {
      command = _manager.parseDql(query);
    }

    if (query is List) {
      command = _manager.parseList(query);
    }

    if (command == null) {
      return response..close(DSError.INVALID_PARAMETER);
    }
    command.addResponse(response);
    return response;
  }
}