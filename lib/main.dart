import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';

int id = 0;
final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();
final StreamController<String?> selectNotificationStream = StreamController<String?>.broadcast();
const String navigationActionId = 'id_3';

@pragma('vm:entry-point')
void notificationTapBackground(NotificationResponse notificationResponse) {
  // ignore: avoid_print
  print('notification(${notificationResponse.id}) action tapped: '
      '${notificationResponse.actionId} with'
      ' payload: ${notificationResponse.payload}');
  if (notificationResponse.input?.isNotEmpty ?? false) {
    // ignore: avoid_print
    print('notification action tapped with input: ${notificationResponse.input}');
  }
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final LinuxInitializationSettings initializationSettingsLinux = LinuxInitializationSettings(
    defaultActionName: 'Open notification',
    defaultIcon: AssetsLinuxIcon('icons/app_icon.png'),
  );
  final InitializationSettings initializationSettings = InitializationSettings(linux: initializationSettingsLinux);
  await flutterLocalNotificationsPlugin.initialize(
    initializationSettings,
    onDidReceiveNotificationResponse: (NotificationResponse notificationResponse) {
      switch (notificationResponse.notificationResponseType) {
        case NotificationResponseType.selectedNotification:
          selectNotificationStream.add(notificationResponse.payload);
          break;
        case NotificationResponseType.selectedNotificationAction:
          if (notificationResponse.actionId == navigationActionId) {
            selectNotificationStream.add(notificationResponse.payload);
          }
          break;
      }
    },
    onDidReceiveBackgroundNotificationResponse: notificationTapBackground,
  );
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      navigatorObservers: [FlutterSmartDialog.observer],
      builder: FlutterSmartDialog.init(),
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      darkTheme: ThemeData.dark(useMaterial3: true),
      themeMode: ThemeMode.system,
      home: const MyHomePage(),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key});

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  int _counter = 0;
  void _incrementCounter() {
    setState(() {
      _counter++;
    });
    _showNotification(title: _counter.toString(), body: _counter.toString());
    SmartDialog.showToast('$_counter');
  }

  Future<void> _showNotification({String title = 'plain titleplain title', String body = 'plain body'}) async {
    const AndroidNotificationDetails androidNotificationDetails = AndroidNotificationDetails(
        'your channel id', 'your channel name',
        channelDescription: 'your channel description',
        importance: Importance.max,
        priority: Priority.high,
        ticker: 'ticker');
    const NotificationDetails notificationDetails = NotificationDetails(android: androidNotificationDetails);
    await flutterLocalNotificationsPlugin.show(id++, title, body, notificationDetails, payload: 'item x');
  }

  @override
  void initState() {
    isLoadNBD();
    super.initState();
  }

  var is_nbd_module_load = false;
  Future<void> isLoadNBD() async {
    var result = await runLinuxScript('ls', ['/dev/nbd*']);
    is_nbd_module_load = result == 0;
    setState(() {});
  }

  Future<void> loadNBDModule() async {
    var result = await runLinuxScript('pkexec', ['modprobe', 'nbd']);
    setState(() {});
  }

  List<String> prints = [];
  var vd1 = TextEditingController();
  bool isMounting = false;

  Future<int> runLinuxScript(String scriptPath, List<String> arguments) async {
    // prints = ['$scriptPath ${arguments.join(' ')}'];
    prints = ['/usr/bin/bash -c \'$scriptPath ${arguments.join(' ')}\''];
    // 使用ProcessStart信息来配置脚本执行
    // final process = await Process.start(scriptPath, arguments, runInShell: true);
    final process = await Process.start('/bin/sh', ['-c', '\'$scriptPath ${arguments.join(' ')}\'']);

    // 监听脚本的stdout
    process.stdout.transform(Utf8Decoder()).listen((ob_) {
      prints.add(ob_);
    });

    // 监听脚本的stderr
    process.stderr.transform(Utf8Decoder()).listen((ob_) {
      prints.add(ob_);
    });
    // 等待脚本执行完成
    var result = await process.exitCode;
    prints.add('exitCode: $result');
    return result;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: DefaultTabController(
        length: 3,
        child: Scaffold(
          body: Container(
            padding: EdgeInsets.all(10),
            child: Column(
              children: [
                Expanded(
                  child: Column(
                    children: [
                      if (is_nbd_module_load)
                        ListTile(
                          leading: const Icon(Icons.check_circle_sharp, color: Colors.green),
                          title: const Text('The nbd module is loaded'),
                          trailing: TextButton(
                            onPressed: () async {
                              var result = await runLinuxScript('modprobe', ['-r', 'nbd']);
                              setState(() {});
                            },
                            child: const Text('unload'),
                          ),
                        ),
                      if (!is_nbd_module_load)
                        ListTile(
                          leading: const Icon(Icons.warning, color: Colors.amber),
                          title: const Text('The nbd module is not loaded'),
                          trailing: TextButton(onPressed: loadNBDModule, child: const Text('load')),
                        ),
                      TextField(
                        controller: vd1,
                        decoration: InputDecoration(
                            hintText: ('disk file'),
                            labelText: '/dev/nbd0',
                            helperText: 'qemu-nbd -c /dev/nbdX /path/to/file',
                            suffix: isMounting
                                ? const CircularProgressIndicator()
                                : TextButton(
                                    onPressed: () async {
                                      setState(() {
                                        isMounting = true;
                                      });
                                      SmartDialog.showLoading(msg: '挂载中...');
                                      var file = vd1.text;
                                      if (File(file).existsSync()) {
                                        await runLinuxScript('qemu-nbd', ['-c', '/dev/nbd0', file]);
                                        await SmartDialog.dismiss();
                                      } else {
                                        await SmartDialog.dismiss();
                                        await SmartDialog.showNotify(msg: '文件不存在！', notifyType: NotifyType.failure);
                                      }
                                      setState(() {
                                        isMounting = false;
                                      });
                                    },
                                    child: const Text('mount'))),
                      ),
                    ],
                  ),
                ),
                Container(
                  alignment: Alignment.topLeft,
                  height: 180,
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: prints.map((e) => Text(e)).cast<Text>().toList(),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _incrementCounter,
        tooltip: 'Increment',
        child: const Icon(Icons.add),
      ),
    );
  }
}
