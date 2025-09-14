
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:share_plus/share_plus.dart';
import 'package:tamil_news/colors_utill.dart';
import 'package:webview_flutter/webview_flutter.dart';

class WebviewPage extends StatefulWidget {
  final String url;
  final String title;
  bool _isOffline = false;

  WebviewPage({super.key, required this.url, required this.title});

  @override
  State<WebviewPage> createState() => _MyWebViewPageState();
}

class _MyWebViewPageState extends State<WebviewPage> {
  late final WebViewController _controller;
  bool _isLoading = true;
  double _progress = 0;
  // bool _canPopPage = false;

  @override
  void initState() {
    super.initState();
    _checkConnectivity();

    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted) // Enable JavaScript
      ..setBackgroundColor(const Color(0x00000000)) // Optional: set background color
      ..setNavigationDelegate(
        NavigationDelegate(
          onProgress: (int progress) {
            // Update loading bar.
            debugPrint('WebView is loading (progress : $progress%)');
            setState(() {
              _progress = progress / 100;
            });
          },
          onPageStarted: (String url) {
            debugPrint('Page started loading: $url');
            setState(() {
              _isLoading = true;
            });
          },
          onPageFinished: (String url) {
            debugPrint('Page finished loading: $url');
            setState(() {
              _isLoading = false;
            });
            MobileAds.instance.registerWebView(_controller);
            // You can execute JavaScript here if needed
            // _controller.runJavaScriptReturningResult('document.title').then((title) {
            //   debugPrint('Page title: $title');
            // });
          },
          onWebResourceError: (WebResourceError error) {
            debugPrint('''
                  Page resource error:
                    code: ${error.errorCode}
                    description: ${error.description}
                    errorType: ${error.errorType}
                    isForMainFrame: ${error.isForMainFrame}
          ''');
            // Optionally show an error message to the user
            setState(() {
              _isLoading = false;
              widget._isOffline = true;
            });
          },
          onNavigationRequest: (NavigationRequest request) async {
            // Handle social sharing URLs
            if (request.url.startsWith('https://ulloornews.com/')) {
              return NavigationDecision.navigate;
            } else {
              String? shareText  = getSharingText(request.url);
              if (shareText != null) {
                await Share.share(shareText);
                return NavigationDecision.prevent;
              } else {
                return NavigationDecision.prevent;
              }
            }
          },
        ),
      )
      ..addJavaScriptChannel( // For communication from web to Flutter
        'Toaster',
        onMessageReceived: (JavaScriptMessage message) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(message.message)),
          );
        },
      )
      ..loadRequest(Uri.parse(widget.url)); // Load the initial URL
  }

  Future _showExitDialog(BuildContext context) async {
    await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          // title: Text('Exit', style: TextStyle(color: Colors.red),),
          content: Text('Are you sure you want to exit from $appName?', style: TextStyle(color: loginBackgroundColor, fontSize: 16),),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancel', style: TextStyle(color: Colors.green, fontSize: 14),),
              onPressed: () {
                Navigator.of(dialogContext).pop(); // User does not want to exit
              },
            ),
            TextButton(
              child: const Text('Exit', style: TextStyle(color: Colors.red, fontSize: 14)),
              onPressed: () {
                Navigator.of(dialogContext).pop(); // Close the dialog
                SystemNavigator.pop(); // Pop the current route
              },
            ),
          ],
        );
      },
    ) ??
        false; // If dialog is dismissed by tapping outside, default to false
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (bool didPop, dynamic result) async {
        if (didPop) {
          return; // Already popping, nothing to do.
        }

        // First, check if the WebView can go back
        if (await _controller.canGoBack()) {
          await _controller.goBack();
        } else {
          await _showExitDialog(context);
        }
      },
      child: Scaffold(
        body: widget._isOffline ? _noNetworkPage() : SafeArea(
          bottom: true,
          child: Stack(
            children: [
              WebViewWidget(controller: _controller),
              if (_isLoading)
                LinearProgressIndicator(value: _progress > 0 ? _progress : null), // Show determinate or indeterminate progress
            ],
          ),
        ),
      ),
    );
  }

  String? getSharingText(String url) {
    String? textToShare;
    String key = '';
    final uri = Uri.parse(url);
    if (url.contains("linkedin.com/") ||
        url.contains("telegram.me/") ||
        url.contains("instagram.com/") ||
        url.contains("reddit.com/")||
        url.contains("mix.com/") || url.contains("twitter.com/")) {
      key = 'url';
    } else if(url.contains("facebook.com/")) {
      key = 'u';
    } else if(url.contains("whatsapp.com/send") || url.contains("mastodon.social/")) {
      key = 'text';
    }
    if (uri.queryParameters.containsKey(key)) {
      textToShare = uri.queryParameters[key];
    }

    return textToShare;
  }

  Widget _noNetworkPage() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.wifi_off, size: 100, color: Colors.grey),
          const SizedBox(height: 20),
          const Text(
            "No Internet Connection",
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),
          const Text(
            "Please check your connection and try again.",
            style: TextStyle(fontSize: 16, color: Colors.grey),
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: _retryLoading,
            child: const Text("Retry"),
          )
        ],
      ),
    );
  }

  // Check connectivity status
  Future<void> _checkConnectivity() async {
    var result = await Connectivity().checkConnectivity();
    setState(() {
      widget._isOffline = (result == ConnectivityResult.none);
    });
  }

  // Retry button for offline page
  void _retryLoading() async {
    await _checkConnectivity();
    if (!widget._isOffline) {
      _controller.reload();
    }
  }
}

