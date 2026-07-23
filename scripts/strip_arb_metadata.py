#!/usr/bin/env python3
import json
import sys
import os
import glob

ARB_DIR = os.path.join(os.path.dirname(__file__), '..', 'lib', 'l10n')
ARB_DIR = os.path.abspath(ARB_DIR)

def strip_arb(filepath):
    with open(filepath, 'r', encoding='utf-8') as f:
        data = json.load(f)
    
    cleaned = {}
    for key, value in data.items():
        if key == '@@locale':
            cleaned[key] = value
            continue
        
        # Keep the actual string value, but fix the broken 6MB moijbake explosion!
        if not key.startswith('@'):
            if isinstance(value, str) and len(value) > 500:
                print(f"  Fixing massive garbage string in key '{key}'")
                cleaned[key] = "Go to More > Channels to add a channel"
            else:
                cleaned[key] = value
            continue
        
        # For @-metadata entries, only keep placeholder definitions
        if isinstance(value, dict):
            minimal = {}
            if 'placeholders' in value:
                minimal['placeholders'] = value['placeholders']
            if minimal:
                cleaned[key] = minimal
    
    with open(filepath, 'w', encoding='utf-8') as f:
        json.dump(cleaned, f, ensure_ascii=False, indent=2)
    
    original_size = os.path.getsize(filepath)
    new_size = len(json.dumps(cleaned, ensure_ascii=False, indent=2).encode('utf-8'))
    print(f'{os.path.basename(filepath)}: {original_size//1024}KB -> {new_size//1024}KB')

def main():
    arb_files = glob.glob(os.path.join(ARB_DIR, 'app_*.arb'))
    if not arb_files:
        print(f'No ARB files found in {ARB_DIR}')
        sys.exit(1)
    
    print(f'Found {len(arb_files)} ARB files. Stripping metadata and fixing moijbake...')
    for filepath in arb_files:
        strip_arb(filepath)
    
    print('Done! Run `flutter gen-l10n` to regenerate Dart files.')

if __name__ == '__main__':
    main()
