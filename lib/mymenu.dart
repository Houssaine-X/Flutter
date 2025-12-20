import 'package:flutter/material.dart';
import 'package:test_app/vocal_assistant.dart';

class MyMenu extends StatefulWidget {
  const MyMenu({super.key});

  @override
  State<MyMenu> createState() => _MyMenuState();
}

class _MyMenuState extends State<MyMenu> {
  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: Column(
        children: [
          DrawerHeader(
            child: Row(
              children: [
                CircleAvatar(
                  backgroundImage: AssetImage('assets/images/avatar.jpg'),
                  radius: 35.0,
                ),
                const SizedBox(width: 25.0),
                const Expanded(child: Text('test user')),
              ],
            ),
          ),

          ExpansionTile(
            leading: Image.asset(
              'assets/icons/image_icon.png',
              width: 28,
              height: 28,
              fit: BoxFit.contain,
            ),
            title: const Text('Image classification models')
            ,
            children: const [
              ListTile(
                title: Text('ANN Model'),
              ),
              ListTile(
                title: Text('CNN Model'),
              ),
            ],
          ),

          ListTile(
            leading: ImageIcon(
              AssetImage('assets/icons/image_icon.png'),
              size: 28,
            ),
            title: const Text('Stock price prediction model'),
          ),

           ListTile(
            title: Text('Vocal Assistant'),
            onTap: () {
              Navigator.pop(context); // Close drawer
              // Use the route constant to avoid mismatches
              Navigator.pushNamed(context, VocalAssistant.routeName);
            },
          ),

          const ListTile(
            title: Text('Retrieval Augmented Generation Model'),
          ),
        ],
      ),
    );
  }
}
