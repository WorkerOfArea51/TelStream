import json

with open(r'C:\Users\MidNight Hawk\.gemini\antigravity-ide\brain\f573844a-7619-4a62-b310-378b3045a04b\.system_generated\logs\transcript_full.jsonl', 'r', encoding='utf-8') as f:
    for line in f:
        if 'Batch 3' in line:
            with open('audit_report_dump.md', 'w', encoding='utf-8') as out:
                out.write(line)
            print('Dumped successfully.')
            break
