import 'rpc_object.dart';

class RpcError {
  final int code;
  final String message;
  final RpcMeta data;

  static const int kInvalidRequest = -32600;
  static const int kMethodNotFound = -32601;
  static const int kInvalidParams = -32602;
  static const int kInternalError = -32603;
  static const int kParseError = -32700;

  /// Use `[]` and `[]=` operators to access and modify [data]
  RpcError({required this.code, required this.message, RpcMeta? data})
      : data = data ?? {};

  /// Creates [RpcError] from [meta]
  factory RpcError.fromMeta(RpcMeta meta) => RpcError(
        code: meta['code'],
        message: meta['message'],
        data: meta['data'],
      );

  /// Is this [RpcError] contains extra data
  bool get hasData => data.isNotEmpty;

  /// Returns [RpcMeta] from the current [RpcError]
  RpcMeta toMeta() => {
        'code': code,
        'message': message,
        'data': data,
      };

  dynamic operator [](String key) => data[key];
  void operator []=(String key, dynamic value) => data[key] = value;

  @override
  String toString() =>
      'JsonRpcError(code: $code, message: $message, data: $data)';

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is RpcError &&
        other.code == code &&
        other.message == message &&
        other.data == data;
  }

  @override
  int get hashCode => code.hashCode ^ message.hashCode ^ data.hashCode;
}
