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
;       verifies each copy by size and ABORTS the install if anything fails.
;   R2m When the chosen {app} has NO database and exactly ONE other install folder has one (e.g. an old
;       all-users install in Program Files), PrepareToInstall migrates it: stops the app, copies the DB
;       (+ -wal, -shm) READ-ONLY from the old folder into {app}\backups\pre_migrate_<tag>_<ts>\ (kept) and
;       \staging\, verifies size + SHA-256 against the source, then moves the staging copies into {app}
;       with RenameFile (never overwrites; the .db is placed last). On any failure it aborts and moves
;       the files it placed back into its staging folder; the old folder is never written or deleted.
;       Only in an INTERACTIVE install, only from a folder that is still a registered installation
;       (App Path + unins###.exe) and never twice for the same DB (HKCU marker with its SHA-256);
;       otherwise Setup aborts with the wrong-folder message. After the new version is installed
;       (ssPostInstall) the app is stopped again, the old DB re-checked against its fingerprint, and
;       only then the old uninstaller runs elevated (the old DB is uninsneveruninstall, so it stays
;       behind); if anything fails the user is told the old version is still there and must not be
;       used. Several other folders with a DB and none in {app}: ambiguous, Setup aborts.
;   R3  Uninstall keeps every piece of data: the database, .env and backups\ are never Setup
;       files, so the uninstaller does not own them and leaves them in place.
; tests/unit/test_installer_safety.py and scripts/release/bundle_guard.py enforce these rules.
; This file is UTF-8 with BOM so ISCC reads the Arabic messages in [Code] correctly.
; =====================================================================

#define MyAppName "Sorour Logistics"
#define MyAppVersion "2.5.1"
#define MyAppPublisher "Sorour Logistics"
#define MyAppURL "https://sorourlogistics.com"
; The app is started through frontend.exe itself (it starts backend.exe and waits for /health).
; Nothing in this script may point at the .vbs/.bat launchers: Windows is removing VBScript
; (absent in Windows Sandbox), which left the silent-update relaunch on an empty "Choose an app"
; dialog. The old launchers are no longer shipped and are removed from {app} ([InstallDelete]): they
; "freed" port 28080 with taskkill on every netstat line containing :28080, which also matched the
; running frontend.exe's own connections and closed the open app.
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
OutputBaseFilename=Sorour_Logistics_Setup_v2.5.1
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
Source: "..\dist\Sorour_Logistics_Standalone\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs; Excludes: "*.db,*.db-wal,*.db-shm,*.db-journal,*.sqlite*,.env,.env.*,*.key,*.pem,*.pfx,*.p12,backups\*,updates\*,reset_clean_production_db.py,clean_and_isolate_databases.py,sync_to_production.py,execute_user_database_updates.py,populate_all_world_transport_locations.py,clean_transport_locations.py,update_db_schema.py,restore_database.py,prepare_uat_environment.py,seed.py,\dist\*,Launch_Sorour_Logistics.vbs,Launch_ImportFlow.vbs,Sorour_Logistics_App.bat"

[InstallDelete]
; The ONLY allowed delete entries: destructive maintenance scripts that installers before Phase 0b
; copied into {app} (audit A4) and the legacy script launchers (see the note at the top). Exact file
; names, Type: files, no wildcards. Never add data here (scripts/release/bundle_guard.py fails on
; anything else).
Type: files; Name: "{app}\reset_clean_production_db.py"
Type: files; Name: "{app}\clean_and_isolate_databases.py"
Type: files; Name: "{app}\sync_to_production.py"
; seed.py: dev seeder with fixed demo passwords, found in the production {app} (2026-09-24).
Type: files; Name: "{app}\seed.py"
; Legacy launchers: their port-28080 taskkill closed the running app (2026-10-05). Also excluded above.
Type: files; Name: "{app}\Launch_Sorour_Logistics.vbs"
Type: files; Name: "{app}\Launch_ImportFlow.vbs"
Type: files; Name: "{app}\Sorour_Logistics_App.bat"
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
  UninstallWaitAttempts = 240; { 240 x 500 ms = 2 minutes }
  // HKCU marker of the last R2m migration (source path + SHA-256): the same database is never migrated twice.
  MigrationMarkerKey = 'Software\{#MyAppPublisher}\{#MyAppName}\InstallerMigration';

type
  { Existence, size and SHA-256 of sorour_logistics.db (+ -wal, -shm) in one folder. }
  TDbFingerprint = record
    HasWal, HasShm: Boolean;
    DbHigh, DbLow, WalHigh, WalLow, ShmHigh, ShmLow: Cardinal;
    HashDb, HashWal, HashShm: String;
  end;

var
  MigratedFromDir: String;         { old install folder the database was migrated from ('' = none) }
  MigrationBackupDir: String;      { verified copy of the migrated files }
  MigratedSource: TDbFingerprint;  { the old database as it was copied; re-checked before retiring }
  OldInstallStillPresent: Boolean;

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

/// Adds Dir to Dirs when it is not the chosen app folder, holds a database and is not listed yet
// (the registered all-users path and the Program Files default are usually the same folder).
procedure AddDatabaseFolder(var Dirs: TArrayOfString; const Dir, AppDir: String);
var
  Found: String;
  I, Count: Integer;
begin
  Found := DatabaseFolderIfOther(Dir, AppDir);
  if Found = '' then
    Exit;
  Count := GetArrayLength(Dirs);
  for I := 0 to Count - 1 do
    if NormalizeDir(Dirs[I]) = NormalizeDir(Found) then
      Exit;
  SetArrayLength(Dirs, Count + 1);
  Dirs[Count] := Found;
end;

{ Security review #1: an earlier install may live under the other install mode's folder
  (per-user %LOCALAPPDATA%\Programs vs all-users Program Files). Installing next to an empty
  database there would hide the real data, so look for it everywhere it can be and return
  every distinct folder (other than the chosen app folder) that holds a database. }
function FindDatabasesOutsideApp(const AppDir: String): TArrayOfString;
var
  Dirs: TArrayOfString;
begin
  SetArrayLength(Dirs, 0);
  AddDatabaseFolder(Dirs, RegisteredAppPath(HKCU), AppDir);
  AddDatabaseFolder(Dirs, RegisteredAppPath(HKLM32), AppDir);
  if IsWin64 then
    AddDatabaseFolder(Dirs, RegisteredAppPath(HKLM64), AppDir);
  AddDatabaseFolder(Dirs, ExpandConstant('{userpf}\{#MyAppName}'), AppDir);
  AddDatabaseFolder(Dirs, ExpandConstant('{commonpf32}\{#MyAppName}'), AppDir);
  if IsWin64 then
    AddDatabaseFolder(Dirs, ExpandConstant('{commonpf64}\{#MyAppName}'), AppDir);
#ifdef RehearsalOldInstallDir
  // Rehearsal builds only (ISCC /DRehearsalOldInstallDir=...): a fake old install folder.
  AddDatabaseFolder(Dirs, '{#RehearsalOldInstallDir}', AppDir);
#endif
#ifdef RehearsalOldInstallDir2
  AddDatabaseFolder(Dirs, '{#RehearsalOldInstallDir2}', AppDir);
#endif
  Result := Dirs;
end;

function JoinFolders(const Dirs: TArrayOfString): String;
var
  I: Integer;
begin
  Result := '';
  for I := 0 to GetArrayLength(Dirs) - 1 do
  begin
    if Result <> '' then
      Result := Result + #13#10;
    Result := Result + AddBackslash(Dirs[I]) + DbFileName;
  end;
end;

// The database lives in another folder and Setup will not migrate it automatically: several folders
// (ambiguous), a folder that is no longer a registered installation, or a silent install.
function WrongFolderAbortMessage(const FoundDbs, AppDir, Reason: String): String;
begin
  Result :=
    'تم العثور على قاعدة بيانات البرنامج في مجلد تثبيت آخر ولا يمكن نقلها تلقائياً، فتم إيقاف التثبيت حتى لا يعمل البرنامج بقاعدة بيانات فارغة أو خاطئة. بياناتك لم تتغير.' + #13#10 +
    'شغّل برنامج التثبيت بنفسك (ليس تحديثاً صامتاً)، ولو ظهرت هذه الرسالة مرة أخرى تواصل مع الدعم الفني لنقل التثبيت بأمان.' + #13#10#13#10 +
    'An existing ImportFlow database was found in a different installation folder and Setup cannot move it automatically. Setup stopped so the program does not run with an empty or wrong database. Your data was not changed.' + #13#10 +
    'Run Setup yourself (not as a silent update); if this message appears again, contact support to move the installation safely.' + #13#10#13#10 +
    'Reason: ' + Reason + #13#10 +
    'Existing data: ' + #13#10 + FoundDbs + #13#10 +
    'Selected folder: ' + AppDir;
end;

function MigrationAbortMessage(const Detail, OldDir, AppDir: String): String;
begin
  Result :=
    'تعذّر نقل قاعدة البيانات من التثبيت القديم إلى المجلد الجديد، فتم إيقاف التثبيت حفاظاً على بياناتك. قاعدة البيانات في المجلد القديم لم تتغير.' + #13#10 +
    'أغلق البرنامج تماماً وأعد المحاولة، ولو تكررت المشكلة تواصل مع الدعم الفني.' + #13#10#13#10 +
    'The database could not be migrated from the old installation, so Setup stopped to protect your data. The database in the old folder was not changed.' + #13#10 +
    'Close the application completely and try again. If this keeps happening, contact support.' + #13#10#13#10 +
    'Details: ' + Detail + #13#10 +
    'Existing data: ' + AddBackslash(OldDir) + DbFileName + #13#10 +
    'Selected folder: ' + AppDir;
end;

function OldInstallNotice(const OldDir, Detail: String): String;
begin
  Result :=
    'تم نقل بياناتك إلى التثبيت الجديد، لكن النسخة القديمة من البرنامج ما زالت مثبتة في:' + #13#10 + OldDir + #13#10 +
    'احذفها من الإعدادات ← التطبيقات (Settings → Apps) ولا تستخدمها بعد الآن: أي بيانات تُدخل فيها لن تظهر في النسخة الجديدة.' + #13#10#13#10 +
    'Your data was moved to the new installation, but the old version is still installed in:' + #13#10 + OldDir + #13#10 +
    'Remove it from Settings → Apps and do not use it any more: anything entered there will not appear in the new version.' + #13#10#13#10 +
    'Details: ' + Detail;
end;

{ Folder-name tag for the migration backup: letters and digits of the old path, other characters
  collapsed to '_' (C:\Program Files (x86)\Sorour Logistics -> C_Program_Files_x86_Sorour_Logistics),
  at most the last 48 characters. }
function MakeFolderTag(const Dir: String): String;
var
  I: Integer;
  C: Char;
begin
  Result := '';
  for I := 1 to Length(Dir) do
  begin
    C := Dir[I];
    if ((C >= '0') and (C <= '9')) or ((C >= 'a') and (C <= 'z')) or ((C >= 'A') and (C <= 'Z')) then
      Result := Result + C
    else if (Result <> '') and (Result[Length(Result)] <> '_') then
      Result := Result + '_';
  end;
  if (Result <> '') and (Result[Length(Result)] = '_') then
    Result := Copy(Result, 1, Length(Result) - 1);
  if Length(Result) > 48 then
    Result := Copy(Result, Length(Result) - 47, 48); // keep the distinctive end of the path
  if Result = '' then
    Result := 'old_install';
end;

{ SHA-256 of a file (read-only). False with ErrorText when the file cannot be read. }
function TryFileSha256(const FileName: String; var Hash, ErrorText: String): Boolean;
begin
  Result := False;
  Hash := '';
  try
    Hash := GetSHA256OfFile(FileName);
    Result := Hash <> '';
    if not Result then
      ErrorText := 'empty hash for ' + FileName;
  except
    ErrorText := 'cannot read ' + FileName + ': ' + GetExceptionMessage;
  end;
end;

{ Size and SHA-256 of one existing file (read-only). }
function ReadFileFingerprint(const FileName: String; var SizeHigh, SizeLow: Cardinal; var Hash, ErrorText: String): Boolean;
begin
  Result := False;
  if not GetFileSizeParts(FileName, SizeHigh, SizeLow) then
  begin
    ErrorText := 'cannot read the size of ' + FileName;
    Exit;
  end;
  Result := TryFileSha256(FileName, Hash, ErrorText);
end;

{ Fingerprint of the database in one folder: the .db is required, -wal / -shm are optional. Read-only. }
function ReadSourceFingerprint(const SrcDb: String; var F: TDbFingerprint; var ErrorText: String): Boolean;
begin
  Result := False;
  F.HasWal := FileExists(SrcDb + '-wal');
  F.HasShm := FileExists(SrcDb + '-shm');
  F.HashWal := '';
  F.HashShm := '';
  if not ReadFileFingerprint(SrcDb, F.DbHigh, F.DbLow, F.HashDb, ErrorText) then
    Exit;
  if F.HasWal then
    if not ReadFileFingerprint(SrcDb + '-wal', F.WalHigh, F.WalLow, F.HashWal, ErrorText) then
      Exit;
  if F.HasShm then
    if not ReadFileFingerprint(SrcDb + '-shm', F.ShmHigh, F.ShmLow, F.HashShm, ErrorText) then
      Exit;
  Result := True;
end;

{ Same files (existence of -wal / -shm included) with the same content. }
function SameFingerprint(const A, B: TDbFingerprint): Boolean;
begin
  Result := (A.HasWal = B.HasWal) and (A.HasShm = B.HasShm)
    and (CompareText(A.HashDb, B.HashDb) = 0)
    and (CompareText(A.HashWal, B.HashWal) = 0)
    and (CompareText(A.HashShm, B.HashShm) = 0);
end;

{ True when FileName exists with exactly this size. }
function FileSizeMatches(const FileName: String; SizeHigh, SizeLow: Cardinal; var ErrorText: String): Boolean;
var
  High, Low: Cardinal;
begin
  Result := False;
  if not GetFileSizeParts(FileName, High, Low) then
  begin
    ErrorText := 'copy is missing: ' + FileName;
    Exit;
  end;
  if (High <> SizeHigh) or (Low <> SizeLow) then
  begin
    ErrorText := 'copy size differs from the original: ' + FileName;
    Exit;
  end;
  Result := True;
end;

{ True when FileName exists with exactly this size and SHA-256. }
function FileMatches(const FileName: String; SizeHigh, SizeLow: Cardinal; const Hash: String; var ErrorText: String): Boolean;
var
  Actual: String;
begin
  Result := False;
  if not FileSizeMatches(FileName, SizeHigh, SizeLow, ErrorText) then
    Exit;
  if not TryFileSha256(FileName, Actual, ErrorText) then
    Exit;
  if CompareText(Actual, Hash) <> 0 then
  begin
    ErrorText := 'copy content (SHA-256) differs from the original: ' + FileName;
    Exit;
  end;
  Result := True;
end;

{ Copy one source file READ-ONLY into the migration folder <app>\backups\pre_migrate_<Stamp><SubDir>
  (SubDir = '\' for the kept backup, '\staging\' for the copy that is moved into place) and verify it.
  FailIfExists=True: never overwrites. The destination is written out literally so bundle_guard can
  prove statically that it lies under a pre_migrate_ backup folder. }
function CopyToMigrationFolder(const SourceFile, Stamp, SubDir: String; SizeHigh, SizeLow: Cardinal;
  const Hash: String; var ErrorText: String): Boolean;
var
  Target: String;
begin
  Result := False;
  Target := ExpandConstant('{app}\backups\pre_migrate_') + Stamp + SubDir + ExtractFileName(SourceFile);
  if FileExists(Target) then
  begin
    ErrorText := 'migration copy already exists: ' + Target;
    Exit;
  end;
  if not CopyFile(SourceFile, ExpandConstant('{app}\backups\pre_migrate_') + Stamp + SubDir + ExtractFileName(SourceFile), True) then
  begin
    ErrorText := 'copy failed: ' + SourceFile + ' -> ' + Target;
    Exit;
  end;
  if not FileMatches(Target, SizeHigh, SizeLow, Hash, ErrorText) then
    Exit;
  Log('Migration copy verified (size + SHA-256): ' + SourceFile + ' -> ' + Target);
  Result := True;
end;

{ Kept backup ('\') and staging ('\staging\') copies of the .db and the -wal / -shm that exist. }
function CopyAllToMigrationFolder(const SrcDb, Stamp, SubDir: String; const F: TDbFingerprint; var ErrorText: String): Boolean;
begin
  Result := False;
  if not CopyToMigrationFolder(SrcDb, Stamp, SubDir, F.DbHigh, F.DbLow, F.HashDb, ErrorText) then
    Exit;
  if F.HasWal then
    if not CopyToMigrationFolder(SrcDb + '-wal', Stamp, SubDir, F.WalHigh, F.WalLow, F.HashWal, ErrorText) then
      Exit;
  if F.HasShm then
    if not CopyToMigrationFolder(SrcDb + '-shm', Stamp, SubDir, F.ShmHigh, F.ShmLow, F.HashShm, ErrorText) then
      Exit;
  Result := True;
end;

{ Move a verified staging copy into the app folder. RenameFile (MoveFile) is atomic on one volume and
  fails when the target already exists, so it can never overwrite a database. Suffix: '', '-wal', '-shm'. }
function PlaceMigratedFile(const Stamp, Suffix: String): Boolean;
begin
  if Suffix = '-wal' then
    Result := RenameFile(ExpandConstant('{app}\backups\pre_migrate_') + Stamp + '\staging\sorour_logistics.db-wal', ExpandConstant('{app}\sorour_logistics.db-wal'))
  else if Suffix = '-shm' then
    Result := RenameFile(ExpandConstant('{app}\backups\pre_migrate_') + Stamp + '\staging\sorour_logistics.db-shm', ExpandConstant('{app}\sorour_logistics.db-shm'))
  else
    Result := RenameFile(ExpandConstant('{app}\backups\pre_migrate_') + Stamp + '\staging\sorour_logistics.db', ExpandConstant('{app}\sorour_logistics.db'));
end;

{ Failure after placing files: move ONLY the files this run placed back into its own staging folder
  (nothing is deleted). The .db goes first so a half-migrated folder never looks like a finished one. }
function UndoPlacedFiles(const Stamp: String; PlacedDb, PlacedWal, PlacedShm: Boolean): String;
begin
  Result := '';
  if PlacedDb then
    if not RenameFile(ExpandConstant('{app}\sorour_logistics.db'), ExpandConstant('{app}\backups\pre_migrate_') + Stamp + '\staging\sorour_logistics.db') then
      Result := Result + ' Could not move back ' + ExpandConstant('{app}\sorour_logistics.db') + '.';
  if PlacedWal then
    if not RenameFile(ExpandConstant('{app}\sorour_logistics.db-wal'), ExpandConstant('{app}\backups\pre_migrate_') + Stamp + '\staging\sorour_logistics.db-wal') then
      Result := Result + ' Could not move back ' + ExpandConstant('{app}\sorour_logistics.db-wal') + '.';
  if PlacedShm then
    if not RenameFile(ExpandConstant('{app}\sorour_logistics.db-shm'), ExpandConstant('{app}\backups\pre_migrate_') + Stamp + '\staging\sorour_logistics.db-shm') then
      Result := Result + ' Could not move back ' + ExpandConstant('{app}\sorour_logistics.db-shm') + '.';
  if Result <> '' then
    Log('MIGRATION ROLLBACK INCOMPLETE:' + Result)
  else
    Log('Migration rolled back: the files placed by this run were moved back to ' + ExpandConstant('{app}\backups\pre_migrate_') + Stamp + '\staging');
end;

{ True when the HKCU marker says this exact database (SHA-256) was already migrated once. }
function AlreadyMigrated(const HashDb: String; var Where: String): Boolean;
var
  Stored: String;
begin
  Result := False;
  Where := '';
  if not RegQueryStringValue(HKCU, MigrationMarkerKey, 'SourceSha256', Stored) then
    Exit;
  if CompareText(Stored, HashDb) <> 0 then
    Exit;
  if not RegQueryStringValue(HKCU, MigrationMarkerKey, 'MigratedTo', Where) then
    Where := '?';
  Result := True;
end;

procedure WriteMigrationMarker(const OldDir, HashDb: String);
begin
  if not (RegWriteStringValue(HKCU, MigrationMarkerKey, 'MigratedFrom', OldDir)
          and RegWriteStringValue(HKCU, MigrationMarkerKey, 'MigratedTo', ExpandConstant('{app}'))
          and RegWriteStringValue(HKCU, MigrationMarkerKey, 'SourceSha256', HashDb)
          and RegWriteStringValue(HKCU, MigrationMarkerKey, 'MigratedAt', GetDateTimeString('yyyy-mm-dd hh:nn:ss', '-', ':'))) then
    Log('WARNING: could not write the migration marker ' + MigrationMarkerKey);
end;

{ R2m: copy the database (+ -wal, -shm) of the one other install folder into the empty app folder.
  The source files are only read. Every copy is verified by size and SHA-256 against the source,
  and the source is fingerprinted again at the end to prove it did not change while it was copied. }
function MigrateDatabaseFromOtherFolder(const OldDir: String; var Source: TDbFingerprint; var ErrorText: String): Boolean;
var
  SrcDb, Stamp, BackupDir, Where: String;
  Recheck: TDbFingerprint;
  PlacedDb, PlacedWal, PlacedShm: Boolean;
begin
  Result := False;
  PlacedDb := False;
  PlacedWal := False;
  PlacedShm := False;
  SrcDb := AddBackslash(OldDir) + DbFileName;

  // never overwrite: the app folder must not hold any database file yet
  if FileExists(ExpandConstant('{app}\sorour_logistics.db')) or FileExists(ExpandConstant('{app}\sorour_logistics.db-wal'))
     or FileExists(ExpandConstant('{app}\sorour_logistics.db-shm')) then
  begin
    ErrorText := 'the selected folder already holds sorour_logistics.db, -wal or -shm; nothing is overwritten';
    Exit;
  end;

  if not ReadSourceFingerprint(SrcDb, Source, ErrorText) then
    Exit;
  if AlreadyMigrated(Source.HashDb, Where) then
  begin
    ErrorText := 'this exact database was already migrated once (to ' + Where + '); it is not migrated again';
    Exit;
  end;

  Stamp := MakeFolderTag(OldDir) + '_' + GetDateTimeString('yyyymmdd_hhnnss', #0, #0);
  BackupDir := ExpandConstant('{app}\backups\pre_migrate_') + Stamp;
  if DirExists(BackupDir) then
  begin
    ErrorText := 'the migration folder already exists: ' + BackupDir;
    Exit;
  end;
  if not ForceDirectories(BackupDir + '\staging') then
  begin
    ErrorText := 'cannot create the migration folder ' + BackupDir;
    Exit;
  end;

  // 1. kept backup copy, 2. staging copy that is moved into place; both verified by size + SHA-256
  if not CopyAllToMigrationFolder(SrcDb, Stamp, '\', Source, ErrorText) then
    Exit;
  if not CopyAllToMigrationFolder(SrcDb, Stamp, '\staging\', Source, ErrorText) then
    Exit;

  // the source must not have changed while it was copied (the app was stopped)
  if not ReadSourceFingerprint(SrcDb, Recheck, ErrorText) then
    Exit;
  if not SameFingerprint(Source, Recheck) then
  begin
    ErrorText := 'the old database changed while it was being copied (is the old version still running?)';
    Exit;
  end;

  // 3. move the staging copies into place: side files first, the .db last
  if Source.HasWal then
  begin
    if not PlaceMigratedFile(Stamp, '-wal') then
    begin
      ErrorText := 'cannot move the migrated -wal into ' + ExpandConstant('{app}') + UndoPlacedFiles(Stamp, PlacedDb, PlacedWal, PlacedShm);
      Exit;
    end;
    PlacedWal := True;
  end;
  if Source.HasShm then
  begin
    if not PlaceMigratedFile(Stamp, '-shm') then
    begin
      ErrorText := 'cannot move the migrated -shm into ' + ExpandConstant('{app}') + UndoPlacedFiles(Stamp, PlacedDb, PlacedWal, PlacedShm);
      Exit;
    end;
    PlacedShm := True;
  end;
  if not PlaceMigratedFile(Stamp, '') then
  begin
    ErrorText := 'cannot move the migrated database into ' + ExpandConstant('{app}') + UndoPlacedFiles(Stamp, PlacedDb, PlacedWal, PlacedShm);
    Exit;
  end;
  PlacedDb := True;

  // 4. a same-volume move keeps the verified content: check the files are there with their size
  if (not FileSizeMatches(ExpandConstant('{app}\sorour_logistics.db'), Source.DbHigh, Source.DbLow, ErrorText))
     or (Source.HasWal and not FileSizeMatches(ExpandConstant('{app}\sorour_logistics.db-wal'), Source.WalHigh, Source.WalLow, ErrorText))
     or (Source.HasShm and not FileSizeMatches(ExpandConstant('{app}\sorour_logistics.db-shm'), Source.ShmHigh, Source.ShmLow, ErrorText)) then
  begin
    ErrorText := ErrorText + UndoPlacedFiles(Stamp, PlacedDb, PlacedWal, PlacedShm);
    Exit;
  end;

  WriteMigrationMarker(OldDir, Source.HashDb);
  MigrationBackupDir := BackupDir;
  Log('Database migrated from ' + SrcDb + ' to ' + ExpandConstant('{app}\sorour_logistics.db') +
      ' (verified by size and SHA-256); backup copy kept in ' + BackupDir);
  Result := True;
end;

{ unins000.exe .. unins999.exe: the only file name an Inno Setup uninstaller has. }
function IsInnoUninstallerName(const FileName: String): Boolean;
var
  Name: String;
  I: Integer;
begin
  Name := Lowercase(FileName);
  Result := (Length(Name) = 12) and (Copy(Name, 1, 5) = 'unins') and (Copy(Name, 9, 4) = '.exe');
  if Result then
    for I := 6 to 8 do
      if (Name[I] < '0') or (Name[I] > '9') then
        Result := False;
end;

{ The uninstaller of the install registered under RootKey/Key, but only when that registration points
  at OldDir and the uninstaller is an unins###.exe directly inside OldDir. }
function UninstallerFromKey(const RootKey: Integer; const Key, OldDir: String; var Exe: String): Boolean;
var
  Path, Value: String;
begin
  Result := False;
  Exe := '';
  if not RegQueryStringValue(RootKey, Key, 'Inno Setup: App Path', Path) then
    Exit;
  if NormalizeDir(Path) <> NormalizeDir(OldDir) then
    Exit;
  if not RegQueryStringValue(RootKey, Key, 'UninstallString', Value) then
    Exit;
  Value := RemoveQuotes(Trim(Value));
  if NormalizeDir(ExtractFileDir(Value)) <> NormalizeDir(OldDir) then
    Exit;
  if not IsInnoUninstallerName(ExtractFileName(Value)) then
    Exit;
  if not FileExists(Value) then
    Exit;
  Exe := Value;
  Result := True;
end;

{ OldDir is still a REGISTERED installation (HKLM 32/64 or HKCU) with its uninstaller. All-users
  registrations (HKLM) need elevation to uninstall; a per-user one does not. }
function FindOldUninstaller(const OldDir: String; var RootKey: Integer; var Key, Exe: String; var Elevate: Boolean): Boolean;
begin
  Result := True;
  Key := AppUninstallKey;
  Elevate := True;
  RootKey := HKLM32;
  if UninstallerFromKey(RootKey, Key, OldDir, Exe) then
    Exit;
  if IsWin64 then
  begin
    RootKey := HKLM64;
    if UninstallerFromKey(RootKey, Key, OldDir, Exe) then
      Exit;
  end;
  Elevate := False;
  RootKey := HKCU;
  if UninstallerFromKey(RootKey, Key, OldDir, Exe) then
    Exit;
#ifdef RehearsalOldUninstallKey
  // Rehearsal builds only: the fake old install is registered per-user under its own test key.
  Key := '{#RehearsalOldUninstallKey}';
  Elevate := True;
  if UninstallerFromKey(RootKey, Key, OldDir, Exe) then
    Exit;
#endif
  Result := False;
end;

{ Retire the old installation so nobody keeps entering data into it. The old installers mark
  sorour_logistics.db uninsneveruninstall (and -wal/-shm are not Setup files), so the old database
  stays behind as a leftover copy. True when the old install is gone; Detail explains a failure. }
function RetireOldInstall(const OldDir: String; var Detail: String): Boolean;
var
  RootKey, ErrorCode, Attempt: Integer;
  Key, Exe, Verb, Remaining: String;
  Elevate: Boolean;
begin
  Result := False;
  if not FindOldUninstaller(OldDir, RootKey, Key, Exe, Elevate) then
  begin
    Detail := 'no registered uninstaller found for ' + OldDir;
    Exit;
  end;
  if Elevate then
  begin
#ifdef RehearsalElevateVerb
    Verb := '{#RehearsalElevateVerb}';
#else
    Verb := 'runas';
#endif
  end
  else
    Verb := '';
  Log('Retiring the old installation: ' + Exe + ' /VERYSILENT /SUPPRESSMSGBOXES /NORESTART (verb "' + Verb + '")');
  if not ShellExec(Verb, Exe, '/VERYSILENT /SUPPRESSMSGBOXES /NORESTART', '', SW_SHOWNORMAL, ewWaitUntilTerminated, ErrorCode) then
  begin
    Detail := 'the old uninstaller did not run (UAC declined or failed), code ' + IntToStr(ErrorCode) + ': ' + SysErrorMessage(ErrorCode);
    Exit;
  end;
  // the Inno uninstaller finishes from a copy in %TEMP%: wait until its registration is gone
  for Attempt := 1 to UninstallWaitAttempts do
  begin
    if not UninstallerFromKey(RootKey, Key, OldDir, Remaining) then
    begin
      Log('The old installation in ' + OldDir + ' was uninstalled.');
      if FileExists(AddBackslash(OldDir) + DbFileName) then
        Log('The old database stays behind as a leftover copy: ' + AddBackslash(OldDir) + DbFileName);
      Result := True;
      Exit;
    end;
    Sleep(500);
  end;
  Detail := 'the old installation in ' + OldDir + ' is still registered after running its uninstaller';
end;

{ ssPostInstall, only after a verified migration AND a completed install of the new version: stop the
  app again, prove the old database is still exactly what was copied, then retire the old install.
  Anything else leaves the old install in place and tells the user not to use it. }
procedure RetireOldInstallAfterInstall;
var
  Current: TDbFingerprint;
  Detail: String;
begin
  Detail := '';
  StopRunningApp;
  if not WaitForAppExit then
    Detail := 'frontend.exe or backend.exe is still running'
  else if not ReadSourceFingerprint(AddBackslash(MigratedFromDir) + DbFileName, Current, Detail) then
    Detail := 'cannot re-check the old database: ' + Detail
  else if not SameFingerprint(MigratedSource, Current) then
    Detail := 'the old database changed after it was copied (was the old version used?); the old version is kept'
  else if RetireOldInstall(MigratedFromDir, Detail) then
    Exit;
  OldInstallStillPresent := True;
  Log('NOTICE: ' + OldInstallNotice(MigratedFromDir, Detail));
  if not WizardSilent then
    MsgBox(OldInstallNotice(MigratedFromDir, Detail), mbInformation, MB_OK);
end;

{ R2m gate: migrate only interactively and only from a folder that is still a registered installation
  with its own uninstaller. A leftover database in an unregistered folder (e.g. after an earlier
  migration and uninstall) is not migrated. }
function MigrationAllowed(const OldDir: String; var Reason: String): Boolean;
var
  RootKey: Integer;
  Key, Exe: String;
  Elevate: Boolean;
begin
  Result := False;
  if WizardSilent then
  begin
#ifdef RehearsalAllowSilentMigration
    Log('Rehearsal build: silent migration allowed');
#else
    Reason := 'silent install: moving the database from another installation is only done in an interactive install';
    Exit;
#endif
  end;
  if not FindOldUninstaller(OldDir, RootKey, Key, Exe, Elevate) then
  begin
    Reason := 'the other folder is not a registered installation (no Inno Setup: App Path + unins###.exe for it)';
    Exit;
  end;
  Result := True;
end;

{ R2m: exactly one other folder holds the database and the app folder has none. '' = migrated, go on.
  The old installation is NOT touched here: it is retired in ssPostInstall, after the new version is in. }
function MigrateFromOldInstall(const OldDir, AppDir: String): String;
var
  ErrorText: String;
begin
  Result := '';
  Log('No database in ' + AppDir + '; migrating the one found in ' + OldDir);
  StopRunningApp;
  if not WaitForAppExit then
  begin
    Result := MigrationAbortMessage('frontend.exe or backend.exe is still running and could not be stopped.', OldDir, AppDir);
    Exit;
  end;
  ErrorText := '';
  if not MigrateDatabaseFromOtherFolder(OldDir, MigratedSource, ErrorText) then
  begin
    Log('Migration failed: ' + ErrorText);
    Result := MigrationAbortMessage(ErrorText, OldDir, AppDir);
    Exit;
  end;
  MigratedFromDir := OldDir;
end;

procedure LogOtherDatabases(const Dirs: TArrayOfString; const DbFile: String);
begin
  if GetArrayLength(Dirs) > 0 then
    Log('The selected folder already has its database (' + DbFile + '); continuing with it. Other install folders '
        + 'that also hold a database are left untouched:' + #13#10 + JoinFolders(Dirs));
end;

function MigrationSummary: String;
begin
  Result :=
    'تم نقل البيانات من: ' + AddBackslash(MigratedFromDir) + DbFileName + #13#10 +
    'Data was migrated from: ' + AddBackslash(MigratedFromDir) + DbFileName + #13#10 +
    'Backup copy: ' + MigrationBackupDir;
end;

procedure CurStepChanged(CurStep: TSetupStep);
begin
#ifdef RehearsalAbortAfterPrepare
  if CurStep = ssInstall then
  begin
    Log('Rehearsal build: simulating a cancel after PrepareToInstall');
    Abort;
  end;
#endif
  // retire the old installation only once the new version is completely installed
  if (CurStep = ssPostInstall) and (MigratedFromDir <> '') then
    RetireOldInstallAfterInstall;
end;

procedure CurPageChanged(CurPageID: Integer);
begin
  if (CurPageID = wpFinished) and (MigratedFromDir <> '') then
  begin
    WizardForm.FinishedLabel.Caption := WizardForm.FinishedLabel.Caption + #13#10#13#10 + MigrationSummary;
    if OldInstallStillPresent then
      WizardForm.FinishedLabel.Caption := WizardForm.FinishedLabel.Caption + #13#10#13#10 + OldInstallNotice(MigratedFromDir, 'see the Setup log');
    WizardForm.FinishedLabel.AdjustHeight;
    WizardForm.RunList.Top := WizardForm.FinishedLabel.Top + WizardForm.FinishedLabel.Height + ScaleY(12);
  end;
end;

procedure DeinitializeSetup;
begin
  if MigratedFromDir <> '' then
    Log(MigrationSummary);
end;

{ R2: runs before any file is installed. A non-empty result aborts Setup
  (interactive: shown on the Preparing page; silent: logged, exit code 7). }
function PrepareToInstall(var NeedsRestart: Boolean): String;
var
  AppDir, DbFile, BackupStamp, BackupDir, ErrorText, Reason: String;
  OtherDirs: TArrayOfString;
begin
  Result := '';
  AppDir := ExpandConstant('{app}');
  DbFile := AddBackslash(AppDir) + DbFileName;
  OtherDirs := FindDatabasesOutsideApp(AppDir);
  if not FileExists(DbFile) then
  begin
    if GetArrayLength(OtherDirs) > 1 then
    begin
      Result := WrongFolderAbortMessage(JoinFolders(OtherDirs), AppDir, 'more than one other folder holds a database');
      Exit;
    end;
    if GetArrayLength(OtherDirs) = 1 then
    begin
      if not MigrationAllowed(OtherDirs[0], Reason) then
      begin
        Result := WrongFolderAbortMessage(JoinFolders(OtherDirs), AppDir, Reason);
        Exit;
      end;
      Result := MigrateFromOldInstall(OtherDirs[0], AppDir);
      Exit;
    end;
    Log('No existing database at ' + DbFile + ' or in any other install folder: fresh install, nothing to back up.');
    Exit;
  end;
  LogOtherDatabases(OtherDirs, DbFile);

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
