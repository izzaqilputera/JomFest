import os
import re

def refactor_file(filepath):
    with open(filepath, 'r', encoding='utf-8') as f:
        content = f.read()

    original_content = content

    # Add import 'theme.dart'; if not present
    if "import 'theme.dart';" not in content and "import 'package:jomfestt/theme.dart';" not in content:
        # insert after the last import
        imports_end = 0
        for m in re.finditer(r'^import .*;$', content, re.MULTILINE):
            imports_end = m.end()
        if imports_end > 0:
            content = content[:imports_end] + "\nimport 'theme.dart';" + content[imports_end:]
        else:
            content = "import 'theme.dart';\n" + content

    # Replace Colors
    replacements = {
        r'Color\(0xFF6C3CE1\)': 'AppColors.primary',
        r'Color\(0xFF9B6DFF\)': 'AppColors.primaryLight',
        r'Color\(0xFFF0EDFF\)': 'AppColors.primarySurface',
        r'Color\(0xFFF8F7FF\)': 'AppColors.scaffoldBg',
        r'Color\(0xFFFFFFFF\)': 'AppColors.white',
        r'Color\(0xFF1A1035\)': 'AppColors.textPrimary',
        r'Color\(0xFF9E9E9E\)': 'AppColors.textSecondary',
        r'Color\(0xFF22C55E\)': 'AppColors.success',
        r'Color\(0xFFDCFCE7\)': 'AppColors.successSurface',
        r'Color\(0xFFE5E7EB\)': 'AppColors.divider',
        r'Colors\.purple': 'AppColors.primary',
        r'Colors\.white': 'AppColors.white',
        r'Colors\.orange': 'AppColors.warning',
        r'Colors\.red': 'AppColors.error',
        r'BorderRadius\.circular\(16\)': 'BorderRadius.circular(AppRadius.card)',
        r'BorderRadius\.circular\(12\)': 'BorderRadius.circular(AppRadius.lg)',
        r'BorderRadius\.circular\(8\)': 'BorderRadius.circular(AppRadius.sm)',
        r'BorderRadius\.circular\(20\)': 'BorderRadius.circular(AppRadius.pill)',
        r'EdgeInsets\.all\(16\)': 'AppSpacing.cardPadding',
        r'EdgeInsets\.all\(8\)': 'EdgeInsets.all(AppSpacing.sm)',
        r'EdgeInsets\.all\(12\)': 'EdgeInsets.all(AppSpacing.md)',
        r'EdgeInsets\.all\(24\)': 'EdgeInsets.all(AppSpacing.xxl)',
        r'EdgeInsets\.all\(32\)': 'EdgeInsets.all(AppSpacing.huge)',
        r'EdgeInsets\.symmetric\(horizontal: 16,\s*vertical: 8\)': 'AppSpacing.chipPadding',
        r'EdgeInsets\.symmetric\(horizontal: 24\)': 'AppSpacing.screenPadding',
        r'EdgeInsets\.symmetric\(horizontal: 10,\s*vertical: 4\)': 'AppSpacing.badgePadding',
        r'BoxDecoration\(\s*color: Colors\.white,\s*borderRadius: BorderRadius\.circular\(16\),\s*border: Border\.all\(color: Colors\.grey\[200\]!\),\s*\)': 'AppDecorations.card()',
    }

    for pattern, repl in replacements.items():
        content = re.sub(pattern, repl, content)

    if content != original_content:
        with open(filepath, 'w', encoding='utf-8') as f:
            f.write(content)
        print(f"Refactored: {filepath}")

lib_dir = os.path.join(os.getcwd(), 'lib')
for filename in os.listdir(lib_dir):
    if filename.endswith('.dart') and filename not in ['theme.dart', 'recommendation_service.dart']:
        refactor_file(os.path.join(lib_dir, filename))
