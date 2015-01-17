import "package:dslink/link.dart";

main() async {
  var link = new Link("rnd.iot-dsa.org", new PrivateKey.generate());
  
  await link.connect();
  
  print("Connected.");
}