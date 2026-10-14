import 'dart:async';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';

import '../models/chat_message.dart';
import '../services/bluetooth_chat_service.dart';

class ChatScreen extends StatefulWidget {
  final BluetoothChatService chatService;
  final String myUserId;
  final String deviceName;

  const ChatScreen({
    super.key,
    required this.chatService,
    required this.myUserId,
    required this.deviceName,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _controller =
      TextEditingController();

  final ScrollController _scroll = ScrollController();

  final List<ChatMessage> _messages = [];

  StreamSubscription<ChatMessage>? _messageSub;
  StreamSubscription<String>? _statusSub;

  String _status = 'جارٍ التحقق من الاتصال...';
  bool _sending = false;

  @override
  void initState() {
    super.initState();

    _messageSub =
        widget.chatService.onMessageReceived.listen((message) {
      if (!mounted) return;

      setState(() {
        if (!_messages.any((item) => item.id == message.id)) {
          _messages.add(message);
        }
      });

      _scrollBottom();
    });

    _statusSub =
        widget.chatService.onStatusChanged.listen((status) {
      if (!mounted) return;

      setState(() {
        _status = status;
      });
    });

    _status = widget.chatService.isConnected
        ? 'متصل'
        : 'غير متصل';
  }

  Future<void> _send() async {
    final text = _controller.text.trim();

    if (text.isEmpty || _sending) return;

    if (!widget.chatService.isConnected) {
      _notice('لا يوجد اتصال نشط بالجهاز الآخر.');
      return;
    }

    setState(() {
      _sending = true;
    });

    try {
      await widget.chatService.sendMessage(
        widget.myUserId,
        text,
      );

      if (!mounted) return;

      // عرض الرسالة محليًا بعد نجاح الإرسال.
      setState(() {
        _messages.add(
          ChatMessage(
            id: 'local-${DateTime.now().microsecondsSinceEpoch}',
            senderId: widget.myUserId,
            text: text,
            timestamp: DateTime.now(),
          ),
        );
      });

      _controller.clear();
      _scrollBottom();
    } catch (error) {
      if (mounted) {
        _notice('تعذر إرسال الرسالة: $error');
      }
    } finally {
      if (mounted) {
        setState(() {
          _sending = false;
        });
      }
    }
  }

  Future<void> _attachments() async {
    await showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) {
        return SafeArea(
          child: Wrap(
            children: [
              ListTile(
                leading: const Icon(Icons.photo),
                title: const Text('اختيار صورة'),
                onTap: () async {
                  Navigator.pop(sheetContext);

                  try {
                    final image = await ImagePicker().pickImage(
                      source: ImageSource.gallery,
                    );

                    if (image != null && mounted) {
                      _notice(
                        'تم اختيار الصورة، لكن إرسالها عبر '
                        'البلوتوث لم يُفعّل بعد.',
                      );
                    }
                  } catch (error) {
                    if (mounted) {
                      _notice('تعذر اختيار الصورة: $error');
                    }
                  }
                },
              ),
              ListTile(
                leading: const Icon(Icons.videocam),
                title: const Text('اختيار فيديو'),
                onTap: () async {
                  Navigator.pop(sheetContext);

                  try {
                    final video = await ImagePicker().pickVideo(
                      source: ImageSource.gallery,
                    );

                    if (video != null && mounted) {
                      _notice(
                        'تم اختيار الفيديو، لكن إرساله عبر '
                        'البلوتوث لم يُفعّل بعد.',
                      );
                    }
                  } catch (error) {
                    if (mounted) {
                      _notice('تعذر اختيار الفيديو: $error');
                    }
                  }
                },
              ),
              ListTile(
                leading: const Icon(Icons.insert_drive_file),
                title: const Text('اختيار ملف أو مستند'),
                onTap: () async {
                  Navigator.pop(sheetContext);

                  try {
                    final result =
                        await FilePicker.platform.pickFiles();

                    if (result != null && mounted) {
                      _notice(
                        'تم اختيار الملف، لكن إرساله عبر '
                        'البلوتوث لم يُفعّل بعد.',
                      );
                    }
                  } catch (error) {
                    if (mounted) {
                      _notice('تعذر اختيار الملف: $error');
                    }
                  }
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _scrollBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;

      _scroll.animateTo(
        _scroll.position.maxScrollExtent,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    });
  }

  void _notice(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  void dispose() {
    _messageSub?.cancel();
    _statusSub?.cancel();

    _controller.dispose();
    _scroll.dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF075E54),
        foregroundColor: Colors.white,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.deviceName,
              style: const TextStyle(fontSize: 17),
            ),
            Text(
              _status,
              style: const TextStyle(fontSize: 12),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'إرفاق ملف',
            onPressed: _attachments,
            icon: const Icon(Icons.attach_file),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: _messages.isEmpty
                ? const Center(
                    child: Text('ابدأ المحادثة بإرسال رسالة'),
                  )
                : ListView.builder(
                    controller: _scroll,
                    padding: const EdgeInsets.all(12),
                    itemCount: _messages.length,
                    itemBuilder: (context, index) {
                      final message = _messages[index];

                      final isMine =
                          message.senderId == widget.myUserId;

                      return Align(
                        alignment: isMine
                            ? Alignment.centerRight
                            : Alignment.centerLeft,
                        child: Container(
                          constraints: BoxConstraints(
                            maxWidth:
                                MediaQuery.of(context).size.width *
                                    0.78,
                          ),
                          margin: const EdgeInsets.symmetric(
                            vertical: 4,
                          ),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 9,
                          ),
                          decoration: BoxDecoration(
                            color: isMine
                                ? const Color(0xFFDCF8C6)
                                : Theme.of(context).cardColor,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Column(
                            crossAxisAlignment:
                                CrossAxisAlignment.end,
                            children: [
                              Align(
                                alignment: Alignment.centerLeft,
                                child: Text(message.text),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${message.timestamp.hour.toString().padLeft(2, '0')}:'
                                '${message.timestamp.minute.toString().padLeft(2, '0')}',
                                style: const TextStyle(
                                  fontSize: 10,
                                  color: Colors.black54,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 8,
                vertical: 6,
              ),
              child: Row(
                children: [
                  IconButton(
                    onPressed: _attachments,
                    icon: const Icon(Icons.add),
                  ),
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _send(),
                      decoration: InputDecoration(
                        hintText: 'اكتب رسالة...',
                        filled: true,
                        fillColor:
                            Theme.of(context).colorScheme.surface,
                        contentPadding:
                            const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 10,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    onPressed: _sending ? null : _send,
                    color: const Color(0xFF075E54),
                    icon: _sending
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                            ),
                          )
                        : const Icon(Icons.send),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}