import "package:grinder/grinder.dart";

void main(List<String> args) {
  task("test", runTests);
  task("analyze", analyze);
  startGrinder(args);
}

void runTests(GrinderContext context) {
  Tests.runCliTests(context, ["api_tests.dart"]);
}

void analyze(GrinderContext context) {
  Analyzer.analyzePaths(context, ["lib/link.dart", "lib/link_browser.dart"]);
}
