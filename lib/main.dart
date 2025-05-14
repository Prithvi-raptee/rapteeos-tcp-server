import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:window_manager/window_manager.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await windowManager.ensureInitialized();

  WindowOptions windowOptions = const WindowOptions(
    size: Size(380, 1080),
    minimumSize: Size(380, 1080),
    maximumSize: Size(380, 1080),
    center: true,
    backgroundColor: Colors.transparent,
    skipTaskbar: false,
    titleBarStyle: TitleBarStyle.normal,
  );

  windowManager.waitUntilReadyToShow(windowOptions, () async {
    await windowManager.setResizable(false);
    await windowManager.setSize(const Size(380, 1080));
    await windowManager.setAlignment(Alignment.topLeft);
    await windowManager.show();
    await windowManager.focus();
  });

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

class Vector3 {
  double x;
  double y;
  double z;

  Vector3(this.x, this.y, this.z);

  Map<String, dynamic> toJson() => {
        'X': x,
        'Y': y,
        'Z': z,
      };
}

class VehicleData {
  int errorCode;
  int alertCode;
  double batterySOC;
  double throttle;
  double speed;
  int dpad;
  int killSwitch;
  int highBeam;
  int indicators;
  int sideStand;
  int absWarning;
  int driveMode;
  int motorStatus;
  int pduState;
  int chargingState;
  int eslState;
  int brakeStatus;
  double batteryTemp;
  double chargingCurrent;
  double chargingVoltage;
  double gpsLat;
  double gpsLng;
  Vector3 acc;
  Vector3 gyro;
  double odometer;
  double tripA;

  VehicleData()
      : errorCode = 0,
        alertCode = 0,
        batterySOC = 75,
        throttle = 0,
        speed = 0.0,
        dpad = 0,
        killSwitch = 0,
        highBeam = 0,
        indicators = 0,
        sideStand = 0,
        absWarning = 0,
        driveMode = 0,
        motorStatus = 0,
        pduState = 0,
        chargingState = 0,
        eslState = 0,
        brakeStatus = 0,
        batteryTemp = 0.0,
        chargingCurrent = 0.0,
        chargingVoltage = 0.0,
        gpsLat = 0.0,
        gpsLng = 0.0,
        acc = Vector3(0.0, 0.0, 0.0),
        gyro = Vector3(0.0, 0.0, 0.0),
        odometer = 0.0,
        tripA = 0.0;

  Map<String, dynamic> toJson() => {
        'error_code': errorCode,
        'alert_code': alertCode,
        'battery_soc': batterySOC, //
        'throttle': throttle, //
        'speed': speed, //
        'dpad': dpad, //
        'killsw': killSwitch, //
        'highbeam': highBeam, //
        'indicators': indicators, //
        'sidestand': sideStand, //
        'abs_warning': absWarning, //
        'drivemode': driveMode, //
        'motor_status': motorStatus, //
        'pdu_state': pduState,
        'charging_state': chargingState,
        'esl_state': eslState,
        'brake_status': brakeStatus,
        'battery_temp': batteryTemp,
        'charging_current': chargingCurrent,
        'charging_voltage': chargingVoltage,
        'gps_latitude': gpsLat,
        'gps_longitude': gpsLng,
        'acc': acc.toJson(),
        'gyro': gyro.toJson(),
        'odometer': odometer,
        'trip_a': tripA,
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

  int _gpsToggleIndex = 0;
  int _motionIndex = 0;

  final List<List<double>> _gpsPoints = [
    [13.017953, 80.173781],
    [13.001177, 80.256496],
    [13.043505, 80.149617],
    [13.043401, 80.253390],
  ];

  final List<Vector3> dummyAccList = [
    Vector3(0.0, 0.0, 0.0),
    Vector3(1.1, -0.5, 0.3),
    Vector3(-0.3, 2.2, -1.0),
    Vector3(0.0, 9.8, 0.0),
    Vector3(3.5, 1.2, -2.3),
  ];

  final List<Vector3> dummyGyroList = [
    Vector3(0.0, 0.0, 0.0),
    Vector3(0.1, 0.2, 0.3),
    Vector3(-0.5, -0.1, 0.6),
    Vector3(1.0, 0.0, 0.0),
    Vector3(0.3, -0.3, 0.8),
  ];

  Map<int, int> modeThrottleLimits = {
    0: 128,
    1: 191,
    2: 255,
    3: 20,
    4: 20,
  };

  Map<int, double> modeMaxSpeeds = {
    0: 75.0,
    1: 90.0,
    2: 150.0,
    3: 5.0,
    4: 5.0,
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
    final maxSpeed = modeMaxSpeeds[vehicleData.driveMode] ?? 75.0;
    final maxThrottle =
        modeThrottleLimits[vehicleData.driveMode] ?? 26; // 26 is ~10% of 255

    if (isAccelerating) {
      setState(() {
        vehicleData.throttle =
            (vehicleData.throttle + 10).clamp(0, maxThrottle).toDouble();
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
            (vehicleData.throttle - 15).clamp(0, maxThrottle).toDouble();
      });
      return -currentSpeed / (decelerationTime * 20);
    }
  }

  Future<void> startServer() async {
    try {
      server = await ServerSocket.bind(InternetAddress.anyIPv4, 9090);
      setState(() {
        isServerRunning = true;
        serverStatus = 'Server Running on Port 9090';
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
        final maxSpeed = modeMaxSpeeds[vehicleData.driveMode] ?? 75.0;
        vehicleData.speed = vehicleData.speed.clamp(0.0, maxSpeed);
      });

      final jsonData = jsonEncode(vehicleData.toJson());
      // print('$jsonData\n'); ///TODO: COMMENTED OUT. ISOLATED CHECKS ONGOING
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
      vehicleData.batterySOC = (vehicleData.batterySOC + 1).clamp(0, 101);
      if (vehicleData.batterySOC > 100) vehicleData.batterySOC = 0;
      vehicleData.batteryTemp = (vehicleData.batteryTemp + 1).clamp(24, 57);
      if (vehicleData.batteryTemp > 57) vehicleData.batteryTemp = 24;
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
        case '!':
          setState(
              () => vehicleData.indicators = (vehicleData.errorCode + 1) % 4);
          break;
        case '@':
          setState(
              () => vehicleData.indicators = (vehicleData.alertCode + 1) % 4);
          break;

        case '`':
          setState(() {
            _motionIndex = (_motionIndex + 1) % dummyAccList.length;
            vehicleData.acc = dummyAccList[_motionIndex];
            vehicleData.gyro = dummyGyroList[_motionIndex];
          });
          break;

        case '-':
          setState(() {
            vehicleData.chargingCurrent =
                vehicleData.chargingCurrent == 12 ? 1 : 0;
          });
          break;

        case '1':
          setState(() {
            ///TODO: FREE
          });

          break;
        case '2': //KILL SWITCH and MOTOR STATUS Toggle
          setState(() {
            if (vehicleData.killSwitch == 0) {
              vehicleData.killSwitch = 1;
            } else if (vehicleData.killSwitch == 1 &&
                vehicleData.motorStatus == 0) {
              vehicleData.motorStatus = 1;
            } else if (vehicleData.killSwitch == 1 &&
                vehicleData.motorStatus == 1) {
              vehicleData.killSwitch = 0;
              vehicleData.motorStatus = 0;
            }
          });
          break;
        case '4': // Indicators Toggle
          setState(
              () => vehicleData.indicators = (vehicleData.indicators + 1) % 4);
          break;
        case '5': // High Beam Toggle
          setState(() {
            vehicleData.highBeam = vehicleData.highBeam == 0 ? 1 : 0;
          });
          break;
        case '6': // Abs Warning Toggle
          setState(() =>
              vehicleData.absWarning = vehicleData.absWarning == 0 ? 1 : 0);
          break;
        case '7':
          setState(
            () {
              /// TODO: FREE
            },
          );
          break;
        case '8': // Side Stand Toggle
          setState(
              () => vehicleData.sideStand = vehicleData.sideStand == 0 ? 1 : 0);
          break;
        case '9':
          setState(() {
            ///TODO: FREE
          });
          break;
        case 'C':
          setState(() {
            vehicleData.pduState = (vehicleData.pduState == 4) ? 5 : 4;
          });
          break;

        case 'E':
          setState(() {
            vehicleData.eslState = (vehicleData.eslState + 1) % 3;
          });
          break;

        case 'P':
          setState(() {
            vehicleData.pduState = (vehicleData.pduState + 1) % 6;
          });
          break;
        case 'X':
          setState(() {
            ///TODO: FREE
          });
          break;

        case 'B':
          setState(() {
            vehicleData.brakeStatus = vehicleData.brakeStatus == 0 ? 1 : 0;
          });
          break;

        case 'T':
          setState(() {
            ///TODO: FREE
          });
          break;
        case 'H':
          setState(() {
            ///TODO: FREE
          });
          break;

        case 'l': // Toggle Lat-Lng
          setState(() {
            _gpsToggleIndex = (_gpsToggleIndex + 1) % _gpsPoints.length;
            vehicleData.gpsLat = _gpsPoints[_gpsToggleIndex][0];
            vehicleData.gpsLng = _gpsPoints[_gpsToggleIndex][1];
          });
          break;

        case 'M': // Drive Mode Toggle
          setState(() {
            vehicleData.driveMode = (vehicleData.driveMode + 1) % 5;
            vehicleData.speed = vehicleData.speed
                .clamp(0.0, modeMaxSpeeds[vehicleData.driveMode] ?? 75.0);
          });
          break;
        case 'W': // UP
          setState(() {
            vehicleData.dpad |= (1 << 1);
          });
          break;
        case 'D': // RIGHT
          setState(() {
            vehicleData.dpad |= (1 << 2);
          });
          break;
        case 'A': // LEFT
          setState(() {
            vehicleData.dpad |= (1 << 0);
          });
          break;
        case 'S': // BOTTOM
          setState(() {
            vehicleData.dpad |= (1 << 3);
          });
          break;
      }
    } else if (event is RawKeyUpEvent) {
      if (event.logicalKey == LogicalKeyboardKey.space) {
        setState(() => isAccelerating = false);
      }

      setState(() {
        switch (event.logicalKey.keyLabel.toUpperCase()) {
          case 'W':
            vehicleData.dpad &= ~(1 << 1); // Clear UP
            break;
          case 'D':
            vehicleData.dpad &= ~(1 << 2); // Clear RIGHT
            break;
          case 'A':
            vehicleData.dpad &= ~(1 << 0); // Clear LEFT
            break;
          case 'S':
            vehicleData.dpad &= ~(1 << 3); // Clear BOTTOM
            break;
        }
      });
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
    return SizedBox(
      width: 330,
      height: 330,
      child: GridView.count(
        shrinkWrap: true,
        crossAxisCount: 3,
        childAspectRatio: 2,
        mainAxisSpacing: 5,
        crossAxisSpacing: 5,
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
      ),
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Throttle: ${vehicleData.throttle}'),
        Text('Speed: ${vehicleData.speed.toStringAsFixed(2)} km/h'),
        Text('Battery SOC: ${vehicleData.batterySOC}%'),
        Text('Drive Mode: ${vehicleData.driveMode}'),
        Text('Kill Switch: ${vehicleData.killSwitch}'),
        Text('Motor Status: ${vehicleData.motorStatus}'),
        Text('High Beam: ${vehicleData.highBeam}'),
        Text('Indicators: ${vehicleData.indicators}'),
        Text('Side Stand: ${vehicleData.sideStand}'),
        Text('ABS Warning: ${vehicleData.absWarning}'),
        Text('PDU State: ${vehicleData.pduState}'),
        Text('Charging State: ${vehicleData.chargingState}'),
        Text('ESL State: ${vehicleData.eslState}'),
        Text('Brake Status: ${vehicleData.brakeStatus}'),
        Text('Battery Temp: ${vehicleData.batteryTemp.toStringAsFixed(1)} °C'),
        Text(
            'Charging Current: ${vehicleData.chargingCurrent.toStringAsFixed(1)} A'),
        Text(
            'Charging Voltage: ${vehicleData.chargingVoltage.toStringAsFixed(1)} V'),
        Text(
            'GPS: (${vehicleData.gpsLat.toStringAsFixed(6)}, ${vehicleData.gpsLng.toStringAsFixed(6)})'),
        Text(
            'Accelerometer: x=${vehicleData.acc.x.toStringAsFixed(2)}, y=${vehicleData.acc.y.toStringAsFixed(2)}, z=${vehicleData.acc.z.toStringAsFixed(2)}'),
        Text(
            'Gyroscope: x=${vehicleData.gyro.x.toStringAsFixed(2)}, y=${vehicleData.gyro.y.toStringAsFixed(2)}, z=${vehicleData.gyro.z.toStringAsFixed(2)}'),
      ],
    );
  }
}
