import 'package:cloud_firestore/cloud_firestore.dart';

Future<void> sendNotification({
  required String receiverId,
  required String message,
  required String type,
}) async {
  await FirebaseFirestore.instance
      .collection('notifications')
      .doc(receiverId)
      .collection('userNotifications')
      .add({
    'message': message,
    'type': type,
    'read': false,
    'timestamp': Timestamp.now(),
  });
}

