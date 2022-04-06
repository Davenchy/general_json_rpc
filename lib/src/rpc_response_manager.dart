import 'dart:async';

import 'types/types.dart';

class RpcResponseManager {
  static RpcResponseManager? _instance;
  static RpcResponseManager get global => _instance ??= RpcResponseManager();

  final Map<dynamic, Completer> _completers = {};

  /// Registers a [Completer] for the given [id]
  void handleResponse(RpcResponse response) {
    final dynamic id = response.id;
    if (id == null) return;

    final Completer? completer = _completers.remove(id);
    if (completer != null) {
      if (response.hasError) {
        completer.completeError(response.error!);
      } else {
        completer.complete(response.result);
      }
    }
  }

  /// Returns a [Future] that completes with the [T] for the given [id].
  ///
  /// If the response has error it will be thrown
  Future<T> waitForResponse<T>(RpcRequest request) {
    assert(
      !request.isNotification,
      'Request must be not a notification request',
    );

    final Completer<T> completer = Completer();
    _completers[request.id] = completer;

    return completer.future;
  }
}
