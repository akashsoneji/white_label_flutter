// import 'package:flutter/material.dart'

// func buySellOrder(){
//   if(selectedTab == 2 || selectedTab == 3) {
//     if priceTextField.text?.trim().count == 0{
//     self.navigationController?.view.makeToast("Please enter price")
//     return
//     }
//     }
//
//     if(Double(self.lotSizeLabel.text!)! > 10.00 ) {
//   self.navigationController?.view.makeToast("Maximum lot size is 10, please trade lower than 10 lot.")
//   return
//   }
//   guard let selectedStock = selectedStock?.symbol else {
//   self.navigationController?.view.makeToast("Maximum lot size is 10, please trade lower than 10 lot.")
//   return
//   }
//
//   let param = NSMutableDictionary(dictionary: ["mt5_account" : tradingAccount!.metaAccountNumber!,
//   "symbol" : selectedStock,
//   "volume" : lotSizeLabel.text!,
//   "price" : priceTextField.text!,
//   "pricetp" : takeProfiteTextField.text!,
//   "pricesl" : stopLossTextField.text!,
//   ])
//   if(selectedTab == 1 ){
//   param.addEntries(from: ["type": isBuy ? "0": "1"])
//   }
//   else if(selectedTab == 2){
//   param.addEntries(from: ["type": isBuy ? "2": "3"])
//   }
//   else {
//   param.addEntries(from: ["type": isBuy ? "4": "5"])
//   }
//
//   let request = RequestModel(url: APIConstant.TradingAPI, httpMethod: .post, parameter: (param as! [String : Any]))
//
//   ServerCommunication.share.APICallingFuncation(request: request, view: self,isShowAlert: true, completion: {result,data  in
//
//   if(result){
//   UserDefaults.standard.set(self.lotSizeLabel.text!, forKey: "lastLotSize")
//
//   DispatchQueue.main.async {
//
//   let mainStoryboard: UIStoryboard = UIStoryboard(name: UIConstants.HomeStoryBoard, bundle: nil)
//   let objVC = mainStoryboard.instantiateViewController(withIdentifier: "OrderStatusVC") as! OrderStatusVC
//   objVC.data = ["isOrderCompleted":true,"data" : (data!.value(forKey: "data") as! NSDictionary),"message":(data!.value(forKey: "message") as! String)]
//   self.navigationController?.pushViewController(objVC, animated: true)
//   }
//   }
//   else {
//   UserDefaults.standard.set(self.lotSizeLabel.text!, forKey: "lastLotSize")
//
//   if data!.value(forKey: "message") as! String == "Not enough money." {
//
//   DispatchQueue.main.async {
//
//   //                                let mainStoryboard: UIStoryboard = UIStoryboard(name: UIConstants.HomeStoryBoard, bundle: nil)
//   //                                let objVC = mainStoryboard.instantiateViewController(withIdentifier: "OrderStatusVC") as! OrderStatusVC
//   //                                objVC.data = ["isOrderCompleted":true,"isBuy":self.isBuy,"lot_size": self.lotSizeLabel.text!,"scriptName" : selectedStock!.InstrumentIdentifier!,"price" : self.priceTextField.text!,"message":(data!.value(forKey: "message") as! String)]
//   //                                self.navigationController?.pushViewController(objVC, animated: true)
//   }
//   }
//   else {
// //                    self.navigationController?.view.makeToast((data!.value(forKey: "message") as! String))
//   }
//   }
//   })
// }

import 'package:audioplayers/audioplayers.dart';
import 'package:get/get.dart';
import 'package:crm_app/constants/api_const.dart';
import 'package:crm_app/widgets/custom_toast.dart';
import 'package:crm_app/screens/trading/data/repositories/trading_repository.dart';
import 'package:crm_app/services/secure_storage_service.dart';
import 'package:crm_app/services/audio_service.dart';
import 'package:crm_app/services/language_service.dart';

class ChartController extends GetxController {
  final TradingRepository _tradingRepo = Get.find<TradingRepository>();
  // ==================== OBSERVABLE STATES ====================
  final _isLoading = false.obs;
  var errorMessage = ''.obs;
  final _lastResponse = Rxn<Map<String, dynamic>>();
  var isLoadingMT5Accounts = false.obs;

  // ==================== GETTERS ====================
  bool get isLoading => _isLoading.value;
  Map<String, dynamic>? get lastResponse => _lastResponse.value;
  final AudioPlayer _player = AudioPlayer();

  // Initialize audio player with proper configuration
  Future<void> _initializeAudioPlayer() async {
    try {
      // Try lowLatency mode first (better for short sounds on most devices)
      try {
        await _player.setPlayerMode(PlayerMode.lowLatency);
        print('Audio player initialized with lowLatency mode');
      } catch (e) {
        // Fallback to mediaPlayer mode if lowLatency fails
        print('lowLatency mode failed, trying mediaPlayer mode: $e');
        await _player.setPlayerMode(PlayerMode.mediaPlayer);
        print('Audio player initialized with mediaPlayer mode');
      }
      // Set release mode to release for short sounds
      await _player.setReleaseMode(ReleaseMode.release);
    } catch (e) {
      print('Error initializing audio player: $e');
    }
  }

  // ==================== CONFIG ====================
  final String apiUrl = "API_URL"; // Replace with your endpoint
  final String token = "Bearer YOUR_TOKEN"; // Replace with secure token

  @override
  void onInit() {
    super.onInit();
    // Initialize audio player on controller creation
    _initializeAudioPlayer();
  }

  Future<void> _playNoMoneySound() async {
    try {
      print('=== PLAYING NO MONEY SOUND ===');

      // Initialize audio player if not already done
      await _initializeAudioPlayer();

      // Stop any currently playing audio
      await _player.stop();

      // Set volume to maximum
      await _player.setVolume(1.0);

      // Set release mode to release for short sounds
      await _player.setReleaseMode(ReleaseMode.release);

      // Play the no money sound from assets
      print('Playing no_money.wav from audio/ folder');
      await _player.play(AssetSource('audio/no_money.wav'));
      print('Successfully played no money sound!');
    } catch (e) {
      print('Error playing no money sound: $e');

      try {
        // Fallback: try alternative path
        print('Trying fallback path: no_money.wav');
        await _player.setPlayerMode(PlayerMode.lowLatency);
        await _player.play(AssetSource('no_money.wav'));
        print('Successfully played no money sound from fallback!');
      } catch (e2) {
        print('Error playing no money sound fallback: $e2');

        // Last fallback: try with mediaPlayer mode
        try {
          print('Trying mediaPlayer mode as final fallback');
          await _player.setPlayerMode(PlayerMode.mediaPlayer);
          await _player.play(AssetSource('audio/alert_sound.mp3'));
          print('Successfully played alert sound with mediaPlayer mode!');
        } catch (e3) {
          print('All sound playback attempts failed: $e3');
        }
      }
    }
  }

  Future<void> _playSuccessSound() async {
    try {
      print('=== PLAYING SUCCESS SOUND ===');

      // Initialize audio player if not already done
      await _initializeAudioPlayer();

      // Stop any currently playing audio
      await _player.stop();

      // Set volume to maximum
      await _player.setVolume(1.0);

      // Set release mode to release for short sounds
      await _player.setReleaseMode(ReleaseMode.release);

      // Play the success sound from assets
      print('Playing success.mp3 from audio/ folder');
      await _player.play(AssetSource('audio/success.mp3'));
      print('Successfully played success sound!');
    } catch (e) {
      print('Error playing success sound: $e');

      try {
        // Fallback: try alternative path
        print('Trying fallback path: success.mp3');
        await _player.setPlayerMode(PlayerMode.lowLatency);
        await _player.play(AssetSource('success.mp3'));
        print('Successfully played success sound from fallback!');
      } catch (e2) {
        print('Error playing success sound fallback: $e2');

        // Last fallback: try with mediaPlayer mode
        try {
          print('Trying mediaPlayer mode as final fallback');
          await _player.setPlayerMode(PlayerMode.mediaPlayer);
          await _player.play(AssetSource('audio/success.mp3'));
          print('Successfully played success sound with mediaPlayer mode!');
        } catch (e3) {
          print('All sound playback attempts failed: $e3');
        }
      }
    }
  }


  // ==================== TRADE METHOD ====================
  // Place Trade Order (Buy/Sell)
  // Returns Map with 'success' bool and 'orderData' if successful
  Future<Map<String, dynamic>> placeTradeOrder({
    required String mt5Account,
    required String symbol,
    required double volume,
    required String type, // "buy" or "sell"
    String? priceSl,
    String? priceTp,
    String? price,
    bool skipSound = false, // Skip playing sound (for one-click trading queue)
  }) async {
    try {
      print('🚀 ===== ChartController.placeTradeOrder() CALLED =====');
      print('🚀 ChartController: Starting placeTradeOrder...');
      print('🚀 ChartController: Parameters:');
      print('   - mt5Account: $mt5Account');
      print('   - symbol: $symbol');
      print('   - volume: $volume');
      print(
        '   - type: $type (${type == "buy"
            ? "BUY"
            : type == "1"
            ? "SELL"
            : type})',
      );
      print('   - priceSl: $priceSl');
      print('   - priceTp: $priceTp');
      print('   - price: $price');
      isLoadingMT5Accounts.value = true; // reuse loading observable
      errorMessage.value = '';

      final token = await SecureStorageService.getAuthToken();
      if (token == null || token.isEmpty) {
        errorMessage.value = TranslationUtils.tr('chart_controller_authentication_token_not_found');
        isLoadingMT5Accounts.value = false;
        return {'success': false, 'error': errorMessage.value};
      }

      final requestData = <String, dynamic>{
        "mt5_account": mt5Account,
        "symbol": symbol,
        "volume": volume,
        "type": type,
      };

      if (price != null && price.isNotEmpty) {
        requestData["price"] = price;
      }
      if (priceSl != null && priceSl.isNotEmpty) {
        requestData["stop_loss"] = priceSl;
        requestData["sl"] = priceSl;
      }
      if (priceTp != null && priceTp.isNotEmpty) {
        requestData["take_profit"] = priceTp;
        requestData["tp"] = priceTp;
      }

      print(
        '🚀 ChartController: Making API call to ${ApiConstants.placeOrder}',
      );
      print('🚀 ChartController: Request data: $requestData');

      final response = await _tradingRepo.placeOrder(
        data: requestData,
        token: token,
      );

      print(
        '🔍 ChartController: Trade API response success: ${response.success}',
      );
      print('🔍 ChartController: Trade API response data: ${response.data}');
      print(
        '🔍 ChartController: Trade API response message: ${response.message}',
      );

      if (response.success) {
        final data = response.data;
        final message = data['message']?.toString().toLowerCase() ?? '';

        print('✅ ChartController: Order placed successfully!');
        print('🔊 ChartController: Message from API: $message');

        // Only play sound if not skipped (for one-click trading, sound is played by queue service)
        // ✅ OPTIMIZATION: Play audio in background (non-blocking) to avoid delaying response
        if (!skipSound) {
          print('🔊 ChartController: Starting audio playback (non-blocking)...');
          // Play audio in background - don't await to avoid blocking response
          AudioService.playSuccessSound().catchError((audioError, stackTrace) {
            print('❌ ChartController: Error with AudioService: $audioError');
            print('❌ ChartController: Trying fallback _playSuccessSound()...');
            // Try fallback in background too
            _playSuccessSound().catchError((fallbackError) {
              print(
                '❌ ChartController: Fallback audio also failed: $fallbackError',
              );
            });
          });
        } else {
          print(
            '🔊 ChartController: Sound playback skipped (one-click trading)',
          );
        }

        // Handle no money case (shouldn't happen if success, but just in case)
        if (message.contains('not enough money')) {
          print(
            '⚠️ ChartController: Warning - Success but no money message detected',
          );
          try {
            await testNoMoneySound();
          } catch (e) {
            print('❌ ChartController: Error playing no money sound: $e');
          }
        }

        // Don't show toast here - will be shown in confirmation screen
        // CustomToastService.showSuccess(
        //   message: data['message'] ?? 'Trade executed successfully',
        //   title: 'Trade Success',
        // );

        print('✅ ChartController: Order placement completed successfully');

        // Return order data for confirmation screen
        return {
          'success': true,
          'orderData': data,
          'symbol': symbol,
          'orderType': type,
          'volume': volume,
        };
      } else {
        print("❌ ChartController: Order failed - ${response.message}");
        errorMessage.value = response.message ?? TranslationUtils.tr('chart_controller_failed_to_execute_trade');
        CustomToastService.showError(message: errorMessage.value);

        // Play no money sound if the error is about insufficient funds
        final responseErrorMessage = response.message?.toLowerCase() ?? '';
        final responseData = response.data;
        final dataMessage =
            responseData is Map<String, dynamic>
                ? responseData['message']?.toString().toLowerCase() ?? ''
                : '';

        if (responseErrorMessage.contains('not enough money') ||
            responseErrorMessage.contains('insufficient') ||
            dataMessage.contains('not enough money') ||
            dataMessage.contains('insufficient')) {
          try {
            print('Playing no money sound for insufficient funds error...');
            await _playNoMoneySound();
          } catch (e) {
            print('Error playing no money sound: $e');
          }
        }

        return {'success': false, 'error': errorMessage.value};
      }
    } catch (e) {
      errorMessage.value = '${TranslationUtils.tr('chart_controller_error_placing_trade')}: $e';
      print('❌ ChartController: Error placing trade: $e');
      return {'success': false, 'error': errorMessage.value};
    } finally {
      isLoadingMT5Accounts.value = false;
      print('DashboardController: placeTradeOrder completed');
    }
  }

  // ==================== PRIVATE HELPERS ====================

  // ==================== TEST METHODS ====================
  // Test method to play no money sound
  Future<void> testNoMoneySound() async {
    try {
      print('Testing no money sound...');
      await _playNoMoneySound();
      print('No money sound test completed');
    } catch (e) {
      print('Error testing no money sound: $e');
    }
  }

  // ==================== CLEANUP ====================
  @override
  void onClose() {
    _player.dispose();
    super.onClose();
  }
}
