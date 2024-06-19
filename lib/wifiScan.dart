import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:wifi_iot/wifi_iot.dart';

class WifiScanner extends StatefulWidget {
  final BluetoothDevice bleDevice;
  const WifiScanner({super.key, required this.bleDevice});

  @override
  _WifiScannerState createState() => _WifiScannerState();
}

class _WifiScannerState extends State<WifiScanner> {
  List<WifiNetwork> wifiNetworks = [];
  final TextEditingController _ssidController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  @override
  void initState() {
    super.initState();
    scanWifi();
  }

  ///wifi scan
  Future<void> scanWifi() async {
    if (await _requestPermissions()) {
      try {
        List<WifiNetwork>? networks = await WiFiForIoTPlugin.loadWifiList();
        setState(() {
          wifiNetworks = networks ?? [];
        });
      } catch (e) {
        print('Error: $e');
      }
    }
  }

  ///request permissions
  Future<bool> _requestPermissions() async {
    var status = await Permission.location.request();
    if (status.isGranted) {
      return true;
    } else {
      return false;
    }
  }

  ///wifi connection
  void connectToWifi(String ssid, String password) async {
    try {
      await WiFiForIoTPlugin.connect(ssid,
          password: password, security: NetworkSecurity.WPA);
      print('Connected to $ssid');
    } catch (e) {
      print('Error: $e');
    }
  }

  ///wifi connection dialog box
  void _showConnectDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text("Connect to Wi-Fi"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _ssidController,
                decoration: InputDecoration(labelText: "SSID"),
              ),
              TextField(
                controller: _passwordController,
                decoration: InputDecoration(labelText: "Password"),
                obscureText: true,
              ),
            ],
          ),
          actions: [
            TextButton(
              child: Text("Cancel"),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: Text("Connect"),
              onPressed: () {
                String ssid = _ssidController.text;
                String password = _passwordController.text;
                connectToWifi(ssid, password);
                Navigator.of(context).pop();
                String message = jsonEncode({"ssid": ssid, "password": password});
                _sendMessage(message);
                print("ssid: $ssid , pwd: $password");
              },
            ),
          ],
        );
      },
    );
  }

  /// sending response of wifi to device
  Future<void> _sendMessage(String message) async {
    List<BluetoothService> services = await widget.bleDevice.discoverServices();
    for (BluetoothService service in services) {
      for (BluetoothCharacteristic characteristic in service.characteristics) {
        if (characteristic.properties.write) {
          try {
            await characteristic.write(message.codeUnits);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Wifi connected to "${widget.bleDevice.name}"'),
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
        title: Text('Wi-Fi Scanner'),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              itemCount: wifiNetworks.length,
              itemBuilder: (context, index) {
                bool isSecured = wifiNetworks[index].capabilities!.contains("WEP") ||
                    wifiNetworks[index].capabilities!.contains("WPA") ||
                    wifiNetworks[index].capabilities!.contains("EAP");
                return InkWell(
                  onTap: () {
                    _ssidController.text = wifiNetworks[index].ssid ?? '';
                    _showConnectDialog();
                  },
                  child: ListTile(
                    title: Text(wifiNetworks[index].ssid ?? "Unknown SSID"),
                    subtitle: Text(isSecured ? 'Secured' : 'Open'),
                    trailing: Icon(Icons.wifi),
                  ),
                );
              },
            ),
          ),
          FloatingActionButton(
            onPressed: scanWifi,
            child: Icon(Icons.refresh),
          ),
        ],
      ),
    );
  }


}

