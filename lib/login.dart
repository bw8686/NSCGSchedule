import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:go_router/go_router.dart';
import 'package:nscgschedule/requests.dart';
import 'package:nscgschedule/settings.dart';

class Login extends StatefulWidget {
  const Login({super.key});

  @override
  State<Login> createState() => _LoginState();
}

class _LoginState extends State<Login> {
  final CookieManager _cookieManager = CookieManager.instance();
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Text('Login'),
      ),
      body: Center(
        child: InAppWebView(
          initialUrlRequest: URLRequest(url: WebUri('https://my.nulc.ac.uk')),
          onLoadStop: (controller, url) async {
            if (url.toString().startsWith('https://my.nulc.ac.uk')) {
              settings.setKey(
                'cookies',
                (await _cookieManager.getCookies(
                  url: WebUri('https://my.nulc.ac.uk'),
                )).toString(),
              );
              settings.setBool('loggedin', true);
              await NSCGRequests().getTimeTable();
              _cookieManager.deleteAllCookies();
              if (mounted) {
                // ignore: use_build_context_synchronously
                context.go('/Timetable');
              }
            }
          },
        ),
      ),
    );
  }
}
