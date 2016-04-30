import "simple_links_test.dart" as SimpleLinksTests;
import "simple_nodes_test.dart" as SimpleNodesTests;
import "large_links_test.dart" as LargeLinksTests;

import "worker_test.dart" as WorkerTests;
import "utils/all.dart" as UtilsTests;
import "broker_discovery_test.dart" as BrokerDiscoveryTests;

main() {
  UtilsTests.main();
  SimpleLinksTests.main();
  SimpleNodesTests.main();
  LargeLinksTests.main();
  WorkerTests.main();
  BrokerDiscoveryTests.main();
}
