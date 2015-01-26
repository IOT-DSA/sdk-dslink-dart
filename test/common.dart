library dslink.test.common;

export "package:scheduled_test/scheduled_test.dart";
import "package:unittest/vm_config.dart";
import "package:unittest/compact_vm_config.dart";

void setupTests(List<String> args) {
  if (args.contains("-v") || args.contains("--verbose")) {
    useVMConfiguration();
  } else {
    useCompactVMConfiguration();
  }
}
