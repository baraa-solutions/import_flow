; =====================================================================
; Sorour Logistics ERP — Inno Setup Script
; Builds a Single Fast Windows Setup Wizard (.EXE Installer)
; =====================================================================
; PRODUCTION DATABASE SAFETY (docs/plans/update-system-plan.md, section 0)
;   R1  This installer never ships, replaces or deletes *.db, *.db-wal, *.db-shm, .env,
;       backups\ or updates\. There is NO [UninstallDelete] section; [InstallDelete] only removes
;       the legacy destructive scripts old installers left in {app} (exact names).
;       The backend creates an empty database on first run when none exists.
;   R2  PrepareToInstall (see [Code]) stops frontend.exe/backend.exe, copies the existing
;       database (+ -wal, -shm) to {app}\backups\pre_install_<old version>_<timestamp>\,
;       verifies each copy by size and ABORTS the install if anything fails. It also aborts
;       when the database exists in another install folder but not in the chosen {app}.
;   R3  Uninstall keeps every piece of data: the database, .env and backups\ are never Setup
;       files, so the uninstaller does not own them and leaves them in place.
; tests/unit/test_installer_safety.py and scripts/release/bundle_guard.py enforce these rules.
; This file is UTF-8 with BOM so ISCC reads the Arabic messages in [Code] correctly.
; =====================================================================

#define MyAppName "Sorour Logistics"
#define MyAppVersion "2.1.0"
#define MyAppPublisher "Sorour Logistics"
#define MyAppURL "https://sorourlogistics.com"
; The app is started through frontend.exe itself (it starts backend.exe and waits for /health).
; Nothing in this script may point at the .vbs/.bat launchers: Windows is removing VBScript
; (absent in Windows Sandbox), which left the silent-update relaunch on an empty "Choose an app"
; dialog. The launchers are still shipped as a harmless manual fallback.
#define MyAppExeName "frontend.exe"
#define AppIconPath "app_icon.ico"

[Setup]
AppId={{D37B4254-8B6A-4A73-B5DF-719584C8A69E}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppPublisher={#MyAppPublisher}
AppPublisherURL={#MyAppURL}
AppSupportURL={#MyAppURL}
AppUpdatesURL={#MyAppURL}
DefaultDirName={autopf}\{#MyAppName}
DefaultGroupName={#MyAppName}
AllowNoIcons=yes
OutputDir=..\dist\releases
OutputBaseFilename=Sorour_Logistics_Setup_v2.1.0
SetupIconFile={#AppIconPath}
Compression=lzma2/max
SolidCompression=yes
WizardStyle=modern
; Always the same (per-user) install mode: no PrivilegesRequiredOverridesAllowed, so an upgrade
; can never switch to all-users and land in a different {app} next to an empty database.
; PrepareToInstall also aborts if the database is found under the other mode's folder.
PrivilegesRequired=lowest
UninstallDisplayIcon={app}\app_icon.ico
CloseApplications=yes
RestartApplications=no

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: unchecked

[Dirs]
; R3: data folders are created with uninsneveruninstall so the uninstaller never removes them,
; even when empty. Their contents are never Setup files, so they are never deleted either.
Name: "{app}\backups"; Flags: uninsneveruninstall
Name: "{app}\updates"; Flags: uninsneveruninstall

[Files]
; Application binaries and assets ONLY.
; R1: Excludes keeps databases, secrets, data folders and the destructive maintenance scripts out of
; the installer even if they ever appear in the staging folder. There must never be a [Files] entry
; for sorour_logistics.db or .env: the live data in {app} is never replaced by Setup.
Source: "..\dist\Sorour_Logistics_Standalone\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs; Excludes: "*.db,*.db-wal,*.db-shm,*.db-journal,*.sqlite*,.env,.env.*,*.key,*.pem,*.pfx,*.p12,backups\*,updates\*,reset_clean_production_db.py,clean_and_isolate_databases.py,sync_to_production.py,execute_user_database_updates.py,populate_all_world_transport_locations.py,clean_transport_locations.py,update_db_schema.py,restore_database.py,prepare_uat_environment.py,seed.py,\dist\*"

[InstallDelete]
; The ONLY allowed delete entries: destructive maintenance scripts that installers before Phase 0b
; copied into {app} (audit A4). Exact file names, Type: files, no wildcards. Never add data here
; (scripts/release/bundle_guard.py fails on anything else).
Type: files; Name: "{app}\reset_clean_production_db.py"
Type: files; Name: "{app}\clean_and_isolate_databases.py"
Type: files; Name: "{app}\sync_to_production.py"
; seed.py: dev seeder with fixed demo passwords, found in the production {app} (2026-09-24).
Type: files; Name: "{app}\seed.py"
; {app}\data\ (Flutter runtime: app.so, icudtl.dat, flutter_assets) is only ever overwritten file-by-file
; by [Files]; nothing is deleted there. {app}\dist\ (unknown content) is never touched: no [Files]
; entry targets it and the staging Excludes "\dist\*" keep a stray dist folder out of the installer.

[Icons]
; Shortcuts are re-created on every install, overwriting same-named ones, so an upgrade replaces
; old shortcuts that pointed at Launch_Sorour_Logistics.vbs.
Name: "{group}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; IconFilename: "{app}\app_icon.ico"; WorkingDir: "{app}"
Name: "{group}\{cm:UninstallProgram,{#MyAppName}}"; Filename: "{uninstallexe}"
Name: "{autodesktop}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; IconFilename: "{app}\app_icon.ico"; WorkingDir: "{app}"; Tasks: desktopicon

[Run]
; Interactive install: optional "Launch" checkbox on the last page (unchanged behaviour).
Filename: "{app}\{#MyAppExeName}"; WorkingDir: "{app}"; Description: "{cm:LaunchProgram,{#StringChange(MyAppName, '&', '&&')}}"; Flags: postinstall nowait skipifsilent
; Silent in-app update (plan C11): relaunch the app only when /RELAUNCH=1 is passed.
Filename: "{app}\{#MyAppExeName}"; WorkingDir: "{app}"; Flags: nowait runasoriginaluser; Check: ShouldRelaunchAfterSilentInstall

; R3: no [UninstallDelete] section on purpose. Uninstall removes only files Setup installed;
; sorour_logistics.db (+ -wal/-shm), .env, backups\ and updates\ stay on disk.

[Code]
const
  DbFileName = 'sorour_logistics.db';
  AppUninstallKey = 'Software\Microsoft\Windows\CurrentVersion\Uninstall\{D37B4254-8B6A-4A73-B5DF-719584C8A69E}_is1';
  ProcessWaitAttempts = 20; { 20 x 500 ms = 10 seconds }

{ C11: /RELAUNCH=1 on a /SILENT or /VERYSILENT install restarts the app after the update. }
function ShouldRelaunchAfterSilentInstall: Boolean;
begin
  Result := WizardSilent and (ExpandConstant('{param:RELAUNCH|0}') = '1');
end;

{ True while a process with this image name exists. Unknown state counts as running (fail safe). }
function IsProcessRunning(const ExeName: String): Boolean;
var
  OutFile: String;
  Output: AnsiString;
  ResultCode: Integer;
begin
  Result := True;
  OutFile := ExpandConstant('{tmp}\process_check_' + ExeName + '.txt');
  // bundle_guard only accepts deletions whose argument is literally under the tmp constant
  DeleteFile(ExpandConstant('{tmp}\process_check_' + ExeName + '.txt'));
  if not Exec(ExpandConstant('{cmd}'), '/C tasklist /NH /FI "IMAGENAME eq ' + ExeName + '" > "' + OutFile + '"',
              '', SW_HIDE, ewWaitUntilTerminated, ResultCode) then
  begin
    Log('Could not run tasklist to check ' + ExeName);
    Exit;
  end;
  if not LoadStringFromFile(OutFile, Output) then
  begin
    Log('Could not read tasklist output for ' + ExeName);
    Exit;
  end;
  Result := Pos(Lowercase(ExeName), Lowercase(String(Output))) > 0;
end;

// K2 (update-system spec): no /T (tree kill) here. During an in-app update this Setup runs as a child of
// backend.exe, so killing the backend's process tree would kill Setup inside its own PrepareToInstall and
// the update would silently not happen. Matching by image name already stops both PyInstaller onefile
// processes (bootloader parent and child) of each exe.
procedure StopRunningApp;
var
  ResultCode: Integer;
begin
  Exec(ExpandConstant('{sys}\taskkill.exe'), '/F /IM frontend.exe', '', SW_HIDE, ewWaitUntilTerminated, ResultCode);
  Exec(ExpandConstant('{sys}\taskkill.exe'), '/F /IM backend.exe', '', SW_HIDE, ewWaitUntilTerminated, ResultCode);
end;

{ Kill both processes and wait until they are really gone, so the DB files are consistent on disk. }
function WaitForAppExit: Boolean;
var
  Attempt: Integer;
begin
  Result := False;
  for Attempt := 1 to ProcessWaitAttempts do
  begin
    if (not IsProcessRunning('frontend.exe')) and (not IsProcessRunning('backend.exe')) then
    begin
      Sleep(500); { let Windows release the file handles }
      Result := True;
      Exit;
    end;
    if (Attempt mod 4) = 0 then
      StopRunningApp;
    Sleep(500);
  end;
end;

function SanitizeForPath(const Raw: String): String;
var
  I: Integer;
  C: Char;
begin
  Result := '';
  for I := 1 to Length(Raw) do
  begin
    C := Raw[I];
    if ((C >= '0') and (C <= '9')) or ((C >= 'a') and (C <= 'z')) or ((C >= 'A') and (C <= 'Z'))
       or (C = '.') or (C = '-') or (C = '_') then
      Result := Result + C;
  end;
end;

{ Version of the installation being replaced, from its uninstall registry key; 'unknown' if absent. }
function GetInstalledVersion: String;
var
  Value: String;
begin
  Value := '';
  if not RegQueryStringValue(HKCU, AppUninstallKey, 'DisplayVersion', Value) then
    if not RegQueryStringValue(HKLM, AppUninstallKey, 'DisplayVersion', Value) then
      Value := '';
  Result := SanitizeForPath(Value);
  if Result = '' then
    Result := 'unknown';
end;

{ File size as two 32-bit halves (no Int64 arithmetic needed to compare them). }
function GetFileSizeParts(const FileName: String; var SizeHigh, SizeLow: Cardinal): Boolean;
var
  FindRec: TFindRec;
begin
  Result := False;
  if FindFirst(FileName, FindRec) then
  begin
    try
      SizeHigh := FindRec.SizeHigh;
      SizeLow := FindRec.SizeLow;
      Result := True;
    finally
      FindClose(FindRec);
    end;
  end;
end;

{ Copy one DB file into the pre-install backup folder <app>\backups\pre_install_<BackupStamp>
  and verify the copy exists with the same size.
  Optional files (-wal / -shm) that do not exist are skipped; a required file must exist.
  The CopyFile destination is written out literally (not via a variable) so bundle_guard can
  prove statically that the installer only ever writes into a pre_install_ backup folder. }
function BackupOneFile(const SourceFile, BackupStamp: String; Required: Boolean; var ErrorText: String): Boolean;
var
  Target: String;
  SrcHigh, SrcLow, DstHigh, DstLow: Cardinal;
begin
  Result := False;
  if not FileExists(SourceFile) then
  begin
    if Required then
      ErrorText := 'file not found: ' + SourceFile
    else
      Result := True;
    Exit;
  end;
  Target := ExpandConstant('{app}\backups\pre_install_') + BackupStamp + '\' + ExtractFileName(SourceFile);
  if not GetFileSizeParts(SourceFile, SrcHigh, SrcLow) then
  begin
    ErrorText := 'cannot read the size of ' + SourceFile;
    Exit;
  end;
  if not CopyFile(SourceFile, ExpandConstant('{app}\backups\pre_install_') + BackupStamp + '\' + ExtractFileName(SourceFile), True) then
  begin
    ErrorText := 'copy failed: ' + SourceFile + ' -> ' + Target;
    Exit;
  end;
  if not GetFileSizeParts(Target, DstHigh, DstLow) then
  begin
    ErrorText := 'backup copy is missing: ' + Target;
    Exit;
  end;
  if (DstHigh <> SrcHigh) or (DstLow <> SrcLow) then
  begin
    ErrorText := 'backup copy size differs from the original: ' + Target;
    Exit;
  end;
  Log('Pre-install backup verified: ' + SourceFile + ' -> ' + Target);
  Result := True;
end;

function BackupAbortMessage(const Detail, DbFile: String): String;
begin
  Result :=
    'تعذّر أخذ نسخة احتياطية من قاعدة البيانات قبل التثبيت، فتم إيقاف التثبيت حفاظاً على بياناتك. لم يتم تغيير أي ملف في البرنامج.' + #13#10 +
    'أغلق البرنامج تماماً وأعد المحاولة، ولو تكررت المشكلة تواصل مع الدعم الفني.' + #13#10#13#10 +
    'The database could not be backed up before installation, so Setup stopped to protect your data. No program files were changed.' + #13#10 +
    'Close the application completely and try again. If this keeps happening, contact support.' + #13#10#13#10 +
    'Details: ' + Detail + #13#10 +
    'Database: ' + DbFile;
end;

function NormalizeDir(const Dir: String): String;
begin
  Result := Lowercase(RemoveBackslashUnlessRoot(Trim(Dir)));
end;

// Returns Dir when it is not the chosen app folder and holds a database, otherwise ''.
function DatabaseFolderIfOther(const Dir, AppDir: String): String;
begin
  Result := '';
  if Trim(Dir) = '' then
    Exit;
  if NormalizeDir(Dir) = NormalizeDir(AppDir) then
    Exit;
  if FileExists(AddBackslash(Trim(Dir)) + DbFileName) then
    Result := RemoveBackslashUnlessRoot(Trim(Dir));
end;

function RegisteredAppPath(const RootKey: Integer): String;
begin
  Result := '';
  if not RegQueryStringValue(RootKey, AppUninstallKey, 'Inno Setup: App Path', Result) then
    Result := '';
end;

{ Security review #1: an earlier install may live under the other install mode's folder
  (per-user %LOCALAPPDATA%\Programs vs all-users Program Files). Installing next to an empty
  database there would hide the real data, so look for it everywhere it can be. }
function FindDatabaseOutsideApp(const AppDir: String): String;
begin
  Result := DatabaseFolderIfOther(RegisteredAppPath(HKCU), AppDir);
  if Result = '' then
    Result := DatabaseFolderIfOther(RegisteredAppPath(HKLM32), AppDir);
  if (Result = '') and IsWin64 then
    Result := DatabaseFolderIfOther(RegisteredAppPath(HKLM64), AppDir);
  if Result = '' then
    Result := DatabaseFolderIfOther(ExpandConstant('{userpf}\{#MyAppName}'), AppDir);
  if Result = '' then
    Result := DatabaseFolderIfOther(ExpandConstant('{commonpf32}\{#MyAppName}'), AppDir);
  if (Result = '') and IsWin64 then
    Result := DatabaseFolderIfOther(ExpandConstant('{commonpf64}\{#MyAppName}'), AppDir);
end;

function WrongFolderAbortMessage(const FoundDir, AppDir: String): String;
begin
  Result :=
    'تم العثور على قاعدة بيانات البرنامج في مجلد تثبيت آخر، فتم إيقاف التثبيت حتى لا يعمل البرنامج بقاعدة بيانات فارغة. بياناتك لم تتغير.' + #13#10 +
    'تواصل مع الدعم الفني لنقل التثبيت بأمان.' + #13#10#13#10 +
    'An existing ImportFlow database was found in a different installation folder. Setup stopped so the update is not installed next to an empty database. Your data was not changed.' + #13#10 +
    'Contact support to move the installation safely.' + #13#10#13#10 +
    'Existing data: ' + AddBackslash(FoundDir) + DbFileName + #13#10 +
    'Selected folder: ' + AppDir;
end;

{ R2: runs before any file is installed. A non-empty result aborts Setup
  (interactive: shown on the Preparing page; silent: logged, exit code 7). }
function PrepareToInstall(var NeedsRestart: Boolean): String;
var
  AppDir, DbFile, BackupStamp, BackupDir, ErrorText, OtherDir: String;
begin
  Result := '';
  AppDir := ExpandConstant('{app}');
  DbFile := AddBackslash(AppDir) + DbFileName;
  if not FileExists(DbFile) then
  begin
    OtherDir := FindDatabaseOutsideApp(AppDir);
    if OtherDir <> '' then
    begin
      Result := WrongFolderAbortMessage(OtherDir, AppDir);
      Exit;
    end;
    Log('No existing database at ' + DbFile + ' or in any other install folder: fresh install, nothing to back up.');
    Exit;
  end;

  StopRunningApp;
  if not WaitForAppExit then
  begin
    Result := BackupAbortMessage('frontend.exe or backend.exe is still running and could not be stopped.', DbFile);
    Exit;
  end;

  BackupStamp := GetInstalledVersion + '_' + GetDateTimeString('yyyymmdd_hhnnss', #0, #0);
  BackupDir := ExpandConstant('{app}\backups\pre_install_') + BackupStamp;
  if not ForceDirectories(BackupDir) then
  begin
    Result := BackupAbortMessage('cannot create the backup folder ' + BackupDir, DbFile);
    Exit;
  end;

  ErrorText := '';
  if not BackupOneFile(DbFile, BackupStamp, True, ErrorText) then
  begin
    Result := BackupAbortMessage(ErrorText, DbFile);
    Exit;
  end;
  if not BackupOneFile(DbFile + '-wal', BackupStamp, False, ErrorText) then
  begin
    Result := BackupAbortMessage(ErrorText, DbFile);
    Exit;
  end;
  if not BackupOneFile(DbFile + '-shm', BackupStamp, False, ErrorText) then
  begin
    Result := BackupAbortMessage(ErrorText, DbFile);
    Exit;
  end;
  Log('Pre-install database backup completed in ' + BackupDir);
end;
