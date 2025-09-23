import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:nscgschedule/settings.dart';
import 'package:dynamic_color/dynamic_color.dart';
import 'package:get_it/get_it.dart';
import 'package:nscgschedule/notifications.dart';
import 'package:package_info_plus/package_info_plus.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  bool _isDarkMode = false;
  bool _useSystemTheme = true;
  bool _useMaterialYou = true;
  bool _notificationsEnabled = true;
  bool _notifyOnStartTime = true;
  bool _notifyMinutesBeforeEnabled = true;
  int _notifyMinutesBefore = 5;
  bool _supportsMaterialYou = false;
  PackageInfo? _packageInfo;
  late final ValueNotifier<ThemeMode> _themeNotifier;
  final _materialYouNotifier = ValueNotifier<bool>(false);
  final TextEditingController _minutesBeforeController =
      TextEditingController();
  final TextEditingController _testMinutesController = TextEditingController(
    text: '1',
  );
  bool _debugMode = false;

  @override
  void initState() {
    super.initState();
    _themeNotifier = ValueNotifier(ThemeMode.system);
    _loadPreferences().then((_) {
      // Check Material You support after loading preferences
      if (mounted) {
        setState(() {
          _materialYouNotifier.value = _useMaterialYou;
        });
      }
    });
    init();
  }

  Future<void> init() async {
    final debugMode = await settings.getBool('debugMode');
    setState(() {
      _debugMode = debugMode;
    });
  }

  @override
  void dispose() {
    _themeNotifier.dispose();
    _materialYouNotifier.dispose();
    _minutesBeforeController.dispose();
    _testMinutesController.dispose();
    super.dispose();
  }

  Future<void> _loadPreferences() async {
    _useSystemTheme = await settings.getUseSystemTheme();
    _isDarkMode = await settings.getDarkMode();
    _useMaterialYou = await settings.getUseMaterialYou();
    _notificationsEnabled = await settings.getNotificationsEnabled();
    _notifyOnStartTime = await settings.getNotifyOnStartTime();
    _notifyMinutesBeforeEnabled = await settings
        .getNotifyMinutesBeforeEnabled();
    _notifyMinutesBefore = await settings.getNotifyMinutesBefore();
    _minutesBeforeController.text = _notifyMinutesBefore.toString();
    _packageInfo = await PackageInfo.fromPlatform();

    if (mounted) {
      setState(() {
        _themeNotifier.value = _useSystemTheme
            ? ThemeMode.system
            : _isDarkMode
            ? ThemeMode.dark
            : ThemeMode.light;
      });
    }
  }

  Future<void> _updateTheme(bool isDarkMode) async {
    await settings.setDarkMode(isDarkMode);
    if (mounted) {
      setState(() {
        _isDarkMode = isDarkMode;
        if (!_useSystemTheme) {
          _themeNotifier.value = isDarkMode ? ThemeMode.dark : ThemeMode.light;
        }
      });
    }
  }

  Future<void> _updateSystemTheme(bool useSystem) async {
    await settings.setUseSystemTheme(useSystem);
    if (mounted) {
      setState(() {
        _useSystemTheme = useSystem;
        _themeNotifier.value = useSystem
            ? ThemeMode.system
            : _isDarkMode
            ? ThemeMode.dark
            : ThemeMode.light;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      body: DynamicColorBuilder(
        builder: (lightDynamic, darkDynamic) {
          final supportsMaterialYou =
              lightDynamic != null && darkDynamic != null;
          if (_supportsMaterialYou != supportsMaterialYou) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) {
                setState(() {
                  _supportsMaterialYou = supportsMaterialYou;
                  if (!_supportsMaterialYou) {
                    _materialYouNotifier.value = false;
                    settings.setUseMaterialYou(false);
                  }
                });
              }
            });
          }

          return ListView(
            children: [
              const Padding(
                padding: EdgeInsets.all(16.0),
                child: Text(
                  'Appearance',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
              ValueListenableBuilder<ThemeMode>(
                valueListenable: _themeNotifier,
                builder: (context, themeMode, _) {
                  return Column(
                    children: [
                      ValueListenableBuilder<bool>(
                        valueListenable: _materialYouNotifier,
                        builder: (context, useMaterialYou, _) {
                          return SwitchListTile(
                            title: const Text('Material You'),
                            subtitle: _supportsMaterialYou
                                ? const Text(
                                    'Use dynamic theming based on wallpaper',
                                  )
                                : const Text(
                                    'Not supported on this device',
                                    style: TextStyle(color: Colors.grey),
                                  ),
                            value: _supportsMaterialYou && useMaterialYou,
                            onChanged: _supportsMaterialYou
                                ? (value) async {
                                    await settings.setUseMaterialYou(value);
                                    if (mounted) {
                                      setState(() {
                                        _useMaterialYou = value;
                                        _materialYouNotifier.value = value;
                                      });
                                    }
                                  }
                                : null,
                            secondary: Icon(
                              Icons.palette,
                              color: _supportsMaterialYou ? null : Colors.grey,
                            ),
                          );
                        },
                      ),
                      SwitchListTile(
                        title: const Text('Use System Theme'),
                        subtitle: const Text('Match system light/dark theme'),
                        value: _useSystemTheme,
                        onChanged: _updateSystemTheme,
                        secondary: const Icon(Icons.phone_android),
                      ),
                      AnimatedOpacity(
                        duration: const Duration(milliseconds: 200),
                        opacity: _useSystemTheme ? 0.6 : 1.0,
                        child: IgnorePointer(
                          ignoring: _useSystemTheme,
                          child: SwitchListTile(
                            title: const Text('Dark Mode'),
                            subtitle: _useSystemTheme
                                ? const Text('Using system theme')
                                : const Text('Toggle dark mode'),
                            value: _isDarkMode,
                            onChanged: _updateTheme,
                            secondary: Icon(
                              _isDarkMode ? Icons.dark_mode : Icons.light_mode,
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
              const Divider(),
              const Padding(
                padding: EdgeInsets.all(16.0),
                child: Text(
                  'Notifications',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
              SwitchListTile(
                title: const Text('Enable Notifications'),
                value: _notificationsEnabled,
                onChanged: (value) async {
                  await settings.setNotificationsEnabled(value);
                  setState(() {
                    _notificationsEnabled = value;
                  });
                },
                secondary: const Icon(Icons.notifications),
              ),
              SwitchListTile(
                title: const Text('Notify on lesson start'),
                value: _notifyOnStartTime,
                onChanged: _notificationsEnabled
                    ? (value) async {
                        await settings.setNotifyOnStartTime(value);
                        setState(() {
                          _notifyOnStartTime = value;
                        });
                      }
                    : null,
                secondary: const Icon(Icons.timer),
              ),
              SwitchListTile(
                title: const Text('Enable "minutes before" notification'),
                value: _notifyMinutesBeforeEnabled,
                onChanged: _notificationsEnabled
                    ? (value) async {
                        await settings.setNotifyMinutesBeforeEnabled(value);
                        setState(() {
                          _notifyMinutesBeforeEnabled = value;
                        });
                      }
                    : null,
                secondary: const Icon(Icons.timer_10),
              ),
              ListTile(
                leading: const SizedBox(width: 0),
                title: const Text('Minutes before (custom)'),
                subtitle: const Text('Enter any number of minutes'),
                trailing: SizedBox(
                  width: 100,
                  child: TextField(
                    controller: _minutesBeforeController,
                    enabled:
                        _notificationsEnabled && _notifyMinutesBeforeEnabled,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      hintText: 'e.g. 7',
                      isDense: true,
                    ),
                    onSubmitted: (value) async {
                      final parsed = int.tryParse(value.trim());
                      if (parsed != null && parsed >= 0 && parsed <= 240) {
                        await settings.setNotifyMinutesBefore(parsed);
                        setState(() {
                          _notifyMinutesBefore = parsed;
                        });
                      } else {
                        // Reset to current valid value
                        _minutesBeforeController.text = _notifyMinutesBefore
                            .toString();
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Please enter a valid number between 0 and 240',
                            ),
                          ),
                        );
                      }
                    },
                  ),
                ),
              ),
              if (_debugMode) ...[
                const Divider(),
                // Debug and actions
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Text(
                    'Notification Tools',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                ListTile(
                  leading: const Icon(Icons.refresh),
                  title: const Text('Reschedule notifications'),
                  subtitle: const Text(
                    'Recreates all notifications from current timetable and settings',
                  ),
                  onTap: () async {
                    final ns = GetIt.I<NotificationService>();
                    ns.requestReschedule();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Reschedule requested')),
                    );
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.list),
                  title: const Text('List pending notifications'),
                  onTap: () async {
                    final ns = GetIt.I<NotificationService>();
                    final pending = await ns.getPendingNotifications();
                    if (!context.mounted) return;
                    showDialog(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: Text('Pending (${pending.length})'),
                        content: SizedBox(
                          width: double.maxFinite,
                          child: SingleChildScrollView(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: pending
                                  .map(
                                    (p) => Padding(
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 4.0,
                                      ),
                                      child: Text(
                                        '#${p.id}: ${p.title ?? ''} — ${p.body ?? ''}',
                                      ),
                                    ),
                                  )
                                  .toList(),
                            ),
                          ),
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.of(ctx).pop(),
                            child: const Text('Close'),
                          ),
                        ],
                      ),
                    );
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.delete_forever),
                  title: const Text('Cancel all notifications'),
                  onTap: () async {
                    final ns = GetIt.I<NotificationService>();
                    await ns.cancelAllNotifications();
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('All notifications cancelled'),
                      ),
                    );
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.notifications_active),
                  title: const Text('Schedule test notification'),
                  subtitle: const Text(
                    'Schedules a single test notification in N minute(s)',
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: 50,
                        child: TextField(
                          controller: _testMinutesController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            isDense: true,
                            hintText: '1',
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: () async {
                          final ns = GetIt.I<NotificationService>();
                          final m =
                              int.tryParse(
                                _testMinutesController.text.trim(),
                              ) ??
                              1;
                          await ns.scheduleTestNotification(minutesFromNow: m);
                          if (!context.mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                'Test notification scheduled in $m minute(s)',
                              ),
                            ),
                          );
                        },
                        child: const Text('Go'),
                      ),
                    ],
                  ),
                ),
              ],
              const Divider(),
              ListTile(
                leading: const Icon(Icons.update),
                title: const Text('Update'),
                subtitle: Text('Your up to date'),
                trailing: const Icon(Icons.arrow_forward_ios),
                // subtitle: Text(_packageInfo?.version ?? 'Loading...'),
              ),
              ListTile(
                title: const Text('About'),
                subtitle: const Text('App version 1.0.0'),
                leading: const Icon(Icons.info_outline),
                trailing: _debugMode
                    ? Badge(
                        padding: const EdgeInsets.all(4),
                        isLabelVisible: true,
                        label: Text('Debug Enabled'),
                      )
                    : null,
                onTap: () {
                  // Show about dialog
                  showAboutDialog(
                    context: context,
                    applicationName: 'NSCG Schedule',
                    applicationVersion: _packageInfo?.version ?? 'Loading...',
                    applicationIcon: const Center(child: FlutterLogo(size: 55)),
                    children: [
                      Text('A Schedule/TimeTable app for NSCG students'),
                    ],
                  );
                },
                onLongPress: () async {
                  if (await settings.getBool('debugMode')) {
                    settings.setBool('debugMode', false);
                    setState(() {
                      _debugMode = false;
                    });
                  } else {
                    settings.setBool('debugMode', true);
                    setState(() {
                      _debugMode = true;
                    });
                  }
                },
              ),
            ],
          );
        },
      ),
    );
  }
}
