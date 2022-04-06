import 'dart:convert';

import 'request_object.dart';
import 'response_object.dart';
import 'rpc_object_type.dart';
import 'rpc_object.dart';

class RpcBatch extends RpcObject {
  RpcBatch([List<RpcObjectType>? rpcTypes]) : rpcTypes = rpcTypes ?? [];

  final List<RpcObjectType> rpcTypes;

  /// Converts [meta] to [RpcBatch]
  factory RpcBatch.fromMeta(List<RpcMeta> meta) {
    final rpcTypes = <RpcObjectType>[];
    for (final rpcTypeMeta in meta) {
      final rpcType = RpcObjectType.fromMeta(rpcTypeMeta);
      rpcTypes.add(rpcType);
    }
    return RpcBatch(rpcTypes);
  }

  int get length => rpcTypes.length;

  /// Converts current **batch** to a [List] of [RpcMeta]
  List<RpcMeta> toMeta() =>
      rpcTypes.map<RpcMeta>((rpcType) => rpcType.toMeta()).toList();

  @override
  List<int> encode({String postfix = '%SEP%'}) =>
      utf8.encode(jsonEncode(toMeta()) + postfix);

  /// Append [RpcObjectType] to the current **batch**
  void add(RpcObjectType rpcType) => rpcTypes.add(rpcType);

  /// Append [rpcTypes] to [instance.rpcTypes]
  void addAll(List<RpcObjectType> rpcTypes) => this.rpcTypes.addAll(rpcTypes);

  /// Returns **true** if [rpcTypes] is empty
  bool get isEmpty => rpcTypes.isEmpty;

  /// Returns all [RpcResponses] inside the current **batch**
  List<RpcResponse> getAllResponses() =>
      rpcTypes.whereType<RpcResponse>().toList().cast<RpcResponse>();

  /// This method is loops throw all objects in [rpcTypes] and ease handling them
  ///
  /// Returns [RpcBatch] with [RpcResponse]s inside
  ///
  /// And ignores if object is of unsupported [RpcObjectType] type
  ///
  /// [onRequestAll] is called if [rpcObject] is a [RpcRequest],
  /// If [onRequestAll] is set then it **overwrite** [onRequest] and [onNotification]
  ///
  /// [onRequest] is called if [rpcObject] is a [RpcRequest] and **is not** a notification
  ///
  /// [onNotification] is called if [rpcObject] is a [RpcRequest] and **is** a notification
  ///
  /// [onResponse] is called if [rpcObject] is a [RpcResponse]
  ///
  /// [onResult] is called if [rpcObject] is a [RpcResponse] and has a **result**
  ///
  /// [onError] is called if [rpcObject] is a [RpcResponse] and has an **error**
  Future<RpcBatch> handle({
    RpcRequestHandler? onRequestAll,
    RpcRequestHandler? onRequest,
    NotificationHandler? onNotification,
    RpcResponseHandler? onResponse,
    ResponseResultHandler? onResult,
    ResponseErrorHandler? onError,
  }) async {
    final resultBatch = RpcBatch();
    for (final rpcObject in rpcTypes) {
      if (rpcObject is RpcResponse) {
        rpcObject.handle(onResult: onResult, onError: onError);
        onResponse?.call(rpcObject);
      } else if (rpcObject is RpcRequest) {
        final response = await (onRequestAll != null
            ? onRequestAll.call(rpcObject)
            : rpcObject.handle(
                onRequest: onRequest,
                onNotification: onNotification,
              ));
        if (response != null) resultBatch.add(response);
      }
    }
    return resultBatch;
  }

  @override
  String toString() =>
      'JsonRpcBatch${rpcTypes.map<String>((rpc) => rpc.runtimeType.toString())}';
}
