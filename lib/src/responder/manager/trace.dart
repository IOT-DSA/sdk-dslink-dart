part of dslink.responder;


typedef ResponseTraceCallback(ResponseTrace update);

/// 
class ResponseTrace {
  
  /// data path for trace
  String path;
  /// 'list' 'subscribe' 'invoke'
  String type;
  
  /// value is + - or blank string
  String change;
  
  /// action name, only needed by invoke
  String action;
  /// rid, only needed by invoke
  int rid;
  
//  {'name': 'path', 'type': 'string'},
//  {'name': 'type', 'type': 'string'},
//  {'name': 'rid', 'type': 'number'},
//  {'name': 'action', 'type': 'string'},
//  {'name': 'change', 'type': 'string'},
  List get rowData => [path, type, rid, action, change];
  
  ResponseTrace(this.path, this.type, this.rid, [this.change = '', this.action]);
}
