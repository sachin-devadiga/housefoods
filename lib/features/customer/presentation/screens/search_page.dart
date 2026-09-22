import 'package:flutter/material.dart';
import 'tabs/search_tab.dart';

/// Full-screen search opened from the home search bar.
class SearchPage extends StatelessWidget {
  final String initialQuery;

  const SearchPage({super.key, this.initialQuery = ''});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Search')),
      body: SearchTab(initialQuery: initialQuery),
    );
  }
}
