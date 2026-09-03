import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'rtsp_viewer_screen.dart';

class ConnectCameraScreen extends StatefulWidget {
  const ConnectCameraScreen({super.key});

  @override
  State<ConnectCameraScreen> createState() => _ConnectCameraScreenState();
}

class _ConnectCameraScreenState extends State<ConnectCameraScreen> {
  final _formKey = GlobalKey<FormState>();
  final _urlController = TextEditingController();

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }

  String? _validateRtspUrl(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) {
      return 'Enter an RTSP link';
    }
    final uri = Uri.tryParse(text);
    if (uri == null || !uri.hasScheme || uri.scheme.toLowerCase() != 'rtsp') {
      return 'URL must start with rtsp://';
    }
    if (uri.host.isEmpty) {
      return 'Enter a valid host / IP address';
    }
    return null;
  }

  void _connect() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final url = _urlController.text.trim();
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => RtspViewerScreen(rtspUrl: url),
      ),
    );
  }

  Future<void> _pasteFromClipboard() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text?.trim();
    if (text == null || text.isEmpty) return;
    setState(() => _urlController.text = text);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Connect to Camera'),
        centerTitle: true,
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final maxWidth =
                constraints.maxWidth > 720 ? 720.0 : constraints.maxWidth;
            return Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: maxWidth),
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Form(
                          key: _formKey,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Text(
                                'RTSP link',
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Enter the camera RTSP URL from the other device, then connect to view the live stream.',
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                              const SizedBox(height: 16),
                              TextFormField(
                                controller: _urlController,
                                keyboardType: TextInputType.url,
                                textInputAction: TextInputAction.go,
                                onFieldSubmitted: (_) => _connect(),
                                decoration: InputDecoration(
                                  labelText: 'RTSP URL',
                                  hintText: 'rtsp://192.168.1.105:8554/live',
                                  border: const OutlineInputBorder(),
                                  prefixIcon: const Icon(Icons.link_rounded),
                                  suffixIcon: IconButton(
                                    tooltip: 'Paste',
                                    onPressed: _pasteFromClipboard,
                                    icon: const Icon(Icons.content_paste_rounded),
                                  ),
                                ),
                                validator: _validateRtspUrl,
                              ),
                              const SizedBox(height: 16),
                              FilledButton.icon(
                                onPressed: _connect,
                                icon: const Icon(Icons.play_circle_rounded),
                                label: const Text('Connect'),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Tips',
                              style: theme.textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              '• Both devices must be on the same Wi-Fi\n'
                              '• Start streaming on the camera phone first\n'
                              '• Example: rtsp://PHONE_IP:8554/live',
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
