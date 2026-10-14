import 'dart:async';
import 'dart:convert';

import 'package:flutter_classic_bluetooth/flutter_classic_bluetooth.dart';

import '../models/chat_message.dart';

class BluetoothChatService {
  BluetoothChatService() {
    _bluetooth = FlutterClassicBluetooth();
  }

  late final FlutterClassicBluetooth _bluetooth;

  final StreamController<ChatMessage> _messagesController =
      StreamController<ChatMessage>.broadcast();

  final StreamController<String> _statusController =
      StreamController<String>.broadcast();

  final StreamController<List<dynamic>> _devicesController =
      StreamController<List<dynamic>>.broadcast();

  final Set<String> _receivedMessageIds = <String>{};

  Stream<ChatMessage> get onMessageReceived =>
      _messagesController.stream;

  Stream<String> get onStatusChanged =>
      _statusController.stream;

  Stream<List<dynamic>> get onDevicesChanged =>
      _devicesController.stream;

  dynamic _connection;
  dynamic _server;

  StreamSubscription<String>? _clientSubscription;
  StreamSubscription<dynamic>? _serverSubscription;
  StreamSubscription<dynamic>? _clientStateSubscription;

  bool _isScanning = false;
  bool _isConnecting = false;
  bool _isDisposed = false;

  bool get isConnected {
    try {
      return _connection != null && _connection.isConnected == true;
    } catch (_) {
      return false;
    }
  }

  Future<void> scanDevices() async {
    if (_isDisposed || _isScanning) return;

    _isScanning = true;
    _statusController.add('جارٍ البحث عن الأجهزة...');

    try {
      final permissionStatus =
          await _bluetooth.checkPermissions();

      if (permissionStatus != BtcPermissionStatus.granted &&
          permissionStatus != BtcPermissionStatus.notRequired) {
        final result = await _bluetooth.requestPermissions();

        if (result != BtcPermissionStatus.granted &&
            result != BtcPermissionStatus.notRequired) {
          throw Exception('يجب السماح باستخدام البلوتوث.');
        }
      }

      final enabled = await _bluetooth.isEnabled();

      if (!enabled) {
        throw Exception('يرجى تشغيل البلوتوث من إعدادات الهاتف.');
      }

      final devices = await _bluetooth.scan(
        timeout: const Duration(seconds: 10),
      );

      if (_isDisposed) return;

      _devicesController.add(devices);

      _statusController.add(
        'اكتمل البحث: ${devices.length} جهاز',
      );
    } catch (error) {
      if (!_isDisposed) {
        _statusController.add('تعذر البحث عن الأجهزة: $error');
      }
      rethrow;
    } finally {
      _isScanning = false;
    }
  }

  Future<void> connectToDevice(String address) async {
    if (_isDisposed || _isConnecting) return;

    if (isConnected) {
      throw StateError('يوجد اتصال نشط بالفعل.');
    }

    _isConnecting = true;
    _statusController.add('جارٍ الاتصال...');

    try {
      final connection = await _bluetooth.connect(
        address: address,
        secure: true,
        timeout: const Duration(seconds: 15),
      );

      if (_isDisposed) {
        await connection.close();
        connection.dispose();
        return;
      }

      _connection = connection;

      _clientSubscription = connection.input
          .lines()
          .listen(
            _handleIncomingLine,
            onError: (Object error) {
              if (!_isDisposed) {
                _statusController.add(
                  'حدث خطأ في استقبال البيانات.',
                );
              }
            },
            onDone: () {
              if (!_isDisposed) {
                _statusController.add('انقطع الاتصال.');
              }
            },
          );

      _clientStateSubscription = connection.stateStream.listen(
        (state) {
          if (_isDisposed) return;

          _statusController.add(
            state.name == 'connected'
                ? 'متصل'
                : 'حالة الاتصال: ${state.name}',
          );
        },
      );

      _statusController.add('متصل بنجاح');
    } catch (error) {
      _statusController.add('فشل الاتصال: $error');
      rethrow;
    } finally {
      _isConnecting = false;
    }
  }

  Future<void> startListening() async {
    if (_isDisposed || _server != null) return;

    _statusController.add('جارٍ تشغيل استقبال الاتصالات...');

    try {
      final server = await _bluetooth.startServer(
        serviceName: 'BluetoothChat',
        secure: true,
      );

      if (_isDisposed) {
        await server.close();
        return;
      }

      _server = server;

      _serverSubscription = server.connections.listen(
        (connection) {
          if (_isDisposed) return;

          _statusController.add(
            'اتصل جهاز: ${connection.address}',
          );

          connection.input.lines().listen(
            _handleIncomingLine,
            onError: (Object error) {
              if (!_isDisposed) {
                _statusController.add(
                  'حدث خطأ في استقبال رسالة.',
                );
              }
            },
            onDone: () {
              if (!_isDisposed) {
                _statusController.add('انقطع اتصال الجهاز.');
              }
            },
          );
        },
        onError: (Object error) {
          if (!_isDisposed) {
            _statusController.add('خطأ في خدمة الاستقبال.');
          }
        },
      );

      _statusController.add('جاهز لاستقبال الاتصالات');
    } catch (error) {
      _statusController.add('تعذر تشغيل الاستقبال: $error');
      rethrow;
    }
  }

  Future<void> sendMessage(
    String senderId,
    String text,
  ) async {
    if (_isDisposed) {
      throw StateError('خدمة الاتصال مغلقة.');
    }

    final connection = _connection;

    if (connection == null || !connection.isConnected) {
      throw StateError('لا يوجد جهاز متصل للإرسال إليه.');
    }

    final message = ChatMessage(
      id: '${DateTime.now().microsecondsSinceEpoch}-$senderId',
      senderId: senderId,
      text: text,
      timestamp: DateTime.now(),
    );

    await connection.output.writeLine(
      jsonEncode(message.toJson()),
    );
  }

  void _handleIncomingLine(String line) {
    if (_isDisposed || line.trim().isEmpty) return;

    try {
      final decoded = jsonDecode(line);

      if (decoded is! Map<String, dynamic>) {
        return;
      }

      final message = ChatMessage.fromJson(decoded);

      if (message.id.isEmpty ||
          message.senderId.isEmpty ||
          message.text.length > 10000) {
        return;
      }

      if (!_receivedMessageIds.add(message.id)) {
        return;
      }

      _messagesController.add(message);
    } catch (error) {
      _statusController.add('وصلت بيانات غير صالحة.');
    }
  }

  Future<void> disconnect() async {
    final connection = _connection;
    _connection = null;

    await _clientSubscription?.cancel();
    _clientSubscription = null;

    await _clientStateSubscription?.cancel();
    _clientStateSubscription = null;

    if (connection != null) {
      try {
        await connection.close();
      } finally {
        connection.dispose();
      }
    }

    if (!_isDisposed) {
      _statusController.add('غير متصل');
    }
  }

  Future<void> dispose() async {
    if (_isDisposed) return;

    _isDisposed = true;

    await _clientSubscription?.cancel();
    await _clientStateSubscription?.cancel();
    await _serverSubscription?.cancel();

    final connection = _connection;
    _connection = null;

    if (connection != null) {
      try {
        await connection.close();
      } catch (_) {
        // قد يكون الاتصال قد انقطع بالفعل.
      }

      connection.dispose();
    }

    final server = _server;
    _server = null;

    if (server != null) {
      await server.close();
    }

    await _messagesController.close();
    await _statusController.close();
    await _devicesController.close();
  }
}