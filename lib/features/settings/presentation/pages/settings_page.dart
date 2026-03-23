import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../components/misc/status_badge.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/color_tokens.dart';
import '../../../../core/theme/theme_provider.dart';
import '../../../../server/providers/server_providers.dart';

class SettingsPage extends ConsumerStatefulWidget {
  const SettingsPage({super.key});

  @override
  ConsumerState<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends ConsumerState<SettingsPage> {
  late TextEditingController _portController;

  @override
  void initState() {
    super.initState();
    _portController = TextEditingController(
      text: '${AppConstants.defaultPort}',
    );
  }

  @override
  void dispose() {
    _portController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final themeMode = ref.watch(themeModeProvider);
    final devices = ref.watch(connectedDevicesProvider);
    final server = ref.watch(wsServerProvider);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Icon(LucideIcons.settings, size: 20, color: ColorTokens.primary),
              const SizedBox(width: 10),
              Text('Settings', style: theme.textTheme.headlineMedium),
            ],
          ),
          const SizedBox(height: 24),

          // App Info
          _SettingsSection(
            title: 'About',
            icon: LucideIcons.info,
            children: [
              _InfoRow('App Name', AppConstants.appName),
              _InfoRow('Version', AppConstants.appVersion),
              _InfoRow('Server Status', server.isRunning ? 'Running' : 'Stopped'),
              _InfoRow('Port', '${server.isRunning ? server.port : AppConstants.defaultPort}'),
              _InfoRow('Connected Devices', '${devices.length}'),
            ],
          ),
          const SizedBox(height: 20),

          // Appearance
          _SettingsSection(
            title: 'Appearance',
            icon: LucideIcons.palette,
            children: [
              _SettingRow(
                label: 'Theme',
                child: SegmentedButton<ThemeMode>(
                  segments: const [
                    ButtonSegment(
                      value: ThemeMode.dark,
                      icon: Icon(LucideIcons.moon, size: 14),
                      label: Text('Dark'),
                    ),
                    ButtonSegment(
                      value: ThemeMode.light,
                      icon: Icon(LucideIcons.sun, size: 14),
                      label: Text('Light'),
                    ),
                  ],
                  selected: {themeMode},
                  onSelectionChanged: (value) {
                    final mode = value.first;
                    if (mode == ThemeMode.dark) {
                      ref.read(themeModeProvider.notifier).setDark();
                    } else {
                      ref.read(themeModeProvider.notifier).setLight();
                    }
                  },
                  style: ButtonStyle(
                    textStyle: WidgetStateProperty.all(
                      const TextStyle(fontSize: 12),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Server
          _SettingsSection(
            title: 'Server',
            icon: LucideIcons.server,
            children: [
              _SettingRow(
                label: 'Port',
                child: SizedBox(
                  width: 100,
                  height: 32,
                  child: TextField(
                    controller: _portController,
                    style: const TextStyle(
                      fontFamily: 'JetBrains Mono',
                      fontSize: 13,
                    ),
                    decoration: InputDecoration(
                      contentPadding:
                          const EdgeInsets.symmetric(horizontal: 10),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                    keyboardType: TextInputType.number,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  ElevatedButton.icon(
                    onPressed: () async {
                      final port =
                          int.tryParse(_portController.text) ?? AppConstants.defaultPort;
                      if (server.isRunning) {
                        await server.stop();
                      } else {
                        await server.start(port: port);
                      }
                      setState(() {});
                    },
                    icon: Icon(
                      server.isRunning ? LucideIcons.square : LucideIcons.play,
                      size: 14,
                    ),
                    label: Text(server.isRunning ? 'Stop Server' : 'Start Server'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor:
                          server.isRunning ? ColorTokens.error : ColorTokens.success,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Connected Devices
          if (devices.isNotEmpty)
            _SettingsSection(
              title: 'Connected Devices',
              icon: LucideIcons.smartphone,
              children: [
                ...devices.map((d) => Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isDark
                            ? const Color(0xFF161B22)
                            : const Color(0xFFF6F8FA),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: theme.dividerColor),
                      ),
                      child: Row(
                        children: [
                          PlatformBadge(platform: d.platform),
                          const SizedBox(width: 8),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                d.appName,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13,
                                ),
                              ),
                              Text(
                                '${d.deviceName} - ${d.osVersion}',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.grey[500],
                                ),
                              ),
                            ],
                          ),
                          const Spacer(),
                          Container(
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                              color: ColorTokens.success,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ],
                      ),
                    )),
              ],
            ),
        ],
      ),
    );
  }
}

class _SettingsSection extends StatelessWidget {
  final String title;
  final IconData icon;
  final List<Widget> children;

  const _SettingsSection({
    required this.title,
    required this.icon,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF161B22) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.dividerColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: ColorTokens.primary),
              const SizedBox(width: 8),
              Text(title, style: theme.textTheme.titleMedium),
            ],
          ),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }
}

class _SettingRow extends StatelessWidget {
  final String label;
  final Widget child;

  const _SettingRow({required this.label, required this.child});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: TextStyle(fontSize: 13, color: Colors.grey[500]),
            ),
          ),
          child,
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _InfoRow(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          SizedBox(
            width: 140,
            child: Text(
              label,
              style: TextStyle(fontSize: 12, color: Colors.grey[500]),
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontFamily: 'JetBrains Mono',
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}
