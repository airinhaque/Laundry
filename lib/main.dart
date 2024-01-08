
//import 'dart:js_interop';
import 'dart:async';
import 'dart:math';
//firebase core for initializing firebase services
import 'package:firebase_core/firebase_core.dart';
//handling cloud messaging for push notification
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
//displaying local notification
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
//import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:qr_code_scanner/qr_code_scanner.dart';
//for scanning QR code
import 'scanned_qr_screen.dart';
//uni link is handling deeplinking and url activities
import 'package:uni_links/uni_links.dart';
import 'package:flutter/services.dart' show PlatformException;
import 'package:provider/provider.dart';
import 'package:cloud_function/model_theme.dart';
import 'package:cloud_function/palette.dart';
//import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';
import 'package:giffy_dialog/giffy_dialog.dart';

String? _sharingCode;
String? machineId; 
String generatedLaundryCode = '';


//main function serves as the entry point of the application
//main fucntion ensures that flutter's UI framework is initialized using widgetflutterbinding

Future<void> main() async {
WidgetsFlutterBinding.ensureInitialized();
//initializeApp is called to initialize firebase services
await Firebase.initializeApp();
//these two are invoked to set up firebase messaging and local notification
initializeFirebaseMessaging();
initializeLocalNotifications();
//initUniLinks is callled to set up deep linking ( Initialization of deep linking)
initUniLinks();
runApp( const MyApp());
}


//This function initializes the handling of deep linking (URLs) using the Uni_links package

Future<void> initUniLinks() async {
bool kDebugMode = true;
  print('receiving intent');
//Platform messages may fail, so we use a try/catch PlatformException.
try {

//it attemps to retrieve the initial link using getInitialLink to check for incoming QR code links

//if the link is found , it extracts the  machineId using regular expression from the link data
final initialLink = await getInitialLink();
if (kDebugMode) {
  print('initialLink: $initialLink');
String? str = "";
try {
str = initialLink as String;
//RegExp exp = RegExp(r'^.*machineId(?=\=)\=(\d+)'); // For URL like (https://laundry.nyuad.io/machine.html?myname=matt&machineId=45609809895&time=now)
//RegExp exp = RegExp(r'^.*(?=\=)\=(.+)$'); // For URL like (https://laundry.nyuad.io/machine.html?machineId=machine_1)
RegExp exp = RegExp(r'machineId=(\d+)'); // For URL like (https://laundry.nyuad.io/machine.html?machineId=45609809895)



RegExpMatch? match = exp.firstMatch(str);
  print(match![1]); // "Parse"



if(match != null) {
      
      String machineId = match.group(1)!;
          // Subscribe the user to the machine using the extracted machine ID
          
          await subscribeToMachine(machineId);
          
          // Show a local notification to indicate successful subscription
          //displayScannedQrCodeNotification('Successfully subscribed to Machine ID: $machineId');
        } else {
          // If the machine ID cannot be extracted from the link, show an error notification.
         // displayScannedQrCodeNotification('Invalid QR Code');
        }
     

} catch(err) {


}
print(str);
}
// Parse the link and warn the user, if it is not correct,
// but keep in mind it could be `null`.
} on PlatformException {
if (kDebugMode) {
print('Error getting initial link');
}
// Handle exception by warning the user their action did not succeed
// return?
}
}

//This function send a post request to the cloud function URL using the http package to subscribe the user to a specific machine
//It expects a response from the server which is examined for different status code

Future<bool> subscribeToMachine(String machineId) async {
  final token = await _firebaseMessaging.getToken();

  const cloudFunctionUrl = 'https://us-central1-lively-option-392317.cloudfunctions.net/subscribeToMachine';
  final response = await http.post(
    Uri.parse(cloudFunctionUrl),
    body: {'machineId': machineId, 'token': token},
  );

  if (response.statusCode == 200) {
    // Subscription successful
    print('Subscription successful');
    return true;
  } else if (response.statusCode == 409) {
    // Machine is already in use
    print('Machine is already in use');
    return false;
  } else {
    // Subscription failed
    print('Subscription failed');
    return false;
  }
}



//_firebaseMessaging instance is  used to set up Firebase Cloud Messaging for push notification
  final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;
  FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
  FlutterLocalNotificationsPlugin();

//request permission is called to request permission from the user to recieve notification
  void initializeFirebaseMessaging() async {
    await _firebaseMessaging.requestPermission();
    await _firebaseMessaging.setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,

    );

     @override
    void initState() {
    initializeFirebaseMessaging();
    initializeLocalNotifications();
  }
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      print('Foreground Notification: ${message.notification?.title} - ${message.notification?.body}');
      displayLocalNotification(message.notification?.title, message.notification?.body);
      
    });

    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      print('Background/terminated Notification: ${message.notification?.title} - ${message.notification?.body}');
      displayLocalNotification(message.notification?.title, message.notification?.body);
    });

    FirebaseMessaging.instance.getInitialMessage().then((RemoteMessage? message) {
      if (message != null) {
        print('Closed App Notification: ${message.notification?.title} - ${message.notification?.body}');
        // Handle the notification
        displayLocalNotification(message.notification?.title, message.notification?.body);
      }
    });
  }

 void initializeLocalNotifications() {
    var initializationSettingsAndroid = const AndroidInitializationSettings('@mipmap/ic_launcher');
    var initializationSettingsIOS = const DarwinInitializationSettings(
    requestAlertPermission: true,
    requestBadgePermission: true,
    requestSoundPermission: true,);


    var initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,   iOS: initializationSettingsIOS,
    );
    flutterLocalNotificationsPlugin.initialize(initializationSettings);
  }

  Future<void> displayLocalNotification(String? title, String? body) async {
    AndroidNotificationChannel channel = AndroidNotificationChannel(
     
      Random.secure().nextInt(100000).toString(),
      'High Importance Notification',
      importance: Importance.max     
      );

    AndroidNotificationDetails androidNotificationDetails = AndroidNotificationDetails(
      channel.id.toString(),
      channel.name.toString(),
      channelDescription: 'This is a channel for high importance notification',
      importance: Importance.high,
      priority: Priority.high,
      ticker: 'ticker'
      );

const DarwinNotificationDetails darwinNotificationDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,

      );
  
      // ignore: unused_local_variable
      NotificationDetails notificationDetails = NotificationDetails(android: androidNotificationDetails
      ,iOS: darwinNotificationDetails);

    await flutterLocalNotificationsPlugin.show(
      0,
      title,
      body,
      androidNotificationDetails as NotificationDetails?,
      payload: 'notification',
    );
  }

//ListData is an inheritedWidget that provides data to its descendant widgets, holds a list of energyConsumption values and an addEnergyConsumption function

//This widget allows descendant widgets to access this data without the need to explicitly pass it down through the widget tree

class ListData extends InheritedWidget {
  final List<double> energyConsumption;
  final Function(double) addEnergyConsumption;

  ListData({
    required this.energyConsumption,
    required this.addEnergyConsumption,
    required Widget child,
  }) : super(child: child);

  static ListData of(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<ListData>()!;
  }

  @override
  bool updateShouldNotify(ListData oldWidget) {
    return energyConsumption != oldWidget.energyConsumption;
  }
}


//defines the main structure of the app using the material app widget
//uses ChangeNotifierProvider to manage the app's theme state using the ModelTheme class

class MyApp extends StatelessWidget {
const MyApp({super.key});
static const appTitle = 'Laundry';

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => ModelTheme(),
      child: Consumer<ModelTheme>(
          builder: (context, ModelTheme themeNotifier, child) {
        return MaterialApp(

          //the theme can be toggle between light and dark mode
      
          theme: themeNotifier.isDark
              ? ThemeData(
                  brightness: Brightness.dark,
                )
              : ThemeData(
                  brightness: Brightness.light,
                  primaryColor: Colors.white,
                  primarySwatch: Palette.kToDark,
                ),
          debugShowCheckedModeBanner: false,
          title: appTitle,
          //app's main screen is ScannedQRScreen
          home:const ScannedQRScreen(title: appTitle),
        );
      }),
    );
  }
}

//This class is responsible for QR code scanning screen
//It manages the QR scanner view, handling scanned data and showing notiification

@override
class QRScanScreen extends StatefulWidget {
const QRScanScreen({super.key});

@override
_QRScanScreenState createState() => _QRScanScreenState();
}

class _QRScanScreenState extends State<QRScanScreen> {
List<String> subscribedMachines = []; // List to store subscribed machine IDs

   bool qrCodeScanned = false;
  
final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;
FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
FlutterLocalNotificationsPlugin();
bool isScanning = true;



@override
void initState() {
super.initState();
initializeFirebaseMessaging();
}

void initializeFirebaseMessaging() async {
await _firebaseMessaging.requestPermission();
await _firebaseMessaging.setForegroundNotificationPresentationOptions(
alert: true,
badge: true,
sound: true,
);

FirebaseMessaging.onMessage.listen((RemoteMessage message) {
print(
'Foreground Notification: ${message.notification?.title} - ${message.notification?.body}');
displayLocalNotification(
message.notification?.title, message.notification?.body);

});


FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
print(
'Background/terminated Notification: ${message.notification?.title} - ${message.notification?.body}');
displayLocalNotification(
message.notification?.title, message.notification?.body);
});


FirebaseMessaging.instance
.getInitialMessage()
.then((RemoteMessage? message) {
if (message != null) {
print(
'Closed App Notification: ${message.notification?.title} - ${message.notification?.body}');
displayLocalNotification(
message.notification?.title, message.notification?.body);
}
});
}


void initializeLocalNotifications() {
var initializationSettingsAndroid = const AndroidInitializationSettings('@mipmap/ic_launcher');
var iosInitializationSettings = const DarwinInitializationSettings();

var initializationSettings = InitializationSettings(
android: initializationSettingsAndroid,
iOS: iosInitializationSettings,
);

flutterLocalNotificationsPlugin.initialize(initializationSettings);
}


Future<void> displayLocalNotification(String? title, String? body) async {

}

QRViewController? controller;

// @override
@override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Laundry ')),
      body: qrCodeScanned ? null : buildQRView(context),
    );
  }

//buildQRView function constructs the UI for QR code scanning using the QRView widget
//The overlay shape is defined using QrScannerOverlayShape

Widget buildQRView(BuildContext context) {

  var scanArea = ( MediaQuery.of(context).size.width < 400 ||
          MediaQuery.of(context).size.height <400)
          ? 200.0
          : 250.0;
return QRView(
key: qrKey,
onQRViewCreated: _onQRViewCreated,
overlay: QrScannerOverlayShape(
    borderColor: Colors.white,
    borderRadius:10,
    borderLength: 30,
    borderWidth: 10,
    cutOutSize: scanArea),

);
}


//_onQRViewCreated is a callback that is executed when the QR scanner view is created. It listens to scanned data and extracts the machine Id using _extractMachineIdFromQrCode

final GlobalKey qrKey = GlobalKey(debugLabel: 'QR');

  void _onQRViewCreated(QRViewController controller) async {
    this.controller = controller;
    bool hasScanned = false;
    controller.scannedDataStream.listen((scanData) async {
      if (!hasScanned && scanData.format == BarcodeFormat.qrcode) {
        hasScanned = true;
         String? qrCodeData = scanData.code;
         String? machineId = _extractMachineIdFromQrCode(qrCodeData!);
       
        // String? qrCodeData = scanData.code;
        // String? machineId = _extractMachineIdFromQrCode(qrCodeData!);

        if (machineId != null) {
           //controller.dispose();
             displayScannedQrCodeNotification('Successfully scanned Laundry Machine');
             Navigator.pop(context);
            await subscribeToMachine(machineId);
           _updateSubscribedMachinesUI(machineId);
               // Navigator.pop(context);
          //_updateMachineInUseUI(machineId);

          // Show a local notification to indicate successful subscription
        

          // Dispose the QR scanner controller
          controller.dispose();

          // Call setState to update UI
          setState(() {
            qrCodeScanned = true;

          });
          
        } else {
          _updateMachineInUseUI(machineId!);
          displayScannedQrCodeNotification('Invalid QR Code');
        }
      }
    });
  }
                    
  //        await subscribeToMachine(machineId);
         
  //         _updateSubscribedMachinesUI(machineId);

  //           Navigator.pop(context); 
  //           displayScannedQrCodeNotification('Successfully scanned Laundry Machine'); //$machineId'

       
                   

        
  //          displayScannedQrCodeNotification('Successfully scanned Laundry Machine'); //$machineId'
  //      // displayScannedQrCodeNotification('Successfully scanned machine: $machineId');
  //      // Call setState to update UI
  //         setState(() {
  //           qrCodeScanned = true;
  //         });
  

  //       } else {
  //         controller.dispose();

  //         Navigator.pop(context); 
    
  //         _updateMachineInUseUI(machineId!);
  //         displayScannedQrCodeNotification('Invalid QR Code');

  //       }
  //     }
  //   });
  // }
//_updateSubscribedMachineUI updates the UI to show  the subscribed machines 
  void _updateSubscribedMachinesUI(String machineId) {
    setState(() {
      subscribedMachines.add(machineId); // Add the machine to the list
      
    });
  }


Future<void> subscribeToMachine(String machineId) async {
  final token = await _firebaseMessaging.getToken();

  const cloudFunctionUrl = 'https://us-central1-lively-option-392317.cloudfunctions.net/subscribeToMachine';
  final response = await http.post(
    Uri.parse(cloudFunctionUrl),
    body: {'machineId': machineId, 'token': token},
  );

  if (response.statusCode == 200) {
    // Subscription successful
    print('Subscription successful');
    _updateSubscribedMachinesUI(machineId); // Update UI
    Navigator.pop(context); 
     setState(() {
      subscribedMachines.add(machineId);
    });

  } else if (response.statusCode == 409) {
    // Machine is already in use, show appropriate message to user
    print('Machine is already in use');
    _updateMachineInUseUI(machineId); // Update UI
  } else {
    // Subscription failed
    print('Subscription failed');
  }
}


// Future<bool> subscribeToMachine(String machineId) async {
//   final token = await _firebaseMessaging.getToken();

//   const cloudFunctionUrl = 'https://us-central1-lively-option-392317.cloudfunctions.net/subscribeToMachine';
//   final response = await http.post(
//     Uri.parse(cloudFunctionUrl),
//     body: {'machineId': machineId, 'token': token},
//   );

//   if (response.statusCode == 200) {
//     // Subscription successful
//     print('Subscription successful');
//     return true;
//   } else if (response.statusCode == 409) {
//     // Machine is already in use
//     print('Machine is already in use');
//    _updateSubscribedMachinesUI(machineId); // Update UI

//     return false;
//   } else {
//     // Subscription failed
//     print('Subscription failed');
//     return false;
//   }
// }



//shows a dialog when a machine is already in use
//   void _updateMachineInUseUI(String machineId) {
//   showDialog(
//     context: context,
//     builder: (context) => AlertDialog(
//       title: const Text('Machine In Use'),
//       content: Text('This laundry machine is already in use.'),
//       actions: [
//         ElevatedButton(
//           onPressed: () {
//             Navigator.pop(context);
//            Navigator.pop(context); // Go back to the previous screen
//           },
//           child: const Text('OK'),
//         ),
//       ],
//     ),
//   );
// }



void _updateMachineInUseUI(String machineId) {
  showDialog(
    context: context,
    builder: (context) => Dialog(
      child: Container(
        padding: EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.network(
              "https://i.pinimg.com/originals/3d/36/c3/3d36c36a6bd147d3b65e4de86087f9f1.gif",
              fit: BoxFit.cover,
            ),
            SizedBox(height: 16),
            Text(
              'Machine In Use',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 22.0, fontWeight: FontWeight.w600),
            ),
            SizedBox(height: 8),
            Text(
              'This laundry machine is already in use.',
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 14),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                  Navigator.pop(context);
              },
              style: ElevatedButton.styleFrom(
                primary: const Color.fromARGB(255, 104, 152, 200),
              ),
              child: Text('OK'),
            ),
          ],
        ),
      ),
    ),
  );
}




 @override
  void dispose() {
    controller?.dispose();
    super.dispose();
  }
// Function to extract the machine ID from the scanned QR code
String? _extractMachineIdFromQrCode(String qrCodeData) {


const String prefix = 'https://laundry.nyuad.io/machine.html?machineId=';
if (qrCodeData.startsWith(prefix)) {
    return qrCodeData.substring(prefix.length);
} else {
    return null;
  }
}



//new code for shaing laundry
  String generateLaundryCode() {
    final uuid = Uuid();
    return uuid.v4();
  }

 

    void showLaundryCodeDialog(String code) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Generated Laundry Code'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SelectableText('Share code with others:'),
              SelectableText(
                code,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }


//generateAndShowLaundryCode to use the stored sharing code
void generateAndShowLaundryCode() {
  if (_sharingCode != null) {
    // Use the stored sharing code if available
    showLaundryCodeDialog(_sharingCode!);
  } else {
    // Generate a new sharing code
    setState(() {
      _sharingCode = generateLaundryCode();
      showLaundryCodeDialog(_sharingCode!);
    });
  }
}

//after genearting the code it sends a post request to the cloud function tozzz

Future<void> generateAndStoreSharingCode(String machineId) async {
  final token = await _firebaseMessaging.getToken();
  final sharingCode = _sharingCode; // Generate the sharing code

if(sharingCode == null) {

  print('sharing code is missing');
  return;
}
  const cloudFunctionUrl =
      'https://us-central1-lively-option-392317.cloudfunctions.net/storeSharingCode';
  final response = await http.post(
    Uri.parse(cloudFunctionUrl),
    body: {'machineId': machineId, 'token': token, 'sharingCode': sharingCode},
  );

  if (response.statusCode == 200) {
    print('Sharing code stored successfully');
  } else {
    print('Failed to store sharing code');
  }
}


// Future<void> subscribeToMachine(String machineId) async {
//   final token = await _firebaseMessaging.getToken();
//   //  final sharingCode = generateLaundryCode(); // Generate the sharing code


//   const cloudFunctionUrl = 'https://us-central1-lively-option-392317.cloudfunctions.net/subscribeToMachine';
//   final response = await http.post(
//     Uri.parse(cloudFunctionUrl),
//    // body: {'machineId': machineId, 'token': token, 'sharingCode': sharingCode},
//    body: {'machineId': machineId, 'token': token},
//   );

//   if (response.statusCode == 200) {
//     // Subscription successful
//     print('Subscription successful');
//    // _updateSubscribedMachinesUI(machineId); // Update UI
//     //Navigator.pop(context); 
//     // setState(() {
//      // subscribedMachines.add(machineId);
//     //});

//   } else if (response.statusCode == 409) {
//     // Machine is already in use, show appropriate message to user
//     print('Machine is already in use');
//    // _updateMachineInUseUI(machineId); // Update UI
//   } else {
//     // Subscription failed
//     print('Subscription failed');
//   }
// }
// Future<void> subscribeToMachine(String machineId) async {
//   final token = await _firebaseMessaging.getToken();
//     //final sharingCode = generateLaundryCode(); // Generate the sharing code


//   const cloudFunctionUrl = 'https://us-central1-lively-option-392317.cloudfunctions.net/subscribeToMachine';
//   final response = await http.post(
//     Uri.parse(cloudFunctionUrl),
//     body: {'machineId': machineId, 'token': token},
//   );

//   if (response.statusCode == 200) {
//     // Subscription successful
//     print('Subscription successful');
//     _updateSubscribedMachinesUI(machineId); // Update UI
//     //Navigator.pop(context); 
//      setState(() {
//       subscribedMachines.add(machineId);
//     });

//   } else if (response.statusCode == 409) {
//     // Machine is already in use, show appropriate message to user
//     print('Machine is already in use');
//     _updateMachineInUseUI(machineId); // Update UI
//   } else {
//     // Subscription failed
//     print('Subscription failed');
//   }
// }


  
//displays a local notification with the QR code data
Future<void> displayScannedQrCodeNotification(String qrCodeData) async {
 AndroidNotificationChannel channel = AndroidNotificationChannel(
     
      Random.secure().nextInt(100000).toString(),
      'High Importance Notification',
      importance: Importance.high     
      );
    AndroidNotificationDetails androidNotificationDetails = AndroidNotificationDetails(
      channel.id.toString(),
      channel.name.toString(),
      channelDescription: 'This is a channel for high importance notification',
      importance: Importance.high,
      priority: Priority.high,
      ticker: 'ticker',
      icon: 'ic_notification', 
      
      );
      
const DarwinNotificationDetails darwinNotificationDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,

      );
  
      NotificationDetails notificationDetails = NotificationDetails(android: androidNotificationDetails
      ,iOS: darwinNotificationDetails);


    await flutterLocalNotificationsPlugin.show(
      0,
      'Laundry Subscription Update',
      qrCodeData,
      notificationDetails, 
      payload: 'notification',
    );
  }

  
}
