import 'dart:io';
import 'dart:convert';

void main() async {
  final urls = [
    'https://raw.githubusercontent.com/SoliSpirit/mtproto/master/list',
    'https://raw.githubusercontent.com/TheSpeedX/PROXY-List/master/socks5.txt',
    'https://raw.githubusercontent.com/TheSpeedX/PROXY-List/master/mtproto.txt'
  ];
  
  for (final url in urls) {
    try {
      final client = HttpClient();
      final request = await client.getUrl(Uri.parse(url));
      final response = await request.close();
      print('URL: $url');
      print('Status: ${response.statusCode}');
      final body = await response.transform(utf8.decoder).join();
      print('Length: ${body.length}');
    } catch(e) {
      print('Error on $url: $e');
    }
  }
}
