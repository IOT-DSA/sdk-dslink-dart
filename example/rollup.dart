import "package:dslink/api.dart";

void main() {
  var values = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15].map(wrapValue).toList();
  print("Sum: ${RollupType.SUM.combine(values)}");
  print("Average: ${RollupType.AVG.combine(values)}");
  print("First: ${RollupType.FIRST.combine(values)}");
  print("Last: ${RollupType.LAST.combine(values)}");
  print("And: ${RollupType.AND.combine(values)}");
  print("Or: ${RollupType.OR.combine(values)}");
  print("Count: ${RollupType.COUNT.combine(values)}");
  print("Maximum: ${RollupType.MAX.combine(values)}");
  print("Minimum: ${RollupType.MIN.combine(values)}");
}

Value wrapValue(input) => Value.of(input);
