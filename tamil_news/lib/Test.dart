import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

class MyWebViewPage extends StatefulWidget {
  final String url;

  const MyWebViewPage({super.key, required this.url});

  @override
  State<MyWebViewPage> createState() => _MyWebViewPageState();
}

class _MyWebViewPageState extends State<MyWebViewPage> {
  late final WebViewController _controller;
  bool _isLoading = true;
  double _progress = 0;
  // To keep track of whether we can pop (exit the screen)
  bool _canPopPage = false;


  @override
  void initState() {
    super.initState();

    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0x00000000))
      ..setNavigationDelegate(
        NavigationDelegate(
          onProgress: (int progress) {
            setState(() {
              _progress = progress / 100;
            });
          },
          onPageStarted: (String url) {
            setState(() {
              _isLoading = true;
            });
          },
          onPageFinished: (String url) {
            setState(() {
              _isLoading = false;
            });
          },
          onWebResourceError: (WebResourceError error) {
            debugPrint('''
Page resource error:
  code: ${error.errorCode}
  description: ${error.description}
  errorType: ${error.errorType}
  isForMainFrame: ${error.isForMainFrame}
          ''');
            setState(() {
              _isLoading = false;
            });
          },
          onNavigationRequest: (NavigationRequest request) {
            if (request.url.startsWith('https://www.youtube.com/')) {
              return NavigationDecision.prevent;
            }
            return NavigationDecision.navigate;
          },
        ),
      )
      ..addJavaScriptChannel(
        'Toaster',
        onMessageReceived: (JavaScriptMessage message) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(message.message)),
          );
        },
      )
      ..loadRequest(Uri.parse(widget.url));
  }

  Future<bool> _showExitDialog(BuildContext context) async {
    return await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Exit App'),
          content: const Text('Are you sure you want to exit the application?'),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancel'),
              onPressed: () {
                Navigator.of(context).pop(false); // User does not want to exit
              },
            ),
            TextButton(
              child: const Text('Exit'),
              onPressed: () {
                Navigator.of(context).pop(true); // User confirms exit
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
    // Wrap your Scaffold with PopScope
    return PopScope(
      // canPop is false initially, meaning back gesture is intercepted.
      // It will be true only if _showExitDialog resolves to true.
      canPop: _canPopPage,
      onPopInvoked: (bool didPop) async {
        // This is invoked AFTER the pop gesture has happened or been blocked.
        // If didPop is true, it means canPop was true and the page is popping.
        // If didPop is false, it means canPop was false, and the pop was prevented.
        // Now, we handle the logic to show the dialog.
        if (didPop) {
          return; // Already popping, nothing to do.
        }

        // First, check if the WebView can go back
        if (await _controller.canGoBack()) {
          await _controller.goBack();
          // After WebView goes back, we don't want the page to pop, so ensure _canPopPage remains false.
          // No need to set _canPopPage here, as the default state of PopScope will re-evaluate.
        } else {
          // If WebView cannot go back, show the exit confirmation dialog for the page/app
          final bool shouldPop = await _showExitDialog(context);
          if (shouldPop) {
            // Allow the page to pop.
            // We need to trigger a re-evaluation or directly pop.
            setState(() {
              _canPopPage = true; // Set flag
            });
            // ignore: use_build_context_synchronously
            if (Navigator.canPop(context)) { // Check if there's a route to pop
              // ignore: use_build_context_synchronously
              Navigator.pop(context); // Manually pop if confirmed
            } else {
              // If it's the root route, you might want to exit the app
              // SystemNavigator.pop(); // This exits the app
            }
          } else {
            // User cancelled, ensure we don't pop.
            setState(() {
              _canPopPage = false;
            });
          }
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('In-App WebView'),
          // ... your existing app bar actions
          actions: [
            IconButton(
              icon: const Icon(Icons.arrow_back_ios),
              onPressed: () async {
                if (await _controller.canGoBack()) {
                  await _controller.goBack();
                } else {
                  // ignore: use_build_context_synchronously
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('No back history item')),
                  );
                }
              },
            ),
            IconButton(
              icon: const Icon(Icons.arrow_forward_ios),
              onPressed: () async {
                if (await _controller.canGoForward()) {
                  await _controller.goForward();
                } else {
                  // ignore: use_build_context_synchronously
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('No forward history item')),
                  );
                }
              },
            ),
            IconButton(
              icon: const Icon(Icons.replay),
              onPressed: () => _controller.reload(),
            ),
          ],
        ),
        body: Stack(
          children: [
            WebViewWidget(controller: _controller),
            if (_isLoading)
              LinearProgressIndicator(value: _progress > 0 ? _progress : null),
          ],
        ),
      ),
    );
  }
}
