import 'user_model.dart';

class LoginResponseModel {
  final bool status;
  final String message;
  final LoginDataModel data;

  LoginResponseModel({
    required this.status,
    required this.message,
    required this.data,
  });

  factory LoginResponseModel.fromJson(Map<String, dynamic> json) {
    return LoginResponseModel(
      status: json['status'] ?? false,
      message: json['message'] ?? '',
      data:
          json['data'] is Map<String, dynamic>
              ? LoginDataModel.fromJson(json['data'] as Map<String, dynamic>)
              : LoginDataModel.fromJson({}),
    );
  }

  Map<String, dynamic> toJson() {
    return {'status': status, 'message': message, 'data': data.toJson()};
  }
}

class LoginDataModel {
  final UserModel user;
  final String token;
  final String websocketToken;

  LoginDataModel({
    required this.user,
    required this.token,
    required this.websocketToken,
  });

  factory LoginDataModel.fromJson(Map<String, dynamic> json) {
    return LoginDataModel(
      user:
          json['user'] is Map<String, dynamic>
              ? UserModel.fromJson(json['user'] as Map<String, dynamic>)
              : UserModel.fromJson({}),
      token: json['token'] ?? '',
      websocketToken: json['websocket_token'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'user': user.toJson(),
      'token': token,
      'websocket_token': websocketToken,
    };
  }
}
