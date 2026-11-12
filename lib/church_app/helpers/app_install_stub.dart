/// Everything here is false on a phone build: there is nothing to install,
/// the app *is* the app. The web implementation next door does the work.
library;

bool runningAsInstalledAppImpl() => false;

bool installPromptAvailableImpl() => false;

Future<String> requestInstallImpl() async => 'unavailable';

String browserUserAgentImpl() => '';
