import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart'; // Importajte ImagePicker

class ChatBar extends StatelessWidget {
  final TextEditingController controller;
  final Function(String) onSend;
  final String locationName;
  final String replyingTo;
  final Function onPickImage;
  final Function onTakePhoto;

  const ChatBar({
    super.key,
    required this.controller,
    required this.onSend,
    required this.locationName,
    required this.replyingTo,
    required this.onPickImage,
    required this.onTakePhoto,
  });

  Widget _buildTextField() {
    return TextField(
      controller: controller,
      decoration: InputDecoration(
        hintText: 'Type Here...',
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(30.0),
          borderSide: BorderSide.none,
        ),
        filled: true,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 20.0, vertical: 10.0),
        fillColor: Colors.grey[200],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
      child: Column(
        children: [
          if (replyingTo.isNotEmpty)
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
              margin: const EdgeInsets.only(bottom: 4.0),
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(12.0),
              ),
              child: Text(
                'Replying to: $replyingTo',
                style: const TextStyle(fontSize: 12.0, color: Colors.black),
              ),
            ),
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.photo),
                onPressed: () => onPickImage(ImageSource.gallery),
              ),
              IconButton(
                icon: const Icon(Icons.camera_alt),
                onPressed: () => onTakePhoto(),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildTextField(),
                  ],
                ),
              ),
              const SizedBox(width: 8.0),
              CircleAvatar(
                backgroundColor: Colors.blue,
                child: IconButton(
                  icon: const Icon(Icons.send, color: Colors.white),
                  onPressed: () => onSend(controller.text),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
