import 'package:fairytrail/widgets/widgets.dart';
import 'package:flutter/material.dart';

class CampfireScreen extends StatelessWidget {
  const CampfireScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const AppScaffold(
      title: 'Campfire',
      padding: EdgeInsets.only(bottom: 88),
      body: AppEmptyView(
        title: 'Campfire',
        subtitle: 'Community hangouts will appear here',
        icon: Icons.local_fire_department_outlined,
      ),
    );
  }
}
