def fix_tests():
    with open('tests/unit/test_migration_system_message_codes.py', 'r', encoding='utf-8') as f:
        c = f.read()
    c = c.replace('HEAD = "a9b8c7d6e5f4"', 'HEAD = "c35e0daacd1f"')
    with open('tests/unit/test_migration_system_message_codes.py', 'w', encoding='utf-8') as f:
        f.write(c)

    with open('tests/unit/test_default_admin_forced_change.py', 'r', encoding='utf-8') as f:
        c2 = f.read()
    c2 = c2.replace('HEAD_REVISION = "a9b8c7d6e5f4"', 'HEAD_REVISION = "c35e0daacd1f"')
    with open('tests/unit/test_default_admin_forced_change.py', 'w', encoding='utf-8') as f:
        f.write(c2)

    with open('tests/unit/test_migration_runner.py', 'r', encoding='utf-8') as f:
        c3 = f.read()
    c3 = c3.replace('PREVIOUS_HEAD = "a9b8c7d6e5f4"', 'PREVIOUS_HEAD = "d3e4f5a6b7c8"')
    with open('tests/unit/test_migration_runner.py', 'w', encoding='utf-8') as f:
        f.write(c3)
    print("Updated test revision constants successfully")

if __name__ == '__main__':
    fix_tests()
