'===================================================================
' LaunchWebLauncher.vbs
' Lanzador de ACMSLWebServer + WebLauncher
'
' 1) Lee el puerto configurado en ACMSLWebServer.ini
'    y avisa si no esta disponible
' 2) Si ACMSLServerClaude.exe no esta corriendo, lo lanza minimizado
' 3) Espera a que el servidor responda en el puerto configurado
' 4) Abre Edge en modo --app (sin pestanas, sin barra de URL)
'    con un user-data-dir propio para poder rastrear el proceso
' 5) Monitoriza Edge: cuando el usuario cierra la ventana,
'    cierra automaticamente el servidor de forma ordenada
'
' USO:
'   LaunchWebLauncher.vbs [cl=<config>] [lang=<idioma>]
'   LaunchWebLauncher.vbs <config> [<idioma>]
'
' Ejemplos:
'   LaunchWebLauncher.vbs cl=mint
'   LaunchWebLauncher.vbs cl=mint lang=es
'   LaunchWebLauncher.vbs mint
'   LaunchWebLauncher.vbs mint es
'===================================================================

Option Explicit

Const SERVER_EXE       = "ACMSLWebServer.exe"
Const INI_FILE         = "ACMSLWebServer.ini"
Const MAX_WAIT_SECONDS = 10
Const EDGE_PROFILE_NAME = "ACMSLWebLauncher"
Const POLL_INTERVAL_MS = 500

Dim objShell, objWMI, objFSO
Set objShell = CreateObject("WScript.Shell")
Set objWMI   = GetObject("winmgmts:\\.\root\cimv2")
Set objFSO   = CreateObject("Scripting.FileSystemObject")

' Directorio del script (donde estan el .exe y WebLauncher.html)
Dim scriptDir
scriptDir = Left(WScript.ScriptFullName, InStrRev(WScript.ScriptFullName, "\"))

' ===================================================================
' PASO 0: Procesar argumentos de linea de comando
' ===================================================================
Dim configClient, language, uiLanguage
configClient = ""
language = ""

If WScript.Arguments.Count > 0 Then
    Dim arg, i
    For i = 0 To WScript.Arguments.Count - 1
        arg = WScript.Arguments(i)
        If InStr(arg, "=") > 0 Then
            Dim parts
            parts = Split(arg, "=", 2)
            If UCase(parts(0)) = "CL" Then
                configClient = parts(1)
            ElseIf UCase(parts(0)) = "LANG" Then
                language = parts(1)
            End If
        Else
            If i = 0 Then
                configClient = arg
            ElseIf i = 1 Then
                language = arg
            End If
        End If
    Next
End If

uiLanguage = ResolveRegionLanguage()

' Si no se ha indicado configuracion, salir sin hacer nada
If configClient = "" Then
    WScript.Quit 0
End If

' Perfil temporal de Edge para aislar el proceso
Dim edgeProfileDir
edgeProfileDir = objShell.ExpandEnvironmentStrings("%TEMP%") & "\" & EDGE_PROFILE_NAME

' ===================================================================
' PASO 1: Comprobar si el servidor ya esta corriendo
' ===================================================================
Dim colProcesses
Set colProcesses = objWMI.ExecQuery( _
    "SELECT Name FROM Win32_Process WHERE Name='" & SERVER_EXE & "'")

Dim serverYaCorria
serverYaCorria = (colProcesses.Count > 0)

' ===================================================================
' PASO 2: Leer el puerto del INI y comprobar si esta disponible
' ===================================================================
Dim iniPath, serverPort
iniPath = scriptDir & INI_FILE

serverPort = ReadPortFromINI(iniPath)
If serverPort = 0 Then
    MsgBox "No se encontro un valor port= valido en " & INI_FILE & "." & _
           vbCrLf & vbCrLf & _
           "Revise el fichero INI antes de iniciar ACMSLWebServer.", _
           vbExclamation, "ACMSLWebServer"
    WScript.Quit 1
End If

If Not serverYaCorria Then
    If Not IsPortAvailable(serverPort) Then
        MsgBox "El puerto configurado en " & INI_FILE & " (" & serverPort & ") no esta disponible." & _
               vbCrLf & vbCrLf & _
               "Libere ese puerto o cambie manualmente el valor port= en el fichero INI.", _
               vbExclamation, "ACMSLWebServer"
        WScript.Quit 1
    End If
End If

' URL base del servidor (dinamica segun el puerto configurado)
Dim SERVER_URL
SERVER_URL = "http://localhost:" & serverPort & "/"

' Construir URL con parametros
Dim finalURL, hasParams
finalURL  = SERVER_URL
hasParams = False

If configClient <> "" Then
    finalURL  = finalURL & "?cl=" & configClient
    hasParams = True
End If

' ===================================================================
' PASO 3: Lanzar el servidor si no esta corriendo
' ===================================================================
If Not serverYaCorria Then
    Dim serverPath
    serverPath = scriptDir & SERVER_EXE

    If Not objFSO.FileExists(serverPath) Then
        MsgBox "No se encuentra " & serverPath, vbCritical, "Error"
        WScript.Quit 1
    End If

    ' Lanzar minimizado (7 = minimized, False = no esperar)
    objShell.Run """" & serverPath & """ lang=" & uiLanguage, 7, False
End If

' ===================================================================
' PASO 4: Esperar a que el servidor responda
' ===================================================================
Dim ready, elapsed
ready   = False
elapsed = 0

Do While Not ready And elapsed < MAX_WAIT_SECONDS
    ready = ServerResponde()
    If Not ready Then
        WScript.Sleep 500
        elapsed = elapsed + 0.5
    End If
Loop

If Not ready Then
    MsgBox "El servidor no responde despues de " & MAX_WAIT_SECONDS & " segundos.", _
           vbExclamation, "ACMSLWebServer"
    WScript.Quit 1
End If

' ===================================================================
' PASO 5: Abrir Edge en modo app con perfil aislado
' ===================================================================
Dim edgePath
edgePath = FindEdge()

If edgePath = "" Then
    ' Fallback: navegador por defecto (sin monitorizacion)
    objShell.Run finalURL
Else
    ' Comprobar si Edge con nuestro perfil ya esta corriendo
    Dim colEdgeCheck
    Set colEdgeCheck = GetEdgeAppProcesses()

    If colEdgeCheck.Count > 0 Then
        Set colEdgeCheck = Nothing
        Set colProcesses = Nothing
        Set objFSO = Nothing
        Set objWMI = Nothing
        Set objShell = Nothing
        WScript.Quit 0
    End If
    Set colEdgeCheck = Nothing

    ' Crear directorio de perfil si no existe
    If Not objFSO.FolderExists(edgeProfileDir) Then
        objFSO.CreateFolder edgeProfileDir
    End If

    ' Lanzar Edge con perfil aislado
    LaunchEdgeApp edgePath, finalURL, edgeProfileDir

    ' Esperar a que Edge arranque
    WScript.Sleep 3000

    ' ==============================================================
    ' PASO 6: Monitorizar Edge - cuando se cierre, parar el servidor
    ' ==============================================================
    Dim colEdge

    Do
        WScript.Sleep POLL_INTERVAL_MS

        Set colEdge = GetEdgeAppProcesses()

        If colEdge.Count = 0 Then
            If ShowTopmostExitConfirmation(uiLanguage) = vbYes Then
                Exit Do
            End If

            LaunchEdgeApp edgePath, finalURL, edgeProfileDir
            WScript.Sleep 1500
        End If
    Loop

    ' Edge cerrado: cerrar el servidor (solo si lo lanzamos nosotros)
    If Not serverYaCorria Then
        RequestServerShutdown
        If Not WaitForServerProcessExit(MAX_WAIT_SECONDS) Then
            ForceTerminateServer
            Call WaitForServerProcessExit(3)
        End If
    End If
End If

' ===================================================================
' LIMPIEZA
' ===================================================================
Set colProcesses = Nothing
Set objFSO = Nothing
Set objWMI = Nothing
Set objShell = Nothing
WScript.Quit 0

'===================================================================
' GetEdgeAppProcesses: devuelve solo los procesos raiz de Edge que
' corresponden a la ventana app lanzada por este script
'===================================================================
Function GetEdgeAppProcesses()
    Set GetEdgeAppProcesses = objWMI.ExecQuery( _
        "SELECT ProcessId FROM Win32_Process WHERE Name='msedge.exe'" & _
        " AND CommandLine LIKE '%--app=%'" & _
        " AND CommandLine LIKE '%" & EDGE_PROFILE_NAME & "%'")
End Function

'===================================================================
' ResolveRegionLanguage: usa siempre el idioma de Region de Windows
'===================================================================
Function ResolveRegionLanguage()
    ResolveRegionLanguage = NormalizeLanguage(GetWindowsLocaleName())
    If ResolveRegionLanguage = "" Then
        ResolveRegionLanguage = "en"
    End If
End Function

'===================================================================
' GetWindowsLocaleName: lee el locale de Windows desde el registro
'===================================================================
Function GetWindowsLocaleName()
    On Error Resume Next
    GetWindowsLocaleName = objShell.RegRead("HKCU\Control Panel\International\LocaleName")
    If Err.Number <> 0 Then
        Err.Clear
        GetWindowsLocaleName = objShell.RegRead("HKCU\Control Panel\International\sLanguage")
    End If
    If Err.Number <> 0 Then
        Err.Clear
        GetWindowsLocaleName = ""
    End If
    On Error GoTo 0
End Function

'===================================================================
' NormalizeLanguage: normaliza el codigo de idioma soportado
'===================================================================
Function NormalizeLanguage(value)
    Dim shortCode
    shortCode = LCase(Left(Trim(CStr(value)), 2))

    Select Case shortCode
        Case "es", "en", "it", "fr", "de", "pt"
            NormalizeLanguage = shortCode
        Case Else
            NormalizeLanguage = ""
    End Select
End Function

'===================================================================
' GetLocalizedText: textos UI del launcher segun idioma
'===================================================================
Function GetLocalizedText(langCode, textKey)
    Select Case textKey
        Case "exit_confirm_message"
            Select Case langCode
                Case "es": GetLocalizedText = "Desea salir realmente de WebLauncher?"
                Case "it": GetLocalizedText = "Si desidera davvero uscire da WebLauncher?"
                Case "fr": GetLocalizedText = "Voulez-vous vraiment quitter WebLauncher ?"
                Case "de": GetLocalizedText = "Mochten Sie WebLauncher wirklich beenden?"
                Case "pt": GetLocalizedText = "Deseja realmente sair do WebLauncher?"
                Case Else: GetLocalizedText = "Do you really want to exit WebLauncher?"
            End Select
        Case "exit_confirm_title"
            Select Case langCode
                Case "es": GetLocalizedText = "Confirmar salida"
                Case "it": GetLocalizedText = "Conferma uscita"
                Case "fr": GetLocalizedText = "Confirmer la fermeture"
                Case "de": GetLocalizedText = "Beenden bestatigen"
                Case "pt": GetLocalizedText = "Confirmar saida"
                Case Else: GetLocalizedText = "Confirm exit"
            End Select
        Case Else
            GetLocalizedText = ""
    End Select
End Function

'===================================================================
' ShowTopmostExitConfirmation: muestra la confirmacion en primer plano
'===================================================================
Function ShowTopmostExitConfirmation(langCode)
    Dim popupFlags

    popupFlags = vbQuestion + vbYesNo + vbDefaultButton2 + vbSystemModal + vbMsgBoxSetForeground
    ShowTopmostExitConfirmation = objShell.Popup( _
        GetLocalizedText(langCode, "exit_confirm_message"), _
        0, _
        GetLocalizedText(langCode, "exit_confirm_title"), _
        popupFlags)
End Function

'===================================================================
' IsPortAvailable: ejecuta netstat y comprueba si el puerto indicado
' esta libre para poder arrancar el servidor
'===================================================================
Function IsPortAvailable(port)
    Dim tmpFile, f, netstatOut, lines, i, lineText
    tmpFile    = objShell.ExpandEnvironmentStrings("%TEMP%") & "\acmsl_portcheck.tmp"
    netstatOut = ""

    objShell.Run "cmd /c netstat -an -p tcp > """ & tmpFile & """", 0, True

    If objFSO.FileExists(tmpFile) Then
        Set f = objFSO.OpenTextFile(tmpFile, 1)
        netstatOut = f.ReadAll
        f.Close
        objFSO.DeleteFile tmpFile, True
    End If

    IsPortAvailable = True
    lines = Split(netstatOut, vbCrLf)

    For i = 0 To UBound(lines)
        lineText = Trim(lines(i))
        If InStr(1, lineText, ":" & port & " ", vbTextCompare) > 0 And _
           InStr(1, lineText, "LISTENING", vbTextCompare) > 0 Then
            IsPortAvailable = False
            Exit Function
        End If
    Next
End Function

'===================================================================
' LaunchEdgeApp: abre Edge en modo app con el perfil aislado
'===================================================================
Sub LaunchEdgeApp(edgePath, finalURL, edgeProfileDir)
    Dim edgeCmd
    edgeCmd = """" & edgePath & """ --app=" & finalURL & _
              " --user-data-dir=""" & edgeProfileDir & """"
    objShell.Run edgeCmd, 1, False
End Sub

'===================================================================
' ReadPortFromINI: lee el valor port= de la seccion [server]
'===================================================================
Function ReadPortFromINI(iniFile)
    ReadPortFromINI = 0
    On Error Resume Next
    If Not objFSO.FileExists(iniFile) Then Exit Function

    Dim f, line, p
    Set f = objFSO.OpenTextFile(iniFile, 1)
    Do While Not f.AtEndOfStream
        line = Trim(f.ReadLine)
        If LCase(Left(line, 5)) = "port=" Then
            p = Trim(Mid(line, 6))
            If IsNumeric(p) Then ReadPortFromINI = CInt(p)
            Exit Do
        End If
    Loop
    f.Close
    On Error GoTo 0
End Function

'===================================================================
' UpdateINIPort: sustituye el valor port= en la seccion [server]
'               del fichero INI (lo crea si no existe)
'===================================================================
Sub UpdateINIPort(iniFile, newPort)
    On Error Resume Next
    Dim content, f

    If objFSO.FileExists(iniFile) Then
        Set f   = objFSO.OpenTextFile(iniFile, 1)
        content = f.ReadAll
        f.Close
    Else
        ' Crear un INI minimo
        content = "[server]" & vbCrLf & "port=" & newPort & vbCrLf
        Set f = objFSO.CreateTextFile(iniFile, True)
        f.Write content
        f.Close
        Exit Sub
    End If

    ' Reemplazar la linea port= dentro de [server]
    Dim lines, j, inServer, newContent
    lines      = Split(content, vbCrLf)
    inServer   = False
    newContent = ""

    For j = 0 To UBound(lines)
        Dim trimLine
        trimLine = Trim(lines(j))
        If LCase(trimLine) = "[server]" Then
            inServer   = True
            newContent = newContent & lines(j) & vbCrLf
        ElseIf Len(trimLine) > 0 And Left(trimLine, 1) = "[" Then
            inServer   = False
            newContent = newContent & lines(j) & vbCrLf
        ElseIf inServer And LCase(Left(trimLine, 5)) = "port=" Then
            newContent = newContent & "port=" & newPort & vbCrLf
        Else
            newContent = newContent & lines(j) & vbCrLf
        End If
    Next

    Set f = objFSO.CreateTextFile(iniFile, True)
    f.Write newContent
    f.Close
    On Error GoTo 0
End Sub

'===================================================================
' ServerResponde: comprueba si el servidor responde en SERVER_URL
'===================================================================
Function ServerResponde()
    On Error Resume Next
    Dim http
    Set http = CreateObject("MSXML2.ServerXMLHTTP.6.0")
    http.setTimeouts 1000, 1000, 1000, 1000
    http.Open "GET", SERVER_URL, False
    http.Send

    If Err.Number = 0 And http.Status = 200 Then
        ServerResponde = True
    Else
        ServerResponde = False
    End If

    Set http = Nothing
    On Error GoTo 0
End Function

'===================================================================
' RequestServerShutdown: pide al servidor que se cierre por su API
'===================================================================
Sub RequestServerShutdown()
    On Error Resume Next
    Dim http
    Set http = CreateObject("MSXML2.ServerXMLHTTP.6.0")
    http.setTimeouts 1000, 1000, 2000, 2000
    http.Open "GET", SERVER_URL & "api/shutdown", False
    http.Send
    Set http = Nothing
    On Error GoTo 0
End Sub

'===================================================================
' WaitForServerProcessExit: espera a que no quede ningun proceso del
' servidor vivo durante un maximo de timeoutSeconds segundos
'===================================================================
Function WaitForServerProcessExit(timeoutSeconds)
    Dim elapsed, colServer
    elapsed = 0

    Do While elapsed < timeoutSeconds
        Set colServer = objWMI.ExecQuery( _
            "SELECT ProcessId FROM Win32_Process WHERE Name='" & SERVER_EXE & "'")
        If colServer.Count = 0 Then
            WaitForServerProcessExit = True
            Exit Function
        End If
        WScript.Sleep 250
        elapsed = elapsed + 0.25
    Loop

    WaitForServerProcessExit = False
End Function

'===================================================================
' ForceTerminateServer: ultimo recurso si el cierre ordenado falla
'===================================================================
Sub ForceTerminateServer()
    Dim colServer, proc
    Set colServer = objWMI.ExecQuery( _
        "SELECT * FROM Win32_Process WHERE Name='" & SERVER_EXE & "'")
    For Each proc In colServer
        proc.Terminate
    Next
    Set colServer = Nothing
End Sub

'===================================================================
' FindEdge: localiza msedge.exe
'===================================================================
Function FindEdge()
    Dim paths, p

    paths = Array( _
        objShell.ExpandEnvironmentStrings("%ProgramFiles(x86)%") & "\Microsoft\Edge\Application\msedge.exe", _
        objShell.ExpandEnvironmentStrings("%ProgramFiles%")       & "\Microsoft\Edge\Application\msedge.exe", _
        objShell.ExpandEnvironmentStrings("%LocalAppData%")       & "\Microsoft\Edge\Application\msedge.exe" _
    )

    FindEdge = ""
    For Each p In paths
        If objFSO.FileExists(p) Then
            FindEdge = p
            Exit For
        End If
    Next
End Function
