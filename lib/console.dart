import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

class TestScreen extends StatefulWidget {
  final BluetoothDevice bleDevice;

  const TestScreen({super.key, required this.bleDevice});

  @override
  State<TestScreen> createState() => _TestScreenState();
}

class _TestScreenState extends State<TestScreen> {
  final TextEditingController _controller = TextEditingController();

  Future<void> _disconnectFromDevice(BluetoothDevice device) async {
    try {
      // Check if the device is already connected
      final connectedDevices = await FlutterBluePlus.connectedDevices;
      if (!connectedDevices.contains(device)) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Device "${device.name}" is disconnected'),
          ),
        );

        return;
      }

      // Disconnect from the device
      await device.disconnect();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Disconnected from "${device.name}"'),
        ),
      );
      Navigator.of(context).pop();
    } on Exception catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Disconnection error: $e'),
        ),
      );
    }
  }

  Future<void> _sendMessage(String message) async {
    List<BluetoothService> services = await widget.bleDevice.discoverServices();
    for (BluetoothService service in services) {
      for (BluetoothCharacteristic characteristic in service.characteristics) {
        if (characteristic.properties.write) {
          try {
            await characteristic.write(message.codeUnits);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Message sent to "${widget.bleDevice.name}"'),
              ),
            );
            return;
          } on Exception catch (e) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Failed to send message: $e'),
              ),
            );
            return;
          }
        }
      }
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('No writable characteristic found on "${widget.bleDevice.name}"'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Connected to ${widget.bleDevice.name}"),
        actions: [
          IconButton(
            icon: Icon(Icons.unpublished),
            onPressed: () {
              _disconnectFromDevice(widget.bleDevice);
            },
          )
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: _controller,
              decoration: InputDecoration(
                labelText: 'Enter message',
                border: OutlineInputBorder(),
              ),
            ),
            SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                if (_controller.text.isNotEmpty) {
                  _sendMessage(_controller.text);
                }
              },
              child: Text('Send Message'),
            ),
          ],
        ),
      ),
    );
  }
}
