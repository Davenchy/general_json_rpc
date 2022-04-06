/*

  In this example you will see how to use this package on tcp server and client sides

  server() method is the server side
  client() method is the client side

  on the server method we will define 3 rpc methods [sum, print, quit]

  the `sum` method will take a list of numbers and returns their sum
  the `print` method will get a `message` parameter and prints its content
  the `quit` method with end the application by executing `exit(0);`

  on the client side we will call the 3 methods and wait for results

*/

import 'dart:io';

import 'package:general_json_rpc/general_json_rpc.dart';

void main() {
  server();
  client();
}

void server() async {
  var server = await ServerSocket.bind(InternetAddress.anyIPv4, 8081);
  print('[server] Server is running on port 8081');

  // create MethodRunner to define the rpc methods
  final runner = MethodRunner();

  // now lets define the 3 methods
  runner.register<int>('sum', (numbers) => numbers.reduce((a, b) => a + b));
  runner.register<void>('print', (p) => print(p['message']));
  runner.register<void>('quit', (_) => exit(0));

  // now lets listen for new clients
  await for (final Socket client in server) {
    print('[server] new client');
    client.listen(
      (bytes) async {
        // converts bytes into [RpcObject]
        final rpcObject = RpcObject.decode(bytes);

        // now lets handle different cases
        // we will handle requests and notifications
        // requests has a return value while notifications has not
        // we will handle both using [onRequestAll] parameter
        // we will use runner.executeRequest as a callback
        // handle will return a Future of nullable [RpcObject] which is the response
        // for the current request if it has
        final response = await RpcObject.handle(
          rpcObject,
          onRequestAll: runner.executeRequest,
        );

        // now lets send the response to the client if it is not null
        // before send we must convert it to bytes using the `encode()` method
        if (response != null) client.add(response.encode());
      },
    );
  }
}

void client() async {
  print('[client] connecting...');
  final client = await Socket.connect(InternetAddress.loopbackIPv4, 8081);
  print('[client] connected!');

  // lets listen for data from the server
  client.listen(
    (bytes) async {
      // converts bytes into [RpcObject]
      final rpcObject = RpcObject.decode(bytes);

      // now lets handle the server response
      // server could work fine and returns  a [RpcResponse] containing the result
      // or fail and returns a [RpcResponse] containing error of type [RpcError]
      // so lets handle both cases by using [onResponse] parameter
      // ! also we do not need the [onRequestAll] since we know that the server not sending any requests
      // by using [RpcResponseManager.global.handleResponse] as reference callback for [onResponse]
      // it will notify you when ever any result or error is received
      RpcObject.handle(
        rpcObject,
        onResponse: RpcResponseManager.global.handleResponse,
      );

      // we are not going to send any thing back
      // ! so we do not need to add the next line
      // if (response != null) client.add(response.encode());
    },
  );

  // now lets first request the `sum` method
  // we expect a returned value
  // so we will send a rpc request
  // we will pass 3 numbers 1, 2, 3 in a list
  final request = RpcRequest.create('sum', [1, 2, 3]);

  // now lets send the request to the server
  // first encode it using the `encode()` method then send it
  client.add(request.encode());

  // now lets register the request to be notified on its result
  request.waitForResponse().then((result) {
    print('[client] sum result: $result');
  }).onError<RpcError>((error, _) {
    print('[client] error: ${error.message}');
  });

  // ============================= //
  // now lets call the `print` method
  // we expect no returned value
  // so we will send a rpc notification
  final request2 = RpcRequest.notify('print', {});

  // I created the param as an empty Map
  // to show you how to add extra parameters to the request
  // I am going to define key `message` and add my message to it
  request2['message'] =
      'A message to be printed on the server side by the client';

  // now lets encode and send the notification request
  client.add(request2.encode());

  // ============================= //
  // now lets shutdown the server by calling the `quit` method
  // we expect no returned value
  // so we will send a rpc notification
  // ! comment the next line to prevent app from closing
  // client.add(RpcRequest.notify('quit').encode());
}
