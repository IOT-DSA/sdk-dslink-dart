part of dslink.historian;

abstract class HistorianAdapter {
  Future<HistorianDatabaseAdapter> getDatabase(Map config);

  List<Map<String, dynamic>> getCreateDatabaseParameters();
}

abstract class HistorianDatabaseAdapter {
  Future<HistorySummary> getSummary(String group, String path);
  Future store(List<ValueEntry> entries);
  Stream<ValuePair> fetchHistory(String group, String path, TimeRange range);
  Future purgePath(String group, String path, TimeRange range);
  Future purgeGroup(String group, TimeRange range);

  Future close();

  addWatchPathExtensions(WatchPathNode node) {}
  addWatchGroupExtensions(WatchGroupNode node) {}
}
