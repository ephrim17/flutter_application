import 'package:flutter/material.dart';
import 'package:flutter_application/church_app/helpers/app_text.dart';
import 'package:flutter_application/church_app/helpers/constants.dart';
import 'package:flutter_application/church_app/screens/entry/forgot_password_screen.dart';
import 'package:flutter_application/church_app/screens/entry/login_entry_screen.dart';
import 'package:flutter_application/church_app/screens/entry/login_request_screen.dart';
import 'package:flutter_application/church_app/widgets/app_bar_title_widget.dart';
import 'package:flutter_application/church_app/widgets/church_logo_avatar_widget.dart';
import 'package:flutter_application/church_app/widgets/linear_screen_background_widget.dart';
import 'package:flutter_application/church_app/widgets/solid_button_widget.dart';

class AuthOptionsScreen extends StatelessWidget {
  final String churchId;
  final String churchName;
  final String churchLogo;

  const AuthOptionsScreen({
    super.key,
    required this.churchId,
    required this.churchName,
    this.churchLogo = '',
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: AppBarTitle(text: ""),
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      body: LinearScreenBackground(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ChurchLogoAvatar(
                  logo: churchLogo,
                  size: 92,
                ),
                const SizedBox(height: 16),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                  decoration: carouselBoxDecoration(context),
                  child: Text(
                    churchName,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: SolidButton(
                    label: context.t('auth.login', fallback: 'Login'),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => LoginScreen(
                            churchId: churchId,
                            churchName: churchName,
                            churchLogo: churchLogo,
                          ),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: SolidButton(
                    label: context.t(
                      'auth.request_access',
                      fallback: 'Request Access',
                    ),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => LoginRequestScreen(
                            churchId: churchId,
                            churchName: churchName,
                            churchLogo: churchLogo,
                          ),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: TextButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ForgotPasswordScreen(
                            churchName: churchName,
                            churchLogo: churchLogo,
                          ),
                        ),
                      );
                    },
                    child: Text(
                      context.t('auth.forgot_password',
                          fallback: 'Forgot Password ?'),
                    ),
                  ),
                )
              ],
            ),
          ),
        ),
      ),
    );
  }
}
