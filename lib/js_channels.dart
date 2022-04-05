import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter/webview_flutter.dart';

class JavascriptChannels {

  static Set<JavascriptChannel> toSets(BuildContext context) {
    return [
      _makeToast(context),
      _requestPermissions(context),
      _requestCall(context)
    ].toSet();
  }

  static JavascriptChannel _makeToast(BuildContext context) => JavascriptChannel(
      name: "MakeToast",
      onMessageReceived: (message) {
        Fluttertoast.showToast(
            msg: message.message,
            toastLength: Toast.LENGTH_LONG,
            gravity: ToastGravity.BOTTOM,
            timeInSecForIosWeb: 1,
            backgroundColor: Colors.black,
            textColor: Colors.white,
            fontSize: 16.0
        );
      }
  );

  static JavascriptChannel _requestPermissions(BuildContext context) => JavascriptChannel(
      name: "ReqPermission",
      onMessageReceived: (message) async {
        debugPrint("ReqPermission");
        Map<Permission, PermissionStatus> statuses = await [
          Permission.phone,
          Permission.notification,
        ].request();
      }
  );

  static JavascriptChannel _requestCall(BuildContext context) => JavascriptChannel(
      name: "ReqCall",
      onMessageReceived: (message) async {
        String telUrl = message.message;
        if(!telUrl.startsWith("tel:")) {
          telUrl = "tel:$telUrl";
        }
        launch(telUrl);
      }
  );
}