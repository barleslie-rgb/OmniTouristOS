import 'dart:convert';
import 'package:web_socket_channel/io.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

class CommunityWebSocketService {
  WebSocketChannel? _channel;

  // Connect to the specific community room channel
  void connect(String communityId, String wsBaseUrl) {
    // wsBaseUrl example: "wss://omni-backend-pk28.onrender.com/ws/community"
    final url = Uri.parse('$wsBaseUrl/$communityId');
    _channel = IOWebSocketChannel.connect(url);
  }

  // Stream incoming real-time messages and broadcast events
  Stream<dynamic> get messageStream {
    if (_channel == null) {
      throw Exception("WebSocket connection is not established.");
    }
    return _channel!.stream.map((event) => jsonDecode(event));
  }

  // Send a new chat message through the active socket connection
  void sendMessage({
    required String senderId,
    required String text,
    String type = 'text',
  }) {
    if (_channel != null) {
      final payload = jsonEncode({
        'sender_id': senderId,
        'text': text,
        'type': type,
      });
      _channel!.sink.add(payload);
    }
  }

  // Gracefully close the socket when leaving the chat room
  void disconnect() {
    _channel?.sink.close();
  }
}