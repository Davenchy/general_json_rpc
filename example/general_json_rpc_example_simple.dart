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

        // The `auto` method handles every thing for you
        // Will handle request using [runner] and responses using [RpcResponseManager.global]
        final response = await RpcObject.auto(rpcObject, methodRunner: runner);

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

      // The `auto` method handles every thing for you
      // ! Only will handle responses using [RpcResponseManager.global]
      RpcObject.auto(rpcObject);

      // we are not going to send any thing back
      // ! so we do not need to add the next line
      // if (response != null) client.add(response.encode());
    },
  );

  // ============================= //
  final request2 = RpcRequest.notify('print', {});

  request2['message'] =
      'A message to be printed on the server side by the client';

  client.add(request2.encode());

  // ============================= //
  final request = RpcRequest.create('sum', [1, 2, 3]);
  client.add(request.encode());

  // now lets register the request to be notified on its result
  final sum = await request.waitForResponse();
  print('[client] sum result: $sum');

  // ============================= //
  client.add(RpcRequest.notify('quit').encode());
}