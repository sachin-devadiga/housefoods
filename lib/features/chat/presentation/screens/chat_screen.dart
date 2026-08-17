import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../providers/chat_provider.dart';
import '../widgets/message_bubble.dart';
import '../../domain/models/message_model.dart';

class ChatScreen extends StatefulWidget {
  final String receiverId;
  final String receiverName;

  const ChatScreen({
    super.key,
    required this.receiverId,
    required this.receiverName,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  void _sendMessage() {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final uid = authProvider.userProfile?['uid'] ?? '';
    if (uid.isNotEmpty) {
      context.read<ChatProvider>().sendMessage(
            senderId: uid,
            receiverId: widget.receiverId,
            text: text,
          );
      _messageController.clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final uid = authProvider.userProfile?['uid'] ?? '';
    if (uid.isEmpty) return const Scaffold(body: Center(child: Text("Please login")));

    final chatProvider = context.read<ChatProvider>();

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.receiverName),
        backgroundColor: Colors.white,
        elevation: 1,
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<List<MessageModel>>(
              stream: chatProvider.getMessages(widget.receiverId),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.chat_bubble_outline, size: 64, color: Colors.grey[300]),
                        const SizedBox(height: 16),
                        Text(
                          "Start a conversation with ${widget.receiverName}",
                          style: TextStyle(color: Colors.grey[500]),
                        ),
                      ],
                    ),
                  );
                }

                final messages = snapshot.data!;
                return ListView.builder(
                  reverse: true, // Show newest messages at bottom
                  controller: _scrollController,
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final msg = messages[index];
                    return MessageBubble(
                      message: msg,
                      isMe: msg.senderId == uid,
                    );
                  },
                );
              },
            ),
          ),
          _buildMessageInput(),
        ],
      ),
    );
  }

  Widget _buildMessageInput() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: SafeArea(
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _messageController,
                decoration: InputDecoration(
                  hintText: "Type a message...",
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide.none,
                  ),
                  filled: true,
                  fillColor: Colors.grey[100],
                  contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                ),
                textCapitalization: TextCapitalization.sentences,
              ),
            ),
            const SizedBox(width: 8),
            CircleAvatar(
              backgroundColor: AppTheme.primaryColor,
              child: IconButton(
                icon: const Icon(Icons.send, color: Colors.white, size: 20),
                onPressed: _sendMessage,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
