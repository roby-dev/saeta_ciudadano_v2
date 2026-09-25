import 'user_model.dart';

class LoginResponseModel {
  final bool ok;
  final String token;
  final String refreshToken;
  final UserModel user;

  const LoginResponseModel({
    required this.ok,
    required this.token,
    required this.refreshToken,
    required this.user,
  });

  factory LoginResponseModel.fromJson(Map<String, dynamic> json) {
    return LoginResponseModel(
      ok: json['ok'] as bool? ?? true,
      token: (json['accessToken'] ?? json['token']) as String? ?? '',
      refreshToken: json['refreshToken'] as String? ?? '',
      user: UserModel.fromJson(json['user'] as Map<String, dynamic>),
    );
  }
}
