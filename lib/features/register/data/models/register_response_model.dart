import '../../../auth/data/models/user_model.dart';

class RegisterResponseModel {
  const RegisterResponseModel({
    required this.ok,
    required this.token,
    required this.refreshToken,
    required this.user,
  });

  final bool ok;
  final String token;
  final String refreshToken;
  final UserModel user;

  factory RegisterResponseModel.fromJson(Map<String, dynamic> json) {
    return RegisterResponseModel(
      ok: json['ok'] as bool? ?? true,
      token: (json['token'] ?? json['accessToken']) as String? ?? '',
      refreshToken: json['refreshToken'] as String? ?? '',
      user: UserModel.fromJson(
        (json['user'] ?? json) as Map<String, dynamic>,
      ),
    );
  }
}
