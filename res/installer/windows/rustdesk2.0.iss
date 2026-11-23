#define MyAppName "RustDesk2.0"
#define MyAppVersion "2.0.0"
#define MyAppPublisher "luojiang419"
#define MyAppExeName "rustdesk2.0.exe"
#define MyAppId "{{7DB3360A-DC3B-44AA-9A46-9E41F6942B50}"
#define MyRuntimeAppName "rustdesk2.0"
#define MyBuildDate GetDateTimeString("yyyy-mm-dd hh:nn", "", "")

[Setup]
AppId={#MyAppId}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppPublisher={#MyAppPublisher}
DefaultDirName={autopf}\RustDesk2.0
DefaultGroupName={#MyAppName}
DisableProgramGroupPage=yes
OutputDir=..\..\..\dist
OutputBaseFilename=rustdesk2.0-windows-x64-setup
SetupIconFile=..\..\..\flutter\windows\runner\resources\app_icon.ico
UninstallDisplayIcon={app}\{#MyAppExeName}
Compression=lzma2
SolidCompression=yes
WizardStyle=modern
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
PrivilegesRequired=admin
CloseApplications=yes
RestartApplications=no
VersionInfoVersion={#MyAppVersion}
VersionInfoCompany={#MyAppPublisher}
VersionInfoDescription={#MyAppName} Windows x64 installer
VersionInfoProductName={#MyAppName}
VersionInfoProductVersion={#MyAppVersion}

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: unchecked

[Files]
Source: "..\..\..\flutter\build\windows\x64\runner\Release\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Registry]
Root: HKLM; Subkey: "Software\Microsoft\Windows\CurrentVersion\Uninstall\{#MyRuntimeAppName}"; ValueType: string; ValueName: "InstallLocation"; ValueData: "{app}"; Flags: uninsdeletevalue uninsdeletekeyifempty
Root: HKLM; Subkey: "Software\Microsoft\Windows\CurrentVersion\Uninstall\{#MyRuntimeAppName}"; ValueType: string; ValueName: "BuildDate"; ValueData: "{#MyBuildDate}"; Flags: uninsdeletevalue uninsdeletekeyifempty

[Icons]
Name: "{group}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"
Name: "{autodesktop}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; Tasks: desktopicon

[Run]
Filename: "{app}\{#MyAppExeName}"; Description: "{cm:LaunchProgram,{#StringChange(MyAppName, '&', '&&')}}"; Flags: nowait postinstall skipifsilent
