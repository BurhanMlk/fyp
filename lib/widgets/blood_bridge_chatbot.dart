import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../services/chatbot_service.dart';

class BloodBridgeChatbot extends StatefulWidget {
  const BloodBridgeChatbot({super.key});
  @override
  State<BloodBridgeChatbot> createState() => _BloodBridgeChatbotState();
}

class _BloodBridgeChatbotState extends State<BloodBridgeChatbot> {
  final _svc = ChatbotService();
  final _ctrl = TextEditingController();
  final _scroll = ScrollController();
  bool _show = false;
  bool _loading = false;
  bool _listening = false;
  String _bubble = '';
  String? _attachedFile;

  @override void dispose() { _ctrl.dispose(); _scroll.dispose(); super.dispose(); }

  void _toggle() => setState(() => _show = !_show);

  void _startVoice() {
    setState(() => _listening = true);
    // Simulate voice recognition — in production, use speech_to_text package
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted && _listening) {
        setState(() { _listening = false; _ctrl.text = 'Voice input received (type to replace)'; });
      }
    });
  }

  void _stopVoice() => setState(() => _listening = false);

  void _pickFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['jpg', 'jpeg', 'png', 'gif', 'pdf'],
      );
      if (result != null && result.files.isNotEmpty && mounted) {
        final file = result.files.first;
        setState(() => _attachedFile = file.name);
        _svc.history.add({'role': 'user', 'message': '📎 Uploaded: ${file.name}', 'time': DateTime.now().millisecondsSinceEpoch});
        _send(text: 'I uploaded a file: ${file.name}. Please analyze it.');
      }
    } catch (_) {
      if (mounted) _send(text: '📎 File upload request');
    }
  }

  Future<void> _send({String? text}) async {
    final t = text ?? _ctrl.text.trim();
    if (t.isEmpty) return;
    if (text == null) _ctrl.clear();
    setState(() => _loading = true);
    final r = await _svc.ask(t);
    if (!mounted) return;
    setState(() { _loading = false; _bubble = r['message'] ?? ''; });
    _scrollToEnd();
  }

  void _scrollToEnd() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scroll.hasClients) _scroll.animateTo(_scroll.position.maxScrollExtent, duration: const Duration(milliseconds: 200), curve: Curves.easeOut);
    });
  }

  List<Map<String, dynamic>> get _msgs => _svc.history;

  @override
  Widget build(BuildContext context) {
    return Stack(children: [
      // --- Chat overlay when open ---
      if (_show) ...[
        Positioned.fill(child: GestureDetector(onTap: _toggle, child: Container(color: Colors.black54))),
        Positioned(bottom: 0, left: 0, right: 0, height: MediaQuery.of(context).size.height * 0.55,
          child: Material(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            color: Colors.white,
            child: Column(children: [
              // Header
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(colors: [Color(0xFFD32F2F), Color(0xFFB71C1C)]),
                  borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                ),
                child: Row(children: [
                  const Icon(Icons.chat_rounded, color: Colors.white, size: 22),
                  const SizedBox(width: 10),
                  const Expanded(child: Text('Blood Bridge AI', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16))),
                  IconButton(icon: const Icon(Icons.delete_outline, color: Colors.white70, size: 20), onPressed: () => setState(() => _svc.clear())),
                  IconButton(icon: const Icon(Icons.close, color: Colors.white, size: 20), onPressed: _toggle),
                ]),
              ),
              // Messages
              Expanded(child: _msgs.isEmpty
                ? Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                    const Icon(Icons.chat_bubble_outline, size: 48, color: Colors.grey),
                    const SizedBox(height: 12),
                    const Text('How can I help you?', style: TextStyle(color: Colors.grey, fontSize: 15)),
                    const SizedBox(height: 16),
                    Wrap(spacing: 8, runSpacing: 8, children: ['Donate Blood','Find Donors','Emergency','Register','Verification'].map((q) => ActionChip(
                      label: Text(q, style: const TextStyle(fontSize: 12)),
                      onPressed: () => _send(text: q),
                      backgroundColor: Colors.red.shade50,
                    )).toList()),
                  ])
                : ListView.builder(
                    controller: _scroll, padding: const EdgeInsets.all(12),
                    itemCount: _msgs.length,
                    itemBuilder: (_, i) {
                      final m = _msgs[i]; final me = m['role'] == 'user';
                      return Align(alignment: me ? Alignment.centerRight : Alignment.centerLeft,
                        child: Container(
                          margin: EdgeInsets.only(top: 4, bottom: 4, left: me ? 60 : 0, right: me ? 0 : 60),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          decoration: BoxDecoration(
                            color: me ? const Color(0xFFD32F2F) : Colors.grey.shade100,
                            borderRadius: BorderRadius.only(topLeft: const Radius.circular(14), topRight: const Radius.circular(14), bottomLeft: me ? const Radius.circular(14) : Radius.zero, bottomRight: me ? Radius.zero : const Radius.circular(14)),
                          ),
                          child: Text(m['message'] ?? '', style: TextStyle(fontSize: 13, color: me ? Colors.white : Colors.black87, height: 1.4)),
                        ),
                      );
                    },
                  ),
              ),
              // Voice listening indicator
              if (_listening)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  color: Colors.red.shade50,
                  child: const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Icon(Icons.mic, color: Colors.red, size: 18),
                    SizedBox(width: 8),
                    Text('Listening... Speak now', style: TextStyle(color: Colors.red, fontSize: 13, fontWeight: FontWeight.w500)),
                  ]),
                ),
              // Uploaded file indicator
              if (_attachedFile != null)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  color: Colors.blue.shade50,
                  child: Row(children: [
                    const Icon(Icons.insert_drive_file, color: Colors.blue, size: 16),
                    const SizedBox(width: 8),
                    Expanded(child: Text(_attachedFile!, style: const TextStyle(color: Colors.blue, fontSize: 12), overflow: TextOverflow.ellipsis)),
                    GestureDetector(onTap: () => setState(() => _attachedFile = null), child: const Icon(Icons.close, color: Colors.blue, size: 16)),
                  ]),
                ),
              // Typing dots
              if (_loading) Padding(padding: const EdgeInsets.all(8), child: Row(children: [
                const SizedBox(width: 16),
                _dot(), const SizedBox(width: 4), _dot(), const SizedBox(width: 4), _dot(),
              ])),
              // Input bar
              Container(
                padding: const EdgeInsets.fromLTRB(10, 6, 10, 8),
                decoration: BoxDecoration(color: Colors.white, border: Border(top: BorderSide(color: Colors.grey.shade300))),
                child: SafeArea(top: false, child: Row(children: [
                  // Voice button
                  GestureDetector(
                    onTap: _listening ? _stopVoice : _startVoice,
                    child: Container(
                      width: 38, height: 38,
                      decoration: BoxDecoration(
                        color: _listening ? Colors.red.shade50 : Colors.grey.shade100,
                        shape: BoxShape.circle,
                        border: _listening ? Border.all(color: Colors.red, width: 2) : null,
                      ),
                      child: Icon(_listening ? Icons.mic : Icons.mic_none, color: _listening ? Colors.red : Colors.grey.shade600, size: 20),
                    ),
                  ),
                  const SizedBox(width: 4),
                  // Upload button
                  GestureDetector(
                    onTap: _pickFile,
                    child: Container(
                      width: 38, height: 38,
                      decoration: BoxDecoration(color: Colors.grey.shade100, shape: BoxShape.circle),
                      child: Icon(Icons.attach_file, color: Colors.grey.shade600, size: 20),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(child: Container(
                    decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(25)),
                    child: TextField(
                      controller: _ctrl, onSubmitted: (_) => _send(),
                      style: const TextStyle(fontSize: 14),
                      decoration: const InputDecoration(
                        hintText: 'Type message...', hintStyle: TextStyle(fontSize: 14, color: Colors.grey),
                        border: InputBorder.none, contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      ),
                      minLines: 1, maxLines: 4,
                    ),
                  )),
                  const SizedBox(width: 8),
                  GestureDetector(onTap: () => _send(), child: Container(width: 40, height: 40, decoration: const BoxDecoration(color: Color(0xFFD32F2F), shape: BoxShape.circle), child: const Icon(Icons.send_rounded, color: Colors.white, size: 20))),
                ])),
              ),
            ]),
          ),
        ),
      ],
      // FAB
      Positioned(right: 16, bottom: 80,
        child: FloatingActionButton(
          onPressed: _toggle,
          backgroundColor: const Color(0xFFD32F2F),
          child: Icon(_show ? Icons.close : Icons.chat_rounded, color: Colors.white),
        ),
      ),
    ]);
  }

  Widget _dot() => TweenAnimationBuilder<double>(
    tween: Tween<double>(begin: 0.3, end: 1.0), duration: const Duration(milliseconds: 800),
    builder: (_, v, _c) => Transform.scale(scale: v, child: Container(width: 7, height: 7, decoration: const BoxDecoration(color: Color(0xFFD32F2F), shape: BoxShape.circle))),
  );
}
