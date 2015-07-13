part of dslink.common;

Map defaultProfileMap = {
  "node": {},
  "static": {},
  "getHistory": {
    r"$invokable": "read",
    r"$result": "table",
    r"$params": [
      {"name": "Timerange", "type": "string", 'editor': "daterange"},
      {
        "name": "Interval",
        "type":"enum",
        "editor": buildEnumType([
          "default",
          "none",
          "1Y",
          "3N",
          "1N",
          "1W",
          "1D",
          "12H",
          "6H",
          "4H",
          "3H",
          "2H",
          "1H",
          "30M",
          "15M",
          "10M",
          "5M",
          "1M",
          "30S",
          "15S",
          "10S",
          "5S",
          "1S"
        ])
      },
      {
        "name": "Rollup",
        "type": buildEnumType(
            ["avg", "min", "max", "sum", "first", "last", "count"])
      }
    ],
    r"$columns": [
      {"name": "timestamp", "type": "time"},
      {"name": "value", "type": "dynamic"}
    ]
  },
  "broker":{
    "unode":{
      "addChild":{
        r"$invokable":"config",
        r"$params":[{"name":"Name","type":"string"}]
      },
      "addLink":{
        r"$invokable":"config",
        r"$params":[{"name":"Name","type":"string"},{"name":"Id","type":"string"}]
      },
      "remove":{
        r"$invokable":"config"
      }
    },
    "unoderoot":{
      "addChild":{
        r"$invokable":"config",
        r"$params":[{"name":"Name","type":"string"}]
      },
      "addLink":{
        r"$invokable":"config",
        r"$params":[{"name":"Name","type":"string"},{"name":"Id","type":"string"}]
      }
    }
  }
};