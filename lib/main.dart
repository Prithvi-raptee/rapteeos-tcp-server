import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';


void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'RapteeOS TCP Server',
      theme: ThemeData.dark().copyWith(
        primaryColor: Colors.blue,
        scaffoldBackgroundColor: const Color(0xFF1A1A1A),
      ),
      home: const VehicleSimulator(),
    );
  }
}

class VehicleData {
  double speed;
  int range;
  int modeStatus;
  int contactorStatus;
  double tripDistance;
  int battery;
  int chargerConnected;
  int slowOrFastCharging;
  int remainingChargingTime;
  int indicators;
  int lightBeam;
  int absIndication;
  int killSwitch;
  int sideStand;
  int vehicleError;
  double frontWheelSpeed;
  double rearWheelSpeed;
  int absWarning;
  int motorStatus;
  int vehicleState;
  int dpadValue;
  int chargeByte1000;
  int criticalError;
  int thermalRunaway;
  int highBatteryTemp;
  int throttle;
  int dcCurrentCCS2;

  VehicleData()
      : speed = 0.0,
        range = 120,
        modeStatus = 0,
        contactorStatus = 0,
        tripDistance = 0.0,
        battery = 75,
        chargerConnected = 0,
        slowOrFastCharging = 0,
        remainingChargingTime = 0,
        indicators = 0,
        lightBeam = 0,
        absIndication = 0,
        killSwitch = 0,
        sideStand = 0,
        vehicleError = 0,
        frontWheelSpeed = 0.0,
        rearWheelSpeed = 0.0,
        absWarning = 0,
        motorStatus = 0,
        vehicleState = 0,
        dpadValue = 0,
        criticalError = 0,
        chargeByte1000 = 0,
        thermalRunaway = 0,
        highBatteryTemp = 0,
        throttle = 0,
        dcCurrentCCS2 = 0;

  Map<String, dynamic> toJson() => {
        'speed': speed,
        'range': range,
        'modeStatus': modeStatus,
        'contactorStatus': contactorStatus,
        'tripDistance': tripDistance,
        'battery': battery,
        'chargerConnected': chargerConnected,
        'slowOrFastCharging': slowOrFastCharging,
        'remainingChargingTime': remainingChargingTime,
        'indicators': indicators,
        'lightBeam': lightBeam,
        'absIndication': absIndication,
        'killSwitch': killSwitch,
        'sideStand': sideStand,
        'vehicleError': vehicleError,
        'frontWheelSpeed': speed,
        'rearWheelSpeed': rearWheelSpeed,
        'absWarning': absWarning,
        'motorStatus': motorStatus,
        'vehicleState': vehicleState,
        'dpadValue': dpadValue,
        'chargeByte1000': chargeByte1000,
        'criticalError': criticalError,
        'thermalRunaway': thermalRunaway,
        'highBatteryTemp': highBatteryTemp,
        'throttle': throttle,
        'dcCurrentCCS2': dcCurrentCCS2,
      };
}

class VehicleSimulator extends StatefulWidget {
  const VehicleSimulator({super.key});

  @override
  State<VehicleSimulator> createState() => _VehicleSimulatorState();
}

class _VehicleSimulatorState extends State<VehicleSimulator> {
  ServerSocket? server;
  List<Socket> clients = [];
  VehicleData vehicleData = VehicleData();
  bool isServerRunning = false;
  String serverStatus = 'Server Stopped';
  Timer? dataTimer;
  Timer? chargeTimer;
  bool isAccelerating = false;
  double targetSpeed = 0.0;
  final double accelerationTime = 3.5;
  final double decelerationTime = 4.0;
  double _lastWrittenSpeed = 0.0;

  Map<int, int> modeThrottleLimits = {
    0: 128,
    1: 191,
    2: 255,
  };

  Map<int, double> modeMaxSpeeds = {
    0: 75.0,
    1: 90.0,
    2: 150.0,
    3: 5.0,
  };

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    stopServer();
    super.dispose();
  }

  double calculateAcceleration(double currentSpeed) {
    final maxSpeed = modeMaxSpeeds[vehicleData.modeStatus] ?? 75.0;
    final maxThrottle =
        modeThrottleLimits[vehicleData.modeStatus] ?? 26; // 26 is ~10% of 255

    if (isAccelerating) {
      setState(() {
        vehicleData.throttle =
            (vehicleData.throttle + 10).clamp(0, maxThrottle);
      });

      double throttlePercentage = vehicleData.throttle / 255.0;

      if (currentSpeed < 60.0) {
        return (60.0 / (accelerationTime * 20)) * throttlePercentage;
      } else {
        double remainingSpeed = maxSpeed - currentSpeed;
        return remainingSpeed * 0.05 * throttlePercentage;
      }
    } else {
      setState(() {
        vehicleData.throttle =
            (vehicleData.throttle - 15).clamp(0, maxThrottle);
      });
      return -currentSpeed / (decelerationTime * 20);
    }
  }

  Future<void> startServer() async {
    try {
      server = await ServerSocket.bind(InternetAddress.anyIPv4, 5500);
      setState(() {
        isServerRunning = true;
        serverStatus = 'Server Running on Port 5500';
      });

      server!.listen((client) {
        clients.add(client);
        setState(() {
          serverStatus = 'Client Connected: ${client.remoteAddress.address}';
        });

        client.listen(
          (data) {},
          onError: (error) {
            clients.remove(client);
            setState(() {
              serverStatus = 'Client Error: $error';
            });
          },
          onDone: () {
            clients.remove(client);
            setState(() {
              serverStatus = 'Client Disconnected';
            });
          },
        );
      });

      dataTimer = Timer.periodic(const Duration(milliseconds: 50), (timer) {
        updateAndSendData();
      });

      chargeTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
        updateAndSendChargeData();
      });
    } catch (e) {
      setState(() {
        serverStatus = 'Server Error: $e';
        isServerRunning = false;
      });
    }
  }

  void stopServer() {
    dataTimer?.cancel();
    chargeTimer?.cancel();
    for (var client in clients) {
      client.destroy();
    }
    clients.clear();
    server?.close();
    setState(() {
      isServerRunning = false;
      serverStatus = 'Server Stopped';
    });
  }

  void updateAndSendData() {
    if (isServerRunning) {
      setState(() {
        double acceleration = calculateAcceleration(vehicleData.speed);
        vehicleData.speed += acceleration;

        // Ensure speed stays within bounds
        final maxSpeed = modeMaxSpeeds[vehicleData.modeStatus] ?? 75.0;
        vehicleData.speed = vehicleData.speed.clamp(0.0, maxSpeed);
      });

      final jsonData = jsonEncode(vehicleData.toJson());
      print(jsonData + '\n');
      for (var client in clients) {
        try {
          client.write(jsonData);
        } catch (e) {
          print('Error sending data to client: $e');
        }
      }
    }
  }


  void updateAndSendChargeData() {
    setState(() {
      vehicleData.battery = (vehicleData.battery + 1).clamp(0, 101);
      if (vehicleData.battery > 100) vehicleData.battery = 0;
    });

    final jsonData = jsonEncode(vehicleData.toJson());
    for (var client in clients) {
      try {
        client.write(jsonData);
      } catch (e) {
        print('Error sending charge data to client: $e');
      }
    }
  }

  void handleKeyPress(RawKeyEvent event) {
    if (event is RawKeyDownEvent) {
      if (event.logicalKey == LogicalKeyboardKey.space) {
        setState(() => isAccelerating = true);
      }

      switch (event.logicalKey.keyLabel) {
        case '1':
          if (vehicleData.chargerConnected == 0) {
            setState(() => vehicleData.chargerConnected = 1);
          }
          break;
        case '2':
          setState(() =>
              vehicleData.vehicleState = (vehicleData.vehicleState + 1) % 3);
          break;
        case '4':
          setState(
              () => vehicleData.indicators = (vehicleData.indicators + 1) % 5);
          break;
        case '5':
          setState(() {
            vehicleData.lightBeam = vehicleData.lightBeam == 0 ? 1 : 0;
          });
          break;
        case '6':
          setState(() => vehicleData.absIndication =
              vehicleData.absIndication == 0 ? 1 : 0);
          break;
        case '7':
          setState(() =>
              vehicleData.killSwitch = vehicleData.killSwitch == 0 ? 1 : 0);
          break;
        case '8':
          setState(
              () => vehicleData.sideStand = vehicleData.sideStand == 0 ? 1 : 0);
          break;
        case '9':
          setState(() =>
              vehicleData.vehicleError = vehicleData.vehicleError == 0 ? 1 : 0);
          break;
        case 'C':
          setState(
            () {
              vehicleData.contactorStatus =
                  vehicleData.contactorStatus == 0 ? 2 : 0;
              vehicleData.chargeByte1000 =
                  vehicleData.chargeByte1000 == 0 ? 1 : 0;
            },
          );
          break;
        case 'X':
          setState(
            () {
              vehicleData.criticalError =
                  vehicleData.criticalError == 0 ? 8 : 0;
            },
          );
          break;

        case 'B':
          setState(() =>
              vehicleData.dcCurrentCCS2 = (vehicleData.dcCurrentCCS2 + 1) % 14);
          break;

        case 'T':
          setState(
            () {
              vehicleData.thermalRunaway =
                  vehicleData.thermalRunaway == 0 ? 1 : 0;
            },
          );
          break;
        case 'H':
          setState(
            () {
              vehicleData.highBatteryTemp =
                  vehicleData.highBatteryTemp == 0 ? 1 : 0;
            },
          );
          break;

        case 'M':
          setState(() {
            vehicleData.modeStatus = (vehicleData.modeStatus + 1) % 6;
            vehicleData.speed = vehicleData.speed
                .clamp(0.0, modeMaxSpeeds[vehicleData.modeStatus] ?? 75.0);
          });
          break;
        case 'W':
          setState(() {
            vehicleData.dpadValue = 1;
          });
          break;
        case 'D':
          setState(() {
            vehicleData.dpadValue = 2;
          });
          break;
        case 'A':
          setState(() {
            vehicleData.dpadValue = 3;
          });
          break;
        case 'S':
          setState(() {
            vehicleData.dpadValue = 4;
          });
          break;
      }
    } else if (event is RawKeyUpEvent) {
      if (event.logicalKey == LogicalKeyboardKey.space) {
        setState(() => isAccelerating = false);
      }
      if (['W', 'D', 'A', 'S'].contains(event.logicalKey.keyLabel)) {
        setState(() => vehicleData.dpadValue = 0);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return RawKeyboardListener(
      focusNode: FocusNode(),
      autofocus: true,
      onKey: handleKeyPress,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('RapteeOS TCP Server'),
          actions: [
            IconButton(
              icon: Icon(isServerRunning ? Icons.stop : Icons.play_arrow),
              onPressed: isServerRunning ? stopServer : startServer,
            ),
          ],
        ),
        body: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Server Status: $serverStatus',
                style: const TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 20),
              Text(
                'Connected Clients: ${clients.length}',
                style: const TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 20),
              const Text(
                'Controls:',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              _buildControlGrid(),
              const SizedBox(height: 20),
              _buildDataDisplay(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildControlGrid() {
    return GridView.count(
      shrinkWrap: true,
      crossAxisCount: 2,
      childAspectRatio: 4.5,
      mainAxisSpacing: 10,
      crossAxisSpacing: 10,
      children: [
        _buildControlButton('1', 'Toggle Charger'),
        _buildControlButton('2', 'Cycle Vehicle State'),
        _buildControlButton('4', 'Toggle Indicators'),
        _buildControlButton('5', 'Toggle Lights'),
        _buildControlButton('6', 'Toggle ABS'),
        _buildControlButton('7', 'Toggle Kill Switch'),
        _buildControlButton('8', 'Toggle Side Stand'),
        _buildControlButton('9', 'Toggle Error'),
        _buildControlButton('C', 'Charge State'),
        _buildControlButton('M', 'Cycle Mode'),
        _buildControlButton('Spacebar', 'Speed'),
        _buildControlButton('X', 'Critical Error'),
        _buildControlButton('T', 'Thermal Runaway'),
        _buildControlButton('H', 'High Battery Temp'),
      ],
    );
  }

  Widget _buildControlButton(String key, String label) {
    return Container(
      height: 70,
      width: 80,
      decoration: BoxDecoration(
        color: Colors.blue.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            key,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          Text(
            label,
            style: const TextStyle(fontSize: 12),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildDataDisplay() {
    return Expanded(
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Current Vehicle Data:',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            Text('Speed: ${vehicleData.speed.toStringAsFixed(1)} km/h'),
            Text(
                'Throttle: ${vehicleData.throttle} (${(vehicleData.throttle / 255 * 100).toStringAsFixed(1)}%)'),
            Text('Range: ${vehicleData.range} km'),
            Text('Mode: ${vehicleData.modeStatus}'),
            Text('Battery: ${vehicleData.battery}%'),
            Text(
                'Charger Connected: ${vehicleData.chargerConnected == 1 ? 'Yes' : 'No'}'),
            Text('Vehicle State: ${vehicleData.vehicleState}'),
            Text('DPad Value: ${vehicleData.dpadValue}'),
            Text('Contactor Status: ${vehicleData.contactorStatus}'),
            Text('Charge Byte: ${vehicleData.chargeByte1000}'),
            Text('Critical Error: ${vehicleData.criticalError}'),
            Text('Thermal Runaway: ${vehicleData.thermalRunaway}'),
            Text('High Battery Temp: ${vehicleData.highBatteryTemp}'),
            Text('CPDC: ${vehicleData.dcCurrentCCS2}'),
          ],
        ),
      ),
    );
  }
}
