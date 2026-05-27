// =============================================================================
// AGORA CONFIGURATION
// =============================================================================
// Replace the values below with your credentials from https://console.agora.io
//
// Steps to get credentials:
//   1. Create a project at https://console.agora.io
//   2. Copy your App ID from the project dashboard
//   3. Generate a temporary RTC token (or leave empty for testing in non-secure mode)
//   4. Set a default channel name, or leave empty so users enter it at runtime
// =============================================================================

class AgoraConfig {
  // Your Agora App ID — required. Never ship a production app without this.
  static const String appId = 'af51ab38fe554b98b94af8e82d298b84';

  // RTC Token — required for production. Leave empty ('') only during
  // development when token authentication is disabled in the Agora Console.
  static const String token = '';

  // Default channel name. Users can override this on the Join screen.
  static const String defaultChannelName = 'test_channel';

  // Local user UID. 0 lets Agora assign one automatically.
  static const int localUid = 0;
}
