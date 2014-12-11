part of dslink.protocol;

class DSEncoder {
  static Map encodeNode(DSNode node) {
    var map = {};
    map["name"] = node.name;
    map["hasChildren"] = node.children.isNotEmpty;
    map["hasValue"] = node.hasValue;
    map["hasHistory"] = node.hasValueHistory;
    if (node.hasValue) {
      map["type"] = node.value.type.name;
      map.addAll(encodeFacets(node.valueType));
    }
    if (node.icon != null) {
      map["icon"] = node.icon;
    }
    map.addAll(encodeActions(node));
    return map;
  }
  
  static Map encodeValue(DSNode node) {
    var val = node.value;
    var map = {};
    map["value"] = val.toPrimitive();
    map["status"] = val.status;
    map["type"] = val.type.name;
    map.addAll(encodeFacets(node.valueType));
    map["lastUpdate"] = val.timestamp.toIso8601String();
    return map;
  }
  
  static Map encodeFacets(ValueType type) {
    var map = {};
    if (type.enumValues != null) {
      map["enum"] = type.enumValues.join(",");
    }
    
    if (type.precision != null) {
      map["precision"] = type.precision;
    }
    
    if (type.max != null) {
      map["max"] = type.max;
    }
    
    if (type.min != null) {
      map["min"] = type.min;
    }
    
    if (type.unit != null) {
      map["unit"] = type.unit;
    }
    
    map["type"] = type.name;
    return map;
  }
  
  static encodeTable(Map response, String tableName, Table table, int fromIndex, int maxRows) {
    var columnCount = table.columnCount;
    var types = [];
    var partial = {
      "from": fromIndex,
      "field": "results.${tableName}.rows"
    };
    var items = partial["items"] = [];
    int rowCount = 0;
    List row;
    
    while (table.next()) {
      if (++rowCount > maxRows) {
        break;
      }
      
      row = [];
      items.add(row);
      
      for (var i = 0; i < columnCount; i++) {
        if (table.isNull(i)) {
          row.add(null);
        } else {
          row.add(table.getColumnPrimitive(i));
        }
      }
    }
    
    response["partial"] = partial;
    
    if (rowCount > maxRows) {
      partial["total"] = fromIndex + maxRows + maxRows;
      return true;
    } else {
      partial["total"] = -1;
      return false;
    }
  }
  
  static Map encodeActions(DSNode node) {
    var map = {};
    if (node.actions.isEmpty) {
      return {};
    }
    var actions = map["actions"] = [];
    for (var action in node.actions.values) { 
      if (action.hasTableReturn) {
        var name = action.tableName;
        actions.add({
          "name": action.name,
          "parameters": MapEntry.forMap(action.params).map((it) {
            return {
              "name": it.key
            }..addAll(encodeFacets(it.value));
          }).toList(),
          "results": [
            {
              "name": name,
              "type": "table"
            }
          ]
        });
      } else {
        actions.add({
          "parameters": MapEntry.forMap(action.params).map((it) {
            return {
              "name": it.key
            }..addAll(encodeFacets(it.value));
          }).toList(),
          "results": MapEntry.forMap(action.results).map((it) {
            return {
              "name": it.key
            }..addAll(encodeFacets(it.value));
          }).toList(),
          "name": action.name
        });
      }
    }
    return map;
  }
  
  static bool encodeValueHistory(int reqId, String path, Trend trend, int index, dynamic max, Map res) {
    var valueType = trend.type;
    int end = -1;
    var range = trend.timeRange;
    if (range != null) end = range.to.millisecondsSinceEpoch;
    res["method"] = "GetValueHistory";
    res["reqId"] = reqId;
    res["path"] = path;
    var columns = res["columns"] = [];
    var column = {};
    columns.add(column);
    column["name"] = "timestamp";
    column["type"] = "time";
    column["timezone"] = new DateTime.now().timeZoneName;
    column = {};
    columns.add(column);
    column["name"] = "value";
    column.addAll(encodeFacets(valueType));
    column = {};
    columns.add(column);
    column["name"] = "status";
    column["type"] = "string";
    var partial = res["partial"] = {};
    partial["from"] = index;
    partial["field"] = "rows";
    var items = partial["items"] = [];
    Value val;
    var buff = new StringBuffer();
    int count = 0;
    List row;
    
    while(trend.hasNext()) {
      if (++count > max) {
        break;
      }
      
      val = trend.next();
      row = [];
      items.add(row);
      buff.clear();
      
      if ((end > 0) && (val.timestamp.millisecondsSinceEpoch > end)) {
        break;
      }
      
      buff.write(val.timestamp.toString());
      row.add(buff.toString());
      row.add(val.toPrimitive());
      row.add(val.status);
    }
    
    if (count > max) {
      partial["total"] = index + max + max;
      return true;
    } else {
      partial["total"] = -1;
      return false;
    }
    
    return false;
  }
}