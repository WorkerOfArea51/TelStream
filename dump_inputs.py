import json

transcript_path = r'C:\Users\MidNight Hawk\.gemini\antigravity-ide\brain\f573844a-7619-4a62-b310-378b3045a04b\.system_generated\logs\transcript_full.jsonl'
output_path = r'd:\Study Material\Programming Languages\Project TelStream\user_inputs.txt'

with open(transcript_path, 'r', encoding='utf-8') as f:
    with open(output_path, 'w', encoding='utf-8') as out:
        for line in f:
            try:
                data = json.loads(line)
                if data.get('type') == 'USER_INPUT':
                    content = data.get('content', '')
                    out.write("--- USER INPUT START ---\n")
                    out.write(content[:500] + "\n... [TRUNCATED] ...\n" if len(content) > 500 else content + "\n")
                    out.write("--- USER INPUT END ---\n\n")
            except:
                pass
