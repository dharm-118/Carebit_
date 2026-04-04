/// Generic result wrapper for repository and service responses.
///
/// This helps standardize success and failure handling
/// without throwing exceptions directly into the UI layer.
class Result<T> {
  const Result._({
    required this.data,
    required this.errorMessage,
  });

  final T? data;
  final String? errorMessage;

  /// Returns true when the result contains successful data.
  bool get isSuccess => errorMessage == null;

  /// Returns true when the result contains an error.
  bool get isFailure => errorMessage != null;

  /// Alias for [data].
  T? get dataOrNull => data;

  /// Alias for [errorMessage].
  String? get errorOrNull => errorMessage;

  /// Creates a success result.
  factory Result.success(T data) {
    return Result._(
      data: data,
      errorMessage: null,
    );
  }

  /// Creates a failure result.
  factory Result.failure(String message) {
    return Result._(
      data: null,
      errorMessage: message,
    );
  }

  /// Creates a success result with no meaningful data (for void flows).
  static Result<void> get voidSuccess =>
      const _VoidResult();
}

class _VoidResult extends Result<void> {
  const _VoidResult() : super._(data: null, errorMessage: null);
}

/// Convenience subclass for a successful result, usable as a const.
final class ResultSuccess<T> extends Result<T> {
  const ResultSuccess(T value) : super._(data: value, errorMessage: null);
}

/// Convenience subclass for a failed result, usable as a const.
final class ResultFailure<T> extends Result<T> {
  const ResultFailure(String message)
      : super._(data: null, errorMessage: message);
}
