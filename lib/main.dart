import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:web_socket_channel/io.dart';

void main() => runApp(const ScreenViewerApp());

class ScreenViewerApp extends StatelessWidget {
  const ScreenViewerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Screen Viewer',
      theme: ThemeData.dark(),
      home: const ConnectionScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class ConnectionScreen extends StatefulWidget {
  const ConnectionScreen({super.key});

  @override
  State<ConnectionScreen> createState() => _ConnectionScreenState();
}

class _ConnectionScreenState extends State<ConnectionScreen> {
  final TextEditingController ipController = TextEditingController();
  final TextEditingController portController = TextEditingController(text: '8080');
  bool connecting = false;
  String? error;

  void connect() async {
    if (ipController.text.isEmpty || portController.text.isEmpty) return;
    setState(() { connecting = true; error = null; });
    final uri = 'ws://${ipController.text}:${portController.text}';
    // Navigator will push the viewer screen
    // ignore: use_build_context_synchronously
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => RemoteScreen(uri: uri)),
    ).then((_) => setState(() { connecting = false; }));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('Screen Share Viewer', style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold)),
              const SizedBox(height: 40),
              TextField(controller: ipController, decoration: const InputDecoration(labelText: 'IP Address'), style: const TextStyle(fontSize: 20)),
              const SizedBox(height: 16),
              TextField(controller: portController, decoration: const InputDecoration(labelText: 'Port'), keyboardType: TextInputType.number),
              const SizedBox(height: 40),
              ElevatedButton(
                onPressed: connecting ? null : connect,
                style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 50)),
                child: connecting ? const CircularProgressIndicator() : const Text('Connect to Remote Screen'),
              ),
              if (error != null) Padding(padding: const EdgeInsets.only(top: 20), child: Text(error!, style: const TextStyle(color: Colors.red))),
            ],
          ),
        ),
      ),
    );
  }
}

class RemoteScreen extends StatefulWidget {
  final String uri;
  const RemoteScreen({super.key, required this.uri});

  @override
  State<RemoteScreen> createState() => _RemoteScreenState();
}

class _RemoteScreenState extends State<RemoteScreen> {
  late WebSocketChannel _channel;
  Uint8List? _currentImage;
  bool _connected = true;

  @override
  void initState() {
    super.initState();
    _channel = IOWebSocketChannel.connect(Uri.parse(widget.uri));
    _channel.stream.listen((data) {
      if (data is List<int>) {
        setState(() { _currentImage = Uint8List.fromList(data); });
      }
    }, onError: (error) {
      setState(() { _connected = false; });
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Connection lost')));
    }, onDone: () {
      setState(() { _connected = false; });
    });
  }

  @override
  void dispose() {
    _channel.sink.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,  // prevents accidental back swipe
      onPopInvoked: (didPop) async {
        if (didPop) return;
        final confirm = await showDialog<bool>(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text('Disconnect?'),
            content: const Text('Long press was hidden – do you want to stop viewing?'),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Stay')),
              TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Disconnect')),
            ],
          ),
        );
        if (confirm == true) Navigator.pop(context);
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: GestureDetector(
          // Long press to disconnect (no visible controls)
          onLongPress: () => Navigator.pop(context),
          child: Center(
            child: _currentImage == null
                ? const CircularProgressIndicator()
                : Image.memory(_currentImage!, fit: BoxFit.contain),
          ),
        ),
      ),
    );
  }
}