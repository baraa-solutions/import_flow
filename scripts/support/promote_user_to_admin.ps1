<#
  ImportFlow ERP - promote an existing user to ADMIN (support tool for old installs without an admin user).

  What it does:
    1. Finds the installed database (per-user install folder, or asks for the path).
    2. Stops the running app (asks first).
    3. Copies sorour_logistics.db (+ -wal/-shm) to a backup folder on the Desktop.
    4. Lists the users, asks which one to promote (default: manager), sets role = 'ADMIN'.
  Uses Windows' built-in winsqlite3.dll (no Python needed). Run with the app closed.
  Restore: close the app and copy the backup files back into the install folder.
#>
param(
    [string]$DbPath = "",
    [string]$Username = ""
)

$ErrorActionPreference = "Stop"

function Pause-Exit([int]$code) {
    Write-Host ""
    Read-Host "Press Enter to close" | Out-Null
    exit $code
}

Add-Type -TypeDefinition @"
using System;
using System.Runtime.InteropServices;
public static class WinSqlite {
    [DllImport("winsqlite3.dll", CharSet = CharSet.Unicode)] public static extern int sqlite3_open16(string filename, out IntPtr db);
    [DllImport("winsqlite3.dll")] public static extern int sqlite3_close(IntPtr db);
    [DllImport("winsqlite3.dll", CharSet = CharSet.Unicode)] public static extern int sqlite3_prepare16_v2(IntPtr db, string sql, int nByte, out IntPtr stmt, IntPtr tail);
    [DllImport("winsqlite3.dll")] public static extern int sqlite3_step(IntPtr stmt);
    [DllImport("winsqlite3.dll")] public static extern int sqlite3_finalize(IntPtr stmt);
    [DllImport("winsqlite3.dll")] public static extern IntPtr sqlite3_column_text16(IntPtr stmt, int col);
    [DllImport("winsqlite3.dll", CharSet = CharSet.Unicode)] public static extern int sqlite3_bind_text16(IntPtr stmt, int idx, string value, int n, IntPtr destructor);
    [DllImport("winsqlite3.dll")] public static extern int sqlite3_changes(IntPtr db);
    [DllImport("winsqlite3.dll")] public static extern IntPtr sqlite3_errmsg16(IntPtr db);
    public static string Col(IntPtr stmt, int i) { IntPtr p = sqlite3_column_text16(stmt, i); return p == IntPtr.Zero ? "" : Marshal.PtrToStringUni(p); }
    public static string Err(IntPtr db) { return Marshal.PtrToStringUni(sqlite3_errmsg16(db)); }
}
"@

function Invoke-Sql([IntPtr]$db, [string]$sql, [string[]]$params = @()) {
    $stmt = [IntPtr]::Zero
    if ([WinSqlite]::sqlite3_prepare16_v2($db, $sql, -1, [ref]$stmt, [IntPtr]::Zero) -ne 0) {
        throw "SQL error: $([WinSqlite]::Err($db))"
    }
    try {
        for ($i = 0; $i -lt $params.Count; $i++) {
            [void][WinSqlite]::sqlite3_bind_text16($stmt, $i + 1, $params[$i], -1, [IntPtr](-1))
        }
        $rows = @()
        while ($true) {
            $rc = [WinSqlite]::sqlite3_step($stmt)
            if ($rc -eq 100) { $rows += ,@([WinSqlite]::Col($stmt, 0), [WinSqlite]::Col($stmt, 1), [WinSqlite]::Col($stmt, 2)) }
            elseif ($rc -eq 101) { break }
            else { throw "SQL error: $([WinSqlite]::Err($db))" }
        }
        return ,$rows
    } finally { [void][WinSqlite]::sqlite3_finalize($stmt) }
}

Write-Host "=== ImportFlow ERP: promote a user to ADMIN ===" -ForegroundColor Cyan

# 1. Locate the database
if (-not $DbPath) {
    $candidates = @(
        "$env:LOCALAPPDATA\Programs\Sorour Logistics\sorour_logistics.db",
        "C:\Users\Hp\AppData\Local\Programs\Sorour Logistics\sorour_logistics.db",
        "${env:ProgramFiles(x86)}\Sorour Logistics\sorour_logistics.db",
        "$env:ProgramFiles\Sorour Logistics\sorour_logistics.db"
    )
    $DbPath = $candidates | Where-Object { $_ -and (Test-Path $_) } | Select-Object -First 1
}
if (-not $DbPath -or -not (Test-Path $DbPath)) {
    $DbPath = Read-Host "Database not found automatically. Paste the full path of sorour_logistics.db"
    if (-not (Test-Path $DbPath)) { Write-Host "File not found: $DbPath" -ForegroundColor Red; Pause-Exit 1 }
}
$appDir = Split-Path -Parent $DbPath
Write-Host "Database: $DbPath"

# 2. Stop the app (anything running from the install folder)
$running = Get-Process -ErrorAction SilentlyContinue | Where-Object { $_.Path -and $_.Path.StartsWith($appDir, [StringComparison]::OrdinalIgnoreCase) }
if ($running) {
    Write-Host "The app is running: $($running.Name -join ', ')" -ForegroundColor Yellow
    $ans = Read-Host "Close it now? Unsaved work will be lost (Y/N)"
    if ($ans -notmatch '^[Yy]') { Write-Host "Cancelled. Close the app and run again."; Pause-Exit 1 }
    $running | Stop-Process -Force
    Start-Sleep -Seconds 3
}

# 3. Backup
$bk = Join-Path ([Environment]::GetFolderPath("Desktop")) ("db_backup_before_admin_" + (Get-Date -Format "yyyyMMdd_HHmmss"))
New-Item -ItemType Directory -Path $bk | Out-Null
Copy-Item "$DbPath*" $bk
$copied = Get-ChildItem $bk
if (-not ($copied | Where-Object { $_.Name -eq "sorour_logistics.db" })) { Write-Host "Backup failed, nothing changed." -ForegroundColor Red; Pause-Exit 1 }
Write-Host "Backup saved to: $bk ($($copied.Count) file(s))" -ForegroundColor Green

# 4. List users and promote
$db = [IntPtr]::Zero
if ([WinSqlite]::sqlite3_open16($DbPath, [ref]$db) -ne 0) { Write-Host "Cannot open the database." -ForegroundColor Red; Pause-Exit 1 }
try {
    $users = Invoke-Sql $db "SELECT username, role, CASE is_active WHEN 1 THEN 'active' ELSE 'inactive' END FROM users ORDER BY user_id"
    Write-Host ""
    Write-Host "Users:" -ForegroundColor Cyan
    foreach ($u in $users) { Write-Host ("  {0,-25} role={1,-12} {2}" -f $u[0], $u[1], $u[2]) }

    $adminNames = @(foreach ($u in $users) { if ($u[1].ToUpper() -eq "ADMIN" -and $u[2] -eq "active") { $u[0] } })
    if ($adminNames.Count -gt 0) { Write-Host "Note: active admin(s) already exist: $($adminNames -join ', ')" -ForegroundColor Yellow }

    if (-not $Username) {
        $Username = Read-Host "Username to promote to ADMIN [manager]"
        if (-not $Username) { $Username = "manager" }
    }
    $target = $users | Where-Object { $_[0] -eq $Username }
    if (-not $target) { Write-Host "User '$Username' not found. Nothing changed." -ForegroundColor Red; Pause-Exit 1 }

    $confirm = Read-Host "Promote '$Username' (current role: $($target[1])) to ADMIN? (Y/N)"
    if ($confirm -notmatch '^[Yy]') { Write-Host "Cancelled. Nothing changed."; Pause-Exit 0 }

    [void](Invoke-Sql $db "UPDATE users SET role = 'ADMIN', is_active = 1 WHERE username = ?" @($Username))
    $check = Invoke-Sql $db "SELECT username, role, is_active FROM users WHERE username = ?" @($Username)
    Write-Host ""
    Write-Host "Done: $($check[0][0]) is now role=$($check[0][1])" -ForegroundColor Green
} finally {
    [void][WinSqlite]::sqlite3_close($db)
}

Write-Host ""
Write-Host "Next steps:" -ForegroundColor Cyan
Write-Host "  1. Open the app and sign in as '$Username'."
Write-Host "  2. Change the password right away to a strong one."
Write-Host "  3. Install the update from the update notice."
Write-Host "If anything looks wrong: close the app and copy the files from $bk back into $appDir."
Pause-Exit 0
