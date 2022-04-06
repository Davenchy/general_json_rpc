import 'error_object.dart';
import 'rpc_object.dart';
import 'rpc_object_type.dart';

class RpcResponse extends RpcObjectType {
  final dynamic result;
  final RpcError? error;

  const RpcResponse({dynamic id, this.result, this.error}) : super(id);

  /// Creates a new [RpcResponse] from [meta]
  factory RpcResponse.fromMeta(RpcMeta meta) => RpcResponse(
        id: meta['id'],
        result: meta['result'],
        error: meta['error'] != null ? RpcError.fromMeta(meta['error']) : null,
      );

  /// Is response has an [id]
  bool get hasId => id != null;

  /// Is [id] is [String]
  bool get isIdString => id is String;

  /// Is [id] is [int]
  bool get isIdInt => id is int;

  /// Returns **true** if this response has a [result]
  bool get hasResult => result != null;

  /// Returns **true** if this response has an [error]
  bool get hasError => error != null;

  @override
  RpcMeta toMeta() => {
        'jsonrpc': '2.0',
        'id': id,
        'result': result,
        'error': error?.toMeta(),
      };

  /// Easy handling for the current [RpcResponse]
  ///
  /// [onResult] is called if [hasResult] is **true**
  ///
  /// [onError] is called if [hasError] is **true**
  void handle({
    ResponseResultHandler? onResult,
    ResponseErrorHandler? onError,
  }) {
    if (hasResult) onResult?.call(id, result);
    if (hasError) onError?.call(id, error!);
  }

  dynamic operator [](dynamic key) {
    if (result == null || (result != List && result != Map)) return null;
    return result[key];
  }

  void operator []=(dynamic key, dynamic value) {
    if (result == null || (result != List && result != Map)) return;
    result[key] = value;
  }

  @override
  String toString() =>
      'JsonRpcResponse(id: $id, result: $result, error: $error)';

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is RpcResponse &&
        other.result == result &&
        other.error == error;
  }

  @override
  int get hashCode => result.hashCode ^ error.hashCode;
}
