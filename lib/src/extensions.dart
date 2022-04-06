import 'method_runner.dart';
import 'types/types.dart';

extension BatchRequestsExecuter on RpcBatch {
  Future<RpcBatch> executeAllRequests(
    MethodRunner runner,
  ) async {
    final RpcBatch batch = RpcBatch([]);
    for (final rpcType in rpcTypes) {
      if (rpcType is! RpcRequest) continue;
      final response = await runner.executeRequest(rpcType);
      if (response != null) batch.add(response);
    }
    return batch;
  }
}

extension MethodRunnerRequestExecuter on MethodRunner {
  Future<RpcResponse?> executeRequest(RpcRequest request) async {
    try {
      final result = await call(request.method, request.params);
      if (request.isNotification) return null;
      return request.createResponse(result);
    } on RpcError catch (rpcErr) {
      return request.createResponse(null, rpcErr);
    } catch (err, stk) {
      final rpcError = RpcError(
        code: RpcError.kInternalError,
        message: 'Internal Error',
        data: {
          'error': err.toString(),
          'stacktrace': stk.toString(),
        },
      );
      return request.createResponse(null, rpcError);
    }
  }
}

// void applySocket(Socket socket) {
//   // send data
//   outputSubject.listen(
//     (rpcType) => socket.add([...rpcType.encode(), '\n'.codeUnitAt(0)]),
//   );

//   // receive and process data then return results
//   process(separateJsonPieces(socket)).listen(
//     (response) => socket.add([...response.encode(), '\n'.codeUnitAt(0)]),
//   );
// }

// Stream<Uint8List> separateJsonPieces(Stream<Uint8List> stream) async* {
//   final buffer = StringBuffer();
//   await for (final bytes in stream) {
//     for (final byte in bytes) {
//       if (byte == '\n'.codeUnitAt(0)) {
//         final json = buffer.toString();
//         buffer.clear();
//         if (json.isNotEmpty) {
//           yield Uint8List.fromList(utf8.encode(json));
//         }
//       } else {
//         buffer.writeCharCode(byte);
//       }
//     }
//   }
// }
