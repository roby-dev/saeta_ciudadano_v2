class RegisterRequestModel {
  const RegisterRequestModel({
    required this.dni,
    required this.name,
    required this.lastname,
    required this.phone,
    required this.email,
    required this.password,
    this.role = 'CIUDADANO',
  });

  final String dni;
  final String name;
  final String lastname;
  final String phone;
  final String email;
  final String password;
  final String role;

  Map<String, dynamic> toJson() => {
        'dni': dni,
        'name': name,
        'lastname': lastname,
        'phone': phone,
        'email': email,
        'password': password,
        'role': role,
      };
}
