library dslink.requester;

import 'ds_common.dart';
import 'dart:async';
import 'dart:collection';

part 'src/requester/requester.dart';
part 'src/requester/request.dart';
part 'src/requester/request/list.dart';
part 'src/requester/request/subscribe.dart';

/// update function for raw request callback
typedef void _DsRequestUpdater(String status, List updates, List columns);
