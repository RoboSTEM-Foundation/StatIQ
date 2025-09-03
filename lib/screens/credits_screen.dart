import 'package:flutter/material.dart';
import 'package:stat_iq/constants/app_constants.dart';

class CreditsScreen extends StatelessWidget {
  const CreditsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Credits'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppConstants.spacingM),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Center(
              child: Column(
                children: [
                  Icon(
                    Icons.favorite,
                    size: 48,
                    color: AppConstants.vexIQOrange,
                  ),
                  const SizedBox(height: AppConstants.spacingM),
                  Text(
                    'Credits',
                    style: AppConstants.headline4.copyWith(
                      fontWeight: FontWeight.bold,
                      color: AppConstants.textPrimary,
                    ),
                  ),
                  const SizedBox(height: AppConstants.spacingS),
                  Text(
                    'Special thanks to everyone who made this app possible',
                    style: AppConstants.bodyText2.copyWith(
                      color: AppConstants.textSecondary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppConstants.spacingL),
            
            // Credits List
            _buildCreditCard(
              name: 'alex',
              handle: '@1698v',
              description: 'Thanks for providing a 2nd API key and the opportunity for me to develop this app for statIQ',
              icon: Icons.api,
              color: AppConstants.vexIQBlue,
            ),
            const SizedBox(height: AppConstants.spacingM),
            
            _buildCreditCard(
              name: 'jason',
              handle: '@2982_x',
              description: 'Thanks for considering my request and asking alex to hire me',
              icon: Icons.handshake,
              color: AppConstants.vexIQGreen,
            ),
            const SizedBox(height: AppConstants.spacingM),
            
            _buildCreditCard(
              name: 'cody',
              handle: '@theman___123',
              description: 'Thanks for contributing some code also alex plz unban this guy he made the server fun',
              icon: Icons.code,
              color: AppConstants.vexIQOrange,
            ),
            const SizedBox(height: AppConstants.spacingM),
            
            _buildCreditCard(
              name: 'William Castro',
              handle: '@SunkenSplash',
              description: 'Thanks for giving random info when I ask and for helping with this project',
              icon: Icons.help,
              color: AppConstants.vexIQRed,
            ),
            const SizedBox(height: AppConstants.spacingM),
            
            _buildCreditCard(
              name: 'glitch',
              handle: '@gli4ch',
              description: 'Thanks for designing the icon for the app',
              icon: Icons.design_services,
              color: AppConstants.vexIQBlue,
            ),
            const SizedBox(height: AppConstants.spacingM),
            
            _buildCreditCard(
              name: 'lars',
              handle: '@_lvdg',
              description: 'Thanks for developing this app and making it awesome',
              icon: Icons.developer_mode,
              color: AppConstants.vexIQOrange,
            ),
            
            const SizedBox(height: AppConstants.spacingL),
            
            // Footer
            Center(
              child: Column(
                children: [
                  Divider(color: AppConstants.borderColor),
                  const SizedBox(height: AppConstants.spacingM),
                  Text(
                    'Made with ❤️ for The Capped Pins',
                    style: AppConstants.bodyText2.copyWith(
                      color: AppConstants.textSecondary,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                  const SizedBox(height: AppConstants.spacingS),
                  Text(
                    'VEX IQ Mix & Match 2025-2026',
                    style: AppConstants.caption.copyWith(
                      color: AppConstants.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCreditCard({
    required String name,
    required String handle,
    required String description,
    required IconData icon,
    required Color color,
  }) {
    return Card(
      elevation: AppConstants.elevationS,
      child: Padding(
        padding: const EdgeInsets.all(AppConstants.spacingM),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(AppConstants.spacingM),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(AppConstants.borderRadiusM),
              ),
              child: Icon(
                icon,
                color: color,
                size: 24,
              ),
            ),
            const SizedBox(width: AppConstants.spacingM),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        name,
                        style: AppConstants.headline6.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(width: AppConstants.spacingS),
                      Text(
                        handle,
                        style: AppConstants.bodyText2.copyWith(
                          color: color,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppConstants.spacingS),
                  Text(
                    description,
                    style: AppConstants.bodyText2.copyWith(
                      color: AppConstants.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
} 