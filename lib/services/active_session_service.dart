/// A simple static class to hold the state of the currently active chat session.
/// This allows other parts of the app, like the AppLifecycleObserver in main.dart,
/// to know which session needs to be summarized when the app is paused.
class ActiveSessionService {
  /// The ID of the chat session that is currently visible on the screen.
  /// It's nullable because there might be no active chat session.
  static String? currentSessionId;
}

