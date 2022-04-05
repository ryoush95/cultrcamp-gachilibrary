import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';
// import 'package:webview_cookie_manager/webview_cookie_manager.dart';

import 'constants.dart';
import 'js_channels.dart';


final _initialUrl = "https://sogeum21.cafe24.com/";
/// Define a top-level named handler which background/terminated messages will
/// call.
///
/// To verify things are working, check out the native platform logs.
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // If you're going to use other Firebase services in the background, such as Firestore,
  // make sure you call `initializeApp` before using other Firebase services.
  await Firebase.initializeApp();
  print('Handling a background message ${message.messageId}');
  debugPrint("BG FCM MSG: $message");
}

/// Create a [AndroidNotificationChannel] for heads up notifications
const AndroidNotificationChannel channel = AndroidNotificationChannel(
  'high_importance_channel', // id
  'High Importance Notifications', // title
  'This channel is used for important notifications.', // description
  importance: Importance.high,
);

/// Initialize the [FlutterLocalNotificationsPlugin] package.
final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
FlutterLocalNotificationsPlugin();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();

  // Set the background messaging handler early on, as a named top-level function
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  /// Create an Android Notification Channel.
  ///
  /// We use this channel in the `AndroidManifest.xml` file to override the
  /// default FCM channel to enable heads up notifications.
  await flutterLocalNotificationsPlugin.resolvePlatformSpecificImplementation<
      AndroidFlutterLocalNotificationsPlugin>()
      ?.createNotificationChannel(channel);

  /// Update the iOS foreground notification presentation options to allow
  /// heads up notifications.
  await FirebaseMessaging.instance.setForegroundNotificationPresentationOptions(
    alert: true,
    badge: true,
    sound: true,
  );

  runApp(Application());
}

class Application extends StatelessWidget {
  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'LawnTennis',
      theme: ThemeData(
        // This is the theme of your application.
        //
        // Try running your application with "flutter run". You'll see the
        // application has a blue toolbar. Then, without quitting the app, try
        // changing the primarySwatch below to Colors.green and then invoke
        // "hot reload" (press "r" in the console where you ran "flutter run",
        // or simply save your changes to "hot reload" in a Flutter IDE).
        // Notice that the counter didn't reset back to zero; the application
        // is not restarted.
        primarySwatch: Colors.blue,
      ),
      home: WebViewPage(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class WebViewPage extends StatefulWidget {
  @override
  State<StatefulWidget> createState() => _WebViewPageState();
}

class _WebViewPageState extends State<WebViewPage> {

  final Completer<WebViewController> _webViewController = Completer();
  // final cookieman = WebviewCookieManager();
  int backClickTime = 0;
  String? _fcmToken = "";

  Future<String> _getInitialUrl() async {
    // TODO: 권한 체크 되면 바로 메인페이지로 갈지 확인
    return Permission.notification.isGranted.then((value) {
      debugPrint("Permission.notification::$value");
      String _initialUrl;
      if(value) {
        _initialUrl = "${Constants.baseUrl}${Constants.mainPage}";
        debugPrint("notification.isGranted: $_initialUrl");
      } else {
        _initialUrl = "${Constants.baseUrl}${Constants.permissionPage}";
        debugPrint("!notification.isGranted: $_initialUrl");
      }
      return Future.value("${Constants.baseUrl}${Constants.mainPage}");
    });
  }

  @override
  void initState() {
    // TODO: implement initState
    super.initState();
    FirebaseMessaging.instance
        .getInitialMessage()
        .then((RemoteMessage? message) {
      if (message != null) {
        debugPrint("INITIAL FCM: $message");
      }
    });

    FirebaseMessaging.instance.subscribeToTopic("noti").then((value) {
      debugPrint("fcm Topic subscribed: noti");
    });
    if(kDebugMode) {
      FirebaseMessaging.instance.subscribeToTopic("test").then((value) {
        debugPrint("fcm Topic subscribed: test");
      });
    }

    FirebaseMessaging.onMessage.listen((RemoteMessage? message) {
      debugPrint("ONMESSAGE: $message");
      if(message != null) {
        RemoteNotification? notification = message.notification;
        AndroidNotification? android = message.notification?.android;

        if (notification != null && android != null) {
          flutterLocalNotificationsPlugin.show(
              notification.hashCode,
              notification.title,
              notification.body,
              NotificationDetails(
                android: AndroidNotificationDetails(
                  channel.id,
                  channel.name,
                  channel.description,
                  // TODO add a proper drawable resource to android, for now using
                  //      one that already exists in example app.
                  icon: 'ic_launcher',
                ),
              ));
        }
      }
    });


    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      print('A new onMessageOpenedApp event was published!');
    });

    FirebaseMessaging.instance.getToken().then((token) async{
      debugPrint("onFcmToken: $token");
      _fcmToken = token;
      dynamic ret = _webViewController.future.then((controller) {
        controller.evaluateJavascript("""
                  fn_set_fcmkey("$_fcmToken");
                """);
      });
    });

    if (Platform.isAndroid) WebView.platform = SurfaceAndroidWebView();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      bottom: false,
      maintainBottomViewPadding: true,
      child: Container(
        width: double.infinity,
        height: double.infinity,
        child: WillPopScope(
          child: WebView(
            javascriptMode: JavascriptMode.unrestricted,
            onWebViewCreated: (controller) async {
              if(!_webViewController.isCompleted) {
                _webViewController.complete(controller);
              }
              // await cookieman.setCookies([
              //   Cookie('loginname', 'loginvalue')
              //   ..domain = Constants.domain
              //   ..expires = DateTime.now().add(Duration(minutes: 3))
              //   ..httpOnly = false
              // ]);
              _getInitialUrl().then((value) => controller.loadUrl(value));
            },
            onPageFinished: (url) async {
              if(url.contains(Constants.mainPage)) {
                dynamic ret = _webViewController.future.then((controller) {
                  controller.evaluateJavascript("""
                  fn_set_fcmkey("$_fcmToken");
                """);
                });
              }
              // final gotCookie = await cookieman.getCookies(url);
              // for (var item in gotCookie){
              //   print(item);
              // }
            },
            onPageStarted: (url) async {
              debugPrint("onPageStarted: $url");
              debugPrint("Cookie:${await (await _webViewController.future).evaluateJavascript('document.cookie')}");
            },
            onWebResourceError: (error) {
              debugPrint("onWebResourceError: $error");
            },
            navigationDelegate: (request) async {
              debugPrint("navigationDelegate::next: ${request.url}");
              debugPrint("navigationDelegate::current ${(await (await _webViewController.future).currentUrl())}");
              if(request.url.startsWith(Constants.baseUrl)) {
                if(request.url.contains("permission.php")) {
                  if(await Permission.notification.isGranted &&
                      await Permission.phone.isGranted) {
                    debugPrint("permission permitted");
                    return NavigationDecision.prevent;
                  } else {
                    debugPrint("permission not permitted");
                    return NavigationDecision.navigate;
                  }
                } else {
                  debugPrint("go");
                  return NavigationDecision.navigate;
                }
              } else {
                debugPrint("outside service");
                launch(request.url);
                return NavigationDecision.prevent;
              }
            },
            javascriptChannels: JavascriptChannels.toSets(context),
            gestureNavigationEnabled: true,
            debuggingEnabled: kDebugMode,
          ),
          onWillPop: () => _webViewController.future.then((controller) {
            return controller.currentUrl().then((currentUrl) {
              debugPrint("value.currentUrl() $currentUrl");
              if (currentUrl != null) {
                if (!currentUrl.contains(Constants.mainPage)) {
                  controller.loadUrl(
                      "${Constants.baseUrl}${Constants.mainPage}");
                  return false;
                } else {
                  var now = DateTime
                      .now()
                      .millisecondsSinceEpoch;
                  debugPrint("Back Click Time: ${now - backClickTime}");
                  if (now - backClickTime < 5000) {
                    return true;
                  } else {
                    backClickTime = now;
                    Fluttertoast.showToast(
                        msg: "한번 더 뒤로가기를 누르면 종료됩니다.",
                        toastLength: Toast.LENGTH_LONG,
                        gravity: ToastGravity.BOTTOM,
                        timeInSecForIosWeb: 1,
                        backgroundColor: Colors.black,
                        textColor: Colors.white,
                        fontSize: 16.0
                    );
                    return false;
                  }
                }
              } else {
                return false;
              }
            });
          }),
        ),
      ),
    ),
  );
}