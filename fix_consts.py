import os
import re

def fix_consts(filepath):
    with open(filepath, 'r', encoding='utf-8') as f:
        content = f.read()

    original_content = content

    # Remove `const ` before AppColors, AppSpacing, AppRadius, AppTextStyles
    content = re.sub(r'const\s+(AppColors\.\w+)', r'\1', content)
    content = re.sub(r'const\s+(AppSpacing\.\w+)', r'\1', content)
    content = re.sub(r'const\s+(AppRadius\.\w+)', r'\1', content)
    content = re.sub(r'const\s+(AppTextStyles\.\w+)', r'\1', content)
    content = re.sub(r'const\s+(AppDecorations\.\w+)', r'\1', content)
    
    # Also `color: AppColors.white60` is missing from AppColors, let's change to `AppColors.white.withOpacity(0.6)`
    # or let's see if the error was `AppColors.white60`
    content = re.sub(r'AppColors\.white60', r'AppColors.white.withOpacity(0.6)', content)

    # Some variables like `Colors.grey[200]!` inside const -> remove const
    content = re.sub(r'const\s+BorderSide\(color:\s*Colors\.grey\[200\]!\)', r'BorderSide(color: Colors.grey[200]!)', content)
    
    if content != original_content:
        with open(filepath, 'w', encoding='utf-8') as f:
            f.write(content)
        print(f"Fixed consts in: {filepath}")

lib_dir = os.path.join(os.getcwd(), 'lib')
for filename in os.listdir(lib_dir):
    if filename.endswith('.dart') and filename not in ['theme.dart', 'recommendation_service.dart']:
        fix_consts(os.path.join(lib_dir, filename))
