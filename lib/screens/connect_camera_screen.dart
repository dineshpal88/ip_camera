import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../features/vehicle_monitoring/models/monitored_camera.dart';
import '../features/vehicle_monitoring/services/camera_repository.dart';
import 'camera_screen.dart';
import 'rtsp_viewer_screen.dart';

/// Existing Add Camera / Connect flow — reused by the vehicle monitoring shell.
///
/// - Saves cameras into [CameraRepository] for Scan Vehicle
/// - Still supports immediate RTSP viewing
/// - Still opens the existing host [CameraScreen]
class ConnectCameraScreen extends StatefulWidget {
  const ConnectCameraScreen({
    super.key,
    this.embedded = false,
    this.onCameraSaved,
  });

  /// When true, omit Scaffold chrome (shell already provides AppBar/drawer).
  final bool embedded;

  /// Called after a camera is successfully saved (e.g. jump to Scan Vehicle).
  final VoidCallback? onCameraSaved;

  @override
  State<ConnectCameraScreen> createState() => _ConnectCameraScreenState();
}

class _ConnectCameraScreenState extends State<ConnectCameraScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _urlController = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _nameController.dispose();
    _urlController.dispose();
    super.dispose();
  }

  String? _validateName(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return 'Enter a camera name';
    return null;
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

  Future<void> _addCamera() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _saving = true);
    try {
      final name = _nameController.text.trim();
      final url = _urlController.text.trim();
      final camera = MonitoredCamera(
        id: '${DateTime.now().millisecondsSinceEpoch}',
        name: name,
        streamUrl: url,
        createdAt: DateTime.now(),
      );
      await CameraRepository.instance.add(camera);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            kIsWeb
                ? 'Added "$name". Live RTSP preview needs the Android app; Web will show a stream limitation.'
                : 'Added "$name"',
          ),
        ),
      );
      widget.onCameraSaved?.call();
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _pasteFromClipboard() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text?.trim();
    if (text == null || text.isEmpty) return;
    setState(() => _urlController.text = text);
  }

  void _openHostCamera() {
    if (kIsWeb) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Hosting an RTSP camera works on the Android app, not in the browser.',
          ),
        ),
      );
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => const CameraScreen(),
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    final theme = Theme.of(context);

    return LayoutBuilder(
      builder: (context, constraints) {
        final maxWidth =
            constraints.maxWidth > 720 ? 720.0 : constraints.maxWidth;
        return Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxWidth),
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (kIsWeb)
                  Card(
                    color: theme.colorScheme.surfaceContainerHighest,
                    child: const Padding(
                      padding: EdgeInsets.all(12),
                      child: Text(
                        'Web plays the camera phone MJPEG feed '
                        '(http://PHONE_IP:8080/stream.mjpg) derived from your RTSP URL. '
                        'Start streaming on the Android camera phone first. '
                        'VLC can still use rtsp:// directly.',
                      ),
                    ),
                  ),
                if (kIsWeb) const SizedBox(height: 16),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            'Add Camera',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Save an RTSP camera for Scan Vehicle, or connect now to preview.',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _nameController,
                            textInputAction: TextInputAction.next,
                            decoration: const InputDecoration(
                              labelText: 'Camera name',
                              hintText: 'Entrance Camera',
                              border: OutlineInputBorder(),
                              prefixIcon: Icon(Icons.badge_outlined),
                            ),
                            validator: _validateName,
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _urlController,
                            keyboardType: TextInputType.url,
                            textInputAction: TextInputAction.go,
                            onFieldSubmitted: (_) => _addCamera(),
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
                            onPressed: _saving ? null : _addCamera,
                            icon: _saving
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(Icons.add_a_photo_rounded),
                            label: const Text('Add Camera'),
                          ),
                          const SizedBox(height: 8),
                          OutlinedButton.icon(
                            onPressed: _connect,
                            icon: const Icon(Icons.play_circle_rounded),
                            label: Text(
                              kIsWeb
                                  ? 'Open stream info'
                                  : 'Connect / Preview',
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.phone_android_rounded),
                    title: const Text('Use this phone as a camera'),
                    subtitle: Text(
                      kIsWeb
                          ? 'Available in the Android app (RTSP host)'
                          : 'Opens the existing Camera Screen host / RTSP server',
                    ),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: _openHostCamera,
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
                        Text(
                          kIsWeb
                              ? '• VLC can open rtsp://… directly; browsers cannot\n'
                                  '• Use Android for live RTSP preview\n'
                                  '• Same URL works in VLC: Media → Open Network Stream\n'
                                  '• Added cameras still appear on Scan Vehicle'
                              : '• Both devices must be on the same Wi-Fi\n'
                                  '• Start streaming on the camera phone first\n'
                                  '• Example: rtsp://PHONE_IP:8554/live\n'
                                  '• Added cameras appear on Scan Vehicle without restart',
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
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.embedded) {
      return SafeArea(child: _buildBody(context));
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Add Camera'),
        centerTitle: true,
      ),
      body: SafeArea(child: _buildBody(context)),
    );
  }
}
