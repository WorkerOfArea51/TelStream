import os

vps_path = r'd:\Study Material\Programming Languages\Project TelStream\lib\features\player\video_player_screen.dart'
with open(vps_path, 'r', encoding='utf-8') as f:
    content = f.read()

content = content.replace("if (localPath.startsWith('http://127.0.0.1')) {", "if (StreamingProxyService.isProxyUrl(localPath)) {")
content = content.replace("finalPath.startsWith('http://127.0.0.1')", "StreamingProxyService.isProxyUrl(finalPath)")
content = content.replace("if (mediaUrl.startsWith('http://127.0.0.1')) {", "if (StreamingProxyService.isProxyUrl(mediaUrl)) {")
content = content.replace("mediaUrl.startsWith('http://127.0.0.1')", "StreamingProxyService.isProxyUrl(mediaUrl)")

with open(vps_path, 'w', encoding='utf-8') as f:
    f.write(content)

cvc_path = r'd:\Study Material\Programming Languages\Project TelStream\lib\features\player\custom_video_controls.dart'
with open(cvc_path, 'r', encoding='utf-8') as f:
    content = f.read()

if "import '../../services/streaming_proxy_service.dart';" not in content:
    content = content.replace("import 'package:flutter/material.dart';", "import 'package:flutter/material.dart';\nimport '../../services/streaming_proxy_service.dart';")

content = content.replace("if (playingUrl.startsWith('http://127.0.0.1:')) {", "if (StreamingProxyService.isProxyUrl(playingUrl)) {")

with open(cvc_path, 'w', encoding='utf-8') as f:
    f.write(content)

print('Done!')
