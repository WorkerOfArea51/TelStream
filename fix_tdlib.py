import sys

with open('lib/services/tdlib_service.dart', 'r', encoding='utf-8') as f:
    content = f.read()

start = content.find('  static Map<String, dynamic> sanitizeJson')
end = content.find('  void _startEventLoop()')

new_content = content[:start] + '  static Map<String, dynamic> sanitizeJson(Map<String, dynamic> json) {\n    return TdJsonUtil.sanitize(json);\n  }\n\n' + content[end:]

with open('lib/services/tdlib_service.dart', 'w', encoding='utf-8') as f:
    f.write(new_content)
