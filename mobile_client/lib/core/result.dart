/// Lightweight result wrapper used by repositories in the shared package.
sealed class Result<T> {
  const Result();

  bool get isSuccess;
  bool get isFailure => !isSuccess;

  T? get dataOrNull;
  String? get errorOrNull;

  R when<R>({
    required R Function(T data) success,
    required R Function(String message) failure,
  });
}

final class ResultSuccess<T> extends Result<T> {
  const ResultSuccess(this.data);

  final T data;

  @override
  bool get isSuccess => true;

  @override
  T get dataOrNull => data;

  @override
  String? get errorOrNull => null;

  @override
  R when<R>({
    required R Function(T data) success,
    required R Function(String message) failure,
  }) {
    return success(data);
  }
}

final class ResultFailure<T> extends Result<T> {
  const ResultFailure(this.message);

  final String message;

  @override
  bool get isSuccess => false;

  @override
  T? get dataOrNull => null;

  @override
  String get errorOrNull => message;

  @override
  R when<R>({
    required R Function(T data) success,
    required R Function(String message) failure,
  }) {
    return failure(message);
  }
}
