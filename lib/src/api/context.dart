part of dslink.api;

class DSContext {
  static const String ID_TIME_RANGE = "dsreq_timerange";
  static const String ID_INTERVAL = "dsreq_interval";
  
  static TimeRange getTimeRange() {
    return Zone.current[ID_TIME_RANGE];
  }
  
  static Interval getInterval() {
    return Zone.current[ID_INTERVAL];
  }
}