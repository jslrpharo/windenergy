'===================================================================
' LaunchWebLauncher.vbs
' Lanzador de ACMSLWebServer + WebLauncher
'
' 1) Busca un puerto libre a partir de BASE_PORT (18081)
'    y actualiza ACMSLWebServer.ini si es necesario
' 2) Si ACMSLServerClaude.exe no esta corriendo, lo lanza minimizado
' 3) Espera a que el servidor responda en el puerto elegido
' 4) Abre Edge en modo --app (sin pestanas, sin barra de URL)
'    con un user-data-dir propio para poder rastrear el proceso
' 5) Monitoriza Edge: cuando el usuario cierra la ventana,
'    termina automaticamente el servidor
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
Const BASE_PORT        = 18081
Const MAX_PORT         = 18200
Const MAX_WAIT_SECONDS = 10
Const EDGE_PROFILE_NAME = "ACMSLWebLauncher"
Const POLL_INTERVAL_MS = 2000

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
Dim configClient, language
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
' PASO 2: Determinar el puerto disponible y actualizar el INI
' ===================================================================
Dim iniPath, serverPort
iniPath = scriptDir & INI_FILE

If serverYaCorria Then
    ' Servidor ya en marcha: leer el puerto del INI (fue elegido antes)
    serverPort = ReadPortFromINI(iniPath)
    If serverPort = 0 Then serverPort = BASE_PORT
Else
    ' Servidor parado: buscar un puerto libre y guardar en el INI
    serverPort = FindFreePort(BASE_PORT, MAX_PORT)
    If serverPort = 0 Then
        MsgBox "No se encontro un puerto TCP libre entre " & BASE_PORT & _
               " y " & MAX_PORT & ".", vbCritical, "ACMSLWebServer"
        WScript.Quit 1
    End If
    UpdateINIPort iniPath, serverPort
End If

' URL base del servidor (dinamica segun el puerto elegido)
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

If language <> "" Then
    If hasParams Then
        finalURL = finalURL & "&lang=" & language
    Else
        finalURL = finalURL & "?lang=" & language
    End If
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
    objShell.Run "\"" & serverPath & "\"", 7, False
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
    Set colEdgeCheck = objWMI.ExecQuery( _
        "SELECT ProcessId FROM Win32_Process WHERE Name='msedge.exe'" & _
        " AND CommandLine LIKE '%" & EDGE_PROFILE_NAME & "%'")

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
    Dim edgeCmd
    edgeCmd = "\"" & edgePath & "\" --app=" & finalURL & _
              " --user-data-dir=\"" & edgeProfileDir & "\""
    objShell.Run edgeCmd, 1, False

    ' Esperar a que Edge arranque
    WScript.Sleep 3000

    ' ==============================================================
    ' PASO 6: Monitorizar Edge - cuando se cierre, parar el servidor
    ' ==============================================================
    Dim colEdge

    Do
        WScript.Sleep POLL_INTERVAL_MS

        Set colEdge = objWMI.ExecQuery( _
            "SELECT ProcessId FROM Win32_Process WHERE Name='msedge.exe'" & _
            " AND CommandLine LIKE '%" & EDGE_PROFILE_NAME & "%'")

        If colEdge.Count = 0 Then Exit Do
    Loop

    ' Edge cerrado: terminar el servidor (solo si lo lanzamos nosotros)
    If Not serverYaCorria Then
        Dim colServer, proc
        Set colServer = objWMI.ExecQuery( _
            "SELECT * FROM Win32_Process WHERE Name='" & SERVER_EXE & "'")
        For Each proc In colServer
            proc.Terminate
        Next
        Set colServer = Nothing
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
' FindFreePort: ejecuta netstat una sola vez y busca el primer
' puerto libre en el rango [startPort, maxPort]
'===================================================================
Function FindFreePort(startPort, maxPort)
    Dim tmpFile, f, netstatOut, port
    tmpFile    = objShell.ExpandEnvironmentStrings("%TEMP%") & "\acmsl_portcheck.tmp"
    netstatOut = ""

    objShell.Run "cmd /c netstat -an > \"" & tmpFile & "\"", 0, True

    If objFSO.FileExists(tmpFile) Then
        Set f = objFSO.OpenTextFile(tmpFile, 1)
        netstatOut = f.ReadAll
        f.Close
        objFSO.DeleteFile tmpFile, True
    End If

    FindFreePort = 0
    For port = startPort To maxPort
        ' Buscar ":PORT " (con espacio tras el numero) para evitar falsos positivos
        If InStr(netstatOut, ":" & port & " ") = 0 Then
            FindFreePort = port
            Exit Function
        End If
    Next
End Function

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
