import "package:dslink/common.dart";

main() async {
  var firstPacket = new DSRequestPacket();
  firstPacket.method = DSPacketMethod.list;
  firstPacket.path = "/";
  firstPacket.rid = 920;
  firstPacket.updateId = 911;
  firstPacket.qos = 1;

  var writer = new DSPacketWriter();
  firstPacket.writeTo(writer);
  var data = writer.done();

  var reader = new DSPacketReader();
  var pkt = reader.read(data);

  print("Type: ${pkt.runtimeType}");

  if (pkt is DSNormalPacket) {
    print("Method: ${pkt.method.name}");
    print("Is Partial: ${pkt.isPartial}");
    print("Is Clustered: ${pkt.isClustered}");
    print("Update ID: ${pkt.updateId}");
    print("Request ID: ${pkt.rid}");
  }

  if (pkt is DSRequestPacket) {
    print("QOS: ${pkt.qos}");
    print("Path: ${pkt.path}");
  }

  if (pkt is DSResponsePacket) {
    print("Status: ${pkt.status}");
  }
}
