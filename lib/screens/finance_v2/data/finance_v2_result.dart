import 'models/finance_v2_failure.dart';

/// Outcome of a finance_v2 repository call: either [FinanceV2Ok] with the
/// parsed value or [FinanceV2Err] with a classified [FinanceV2Failure].
sealed class FinanceV2Result<T> {
  const FinanceV2Result();

  bool get isOk => this is FinanceV2Ok<T>;

  T? get valueOrNull => switch (this) {
        FinanceV2Ok<T>(:final value) => value,
        FinanceV2Err<T>() => null,
      };

  FinanceV2Failure? get failureOrNull => switch (this) {
        FinanceV2Ok<T>() => null,
        FinanceV2Err<T>(:final failure) => failure,
      };
}

final class FinanceV2Ok<T> extends FinanceV2Result<T> {
  final T value;

  /// The envelope's message, for a toast after a submit.
  final String message;

  const FinanceV2Ok(this.value, {this.message = ''});
}

final class FinanceV2Err<T> extends FinanceV2Result<T> {
  final FinanceV2Failure failure;

  const FinanceV2Err(this.failure);
}
