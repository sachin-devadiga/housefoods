import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../providers/chat_provider.dart';
import '../../domain/models/chat_room_model.dart';
import 'chat_screen.dart';

class InboxScreen extends StatelessWidget {
  const InboxScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final uid = authProvider.userProfile?['uid'] ?? '';
    if (uid.isEmpty) return const Scaffold(body: Center(child: Text("Please login")));

    final chatProvider = context.read<ChatProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text("Messages"),
        elevation: 1,
      ),
      body: StreamBuilder<List<ChatRoomModel>>(
        stream: chatProvider.getChatRooms(uid),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.chat_outlined, size: 64, color: Colors.grey[300]),
                  const SizedBox(height: 16),
                  const Text("No messages yet", style: TextStyle(color: Colors.grey)),
                ],
              ),
            );
          }

          final rooms = snapshot.data!;
          return ListView.separated(
            itemCount: rooms.length,
            separatorBuilder: (context, index) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final room = rooms[index];
              // In this simplified model, we assume participants[1] is the other person if we are participants[0]
              // Production app would resolve the 'other participant' UID and fetch their specific profile.
              final otherUserId = room.participants.firstWhere((id) => id != uid);

              return ListTile(
                leading: CircleAvatar(
                  backgroundColor: AppTheme.primaryColor.withValues(alpha: 0.1),
                  backgroundImage: room.otherUserImage != null ? NetworkImage(room.otherUserImage!) : null,
                  child: room.otherUserImage == null 
                      ? const Icon(Icons.person, color: AppTheme.primaryColor) 
                      : null,
                ),
                title: Text(
                  room.otherUserName,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Text(
                  room.lastMessage,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: Colors.grey[600]),
                ),
                trailing: Text(
                  DateFormat('hh:mm a').format(room.lastTimestamp),
                  style: TextStyle(color: Colors.grey[400], fontSize: 12),
                ),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => ChatScreen(
                        receiverId: otherUserId,
                        receiverName: room.otherUserName,
                      ),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}
