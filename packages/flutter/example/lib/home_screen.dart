// ignore_for_file: experimental_member_use

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

import 'app_config.dart';
import 'screens/errors_screen.dart';
import 'screens/events_screen.dart';
import 'screens/logs_screen.dart';
import 'screens/metrics_screen.dart';
import 'screens/other_screen.dart';
import 'screens/performance_screen.dart';
import 'theme_provider.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDark = themeProvider.theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Sentry Flutter Example'),
        actions: [
          IconButton(
            onPressed: () {
              themeProvider.theme =
                  isDark ? ThemeData.light() : ThemeData.dark();
            },
            icon: Icon(isDark ? Icons.light_mode : Icons.dark_mode),
          ),
          IconButton(
            onPressed: () => themeProvider.updatePrimaryColor(Colors.orange),
            icon: const Icon(Icons.circle, color: Colors.orange),
          ),
          IconButton(
            onPressed: () => themeProvider.updatePrimaryColor(Colors.green),
            icon: const Icon(Icons.circle, color: Colors.lime),
          ),
        ],
      ),
      body: Column(
        children: [
          if (isIntegrationTest) const IntegrationTestWidget(),
          RichText(
            text: const TextSpan(
              text: '(I am) Rich Text',
              style: TextStyle(
                color: Colors.black,
                fontSize: 16,
              ),
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: GridView.extent(
                maxCrossAxisExtent: 200,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                children: [
                  _CategoryCard(
                    icon: Icons.bug_report,
                    label: 'Errors',
                    onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const ErrorsScreen())),
                  ),
                  _CategoryCard(
                    icon: Icons.send,
                    label: 'Events',
                    onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const EventsScreen())),
                  ),
                  _CategoryCard(
                    icon: Icons.speed,
                    label: 'Performance',
                    onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const PerformanceScreen())),
                  ),
                  _CategoryCard(
                    icon: Icons.list_alt,
                    label: 'Logs',
                    onTap: () => Navigator.push(context,
                        MaterialPageRoute(builder: (_) => const LogsScreen())),
                  ),
                  _CategoryCard(
                    icon: Icons.bar_chart,
                    label: 'Metrics',
                    onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const MetricsScreen())),
                  ),
                  _CategoryCard(
                    icon: Icons.more_horiz,
                    label: 'Other',
                    onTap: () => Navigator.push(context,
                        MaterialPageRoute(builder: (_) => const OtherScreen())),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CategoryCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _CategoryCard({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 48, color: Theme.of(context).colorScheme.primary),
            const SizedBox(height: 12),
            Text(label, style: Theme.of(context).textTheme.titleMedium),
          ],
        ),
      ),
    );
  }
}

class IntegrationTestWidget extends StatefulWidget {
  const IntegrationTestWidget({super.key});

  @override
  State<IntegrationTestWidget> createState() => _IntegrationTestWidgetState();
}

class _IntegrationTestWidgetState extends State<IntegrationTestWidget> {
  var _output = '--';
  var _isLoading = false;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(_output, key: const Key('output')),
        _isLoading
            ? const CircularProgressIndicator()
            : ElevatedButton(
                onPressed: _captureException,
                child: const Text('captureException'),
              ),
      ],
    );
  }

  Future<void> _captureException() async {
    setState(() => _isLoading = true);
    try {
      throw Exception('captureException');
    } catch (error, stackTrace) {
      final id = await Sentry.captureException(error, stackTrace: stackTrace);
      setState(() {
        _output = id.toString();
        _isLoading = false;
      });
    }
  }
}
