import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

class TutorialScreen extends StatefulWidget {
  const TutorialScreen({super.key});

  @override
  State<TutorialScreen> createState() => _TutorialScreenState();
}

class _TutorialScreenState extends State<TutorialScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  final List<IconData> _icons = [
    Icons.pool,
    Icons.tune,
    Icons.show_chart,
    Icons.history,
    Icons.inventory,
    Icons.settings,
    Icons.info,
    Icons.gavel,
  ];

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;

    final titles = [
      localizations.tutorialPage1Title,
      localizations.tutorialPage3Title,
      localizations.tutorialPage4Title,
      localizations.tutorialPage5Title,
      localizations.tutorialPage6Title,
      localizations.tutorialPage7Title,
      localizations.tutorialPage8Title,
      localizations.tutorialPage9Title,
    ];

    final descriptions = [
      localizations.tutorialPage1Description,
      localizations.tutorialPage3Description,
      localizations.tutorialPage4Description,
      localizations.tutorialPage5Description,
      localizations.tutorialPage6Description,
      localizations.tutorialPage7Description,
      localizations.tutorialPage8Description,
      localizations.tutorialPage9Description,
    ];

    return Scaffold(
      appBar: AppBar(
        title: Text(localizations.tutorialTitle),
      ),
      body: Column(
        children: [
          Expanded(
            child: PageView.builder(
              controller: _pageController,
              itemCount: titles.length,
              onPageChanged: (index) {
                setState(() {
                  _currentPage = index;
                });
              },
              itemBuilder: (context, index) => _buildPage(
                icon: _icons[index],
                title: titles[index],
                description: descriptions[index],
              ),
            ),
          ),
          _buildPageIndicator(titles.length),
          if (_currentPage == titles.length - 1)
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: ElevatedButton.icon(
                icon: const Icon(Icons.check),
                label: Text(localizations.closeButtonLabel),
                onPressed: () => Navigator.pop(context),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildPage({
    required IconData icon,
    required String title,
    required String description,
  }) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Center(
        child: Container(
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceVariant.withOpacity(0.15),
            borderRadius: BorderRadius.circular(20),
          ),
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 90, color: theme.colorScheme.primary),
              const SizedBox(height: 24),
              Text(
                title,
                textAlign: TextAlign.center,
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: SingleChildScrollView(
                  child: Text(
                    description,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyLarge,
                  ),
                ),
              ),

            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPageIndicator(int length) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(length, (index) {
          return AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            margin: const EdgeInsets.symmetric(horizontal: 5),
            height: 10,
            width: _currentPage == index ? 24 : 10,
            decoration: BoxDecoration(
              color: _currentPage == index ? Colors.blue : Colors.grey,
              borderRadius: BorderRadius.circular(5),
            ),
          );
        }),
      ),
    );
  }
}
