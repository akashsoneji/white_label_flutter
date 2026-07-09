import 'package:get/get.dart';

class WalletTransaction {
  final String type;
  final String title;
  final String date;
  final String status;
  final String requestId;
  final String account;
  final String amount;
  final bool isNegative;
  final String? paymentMethod;
  final String? senderName;
  final String? paymentCreated;
  final String? created;
  final String? processedOn;
  final String? creditedAmount;
  final RxBool isExpanded = false.obs;

  WalletTransaction({
    required this.type,
    required this.title,
    required this.date,
    required this.status,
    required this.requestId,
    required this.account,
    required this.amount,
    required this.isNegative,
    this.paymentMethod,
    this.senderName,
    this.paymentCreated,
    this.created,
    this.processedOn,
    this.creditedAmount,
  });
}

class CopyTradingSettingsController extends GetxController {
  // Demo wallet balance
  final RxString walletBalance = r'$0.00'.obs;

  // Selected tab in Wallet Screen (Actions, History, About)
  final RxInt selectedWalletTab = 0.obs;

  // Filters
  final RxString selectedTransactionType = 'All'.obs;
  final RxString selectedStatus = 'All'.obs;

  // Mock History Data
  final RxList<WalletTransaction> transactions =
      <WalletTransaction>[
        WalletTransaction(
          type: 'Copytrading',
          title: 'Adding investment',
          date: '02 March, 2026, 9:53',
          status: 'Complete',
          requestId: 'CT4842146',
          account: 'Wallet',
          amount: r'-$3.01',
          isNegative: true,
        ),
        WalletTransaction(
          type: 'Copytrading',
          title: 'Investing with master trader',
          date: '02 March, 2026, 9:53',
          status: 'Complete',
          requestId: 'CT4415812',
          account: 'Wallet',
          amount: r'-$47.00',
          isNegative: true,
        ),
        WalletTransaction(
          type: 'USDT',
          title: 'Deposit',
          date: '02 March, 2026, 9:53',
          status: 'Complete',
          requestId: 'D38021786',
          account: 'Wallet',
          amount: r'+50.00 USDT',
          isNegative: false,
          paymentMethod: 'USDT TRC20',
          senderName: 'Prime_traders',
          paymentCreated: 'Mar 02, 2026 08:22 AM',
          created: 'Mar 02, 2026 08:22 AM',
          processedOn: 'Mar 02, 2026 08:22 AM',
          creditedAmount: '50.01 USD',
        ),
      ].obs;

  @override
  void onInit() {
    super.onInit();
    // Initialize data from API if needed
  }

  void refreshData() {
    // Refresh logic
  }

  void resetFilters() {
    selectedTransactionType.value = 'All';
    selectedStatus.value = 'All';
  }
}
