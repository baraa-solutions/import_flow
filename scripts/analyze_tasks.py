import subprocess
import os

with open('docs/plans/backend-review/TASKS.md', encoding='utf-8') as f:
    lines = f.readlines()

current_wave = 'Unknown'
tasks = []
for line in lines:
    if line.startswith('## Wave '):
        current_wave = line.strip().replace('## ', '')
    elif line.strip().startswith('|') and not line.strip().startswith('| #') and not line.strip().startswith('|---'):
        parts = [p.strip() for p in line.split('|')[1:-1]]
        if len(parts) >= 11:
            tasks.append({
                'num': int(parts[0]),
                'task_id': parts[1],
                'wave': current_wave,
                'scope': parts[2],
                'sev': parts[3],
                'title': parts[4],
                'depends': parts[5],
                'safe': parts[8],
                'status': parts[10]
            })

git_log = subprocess.check_output(['git', 'log', '--oneline'], text=True, errors='ignore').lower()

try:
    gh_prs = subprocess.check_output(['gh', 'pr', 'list', '--state', 'open', '--limit', '100'], text=True, errors='ignore').lower()
except Exception:
    gh_prs = ""

for t in tasks:
    in_git = t['task_id'].lower() in git_log
    in_pr = t['task_id'].lower() in gh_prs
    st = t['status'].lower()
    t['done'] = 'done' in st or in_git or in_pr

todo = [t for t in tasks if not t['done']]
todo_safe_yes = [t for t in todo if t['safe'].lower() == 'yes']
todo_review = [t for t in todo if t['safe'].lower() != 'yes']

os.makedirs('reports', exist_ok=True)
with open('reports/tasks_remaining_report.txt', 'w', encoding='utf-8') as out:
    out.write(f"Total Tasks: {len(tasks)}\n")
    out.write(f"Completed / Merged / Open PR: {len(tasks) - len(todo)}\n")
    out.write(f"Remaining (TODO): {len(todo)}\n")
    out.write(f"  - Safe for Antigravity (yes): {len(todo_safe_yes)}\n")
    out.write(f"  - Requires Human / CTO Review (review required): {len(todo_review)}\n\n")

    out.write("="*80 + "\n")
    out.write("--- 1. Remaining Tasks SAFE FOR ANTIGRAVITY (Safe: yes) ---\n")
    out.write("="*80 + "\n")
    for t in sorted(todo_safe_yes, key=lambda x: x['num']):
        out.write(f"#{t['num']:03d} | {t['task_id']:<10} | {t['wave']:<15} | {t['sev']:<8} | {t['scope']:<25} | {t['title']}\n")

    out.write("\n" + "="*80 + "\n")
    out.write("--- 2. Remaining Tasks REQUIRING REVIEW / HUMAN (review required) ---\n")
    out.write("="*80 + "\n")
    for t in sorted(todo_review, key=lambda x: x['num']):
        out.write(f"#{t['num']:03d} | {t['task_id']:<10} | {t['wave']:<15} | {t['sev']:<8} | {t['scope']:<25} | {t['title']}\n")

print("Report generated at reports/tasks_remaining_report.txt")
