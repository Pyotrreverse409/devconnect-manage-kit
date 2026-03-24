import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
  List<_NetworkInfo> _networkInfos = [];
  String _hostName = '';

  @override
  void initState() {
    super.initState();
    _portController = TextEditingController(
      text: '${AppConstants.defaultPort}',
    );
    _loadNetworkInfo();
  }

  Future<void> _loadNetworkInfo() async {
    try {
      final interfaces = await NetworkInterface.list();
      final infos = <_NetworkInfo>[];
      for (final iface in interfaces) {
        for (final addr in iface.addresses) {
          if (addr.type == InternetAddressType.IPv4 && !addr.isLoopback) {
            infos.add(_NetworkInfo(
              ip: addr.address,
              interfaceName: iface.name,
              type: _guessInterfaceType(iface.name),
            ));
          }
        }
      }
      final hostName = Platform.localHostname;
      if (mounted) {
        setState(() {
          _networkInfos = infos;
          _hostName = hostName;
        });
      }
    } catch (_) {}
  }

  String _guessInterfaceType(String name) {
    final lower = name.toLowerCase();
    if (lower.startsWith('en') || lower.startsWith('eth')) return 'Ethernet';
    if (lower.startsWith('wl') || lower.contains('wi-fi') || lower.contains('wifi')) return 'WiFi';
    if (lower.startsWith('utun') || lower.startsWith('tun') || lower.startsWith('ipsec')) return 'VPN';
    if (lower.startsWith('bridge')) return 'Bridge';
    if (lower.startsWith('lo')) return 'Loopback';
    return name;
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
              if (_hostName.isNotEmpty) ...[
                const SizedBox(height: 4),
                _InfoRow('Host Name', _hostName),
              ],
              if (_networkInfos.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text('Your IP (for real device connection)',
                    style: TextStyle(fontSize: 11, color: Colors.grey[500])),
                const SizedBox(height: 4),
                ..._networkInfos.map((info) => GestureDetector(
                      onTap: () {
                        Clipboard.setData(ClipboardData(text: info.ip));
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Copied ${info.ip}'),
                            duration: const Duration(seconds: 1),
                          ),
                        );
                      },
                      child: MouseRegion(
                        cursor: SystemMouseCursors.click,
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 4),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: ColorTokens.primary.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: ColorTokens.primary.withValues(alpha: 0.2),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                info.type == 'WiFi'
                                    ? LucideIcons.wifi
                                    : info.type == 'VPN'
                                        ? LucideIcons.shield
                                        : LucideIcons.cable,
                                size: 12,
                                color: ColorTokens.primary,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                info.ip,
                                style: const TextStyle(
                                  fontFamily: 'JetBrains Mono',
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: ColorTokens.primary,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                '${info.interfaceName} · ${info.type}',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: Colors.grey[500],
                                  fontFamily: 'JetBrains Mono',
                                ),
                              ),
                              const SizedBox(width: 6),
                              Icon(LucideIcons.copy,
                                  size: 12, color: Colors.grey[500]),
                            ],
                          ),
                        ),
                      ),
                    )),
              ],
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

          // Android ADB
          _SettingsSection(
            title: 'Android Device (USB)',
            icon: LucideIcons.usb,
            children: [
              Text(
                'For Android real device connected via USB, run adb reverse to forward the port:',
                style: TextStyle(fontSize: 12, color: Colors.grey[500]),
              ),
              const SizedBox(height: 8),
              GestureDetector(
                onTap: () {
                  final port = server.isRunning
                      ? server.port
                      : AppConstants.defaultPort;
                  Clipboard.setData(
                    ClipboardData(
                        text: 'adb reverse tcp:$port tcp:$port'),
                  );
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Copied to clipboard'),
                      duration: Duration(seconds: 1),
                    ),
                  );
                },
                child: MouseRegion(
                  cursor: SystemMouseCursors.click,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: isDark
                          ? const Color(0xFF161B22)
                          : const Color(0xFFF0F0F0),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: theme.dividerColor),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            'adb reverse tcp:${server.isRunning ? server.port : AppConstants.defaultPort} tcp:${server.isRunning ? server.port : AppConstants.defaultPort}',
                            style: const TextStyle(
                              fontFamily: 'JetBrains Mono',
                              fontSize: 13,
                              color: ColorTokens.secondary,
                            ),
                          ),
                        ),
                        Icon(LucideIcons.copy,
                            size: 14, color: Colors.grey[500]),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  ElevatedButton.icon(
                    onPressed: () async {
                      final port = server.isRunning
                          ? server.port
                          : AppConstants.defaultPort;
                      try {
                        final result = await Process.run(
                          'adb',
                          ['reverse', 'tcp:$port', 'tcp:$port'],
                        );
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                result.exitCode == 0
                                    ? 'adb reverse OK - Android device can now connect via localhost:$port'
                                    : 'adb error: ${result.stderr}',
                              ),
                              backgroundColor: result.exitCode == 0
                                  ? ColorTokens.success
                                  : ColorTokens.error,
                              duration: const Duration(seconds: 3),
                            ),
                          );
                        }
                      } catch (e) {
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                  'adb not found. Install Android SDK tools first.'),
                              backgroundColor: ColorTokens.error,
                            ),
                          );
                        }
                      }
                    },
                    icon: const Icon(LucideIcons.refreshCw, size: 14),
                    label: const Text('Run ADB Reverse'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: ColorTokens.secondary,
                      foregroundColor: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    onPressed: () async {
                      try {
                        final result =
                            await Process.run('adb', ['devices']);
                        if (mounted) {
                          showDialog(
                            context: context,
                            builder: (ctx) => AlertDialog(
                              title: const Text('ADB Devices'),
                              content: Text(
                                result.stdout.toString().trim(),
                                style: const TextStyle(
                                  fontFamily: 'JetBrains Mono',
                                  fontSize: 12,
                                ),
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () =>
                                      Navigator.pop(ctx),
                                  child: const Text('OK'),
                                ),
                              ],
                            ),
                          );
                        }
                      } catch (e) {
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('adb not found'),
                              backgroundColor: ColorTokens.error,
                            ),
                          );
                        }
                      }
                    },
                    icon: const Icon(LucideIcons.smartphone, size: 14),
                    label: const Text('ADB Devices'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isDark
                          ? const Color(0xFF21262D)
                          : Colors.grey[300],
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 20),

          // iOS iproxy
          _SettingsSection(
            title: 'iOS Device (USB)',
            icon: LucideIcons.apple,
            children: [
              Text(
                'iOS real device auto-connects via WiFi (same network).\n'
                'If you need USB-only (no WiFi), install iproxy:',
                style: TextStyle(fontSize: 12, color: Colors.grey[500]),
              ),
              const SizedBox(height: 8),
              GestureDetector(
                onTap: () {
                  Clipboard.setData(
                    const ClipboardData(text: 'brew install libimobiledevice'),
                  );
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Copied to clipboard'),
                      duration: Duration(seconds: 1),
                    ),
                  );
                },
                child: MouseRegion(
                  cursor: SystemMouseCursors.click,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: isDark
                          ? const Color(0xFF161B22)
                          : const Color(0xFFF0F0F0),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: theme.dividerColor),
                    ),
                    child: Row(
                      children: [
                        const Expanded(
                          child: Text(
                            'brew install libimobiledevice',
                            style: TextStyle(
                              fontFamily: 'JetBrains Mono',
                              fontSize: 13,
                              color: ColorTokens.secondary,
                            ),
                          ),
                        ),
                        Icon(LucideIcons.copy,
                            size: 14, color: Colors.grey[500]),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 6),
              GestureDetector(
                onTap: () {
                  final port = server.isRunning
                      ? server.port
                      : AppConstants.defaultPort;
                  Clipboard.setData(
                    ClipboardData(text: 'iproxy $port $port'),
                  );
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Copied to clipboard'),
                      duration: Duration(seconds: 1),
                    ),
                  );
                },
                child: MouseRegion(
                  cursor: SystemMouseCursors.click,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: isDark
                          ? const Color(0xFF161B22)
                          : const Color(0xFFF0F0F0),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: theme.dividerColor),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            'iproxy ${server.isRunning ? server.port : AppConstants.defaultPort} ${server.isRunning ? server.port : AppConstants.defaultPort}',
                            style: const TextStyle(
                              fontFamily: 'JetBrains Mono',
                              fontSize: 13,
                              color: ColorTokens.secondary,
                            ),
                          ),
                        ),
                        Icon(LucideIcons.copy,
                            size: 14, color: Colors.grey[500]),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  ElevatedButton.icon(
                    onPressed: () async {
                      final port = server.isRunning
                          ? server.port
                          : AppConstants.defaultPort;
                      try {
                        final result = await Process.run(
                          'iproxy',
                          ['$port', '$port'],
                        );
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                result.exitCode == 0
                                    ? 'iproxy started - iOS device can connect via localhost:$port'
                                    : 'iproxy error: ${result.stderr}',
                              ),
                              backgroundColor: result.exitCode == 0
                                  ? ColorTokens.success
                                  : ColorTokens.error,
                              duration: const Duration(seconds: 3),
                            ),
                          );
                        }
                      } catch (e) {
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                  'iproxy not found. Run: brew install libimobiledevice'),
                              backgroundColor: ColorTokens.error,
                            ),
                          );
                        }
                      }
                    },
                    icon: const Icon(LucideIcons.play, size: 14),
                    label: const Text('Run iProxy'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: ColorTokens.secondary,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: ColorTokens.success.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                      color: ColorTokens.success.withValues(alpha: 0.2)),
                ),
                child: Row(
                  children: [
                    Icon(LucideIcons.wifi, size: 14, color: ColorTokens.success),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'WiFi: If your Mac and iOS device are on the same network, '
                        'the SDK auto-connects — no USB setup needed.',
                        style: TextStyle(
                          fontSize: 11,
                          color: ColorTokens.success,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Connection Guide
          _SettingsSection(
            title: 'How to Connect',
            icon: LucideIcons.circleHelp,
            children: [
              _ConnectionGuideStep(
                number: '1',
                title: 'Install SDK in your app',
                code: 'Flutter:  flutter pub add devconnect_flutter\n'
                    'RN:      yarn add devconnect-react-native\n'
                    'Android: implementation("com.github.ridelinktechs...")',
              ),
              _ConnectionGuideStep(
                number: '2',
                title: 'Init in your app code',
                code: 'Flutter:  await DevConnect.init(appName: "MyApp");\n'
                    'RN:      await DevConnect.init({ appName: "MyApp" });\n'
                    'Android: DevConnect.init(context, appName = "MyApp")',
              ),
              _ConnectionGuideStep(
                number: '3',
                title: 'Connect',
                code: 'Emulator/Simulator: auto-detect (no config needed)\n'
                    'Real device WiFi:   host: "${_networkInfos.isNotEmpty ? _networkInfos.first.ip : "your-pc-ip"}"\n'
                    'Real device USB:    click "Run ADB Reverse" above',
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

class _ConnectionGuideStep extends StatelessWidget {
  final String number;
  final String title;
  final String code;

  const _ConnectionGuideStep({
    required this.number,
    required this.title,
    required this.code,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: ColorTokens.primary.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                number,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: ColorTokens.primary,
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: isDark
                        ? const Color(0xFF161B22)
                        : const Color(0xFFF0F0F0),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: SelectableText(
                    code,
                    style: TextStyle(
                      fontFamily: 'JetBrains Mono',
                      fontSize: 11,
                      color: isDark ? const Color(0xFF8B949E) : Colors.black87,
                      height: 1.5,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _NetworkInfo {
  final String ip;
  final String interfaceName;
  final String type;

  const _NetworkInfo({
    required this.ip,
    required this.interfaceName,
    required this.type,
  });
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
