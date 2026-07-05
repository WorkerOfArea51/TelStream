import json
import os

transcript_path = r'C:\Users\MidNight Hawk\.gemini\antigravity-ide\brain\f573844a-7619-4a62-b310-378b3045a04b\.system_generated\logs\transcript_full.jsonl'
output_path = r'd:\Study Material\Programming Languages\Project TelStream\full_audit_recovered.md'

found = False
with open(transcript_path, 'r', encoding='utf-8') as f:
    for line in f:
        try:
            data = json.loads(line)
            if data.get('type') == 'USER_INPUT' and 'Table of Contents' in data.get('content', ''):
                with open(output_path, 'w', encoding='utf-8') as out:
                    out.write(data['content'])
                print(f"Recovered successfully. Length: {len(data['content'])} characters.")
                found = True
                break
        except Exception as e:
            pass

if not found:
    print("Could not find the audit report in the transcript.")
