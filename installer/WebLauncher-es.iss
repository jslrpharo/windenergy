; =============================================================================
;  WebLauncher ACMSL — Instalador en español
;  Inno Setup 6.x
;
;  Requisito previo: C:\ACMSL\WindFarmSimulator\ ya instalado con el paquete
;  de simuladores (los tutoriales integrados y la Guía SCADA residen ahí).
;
;  Para compilar:
;    - Abrir este fichero con Inno Setup 6 y pulsar Build > Compile
;    - El ejecutable resultante se genera en installer\output\
; =============================================================================

#define AppName      "WebLauncher ACMSL"
#define AppVersion   "1.12"
#define AppPublisher "Automated Computing Machinery SL (ACMSL)"
#define AppURL       "https://www.acm-sl.com"
#define InstallDir   "C:\ACMSL\Weblauncher"
#define ConfigName   "uned"
#define LaunchScript "LaunchWebLauncher.vbs"

; Directorio raíz del proyecto (donde está este .iss)
#define SrcDir ".."

; =============================================================================
[Setup]
; IMPORTANTE: regenerar el AppId con Tools > Generate GUID en Inno Setup
AppId={{AEB52C08-A81F-480A-85C3-00A8BC7A9C63}} 
AppName={#AppName}
AppVersion={#AppVersion}
AppVerName={#AppName} {#AppVersion}
AppPublisher={#AppPublisher}
AppPublisherURL={#AppURL}
AppSupportURL={#AppURL}
AppUpdatesURL={#AppURL}

; Directorio de instalación fijo bajo C:\ACMSL\ (coherente con el resto de
; la suite ACMSL). El usuario puede cambiarlo si lo desea.
DefaultDirName={#InstallDir}
DefaultGroupName={#AppName}

; Fichero de salida
OutputDir=output
OutputBaseFilename=WebLauncher-ACMSL-{#AppVersion}-es-Setup
SetupIconFile=ACM_LOGO.ico

; Compresión máxima (el directorio simulators/es puede ser grande)
Compression=lzma2/ultra64
SolidCompression=yes

; Requiere administrador para instalar bajo C:\ACMSL\
PrivilegesRequired=admin

; Solo español — no mostrar selector de idioma
ShowLanguageDialog=no
WizardStyle=modern

; Mostrar resumen de espacio en disco
DiskSpanning=no
UninstallDisplayIcon={app}\installer\ACM_LOGO.ico

; =============================================================================
[Languages]
Name: "spanish"; MessagesFile: "compiler:Languages\Spanish.isl"

; =============================================================================
[Tasks]
Name: "desktopicon"; \
  Description: "Crear acceso directo en el &Escritorio"; \
  GroupDescription: "Accesos directos adicionales:"

; =============================================================================
[Files]

; --- Servidor web y scripts de lanzamiento ---
Source: "{#SrcDir}\ACMSLWebServer.exe";   DestDir: "{app}"; Flags: ignoreversion
Source: "{#SrcDir}\LaunchWebLauncher.vbs"; DestDir: "{app}"; Flags: ignoreversion
Source: "{#SrcDir}\OpenTutorial.vbs";      DestDir: "{app}"; Flags: ignoreversion

; Configuración del servidor (solo si no existe, para no machacar puerto elegido)
Source: "{#SrcDir}\ACMSLWebServer.ini"; DestDir: "{app}"; \
  Flags: onlyifdoesntexist

; --- Páginas web principales ---
Source: "{#SrcDir}\WebLauncher.html"; DestDir: "{app}"; Flags: ignoreversion
Source: "{#SrcDir}\404.html";         DestDir: "{app}"; Flags: ignoreversion

; --- Imágenes (comunes a todos los idiomas) ---
Source: "{#SrcDir}\img\*"; DestDir: "{app}\img"; \
  Flags: ignoreversion recursesubdirs createallsubdirs

; --- Configuraciones ---
; Solo los ficheros necesarios para español
Source: "{#SrcDir}\configurations\uned.json";  DestDir: "{app}\configurations"; Flags: ignoreversion
Source: "{#SrcDir}\configurations\todos.json";  DestDir: "{app}\configurations"; Flags: ignoreversion
Source: "{#SrcDir}\configurations\all.json";    DestDir: "{app}\configurations"; Flags: ignoreversion
Source: "{#SrcDir}\configurations\i18n\es.json"; DestDir: "{app}\configurations\i18n"; Flags: ignoreversion
Source: "{#SrcDir}\configurations\videos\videos-es.xml"; \
  DestDir: "{app}\configurations\videos"; Flags: ignoreversion

; --- Tutoriales (solo español) ---
Source: "{#SrcDir}\tutorials\tutorial.css";          DestDir: "{app}\tutorials"; Flags: ignoreversion
Source: "{#SrcDir}\tutorials\tutorial-standalone.js"; DestDir: "{app}\tutorials"; Flags: ignoreversion
Source: "{#SrcDir}\tutorials\js\*";   DestDir: "{app}\tutorials\js"; \
  Flags: ignoreversion recursesubdirs createallsubdirs
Source: "{#SrcDir}\tutorials\data\*"; DestDir: "{app}\tutorials\data"; \
  Flags: ignoreversion recursesubdirs createallsubdirs
Source: "{#SrcDir}\tutorials\es\*";   DestDir: "{app}\tutorials\es"; \
  Flags: ignoreversion recursesubdirs createallsubdirs

; --- Simuladores (solo español) ---
;Source: "{#SrcDir}\simulators\es\*"; DestDir: "{app}\simulators\es"; \
  ;Flags: ignoreversion recursesubdirs createallsubdirs

; --- Icono para accesos directos ---
Source: "ACM_LOGO.ico"; DestDir: "{app}\installer"; Flags: ignoreversion

; =============================================================================
[Icons]

; Menú Inicio
Name: "{group}\{#AppName}"; \
  Filename: "{sys}\wscript.exe"; \
  Parameters: """{app}\{#LaunchScript}"" cl={#ConfigName}"; \
  WorkingDir: "{app}"; \
  IconFilename: "{app}\installer\ACM_LOGO.ico"; \
  Comment: "Lanzar WebLauncher ACMSL en español"

Name: "{group}\Desinstalar {#AppName}"; \
  Filename: "{uninstallexe}"

; Escritorio (opcional)
Name: "{commondesktop}\{#AppName}"; \
  Filename: "{sys}\wscript.exe"; \
  Parameters: """{app}\{#LaunchScript}"" cl={#ConfigName}"; \
  WorkingDir: "{app}"; \
  IconFilename: "{app}\installer\ACM_LOGO.ico"; \
  Comment: "Lanzar WebLauncher ACMSL en español"; \
  Tasks: desktopicon

; =============================================================================
[Run]
; Ofrecer lanzar la aplicación al terminar la instalación
Filename: "{sys}\wscript.exe"; \
  Parameters: """{app}\{#LaunchScript}"" cl={#ConfigName}"; \
  WorkingDir: "{app}"; \
  Description: "Lanzar {#AppName} ahora"; \
  Flags: nowait postinstall skipifsilent

; =============================================================================
[UninstallDelete]
; Borrar el INI de configuración del servidor al desinstalar
; (contiene el puerto asignado dinámicamente, no tiene valor fuera de la app)
Type: files; Name: "{app}\ACMSLWebServer.ini"

; =============================================================================
[Code]
// Comprueba que el prerequisito C:\ACMSL\WindFarmSimulator\ existe
// Si no existe, avisa pero permite continuar
procedure InitializeWizard;
var
  MsgResult: Integer;
begin
  if not DirExists('C:\ACMSL\WindFarmSimulator') then
  begin
    MsgResult := MsgBox(
      'Atención: No se ha encontrado la carpeta C:\ACMSL\WindFarmSimulator\.' + #13#10 +
      'Esta carpeta contiene los simuladores y tutoriales integrados' + #13#10 +
      'a los que hace referencia WebLauncher.' + #13#10#13#10 +
      '¿Desea continuar la instalación igualmente?',
      mbConfirmation, MB_YESNO);
    if MsgResult = IDNO then
      Abort;
  end;
end;
