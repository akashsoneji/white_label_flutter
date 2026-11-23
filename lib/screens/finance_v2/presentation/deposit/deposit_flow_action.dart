import '../../data/models/deposit_submit_result.dart';
import '../../data/models/finance_channel.dart';

/// What a deposit screen must do after its controller handled a tap on the
/// call-to-action. Controllers decide, screens navigate.
sealed class DepositFlowAction {
  const DepositFlowAction();
}

/// Nothing to do: the controller already updated its own state.
final class DepositFlowNone extends DepositFlowAction {
  const DepositFlowNone();
}

/// The quote was stale: the cards were loaded again and nothing was sent.
final class DepositFlowRatesUpdated extends DepositFlowAction {
  const DepositFlowRatesUpdated();
}

/// The quote can no longer be used on the details screen: go back to the
/// amount screen, which loads the cards again and says the rates changed.
final class DepositFlowReloadChannels extends DepositFlowAction {
  const DepositFlowReloadChannels();
}

/// An offline card: collect the pay details before anything is sent.
final class DepositFlowOpenDetails extends DepositFlowAction {
  final FinanceChannel channel;
  final ChannelQuote quote;

  const DepositFlowOpenDetails({required this.channel, required this.quote});
}

/// The gateway gave a payment page: open it and poll by reference.
final class DepositFlowRedirect extends DepositFlowAction {
  final DepositSubmitResult result;

  const DepositFlowRedirect(this.result);
}

/// The deposit exists and the client must pay to the returned details.
final class DepositFlowShowDetails extends DepositFlowAction {
  final FinanceChannel channel;
  final ChannelQuote quote;
  final DepositSubmitResult result;

  const DepositFlowShowDetails({
    required this.channel,
    required this.quote,
    required this.result,
  });
}

/// The request was created: go to Transaction History.
final class DepositFlowCreated extends DepositFlowAction {
  /// The server's message, possibly empty.
  final String message;

  const DepositFlowCreated(this.message);
}

/// 403 KYC_REQUIRED: open verification.
final class DepositFlowKyc extends DepositFlowAction {
  const DepositFlowKyc();
}

/// 409 QUOTE_CHANGED (or a quote refreshed just before submit): ask the
/// client to accept [newQuote], then call the controller's confirmNewQuote.
final class DepositFlowQuoteChanged extends DepositFlowAction {
  final ChannelQuote newQuote;
  final String oldYouGet;

  const DepositFlowQuoteChanged({
    required this.newQuote,
    required this.oldYouGet,
  });
}

/// A server message to show as it is (FINANCE_DISABLED and the like).
final class DepositFlowMessage extends DepositFlowAction {
  final String message;

  const DepositFlowMessage(this.message);
}

/// 422 on details-screen fields: the messages are already under the fields.
final class DepositFlowFieldErrors extends DepositFlowAction {
  const DepositFlowFieldErrors();
}
