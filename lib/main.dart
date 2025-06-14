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
    minimumSize: Size(380, 1040),
    maximumSize: Size(380, 1040),
    center: true,
    backgroundColor: Colors.transparent,
    skipTaskbar: false,
    titleBarStyle: TitleBarStyle.normal,
  );

  windowManager.waitUntilReadyToShow(windowOptions, () async {
    await windowManager.setResizable(false);
    await windowManager.setSize(const Size(380, 1040));
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
  List<int> errors;
  List<int> alerts;
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
  int regenLevel;
  double whpKm;
  int motorTemp;
  int chargingModeAC;

  VehicleData()
      : errors = [],
        alerts = [],
        batterySOC = 0,
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
        odometer = 5565,
        tripA = 0.0,
        regenLevel = 0,
        whpKm = 5.0,
        motorTemp = 0,
        chargingModeAC = 0;

  Map<String, dynamic> toJson() => {
        'errors': errors,
        'alerts': alerts,
        'battery_soc': batterySOC,
        'throttle': throttle,
        'speed': (speed * 10).round() / 10,
        'dpad': dpad,
        'killsw': killSwitch,
        'highbeam': highBeam,
        'indicators': indicators,
        'sidestand': sideStand,
        'abs_warning': absWarning,
        'drivemode': driveMode,
        'motor_status': motorStatus,
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
        'regen_level': regenLevel,
        'whp_km': whpKm,
        'motor_temp': motorTemp,
        'charging_mode_ac': chargingModeAC,
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

  // MODIFIED: Removed the main dataTimer, added a simulation-specific timer
  Timer? _simulationTimer;
  Timer? chargeTimer;

  bool isAccelerating = false;
  final double accelerationTime = 3.5;
  final double decelerationTime = 4.0;

  // ... (rest of the state variables remain the same)
  int _gpsToggleIndex = 0;
  int _motionIndex = 0;
  int _motorTempIndex = 0;
  int _errorIndex = 0;
  final List<List<int>> _errorCycles = [
    [],
    [0, 2],
    [3]
  ];
  int _alertIndex = 0;
  final List<List<int>> _alertCycles = [
    [],
    [5],
    [0, 3],
    [2]
  ];
  final List<int> _motorTempList = [34, 77, 89, 95];
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
    final maxThrottle = modeThrottleLimits[vehicleData.driveMode] ?? 26;

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
          (rawData) {
            try {
              final message = utf8.decode(rawData);
              final command = jsonDecode(message) as Map<String, dynamic>;
              print('Server received command: $command');

              bool dataChanged = false;

              if (command.containsKey('set_regen_level')) {
                final newRegenSetValue = command['set_regen_level'];
                if (newRegenSetValue is int) {
                  setState(() {
                    vehicleData.regenLevel = newRegenSetValue.clamp(0, 3);
                    dataChanged = true;
                  });
                }
              }
              if (command.containsKey('set_charging_mode_ac')) {
                final newChargingModeACSetValue =
                    command['set_charging_mode_ac'];
                if (newChargingModeACSetValue is int) {
                  setState(() {
                    vehicleData.chargingModeAC = newChargingModeACSetValue;
                    dataChanged = true;
                  });
                }
              }
              if (dataChanged) {
                broadcastData(); // MODIFIED: Call the new broadcast function
              }
            } catch (e) {
              print('Server: Error processing command from client: $e');
              try {
                print(
                    'Server: Raw data received that caused error: ${utf8.decode(rawData)}');
              } catch (_) {
                print(
                    'Server: Raw data (non-utf8) received that caused error: $rawData');
              }
            }
          },
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

      // MODIFIED: Removed the persistent 50ms dataTimer

      // Charge timer can remain as it's a low-frequency, periodic update
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

  Future<void> stopServer() async {
    // MODIFIED: Cancel the new simulation timer as well
    _simulationTimer?.cancel();
    _simulationTimer = null;
    chargeTimer?.cancel();
    chargeTimer = null;

    // ... (rest of stopServer logic is the same)
    List<Socket> clientsToDestroy = List.from(clients);
    for (var client in clientsToDestroy) {
      try {
        client.destroy();
      } catch (e) {
        print('Error directly from client.destroy() in stopServer: $e');
      }
    }
    clients.clear();
    try {
      await server?.close();
    } catch (e) {
      print('Error closing server socket: $e');
    } finally {
      if (mounted) {
        setState(() {
          isServerRunning = false;
          serverStatus = serverStatus.startsWith('Error closing server:')
              ? serverStatus
              : 'Server Stopped';
          server = null;
        });
      }
    }
  }

  // NEW: A dedicated function to run the continuous simulation
  void _runSimulationLoop() {
    // Stop the timer if the vehicle is not accelerating and has come to a stop.
    if (!isAccelerating &&
        vehicleData.speed <= 0.1 &&
        vehicleData.throttle <= 0) {
      _simulationTimer?.cancel();
      _simulationTimer = null;
      setState(() {
        vehicleData.speed = 0; // Clamp to exactly 0
        vehicleData.throttle = 0;
      });
      broadcastData(); // Send the final state
      return;
    }

    // Perform one step of the simulation
    setState(() {
      double acceleration = calculateAcceleration(vehicleData.speed);
      vehicleData.speed += acceleration;
      vehicleData.whpKm = vehicleData.throttle > 0
          ? vehicleData.whpKm + (vehicleData.speed * 0.921371) / 100
          : vehicleData.whpKm - (vehicleData.speed * 0.921371) / 100;
      vehicleData.whpKm = vehicleData.whpKm < 0.5 ? 0.5 : vehicleData.whpKm;
      final maxSpeed = modeMaxSpeeds[vehicleData.driveMode] ?? 75.0;
      vehicleData.speed = vehicleData.speed.clamp(0.0, maxSpeed);
    });

    broadcastData(); // Broadcast the changes from this simulation step
  }

  // MODIFIED: Renamed from updateAndSendData and simplified
  void broadcastData() {
    if (isServerRunning && clients.isNotEmpty) {
      final jsonData = jsonEncode(vehicleData.toJson());
      for (var client in List<Socket>.from(clients)) {
        try {
          client.write(jsonData);
        } catch (e) {
          print(
              'Error sending data to client ${client.remoteAddress.address}: $e');
        }
      }
    }
  }

  void updateAndSendChargeData() {
    if (isServerRunning && clients.isNotEmpty) {
      setState(() {
        vehicleData.batterySOC = (vehicleData.batterySOC + 1).clamp(0, 101);
        if (vehicleData.batterySOC > 100) vehicleData.batterySOC = 0;
        vehicleData.batteryTemp = (vehicleData.batteryTemp + 1).clamp(24, 57);
        if (vehicleData.batteryTemp > 57) vehicleData.batteryTemp = 24;
      });
      broadcastData(); // Use the common broadcast function
    }
  }

  void handleKeyPress(RawKeyEvent event) {
    if (event is RawKeyDownEvent) {
      // MODIFIED: Start the simulation timer on spacebar press
      if (event.logicalKey == LogicalKeyboardKey.space) {
        if (!isAccelerating) {
          setState(() => isAccelerating = true);
          // Start the timer only if it's not already running
          if (_simulationTimer == null || !_simulationTimer!.isActive) {
            _simulationTimer =
                Timer.periodic(const Duration(milliseconds: 50), (timer) {
              _runSimulationLoop();
            });
          }
        }
        return; // Return to avoid double processing
      }

      bool needsUpdate = true;
      switch (event.logicalKey.keyLabel.toUpperCase()) {
        case '!':
          break;
        case '@':
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
            if (vehicleData.pduState >= 0) {
              vehicleData.pduState = 0;
            } else {
              vehicleData.pduState = 1;
            }
          });
          break;
        case '1':
          setState(() {
            if (vehicleData.chargingState == 0) {
              vehicleData.chargingState = 1;
              vehicleData.pduState = 4;
              vehicleData.chargingCurrent = 12.0;
              vehicleData.chargingVoltage = 240.0;
            } else {
              vehicleData.chargingState = 0;
              vehicleData.pduState = 0;
              vehicleData.chargingCurrent = 0.0;
              vehicleData.chargingVoltage = 0.0;
            }
          });
          break;
        case '2':
          setState(() {
            if (vehicleData.killSwitch == 0 &&
                vehicleData.motorStatus == 0 &&
                vehicleData.sideStand == 0) {
              vehicleData.killSwitch = 1;
              vehicleData.motorStatus = 1;
            } else if (vehicleData.killSwitch == 1 &&
                vehicleData.motorStatus == 1) {
              vehicleData.motorStatus = 0;
            } else if (vehicleData.killSwitch == 1 &&
                vehicleData.motorStatus == 0) {
              vehicleData.killSwitch = 0;
              vehicleData.motorStatus = 0;
            } else if (vehicleData.killSwitch == 0 &&
                vehicleData.motorStatus == 0 &&
                vehicleData.sideStand == 1) {
              needsUpdate = false;
            }
            if (vehicleData.motorStatus == 0) vehicleData.whpKm = 0;
          });
          break;
        case '4':
          setState(
              () => vehicleData.indicators = (vehicleData.indicators + 1) % 4);
          break;
        case '5':
          setState(
              () => vehicleData.highBeam = vehicleData.highBeam == 0 ? 1 : 0);
          break;
        case '6':
          setState(() =>
              vehicleData.absWarning = vehicleData.absWarning == 0 ? 1 : 0);
          break;
        case '7':
          setState(() {
            if (vehicleData.killSwitch == 1) {
              vehicleData.killSwitch = 0;
              vehicleData.motorStatus = 0;
              vehicleData.speed = 0;
              isAccelerating = false;
              vehicleData.throttle = 0;
            } else {
              vehicleData.killSwitch = 1;
            }
          });
          break;
        case '8':
          setState(() {
            vehicleData.sideStand = vehicleData.sideStand == 0 ? 1 : 0;
            if (vehicleData.sideStand == 1 && vehicleData.motorStatus == 1) {
              vehicleData.motorStatus = 0;
              vehicleData.killSwitch = 0;
              vehicleData.speed = 0;
              isAccelerating = false;
              vehicleData.throttle = 0;
            }
          });
          break;
        case '9':
          break;
        case 'C':
          setState(() {
            if (vehicleData.chargingState == 0) {
              vehicleData.chargingState = 1;
              vehicleData.pduState = 4;
            } else if (vehicleData.chargingState == 1) {
              vehicleData.chargingState = 2;
              vehicleData.pduState = 5;
            } else {
              vehicleData.chargingState = 0;
              vehicleData.pduState = 0;
            }
          });
          break;
        case 'E':
          setState(() => vehicleData.eslState = (vehicleData.eslState + 1) % 3);
          break;
        case 'P':
          setState(() => vehicleData.pduState = (vehicleData.pduState + 1) % 6);
          break;
        case 'X':
          setState(() {
            _motorTempIndex = (_motorTempIndex + 1) % _motorTempList.length;
            vehicleData.motorTemp = _motorTempList[_motorTempIndex];
          });
          break;
        case 'B':
          setState(() =>
              vehicleData.brakeStatus = vehicleData.brakeStatus == 0 ? 1 : 0);
          break;
        case 'T':
          setState(() {
            _errorIndex = (_errorIndex + 1) % _errorCycles.length;
            vehicleData.errors = _errorCycles[_errorIndex];
          });
          break;
        case 'Q':
          setState(() {
            _alertIndex = (_alertIndex + 1) % _alertCycles.length;
            vehicleData.alerts = _alertCycles[_alertIndex];
          });
          break;
        case 'H':
          setState(() {
            vehicleData.alerts = [2];
            vehicleData.batteryTemp = 60;
          });
          break;
        case 'L':
          setState(() {
            _gpsToggleIndex = (_gpsToggleIndex + 1) % _gpsPoints.length;
            vehicleData.gpsLat = _gpsPoints[_gpsToggleIndex][0];
            vehicleData.gpsLng = _gpsPoints[_gpsToggleIndex][1];
          });
          break;
        case 'M':
          setState(() {
            vehicleData.driveMode = (vehicleData.driveMode + 1) % 5;
            vehicleData.speed = vehicleData.speed
                .clamp(0.0, modeMaxSpeeds[vehicleData.driveMode] ?? 75.0);
          });
          break;
        case 'R':
          setState(() {
            vehicleData.regenLevel = (vehicleData.regenLevel + 1) % 4;
          });
          break;
        case 'W':
          setState(() => vehicleData.dpad |= (1 << 1));
          break; // DPAD will be sent on key up
        case 'D':
          setState(() => vehicleData.dpad |= (1 << 2));
          break;
        case 'A':
          setState(() => vehicleData.dpad |= (1 << 0));
          break;
        case 'S':
          setState(() => vehicleData.dpad |= (1 << 3));
          break;
        default:
          needsUpdate = false;
          break;
      }
      // MODIFIED: Call broadcastData directly if a key press changed the state
      if (needsUpdate && mounted) {
        broadcastData();
      }
    } else if (event is RawKeyUpEvent) {
      // MODIFIED: Set isAccelerating to false on spacebar release.
      // The simulation loop will handle the gradual deceleration.
      if (event.logicalKey == LogicalKeyboardKey.space) {
        if (isAccelerating) {
          setState(() => isAccelerating = false);
        }
        return;
      }

      bool dpadChanged = false;
      setState(() {
        switch (event.logicalKey.keyLabel.toUpperCase()) {
          case 'W':
            vehicleData.dpad &= ~(1 << 1);
            dpadChanged = true;
            break;
          case 'D':
            vehicleData.dpad &= ~(1 << 2);
            dpadChanged = true;
            break;
          case 'A':
            vehicleData.dpad &= ~(1 << 0);
            dpadChanged = true;
            break;
          case 'S':
            vehicleData.dpad &= ~(1 << 3);
            dpadChanged = true;
            break;
        }
      });
      // MODIFIED: Call broadcastData if DPAD state changed
      if (dpadChanged && mounted) {
        broadcastData();
      }
    }
  }

  // ... (The entire build method and its helpers _buildControlGrid,
  //      _buildControlButton, and _buildDataDisplay remain exactly the same)
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
              const Text(
                'Vehicle Data:',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              Expanded(
                child: _buildDataDisplay(),
              ),
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
        physics: const NeverScrollableScrollPhysics(),
        crossAxisCount: 3,
        childAspectRatio: 1.8,
        mainAxisSpacing: 5,
        crossAxisSpacing: 5,
        children: [
          _buildControlButton('1', 'Toggle Charging'),
          _buildControlButton('2', 'Ignition/Motor/Kill'),
          _buildControlButton('4', 'Indicators'),
          _buildControlButton('5', 'Lights'),
          _buildControlButton('6', 'ABS Warning'),
          _buildControlButton('7', 'Kill Switch'),
          _buildControlButton('8', 'Side Stand'),
          _buildControlButton('Q', 'Cycle Alerts'),
          _buildControlButton('C', 'Cycle Charge State'),
          _buildControlButton('M', 'Cycle Drive Mode'),
          _buildControlButton('Space', 'Accelerate'),
          _buildControlButton('X', 'Cycle Motor Temp'),
          _buildControlButton('T', 'Cycle Errors'),
          _buildControlButton('H', 'High Batt Temp Alert'),
          _buildControlButton('R', 'Cycle Regen Level'),
          _buildControlButton('-', 'Toggle Charging (Legacy)'),
          _buildControlButton('P', 'Cycle PDU State'),
          _buildControlButton('E', 'Cycle ESL State'),
        ],
      ),
    );
  }

  Widget _buildControlButton(String key, String label) {
    return Container(
      decoration: BoxDecoration(
          color: Colors.blueGrey.withOpacity(0.2),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.blueGrey.shade700)),
      child: Tooltip(
        message: label,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              key,
              style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: Colors.white),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4.0),
              child: Text(
                label,
                style: const TextStyle(fontSize: 11, color: Colors.white70),
                textAlign: TextAlign.center,
                overflow: TextOverflow.ellipsis,
                maxLines: 2,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDataDisplay() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Throttle: ${vehicleData.throttle.toStringAsFixed(0)}'),
          Text('Speed: ${vehicleData.speed.toStringAsFixed(2)} km/h'),
          Text('Battery SOC: ${vehicleData.batterySOC.toStringAsFixed(0)}%'),
          Text('Drive Mode: ${vehicleData.driveMode}'),
          Text(
              'Kill Switch (0=Active/Killed, 1=Inactive/Can Run): ${vehicleData.killSwitch}'),
          Text('Motor Status (0=Off, 1=On/Ready): ${vehicleData.motorStatus}'),
          Text('High Beam: ${vehicleData.highBeam}'),
          Text('Indicators: ${vehicleData.indicators}'),
          Text('Side Stand (0=Up, 1=Down): ${vehicleData.sideStand}'),
          Text('ABS Warning: ${vehicleData.absWarning}'),
          Text('PDU State: ${vehicleData.pduState}'),
          Text(
              'Charging State (0=No, 1=Charging, 2=Done): ${vehicleData.chargingState}'),
          Text('ESL State: ${vehicleData.eslState}'),
          Text('Brake Status: ${vehicleData.brakeStatus}'),
          Text('Regen Level (Actual): ${vehicleData.regenLevel}'),
          Text('AC Charging Mode (Actual): ${vehicleData.chargingModeAC}'),
          Text('WHP Km: ${vehicleData.whpKm.toStringAsFixed(2)}'),
          Text('Motor Temp: ${vehicleData.motorTemp}°C'),
          Text('Battery Temp: ${vehicleData.batteryTemp.toStringAsFixed(1)}°C'),
          Text(
              'Charging Current: ${vehicleData.chargingCurrent.toStringAsFixed(1)}A'),
          Text(
              'Charging Voltage: ${vehicleData.chargingVoltage.toStringAsFixed(1)}V'),
          Text(
              'GPS: (${vehicleData.gpsLat.toStringAsFixed(6)}, ${vehicleData.gpsLng.toStringAsFixed(6)})'),
          Text(
              'Accelerometer: X:${vehicleData.acc.x.toStringAsFixed(1)} Y:${vehicleData.acc.y.toStringAsFixed(1)} Z:${vehicleData.acc.z.toStringAsFixed(1)}'),
          Text(
              'Gyroscope: X:${vehicleData.gyro.x.toStringAsFixed(1)} Y:${vehicleData.gyro.y.toStringAsFixed(1)} Z:${vehicleData.gyro.z.toStringAsFixed(1)}'),
          Text('DPAD Raw: ${vehicleData.dpad}'),
          Text('Errors: ${vehicleData.errors.toString()}'),
          Text('Alerts: ${vehicleData.alerts.toString()}'),
        ],
      ),
    );
  }
}
