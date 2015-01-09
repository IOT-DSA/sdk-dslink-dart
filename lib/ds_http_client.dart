library dslink.client;
import 'ds_common.dart';

part 'src/http/client_session.dart';

/// a client session for both http and ws
class DsClientSession implements DsSession{
  
  // TODO: implement requestConn
  DsConnection get requestConn => null;

  // TODO: implement responseConn
  DsConnection get responseConn => null;
}