import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:flutterblueplus/wifiScan.dart';
import 'package:permission_handler/permission_handler.dart';

import 'console.dart';

class BLEScan extends StatefulWidget {
  const BLEScan({super.key});

  @override
  _BLEScanState createState() => _BLEScanState();
}

class _BLEScanState extends State<BLEScan> {
  final List<BluetoothDevice> connectedDevicesList = [];
  final List<BluetoothDevice> availableDevicesList = [];
  final Map<DeviceIdentifier, ScanResult> scanResults = {};
  bool isScanning = false;
  StreamSubscription? scanSubscription;

  @override
  void initState() {
    super.initState();
    requestPermissions();
  }

  ///request permissions
  Future<void> requestPermissions() async {
    final status = await [
      Permission.bluetooth,
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
      Permission.location,
    ].request();

    if (status[Permission.location]!.isGranted) {
      startScan();
      getConnectedDevices();
    } else {
      print("Location permission not granted");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Location permission is required for Bluetooth scanning')),
      );
    }
  }

  /// list connected devices
  void getConnectedDevices() async {
    try {
      List<BluetoothDevice> devices = await FlutterBluePlus.connectedDevices;
      setState(() {
        connectedDevicesList.clear();
        connectedDevicesList.addAll(devices);
      });
    } catch (e) {
      print("Error fetching connected devices: $e");
    }
  }
  ///bluetooth scanning start
  void startScan() async {
    print("Scan Started");
    setState(() {
      isScanning = true;
    });

    // Ensure Bluetooth is enabled
    final adapterState = await FlutterBluePlus.adapterState.first;
    if (adapterState != BluetoothAdapterState.on) {
      print("Bluetooth is not enabled");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Bluetooth is not enabled')),
      );
      setState(() {
        isScanning = false;
      });
      return;
    }

    // Listen to scan results
    scanSubscription = FlutterBluePlus.scanResults.listen((results) {
      setState(() {
        for (var result in results) {
          scanResults[result.device.id] = result;
        }
        availableDevicesList.clear();
        availableDevicesList.addAll(
          scanResults.values.map((result) => result.device).where((device) => !connectedDevicesList.contains(device)),
        );
      });
      print("Scan Results: ${scanResults.values.map((result) => result.device.name).toList()}");
    }, onError: (e) {
      print("Error: $e");
    });

    // Start scanning with a timeout
    FlutterBluePlus.startScan(
      withKeywords: ['onwords'],
        timeout: const Duration(seconds: 15)).then((_) {
      setState(() {
        isScanning = false;
      });
    });

    print("List: $availableDevicesList");
  }

  ///bluetooth stop scanning
  void stopScan() {
    scanSubscription?.cancel();
    FlutterBluePlus.stopScan();
    setState(() {
      isScanning = false;
    });
  }

  ///connect to ble device
  Future<void> _connectToDevice(BluetoothDevice device) async {
    try {
      await device.connect();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Connected to ${device.name}')),
      );
      Navigator.of(context).push(MaterialPageRoute(builder: (context) => WifiScanner(bleDevice: device,)));
      getConnectedDevices();
    } on BluetoothConnectionEvent catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Connection failed: $e')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('An error occurred: $e')),
      );
    }
  }

  @override
  void dispose() {
    stopScan();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Scan for Devices'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              startScan();
              getConnectedDevices();
            },
          )
        ],
      ),
      body: Column(
        children: [
          const ListTile(
            title: Text('Connected Devices'),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: connectedDevicesList.length,
              itemBuilder: (context, index) {
                final device = connectedDevicesList[index];
                return ListTile(
                  title: Text(device.name),
                  trailing: Text("Connected"),
                  onTap: () {
                    _connectToDevice(device);
                  },
                );
              },
            ),
          ),
          const ListTile(
            title: Text('Available Devices'),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: availableDevicesList.length,
              itemBuilder: (context, index) {
                final device = availableDevicesList[index];
                return ListTile(
                  title: Text(device.name),
                  trailing: Text("Disconnected"),
                  onTap: () {
                    _connectToDevice(device);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}


