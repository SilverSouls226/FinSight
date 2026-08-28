/// Typed failures surfaced by service implementations so the UI layer can
/// show a specific, non-crashing message instead of an unhandled exception.
sealed class ServiceException implements Exception {
  final String message;
  const ServiceException(this.message);
}

class ServiceUnavailableException extends ServiceException {
  const ServiceUnavailableException([
    super.message = 'The service is temporarily unavailable.',
  ]);
}

class ServiceTimeoutException extends ServiceException {
  const ServiceTimeoutException([
    super.message = 'The request took too long to respond.',
  ]);
}

class MalformedResponseException extends ServiceException {
  const MalformedResponseException([
    super.message = 'Received an unexpected response format.',
  ]);
}
