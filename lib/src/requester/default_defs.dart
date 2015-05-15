part of dslink.requester;

class DefaultDefNodes {
  static final Map _defaultDefs = {
    'node':{},
    'static':{},
    'getHistory':{
      r'$invokable':'read',
      r'$result':'table',
      r"$params":[
        {"name":"Timerange","type":"string",'editor':'daterange'},
        {"name":"Interval","type":"enum[default,none,oneYear,threeMonths,oneMonth,oneWeek,oneDay,twelveHours,sixHours,fourHours,threeHours,twoHours,oneHour,thirtyMinutes,twentyMinutes,fifteenMinutes,tenMinutes,fiveMinutes,oneMinute,thirtySeconds,fifteenSeconds,tenSeconds,fiveSeconds,oneSecond]"},
        {"name":"Rollup","type":"enum[avg,min,max,sum,first,last,count]}"}
      ],
      r"$columns":[
        {"name":"Ts","type":"time"},
        {"name":"Value","type":"object"}
      ]
    }
  };
  static final Map<String, Node> nameMap = (){
    Map rslt = new Map<String, Node>();
    _defaultDefs.forEach((String k, Map m) {
      String path = '/defs/profile/$k';
      RemoteDefNode node = new RemoteDefNode(path);
      m.forEach((String n, Object v) {
        if (n.startsWith(r'$')) {
          node.configs[n] = v;
        } else if (n.startsWith('@')) {
          node.attributes[n] = v;
        }
      });
      node.listed = true;
      rslt[k] = node;
    });
    return rslt;
  }();
  static final Map<String, Node> pathMap = (){
    Map rslt = new Map<String, Node>();
    nameMap.forEach((k, node) {
      rslt[node.remotePath] = node;
    });
    return rslt;
  }();
}