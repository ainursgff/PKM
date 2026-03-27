class ServerConfig {
  static const String _ip = String.fromEnvironment(
    'SERVER_IP',
    defaultValue: '192.168.1.2',
  );

  static const int port = 3000;

  static String get base => 'http://$_ip:$port';
  static String get apiBase => '$base/api';
  static String get imageBase => '$base/makanan/gambar/';
  static String get videoBase => '$base/makanan/video/';
}
