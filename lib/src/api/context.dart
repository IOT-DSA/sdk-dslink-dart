part of dslink.api;

class DSContext {
  static const String ID_TIME_RANGE = "dsreq_timerange";
  static const String ID_INTERVAL = "dsreq_interval";
  static const String ID_ROLLUP_TYPE = "dsreq_rollup_type";
  
  static TimeRange getTimeRange() {
    return Zone.current[ID_TIME_RANGE];
  }
  
  static Interval getInterval() {
    return Zone.current[ID_INTERVAL];
  }
  
  static RollupType getRollupType() {
    return Zone.current[ID_ROLLUP_TYPE];
  }
}