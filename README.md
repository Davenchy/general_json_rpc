# GeneralJsonRpc

GeneralJsonRpc is a package that implements json-rpc v2.0 and its purpose is to ease invoking methods and exchange data throw network

the package is focusing on encoding and decoding json-rpc messages to and from bytes
to ease sending and receiving using any protocol

## A Quick Guide

In this guide you will create a server and client sides application that invokes methods throw
tcp sockets

lets start

- First on the server side we will define 3 methods [sum, print, quit]
  
  - The `sum` method will get numbers list and returns their sum
  
  - The `print` method will get a parameter named `message` and print its content on the server side
  
  - The `quit` method will end the application by executing `exit(0);`

```dart
import 'dart:io';
import 'package:general_json_rpc/general_json_rpc.dart';

void main() {
  server();
  client();
}
```

```dart
final server = await ServerSocket.bind(InternetAddress.anyIPv4, 8081);
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

        // now lets handle all cases
        final response = await RpcObject.auto(rpcObject, methodRunner: runner);

        // now lets send the response to the client if it is not null
        // before send we must convert it to bytes using the `encode()` method
        if (response != null) client.add(response.encode());
      },
    );
  }
```

```dart
void client() async {
  print('[client] connecting...');
  final client = await Socket.connect(InternetAddress.loopbackIPv4, 8081);
  print('[client] connected!');

  // lets create controller to help send requests and responses
  final controller = RpcController();

  // lets listen for messages
  client.listen(
    (bytes) async {
      // lets use our controller to send requests and responses
      controller.sendEvent.addListener(
        // ! encode [rpcMessage] before send
        (rpcMessage) => client.add(rpcMessage.encode()),
      );

      // convert bytes into [RpcObject]
      final rpcObject = RpcObject.decode(bytes);

      // now lets handle the rpcObject
      RpcObject.auto(rpcObject, controller: controller);
    },
  );

  // now lets first request the `sum` method
  // we will pass 3 numbers 1, 2, 3 in a list
  // the sum will return as Future<int>
  // we can handle errors by listening for [RpcError]
  controller.request<int>('sum', [1, 2, 3]).then((result) {
    print('[client] sum result: $result');
  }).onError<RpcError>((error, _) {
    print('[client] error: ${error.message}');
  });

  // ============================= //
  // now lets call the `print` method without expecting a response
  controller.notify(
    'print',
    {
      'message': 'A message to be printed on the server side by the client',
    },
  );

  // ============================= //
  // now lets shutdown the server by calling the `quit` method after 5 seconds
  // we expect no returned value
  // so we will send a rpc notification
  await Future.delayed(
    const Duration(seconds: 5),
    () => controller.notify('quit'),
  );
}
```

<!-- 
### Server side

Now lets start

- First import `dart:io` and `package:general_json_rpc/general_json_rpc.dart`

- Now lets create the `server` method which will simulate the server side

```dart

void server() async {
  ...
}

```

and inside lets create our simple server and bind on port `8081`

```dart
final server = await ServerSocket.bind(InternetAddress.anyIPv4, 8081);
print('[server] Server is running on port 8081');
```

cool, now let create a `MethodRunner` where we are going to define our rpc methods

```dart

final runner = MethodRunner();

// now lets define our 3 methods
runner.register<int>('sum', (numbers) => numbers.reduce((a, b) => a + b));
runner.register<void>('print', (p) => print(p['message']));
runner.register<void>('quit', (_) => exit(0));

```

cool now we defined our 3 methods

now lets listen to the incoming connections

```dart

await for(final Socket client in server) {
  client.listen(
    (bytes) async {
      // 1. lets converts bytes into [RpcObject]
      final rpcObject = RpcObject.decode(bytes);

      // 2. now lets handle the coming requests
      final result = await RpcObject.handle(
        rpcObject,
        onRequestAll: runner.executeRequest,
      );

      // 3. now lets encode the result and send it
      if (result != null) client.add(result.encode());
    },
  );
}
```

Now we create 3 steps to handle am incoming request

1. The incoming request is a list of bytes `Uint8List`
    we converted it to a `RpcObject` using the `decode` method

2. Now lets handling the incoming request by executing the methods and send back the results, and we archived this by referencing the `runner.executeRequest` method as a `onRequestAll` callback method which will be executed when ever the request is a normal method execution or notification request.
The `handle` method returns a `Future` of a **nullable** `RpcObject` which the response.

    > Note if no returned value then no response means no returned `RpcObject` by the `handle` method

3. Finally we need to check if the result is not null then we can send it back to the client
   To send `RpcObject` you need to convert it to bytes, and this archived by using the `RpcObject.encode()` method.

Cool this was the server side, lets take a complete view

```dart
import 'dart:io';
import 'package:general_json_rpc/general_json_rpc.dart';

void main() {
  server();
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
```

----

### Client Side

Cool now we can start implementing the client side.
First lets create the `client` method which simulates the client side

```dart
void client() async {
  ...
}
```

now lets connect to the server

```dart

print('[client] connecting...');
final client = await Socket.connect(InternetAddress.loopbackIPv4, 8081);
print('[client] connected!');
```

Cool, now lets send our requests

The first method is `sum`

```dart
// lets find out the sum of 1, 2 and 3
final request = RpcRequest.create('sum', [1, 2, 3]);

// now lets encode it and send to the server
client.add(request.encode());
```

The next one is `print`

```dart
final request2 = RpcRequest.notify(
  'print',
  {
    'message': 'A message to be printed on server side by client',
  },
);

client.add(request2.encode());
```

also you can use the `[]` and `[]=` operators to assign params

```dart
final request2 = RpcRequest.notify('print', {});
request2['message'] = 'A message to be printed on server side by client';
client.add(request2.encode());
````

Now lets see the deference between `RpcRequest.create` and `RpcRequest.notify`

both creates new instance of `RpcRequest` but `create` creates instance with a generated id while `notify` creates instance with `null` as a id value

> If we expect a returned value from the requested method then we need to specify an **id** for our request so later we will listen and filter the responses to find one with the same **id** to get our returned value

Cool, now lets see the last one which is `quit`

```dart
// We do not expect a returned value so we will use `notify`
// no need to pass params
final request3 = RpcRequest.notify('quit');

// encode and send
client.add(request3.encode());
```

> Do not forget to call `server` and `client` methods in the `main` method

```dart
void main() {
  server();
  client();
}
```

Now lets get a complete view for what we did so far

```dart
import 'dart:io';
import 'package:general_json_rpc/general_json_rpc.dart';

void main() async {
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
  print('[client], connected!');

  // now lets first request the `sum` method
  // we expect a returned value
  // so we will send a rpc request
  // we will pass 3 numbers 1, 2, 3 in a list
  final request = RpcRequest.create('sum', [1, 2, 3]);

  // now lets send the request to the server
  // first encode it using the `encode()` method then send it
  client.add(request.encode());

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
  client.add(RpcRequest.notify('quit').encode());
}
```

Cool we are done, but if we run our code the `sum` method example will not work as expected because we need to listen for the server returned values on our client first.

### Listen for responses

First we need to handle responses at client side

```dart
client.listen(
  (bytes) {
    final rpcObject = RpcObject.decode(bytes);

    RpcObject.handle(
      rpcObject,
      onResponse: RpcResponseManager.global.handleResponse,
    );
  },
)
```

Cool now we are listening to any response and handling it on the global `RpcResponseManager` object.

Now lets handle the `sum` method results

```dart
final request = RpcRequest.create('sum', [1, 2, 3]);

client.add(request.encode());

request.waitForResponse().then((result) {
    print('[client] sum result: $result');
  }).onError<RpcError>((error, _) {
    print('[client] error: ${error.message}');
  });
```

also you can handle it like this

```dart
final sum = await request.waitForResponse();
```

> Do not forget we are sending a notification request with method `quit` to exit the app at the end.
> But now our app needs to wait until we get the response back so we can comment it or send it after we receive the result

```dart
request.waitForResponse().then((result) {
    print('[client] sum result: $result');
    client.add(RpcRequest.notify('quit').encode());
  }).onError<RpcError>((error, _) {
    print('[client] error: ${error.message}');
  });
``` -->
