'===================================================================
' OpenTutorial.vbs
' Abre una URL de tutorial en Edge --app (sin barra de URL ni pestanas).
' Convierte http://localhost:PORT/path  a  file:///BASE/path#from=launcher
' para carga directa desde disco (rapida, sin depender del servidor HTTP).
' El hash #from=launcher activa el modo standalone en tutorial-standalone.js.
'
' USO:
'   cscript OpenTutorial.vbs <url>
'===================================================================
Option Explicit

Dim objShell, objFSO
Set objShell = CreateObject("WScript.Shell")
Set objFSO   = CreateObject("Scripting.FileSystemObject")

If WScript.Arguments.Count < 1 Then WScript.Quit 1
Dim url : url = WScript.Arguments(0)

' --- Perfil Edge aislado para los tutoriales ---
Dim profileDir : profileDir = objShell.ExpandEnvironmentStrings("%TEMP%") & "\ACMSLTutorial"
If Not objFSO.FolderExists(profileDir) Then objFSO.CreateFolder profileDir
' Crear "First Run" para que Edge no muestre el asistente de bienvenida
Dim firstRunFile : firstRunFile = profileDir & "\First Run"
If Not objFSO.FileExists(firstRunFile) Then
    Dim fFirst : Set fFirst = objFSO.CreateTextFile(firstRunFile, False)
    fFirst.Close : Set fFirst = Nothing
End If

' --- Convertir http://localhost:PORT/path  ->  file:///BASE/path#from=launcher ---
' Se usa file:// para carga instantanea desde disco (sin pasar por el servidor).
' El hash #from=launcher es detectado por tutorial-standalone.js para ocultar
' la navegacion interior (el query string ?... no funciona en URLs file://).
Dim baseDir : baseDir = objFSO.GetParentFolderName(WScript.ScriptFullName)
Dim targetUrl : targetUrl = url
If LCase(Left(url, 7)) = "http://" Or LCase(Left(url, 8)) = "https://" Then
    Dim slashPos : slashPos = InStr(8, url, "/")
    Dim urlPath : urlPath = "/"
    If slashPos > 0 Then
        ' Tomar solo la ruta, sin query string
        Dim qPos : qPos = InStr(slashPos, url, "?")
        If qPos > 0 Then
            urlPath = Mid(url, slashPos, qPos - slashPos)
        Else
            urlPath = Mid(url, slashPos)
        End If
    End If
    targetUrl = "file:///" & Replace(baseDir, "\", "/") & urlPath & "#from=launcher"
End If

' LOG de diagnostico
Dim logFile : logFile = objShell.ExpandEnvironmentStrings("%TEMP%") & "\OpenTutorial_log.txt"
Dim fLog : Set fLog = objFSO.CreateTextFile(logFile, True)
fLog.WriteLine "url_in=[" & url & "]"
fLog.WriteLine "targetUrl=[" & targetUrl & "]"
fLog.Close : Set fLog = Nothing

' --- Buscar msedge.exe ---
Dim paths, p
paths = Array( _
    objShell.ExpandEnvironmentStrings("%ProgramFiles(x86)%") & "\Microsoft\Edge\Application\msedge.exe", _
    objShell.ExpandEnvironmentStrings("%ProgramFiles%")       & "\Microsoft\Edge\Application\msedge.exe", _
    objShell.ExpandEnvironmentStrings("%LocalAppData%")       & "\Microsoft\Edge\Application\msedge.exe"  _
)
Dim edgePath : edgePath = ""
For Each p In paths
    If objFSO.FileExists(p) Then edgePath = p : Exit For
Next

If edgePath = "" Then
    MsgBox "No se encontro Microsoft Edge.", vbCritical, "OpenTutorial"
    WScript.Quit 1
End If

' --- Lanzar Edge ---
objShell.Run """" & edgePath & """" & _
    " --app=" & targetUrl & _
    " --user-data-dir=""" & profileDir & """" & _
    " --allow-file-access-from-files" & _
    " --no-first-run --no-default-browser-check --no-restore-last-session", 1, False

Set objFSO   = Nothing
Set objShell = Nothing
WScript.Quit 0
