#ifndef AppVersion
  #define AppVersion "1.0.0"
#endif
#define AppExe "voges_slides.exe"
#define ProgId "VogesSlides.Presentation"

[Setup]
AppId={{4DC4094D-935D-4401-9890-C938262346EA}
ShowLanguageDialog=auto
AppName=Voges Slides
AppVersion={#AppVersion}
AppPublisher=omanoloneto
AppPublisherURL=https://omanoloneto.pro/voges/slides/
AppSupportURL=https://github.com/omanoloneto/voges-slides/issues
VersionInfoVersion={#AppVersion}
DefaultDirName={autopf}\Voges Slides
DisableProgramGroupPage=yes
PrivilegesRequired=lowest
PrivilegesRequiredOverridesAllowed=dialog
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
MinVersion=10.0
ChangesAssociations=yes
SetupIconFile=..\..\windows\runner\resources\app_icon.ico
UninstallDisplayIcon={app}\{#AppExe}
UninstallDisplayName=Voges Slides
OutputDir=..\..\build\installer
OutputBaseFilename=VogesSlides-windows-setup
Compression=lzma2/max
SolidCompression=yes
WizardStyle=modern

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"
Name: "brazilianportuguese"; MessagesFile: "compiler:Languages\BrazilianPortuguese.isl"
Name: "spanish"; MessagesFile: "compiler:Languages\Spanish.isl"

[CustomMessages]
english.PresentationTypeName=Voges Slides Presentation
brazilianportuguese.PresentationTypeName=Apresentação do Voges Slides
spanish.PresentationTypeName=Presentación de Voges Slides

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: unchecked

[Files]
Source: "..\..\build\windows\x64\runner\Release\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{autoprograms}\Voges Slides"; Filename: "{app}\{#AppExe}"
Name: "{autodesktop}\Voges Slides"; Filename: "{app}\{#AppExe}"; Tasks: desktopicon

[Registry]
; adds the app to "Open with" for every format it opens without making it the default program
Root: HKA; Subkey: "Software\Classes\{#ProgId}"; ValueType: string; ValueData: "{cm:PresentationTypeName}"; Flags: uninsdeletekey
Root: HKA; Subkey: "Software\Classes\{#ProgId}\DefaultIcon"; ValueType: string; ValueData: "{app}\{#AppExe},0"
Root: HKA; Subkey: "Software\Classes\{#ProgId}\shell\open\command"; ValueType: string; ValueData: """{app}\{#AppExe}"" ""%1"""
Root: HKA; Subkey: "Software\Classes\.pptx\OpenWithProgids"; ValueType: string; ValueName: "{#ProgId}"; ValueData: ""; Flags: uninsdeletevalue
Root: HKA; Subkey: "Software\Classes\.potx\OpenWithProgids"; ValueType: string; ValueName: "{#ProgId}"; ValueData: ""; Flags: uninsdeletevalue
Root: HKA; Subkey: "Software\Classes\.ppsx\OpenWithProgids"; ValueType: string; ValueName: "{#ProgId}"; ValueData: ""; Flags: uninsdeletevalue
Root: HKA; Subkey: "Software\Classes\Applications\{#AppExe}"; ValueType: string; ValueName: "FriendlyAppName"; ValueData: "Voges Slides"; Flags: uninsdeletekey
Root: HKA; Subkey: "Software\Classes\Applications\{#AppExe}\SupportedTypes"; ValueType: string; ValueName: ".pptx"; ValueData: ""
Root: HKA; Subkey: "Software\Classes\Applications\{#AppExe}\SupportedTypes"; ValueType: string; ValueName: ".potx"; ValueData: ""
Root: HKA; Subkey: "Software\Classes\Applications\{#AppExe}\SupportedTypes"; ValueType: string; ValueName: ".ppsx"; ValueData: ""

[Run]
Filename: "{app}\{#AppExe}"; Description: "{cm:LaunchProgram,Voges Slides}"; Flags: nowait postinstall skipifsilent
