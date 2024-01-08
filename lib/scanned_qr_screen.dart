import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_function/model_theme.dart';
import 'main.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/widgets.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import 'package:flutter/cupertino.dart';


class CustomDragHandleIcon extends StatelessWidget {
  final VoidCallback onDragHandlePressed;

  const CustomDragHandleIcon({
    required this.onDragHandlePressed,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onLongPress: onDragHandlePressed,
      child: Icon(Icons.drag_handle),
    );
  }
}

class ShowWelcomeMessage extends StatelessWidget {
  final bool showWelcomeMessage;
  final VoidCallback onClose;

  const ShowWelcomeMessage({
    required this.showWelcomeMessage,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    final themeNotifier = Provider.of<ModelTheme>(context, listen: false);

    return showWelcomeMessage
        ? Align(
            alignment: Alignment.center,
            child: Container(
              margin: const EdgeInsets.all(16.0),
              padding: const EdgeInsets.all(16.0),
              decoration: BoxDecoration(
                color: themeNotifier.isDark ? Colors.black : Colors.white,
                borderRadius: BorderRadius.circular(8.0),
                boxShadow: const [
                  BoxShadow(
                    color: Colors.black12,
                    offset: Offset(0, 2),
                    blurRadius: 4.0,
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                   Image.asset('assets/images/homescreen.png', width: 150.0),
                  const SizedBox(height: 16.0),
                  const Text(
                    'Scan, Subscribe, Stay Updated!',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16.0,
                   
                    ),
                  ),
                  const SizedBox(height: 8.0),
                  const Text(
                    'Manage your laundry with ease.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      
                    ),
                  ),
                  const SizedBox(height: 16.0),
                  ElevatedButton(
                    onPressed: onClose,
                    child: const Text('Close'),
                  ),
                ],
              ),
            ),
          )
        : SizedBox.shrink();
  }
}


// class ScannedQRScreen extends StatefulWidget {
//   const ScannedQRScreen({super.key, required this.title});

//   final String title;
//   @override
//   State<ScannedQRScreen> createState() =>_ScannedQRScreenState();
// }
class ScannedQRScreen extends StatefulWidget {
  const ScannedQRScreen({Key? key, required this.title}) : super(key: key);

  final String title;

  @override
  State<ScannedQRScreen> createState() => _ScannedQRScreenState();
}

class _ScannedQRScreenState extends State<ScannedQRScreen> {
 bool _showWelcomeMessage = true;
 bool isReorderingWithDragHandle = false;
  List<String> subscribedMachines = [];
  String generatedLaundryCode = '';
  String? _sharingCode;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  List<String> energyConsumption = []; // List to store the data of the listview
  final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;
  SharedPreferences? _prefs;



    @override
    void initState() {
    super.initState();
    // _loadSavedData(); // Load data during initialization
    _loadData() ;

    initializeFirebaseMessaging();

    //Firestore listener
    subscribeToSubscription();
   _checkWelcomeMessage(); 

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
              const SelectableText('Share this code with others:'),
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


Future<void> unsubscribeFromMachineCloudFunction(String machineId, int index) async {
  final token = await _firebaseMessaging.getToken();
  const cloudFunctionUrl = 'https://us-central1-lively-option-392317.cloudfunctions.net/unsubscribeFromMachine';
  
  final response = await http.post(
    Uri.parse(cloudFunctionUrl),
    body: {'machineId': machineId, 'token': token},
  );

  if (response.statusCode == 200) {
    // Unsubscription successful
    print('Unsubscription successful');
    setState(() {
      energyConsumption.removeAt(index);
    });
    _saveData(); // Save updated energyConsumption list
  } else {
    // Unsubscription failed
    print('Unsubscription failed');
  }
}

void _showUnsubscribeConfirmationSnackBar(BuildContext context, int index, String machineId) async {
  await unsubscribeFromMachineCloudFunction(machineId, index);

  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(
      content: Text('You have successfully unsubscribed.'),
      duration: Duration(seconds: 10),
    ),
  );
}


Future<void> _loadData() async {
  _prefs = await SharedPreferences.getInstance();
  setState(() {
    _showWelcomeMessage = _prefs!.getBool('showWelcomeMessage') ?? true;
    energyConsumption = _prefs!.getStringList('energyConsumption') ?? [];
    subscribedMachines = _prefs!.getStringList('subscribedMachines') ?? [];
  });
}

 

  void _saveData() async {
  if (_prefs != null) {
    await _prefs!.setStringList('energyConsumption', energyConsumption);
    await _prefs!.setStringList('subscribedMachines', subscribedMachines);
  }
}

  void initializeFirebaseMessaging() async {
    await _firebaseMessaging.requestPermission();
    await _firebaseMessaging.setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );




FirebaseMessaging.onMessage.listen((RemoteMessage message) {
  print('Foreground Notification: ${message.notification?.title} - ${message.notification?.body}');
  setState(() {
    if (message.data.containsKey('energyConsumption')) {
      String newEnergyConsumption = message.data['energyConsumption'];
      energyConsumption.add(newEnergyConsumption);
      displayLocalNotification(message.notification?.title, message.notification?.body);
      _saveData();
    }
  });
});

FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
  print('Background/terminated Notification: ${message.notification?.title} - ${message.notification?.body}'); 
  // Update your app's UI here when the user opens the app from a notification
  setState(() {
    // notification data contains a key called 'energyConsumption'
    if (message.data.containsKey('energyConsumption')) {
      String newEnergyConsumption = message.data['energyConsumption'];
      energyConsumption.add(newEnergyConsumption);
      displayLocalNotification(message.notification?.title, message.notification?.body);
      _saveData();
    }
  });
});

_firebaseMessaging.getInitialMessage().then((RemoteMessage? message) {
  if (message != null) {
    print('Closed App Notification: ${message.notification?.title} - ${message.notification?.body}');

    // Update your app's UI here when the user opens the app from a closed state using a notification
    setState(() {
      // notification data contains a key called 'energyConsumption'
      if (message.data.containsKey('energyConsumption')) {
        String newEnergyConsumption = message.data['energyConsumption'];
        energyConsumption.add(newEnergyConsumption);
        displayLocalNotification(message.notification?.title, message.notification?.body);
        _saveData();
      }
    });
  }
});
  }

void subscribeToSubscription() {
  //String subscriptionId = 'machineId';
  _firestore.collection('subscriptions').doc(machineId).snapshots().listen((DocumentSnapshot snapshot) {
    if (snapshot.exists) {
      Map<String, dynamic>? data = snapshot.data() as Map<String, dynamic>?;
      if (data != null && data.containsKey('energyConsumption')) {
        String newEnergyConsumption = data['energyConsumption'];
        setState(() {
          energyConsumption.add(newEnergyConsumption);
        });
        _saveData();
      }
    }
  });
}


// this part - not connecting with firebase

//new code for shaing laundry
  String generateLaundryCode() {
    final uuid = Uuid();
    return uuid.v4();
  }

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



// Modify acceptInvitationAndSubscribe to use the stored sharing code
Future<void> acceptInvitationAndSubscribe(String inputCode) async {
  final token = await _firebaseMessaging.getToken();
  final sharingCode = inputCode;

  const cloudFunctionUrl =
      'https://us-central1-lively-option-392317.cloudfunctions.net/acceptInvitationAndSubscribe';
  final response = await http.post(
    Uri.parse(cloudFunctionUrl),
    body: {'sharingCode': sharingCode, 'token': token},
  );

  if (response.statusCode == 200) {
    print('Subscription successful');
    setState(() {
      subscribedMachines.add(inputCode);
    });
    Navigator.pop(context);
  } else if (response.statusCode == 404) {
    // Sharing code not found, show appropriate message to user
    print('Sharing code not found');
    // Show an error message
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Invalid or expired laundry code.'),
      ),
    );
  } else {
    // Subscription failed
    print('Subscription failed');
  }
}



String? machineId; // general machineId variable, remove 

@override
Widget build(BuildContext context) {
  return Consumer<ModelTheme>(
    builder: (context, ModelTheme themeNotifier, child) {
      return Scaffold(
        appBar: AppBar(title: Text(widget.title)),
        body: Column(
          children: [
            if (_showWelcomeMessage)
              // Align(
              //   alignment: Alignment.center,
              //   child: Image.asset('assets/images/washing_machine .png'),
              // ),
            Align(
            alignment: Alignment.center,
            child: Container(
              margin: const EdgeInsets.all(16.0),
              padding: const EdgeInsets.all(16.0),
              decoration: BoxDecoration(
                color: themeNotifier.isDark ? Colors.black : Colors.white,
                borderRadius: BorderRadius.circular(8.0),
                boxShadow: const [
                  BoxShadow(
                    color: Colors.black12,
                    offset: Offset(0, 2),
                    blurRadius: 4.0,
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Image.asset('assets/images/homescreen.png', width: 150.0),
                  const SizedBox(height: 16.0),
                  const Text(
                      'Scan, Subscribe, Stay Updated!',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16.0,
                   
                    ),
                  ),
                  const SizedBox(height: 8.0),
                  const Text(
                    'Manage your laundry with ease.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      
                    ),
                  ),
                  const SizedBox(height: 16.0),
                  // ElevatedButton(
                  //   onPressed: onClose,
                  //   child: const Text('Close'),
                  // ),
                ],
              ),
            ),
          ),
            if (subscribedMachines.isNotEmpty) Divider(),
            if (subscribedMachines.isNotEmpty)
              Expanded(
                child: ListView.builder(
                  itemCount: subscribedMachines.length,
                  itemBuilder: (context, index) {
                    return ListTile(
                      title: Text('Subscribed to: ${subscribedMachines[index]}'),
                    );
                  },
                ),
              ),
         
            if (energyConsumption.isNotEmpty) Divider(),

            if (energyConsumption.isNotEmpty)


    Expanded(
   child: ReorderableListView.builder(
  itemCount: energyConsumption.length,
  itemBuilder: (context, index) {
    bool isSwipingToDelete = true;

    return GestureDetector(
      key: ValueKey(index),
      onHorizontalDragUpdate: (details) {
        // Detect horizontal swipe and prevent vertical movement
        if (details.primaryDelta! < -10) {
          setState(() {
            isSwipingToDelete = true;
          });
        } else if (details.primaryDelta! > 10) {
          setState(() {
            isSwipingToDelete = true;
          });
        }
      },
      onHorizontalDragEnd: (details) {
        if (isSwipingToDelete) {
          setState(() {
            _showUnsubscribeConfirmationSnackBar(context, index, machineId!);
            isSwipingToDelete = true;
          });
        }
      },
      child: Dismissible(
        key: ValueKey(index),
        direction: DismissDirection.horizontal,
        background: Container(),
        secondaryBackground: Container(
          alignment: Alignment.centerRight,
          padding: EdgeInsets.only(right: 20.0),
          child: const Icon(
            Icons.delete,
            color: Color.fromARGB(255, 63, 73, 80),
          ),
        ),
        onDismissed: (direction) {},
        confirmDismiss: (direction) {
          return Future.value(true);
        },
        child: Card(
          elevation: 2,
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          key: ValueKey(index),
          child: ListTile(
            leading: Image.asset(
              'assets/images/W_machine.png', 
              width: 30.0,
              height: 30.0,
            ),
            // title: Text('Your Laundry Status: ${energyConsumption[index]}',
            // style: TextStyle(fontSize: 16), ),
             title: Text('Your Laundry Status: ${energyConsumption[index]}',
              style: TextStyle(fontSize: _calculateFontSize(context)),),
            trailing: GestureDetector(
              onTap: () {
                _showUnsubscribeConfirmationSnackBar(context, index, machineId!);
              },
              child: const Icon(
                Icons.delete,
                color: Colors.red,
              ),
            ),
          ),
        ),
      ),
    );
  },
  onReorder: (oldIndex, newIndex) {
    setState(() {
      if (isReorderingWithDragHandle) {
        if (oldIndex < newIndex) {
          newIndex -= 1;
        }
        final double item = energyConsumption.removeAt(oldIndex) as double;
        energyConsumption.insert(newIndex, item as String);
        _saveData();
      }
      isReorderingWithDragHandle = false;
    });
  },
),

),
      

          ],
        ),
        drawer: Drawer(
          child: ListView(
            padding: EdgeInsets.zero,
            children: [
              const DrawerHeader(
                child: Text('Laundry'),
              ),

             ListTile(
                  title: const Text('Share Laundry'),
                  //onTap: generateAndShowLaundryCode,
                   onTap: () {
                      //   String laundryCode = generateLaundryCode();
                      //   Show an alert dialog with the generated code
                      //   showLaundryCodeDialog(laundryCode);
                      generateAndShowLaundryCode();
                      },

                ),
                ListTile(
                  title: const Text('Accept Invitation'),
                  onTap: () {
                    showDialog(
                      context: context,
                      builder: (context) {
                        String inputCode = '';
                        return AlertDialog(
                          title: const Text('Enter Laundry Code'),
                          content: TextField(
                            onChanged: (value) {
                              inputCode = value;
                            },
                            decoration: const InputDecoration(
                              hintText: 'Enter the laundry code',
                            ),
                          ),
                          actions: [
                            TextButton(
                              onPressed: () async {
                                if (inputCode.isNotEmpty) {
                                  await acceptInvitationAndSubscribe(inputCode);
                                  Navigator.pop(context);
                                } else {
                                  // Show an error message
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                          'Please enter a valid laundry code.'),
                                    ),
                                  );
                                }
                              },
                              child: const Text('Accept'),
                         ),
          ],
        );
      },
    );
  },
),


ListTile(
  title: Row(
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    children: [
      Text(themeNotifier.isDark ? "Dark Mode" : "Dark Mode"),
      CupertinoSwitch(
        value: themeNotifier.isDark,
        onChanged: (value) {
          setState(() {
            themeNotifier.isDark = value;
          });
        },
      ),
    ],
  ),
  onTap: () {
    // This will prevent the ListTile from being selectable
  },
)
            
          ],
        ),
      ),
      
   
             floatingActionButton: FloatingActionButton(
        onPressed: () {
           //Return to the previous screen when the button is pressed
            Navigator.push(
              context,
MaterialPageRoute(builder: (context) => const QRScanScreen()),

);

        },
     
        child: const Icon(Icons.add_a_photo_rounded),
         backgroundColor: Colors.black,
         foregroundColor: Colors.white, 
      ),
       );
       
  });
}

double _calculateFontSize(BuildContext context) {
    double screenWidth = MediaQuery.of(context).size.width;

    if (screenWidth < 400) {
      return 14.0;
    } else if (screenWidth < 600) {
      return 16.0;
    } else {
      return 18.0;
    }
  }




Future<void> _checkWelcomeMessage() async {
  SharedPreferences prefs = await SharedPreferences.getInstance();
  setState(() {
    _showWelcomeMessage = prefs.getBool('showWelcomeMessage') ?? true;
  });
  if (_showWelcomeMessage) {
    await prefs.setBool('showWelcomeMessage', true); //if it is false then the box will disappear after the first opening
  }
}

 
}
