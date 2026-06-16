import os
import re

def fix_colors(filepath):
    with open(filepath, 'r', encoding='utf-8') as f:
        content = f.read()

    original_content = content

    content = re.sub(r'AppColors\.error\[50\]', 'Colors.red.shade50', content)
    content = re.sub(r'AppColors\.error\[100\]', 'Colors.red.shade100', content)
    content = re.sub(r'AppColors\.warning\[50\]', 'Colors.orange.shade50', content)
    content = re.sub(r'AppColors\.warning\[100\]', 'Colors.orange.shade100', content)
    content = re.sub(r'AppColors\.success\[50\]', 'Colors.green.shade50', content)
    content = re.sub(r'AppColors\.success\[100\]', 'Colors.green.shade100', content)
    content = re.sub(r'AppColors\.textSecondary\[\d+\]', 'Colors.grey.shade600', content) # if any
    
    content = re.sub(r'AppColors\.error\.shade50', 'Colors.red.shade50', content)
    content = re.sub(r'AppColors\.warning\.shade50', 'Colors.orange.shade50', content)
    content = re.sub(r'AppColors\.success\.shade50', 'Colors.green.shade50', content)

    content = re.sub(r'AppColors\.white54', 'AppColors.white.withOpacity(0.54)', content)
    content = re.sub(r'AppColors\.white70', 'AppColors.white.withOpacity(0.70)', content)

    if content != original_content:
        with open(filepath, 'w', encoding='utf-8') as f:
            f.write(content)
        print(f"Fixed specific colors in: {filepath}")

lib_dir = os.path.join(os.getcwd(), 'lib')
for filename in os.listdir(lib_dir):
    if filename.endswith('.dart') and filename not in ['theme.dart', 'recommendation_service.dart']:
        fix_colors(os.path.join(lib_dir, filename))
