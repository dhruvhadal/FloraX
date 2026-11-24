import re

with open('lib/core/localization/farmer_localization.dart', 'r', encoding='utf-8') as f:
    content = f.read()

# Extract dictionaries map body
dict_match = re.search(r'_dictionaries\s*=\s*\{([\s\S]+?)\n\s*\};', content)
if not dict_match:
    print("Could not find _dictionaries")
    exit(1)

dict_body = dict_match.group(1)

def parse_lang_dict(lang_code, text):
    pattern = rf"'{lang_code}':\s*\{{([\s\S]+?)\n\s*\}},"
    m = re.search(pattern, text)
    if not m:
        print(f"Could not find {lang_code}")
        return {}
    body = m.group(1)
    
    # Parse key-values safely
    entries = {}
    # Match 'key': 'val',
    # Note: handle multi-line strings if any
    for entry in re.finditer(r"'([a-zA-Z0-9_]+)':\s*'([\s\S]*?)',", body):
        k = entry.group(1)
        v = entry.group(2)
        # normalize newlines inside v
        v = v.replace('\r\n', '\n').replace('\n', '\\n')
        entries[k] = v
    return entries

mr_map = parse_lang_dict('mr', dict_body)
hi_map = parse_lang_dict('hi', dict_body)
en_map = parse_lang_dict('en', dict_body)

print(f"Parsed keys - MR: {len(mr_map)}, HI: {len(hi_map)}, EN: {len(en_map)}")

# Common keys
all_keys = list(dict.fromkeys(list(en_map.keys()) + list(mr_map.keys()) + list(hi_map.keys())))
print(f"Total unique keys: {len(all_keys)}")

# Fill any missing from en or mr
for k in all_keys:
    if k not in mr_map:
        mr_map[k] = en_map.get(k, k)
    if k not in hi_map:
        hi_map[k] = mr_map.get(k, en_map.get(k, k))
    if k not in en_map:
        en_map[k] = k

# Build clean dart text
def format_dict(lang_map):
    lines = []
    for k in all_keys:
        val = lang_map[k].replace("'", "\\'") if "\\'" not in lang_map[k] else lang_map[k]
        lines.append(f"      '{k}': '{val}',\n")
    return "".join(lines)

new_dict_body = f"""    // -------------------------------------------------------------------------
    // 1. MARATHI (मराठी) - Primary Target Dialect
    // -------------------------------------------------------------------------
    'mr': {{
{format_dict(mr_map)}    }},

    // -------------------------------------------------------------------------
    // 2. HINDI (हिन्दी)
    // -------------------------------------------------------------------------
    'hi': {{
{format_dict(hi_map)}    }},

    // -------------------------------------------------------------------------
    // 3. ENGLISH (Standard Reference)
    // -------------------------------------------------------------------------
    'en': {{
{format_dict(en_map)}    }},"""

new_content = content[:dict_match.start(1)] + new_dict_body + content[dict_match.end(1):]

with open('lib/core/localization/farmer_localization.dart', 'w', encoding='utf-8') as f:
    f.write(new_content)

print("farmer_localization.dart cleaned, deduplicated, and formatted successfully.")
