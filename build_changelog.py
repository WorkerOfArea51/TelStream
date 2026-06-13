import re
import os

def main():
    try:
        with open('lib/core/constants.dart', 'r', encoding='utf-8') as f:
            content = f.read()
        
        # Extract the multiline changelog constant
        match = re.search(r"static const String changelog = '''(.*?)''';", content, re.DOTALL)
        changelog = match.group(1).strip() if match else 'No detailed changelog provided.'
        
        # Read the environment variables set by GitHub Actions
        app_version = os.environ.get('APP_VERSION', '2.0.0')
        run_number = os.environ.get('GITHUB_RUN_NUMBER', '0')
        ref_name = os.environ.get('GITHUB_REF_NAME', 'main')
        sha = os.environ.get('GITHUB_SHA', 'unknown')
        
        # Format the build information section
        build_info = (
            f"\n\n---\n\n"
            f"### 🛠️ Build Information\n"
            f"- **Version:** `v{app_version}`\n"
            f"- **Build Number:** `#{run_number}`\n"
            f"- **Branch:** `{ref_name}`\n"
            f"- **Commit SHA:** `{sha}`\n\n"
            f"### 📲 Downloads\n"
            f"- **ARM64 APK:** Optimized for modern 64-bit ARM devices (arm64-v8a).\n"
            f"- **ARM32 APK:** Optimized for older 32-bit ARM devices (armeabi-v7a).\n"
        )
        
        # Write to the destination markdown file
        with open('extracted_changelog.md', 'w', encoding='utf-8') as out:
            out.write(changelog + build_info)
            
        print("Changelog generated successfully with build info!")
    except Exception as e:
        print(f"Error generating changelog: {e}")

if __name__ == '__main__':
    main()
