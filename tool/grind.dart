import "package:grinder/grinder.dart";

void main(List<String> args) {
  task("test", runTests);
  startGrinder(args);
}

void runTests(GrinderContext context) {
  Tests.runCliTests(context, [
    "api_tests.dart"
  ]);
}