VERSION 5.00
Begin VB.Form frmACMSLServerClaude 
   Caption         =   "Form1"
   ClientHeight    =   3435
   ClientLeft      =   45
   ClientTop       =   390
   ClientWidth     =   8745
   LinkTopic       =   "Form1"
   ScaleHeight     =   3435
   ScaleWidth      =   8745
   StartUpPosition =   3  'Windows Default
   Begin VB.CommandButton cmdLimpiarLog 
      Caption         =   "Limpiar log"
      Height          =   372
      Left            =   5640
      TabIndex        =   1
      Top             =   3120
      Width           =   1452
   End
   Begin VB.Timer Timer1 
      Interval        =   50
      Left            =   600
      Top             =   2880
   End
   Begin VB.TextBox txtLog 
      Height          =   3012
      Left            =   120
      MultiLine       =   -1  'True
      ScrollBars      =   3  'Both
      TabIndex        =   0
      Text            =   "frmACMSLServerClaude.frx":0000
      Top             =   120
      Width           =   8412
   End
End
Attribute VB_Name = "frmACMSLServerClaude"
Attribute VB_GlobalNameSpace = False
Attribute VB_Creatable = False
Attribute VB_PredeclaredId = True
Attribute VB_Exposed = False
'===================================================================
' ACMSLWebServer - Servidor HTTP con servicio de archivos estaticos
'===================================================================
' Servidor HTTP en puerto 8080 usando Chilkat ActiveX
'
' Funcionalidades:
'   - Sirve archivos estaticos (HTML, JS, CSS, JSON, XML, imagenes)
'   - API REST para variables en memoria
'   - CORS habilitado
'   - Ruta "/" redirige a WebLauncher.html
'
' Estructura esperada en el directorio del .exe:
'   WebLauncher.html
'   img/           (PNG, JPG, ICO, GIF)
'   configurations/ (JSON, XML, ENC)
'   libs/          (JS)
'
' Endpoints API:
'   GET  /api/info       - Informacion del servidor
'   GET  /api/variable   - Obtener variable (?name=xxx)
'   POST /api/variable   - Guardar variable (JSON body)
'   GET  /api/variables  - Listar todas las variables
'===================================================================

Option Explicit

Private Declare Function GetPrivateProfileString Lib "kernel32" Alias "GetPrivateProfileStringA" ( _
    ByVal lpApplicationName As String, _
    ByVal lpKeyName As Any, _
    ByVal lpDefault As String, _
    ByVal lpReturnedString As String, _
    ByVal nSize As Long, _
    ByVal lpFileName As String) As Long
Private Declare Function WritePrivateProfileString Lib "kernel32" Alias "WritePrivateProfileStringA" ( _
    ByVal lpApplicationName As String, _
    ByVal lpKeyName As Any, _
    ByVal lpString As Any, _
    ByVal lpFileName As String) As Long

Private objSocket As ChilkatSocket
Private bRunning As Boolean
Private colVariables As Collection
Private mBasePath As String  ' Directorio raiz para servir archivos
Private mPort As Long
Private mIniPath As String

' Directorios permitidos para servir archivos (relativos a basePath)
Private Const ALLOWED_DIRS = "/img/,/configurations/,/libs/,/tutorials/,/simulators/"

Private Sub Form_Load()
'    ChilKatGlobalUnlock.CheckGlobalChilKat
    Set objSocket = New ChilkatSocket
    Set colVariables = New Collection

    ' Establecer directorio base (donde esta el .exe)
    mBasePath = App.path
    If Right(mBasePath, 1) <> "\" Then mBasePath = mBasePath & "\"
    mIniPath = mBasePath & "ACMSLWebServer.ini"
    mPort = LeerPuertoConfiguracion(mIniPath)

    ' Desbloquear Chilkat
    Dim success As Long
    If Not ChilKatGlobalUnlock.CheckGlobalChilKat Then
    'success = objSocket.UnlockComponent("Anything for 30-day trial")

'    If success <> 1 Then
        MsgBox "Error desbloqueando Chilkat: " & objSocket.LastErrorText, vbCritical
        End ' ======================================================Exit Sub
    End If

    ' Iniciar servidor en el primer puerto disponible a partir del configurado
    If Not IniciarServidorEnPuertoDisponible() Then
        MsgBox "No se encontro un puerto disponible a partir de " & CStr(mPort) & ": " & objSocket.LastErrorText, vbCritical
        Exit Sub
    End If

    Me.Caption = "ACMSLWebServer - Puerto " & CStr(mPort) & " [" & mBasePath & "]"
    LogMsg "Servidor HTTP iniciado en puerto " & CStr(mPort)
    LogMsg "Directorio base: " & mBasePath
    LogMsg "Esperando conexiones..."
    LogMsg ""

    bRunning = True
    Timer1.Interval = 50
    Timer1.Enabled = True

End Sub

Private Function LeerPuertoConfiguracion(ByVal iniPath As String) As Long
    Const DEFAULT_PORT As Long = 18080
    Dim buffer As String
    Dim charsRead As Long
    Dim valorLeido As String
    Dim puerto As Long

    buffer = Space$(32)
    charsRead = GetPrivateProfileString("server", "port", CStr(DEFAULT_PORT), buffer, Len(buffer), iniPath)
    valorLeido = Trim$(Left$(buffer, charsRead))

    puerto = Val(valorLeido)
    If puerto < 1 Or puerto > 65535 Then
        puerto = DEFAULT_PORT
    End If

    LeerPuertoConfiguracion = puerto
End Function

Private Function IniciarServidorEnPuertoDisponible() As Boolean
    Dim puertoInicial As Long
    Dim puertoActual As Long
    Dim success As Long

    puertoInicial = mPort

    For puertoActual = puertoInicial To 65535
        success = objSocket.BindAndListen(puertoActual, 25)
        If success = 1 Then
            mPort = puertoActual

            If mPort <> puertoInicial Then
                LogMsg "Puerto " & CStr(puertoInicial) & " no disponible. Se usa el puerto " & CStr(mPort)
            End If

            GuardarPuertoConfiguracion mIniPath, mPort
            IniciarServidorEnPuertoDisponible = True
            Exit Function
        End If
    Next puertoActual

    mPort = puertoInicial
    IniciarServidorEnPuertoDisponible = False
End Function

Private Sub GuardarPuertoConfiguracion(ByVal iniPath As String, ByVal puerto As Long)
    Call WritePrivateProfileString("server", "port", CStr(puerto), iniPath)
End Sub

Private Sub Form_QueryUnload(Cancel As Integer, UnloadMode As Integer)
    bRunning = False
    Timer1.Enabled = False

    If Not objSocket Is Nothing Then
        objSocket.Close 0
        Set objSocket = Nothing
    End If

    Set colVariables = Nothing
    DoEvents
End Sub

Private Sub Form_Unload(Cancel As Integer)
    If Not objSocket Is Nothing Then
        objSocket.Close 0
        Set objSocket = Nothing
    End If
End Sub

Private Sub Timer1_Timer()
    If Not bRunning Then Exit Sub
    DoEvents

    Dim objClientSocket As ChilkatSocket
    Set objClientSocket = objSocket.AcceptNextConnection(50)

    If Not objClientSocket Is Nothing Then
        ProcesarPeticion objClientSocket
        Set objClientSocket = Nothing
    End If
End Sub

'===================================================================
' PROCESAMIENTO DE PETICIONES HTTP
'===================================================================

Private Sub ProcesarPeticion(ByVal clientSocket As ChilkatSocket)
    On Error GoTo ErrorHandler

    Dim strRequest As String
    Dim strMethod As String
    Dim strPath As String
    Dim strQueryString As String
    Dim arrHeaders() As String
    Dim contentLength As Long
    Dim i As Long

    ' Leer los headers HTTP
    ' original strRequest = clientSocket.ReceiveUntilMatch(vbCrLf & vbCrLf)
    'strRequest = clientSocket.ReceiveUntil(vbCrLf & vbCrLf)
    strRequest = clientSocket.ReceiveUntilMatch(vbCrLf & vbCrLf)
    If Len(strRequest) = 0 Then
        'clientSocket.Close 100
        clientSocket.Close 0
        Exit Sub
    End If

    ' Parsear metodo y path
    arrHeaders = Split(strRequest, vbCrLf)
    If UBound(arrHeaders) < 0 Then
        clientSocket.Close 0 ' 100
        Exit Sub
    End If

    Dim arrFirstLine() As String
    arrFirstLine = Split(arrHeaders(0), " ")
    If UBound(arrFirstLine) < 1 Then
        clientSocket.Close 0 '100
        Exit Sub
    End If

    strMethod = Trim(arrFirstLine(0))

    ' Separar path y query string
    Dim fullPath As String
    fullPath = Trim(arrFirstLine(1))

    If InStr(fullPath, "?") > 0 Then
        strPath = Left(fullPath, InStr(fullPath, "?") - 1)
        strQueryString = Mid(fullPath, InStr(fullPath, "?") + 1)
    Else
        strPath = fullPath
        strQueryString = ""
    End If

    ' Leer POST body si aplica
    Dim postData As String
    postData = ""

    If strMethod = "POST" Then
        For i = 0 To UBound(arrHeaders)
            If InStr(1, arrHeaders(i), "Content-Length:", vbTextCompare) > 0 Then
                contentLength = Val(Mid(arrHeaders(i), InStr(arrHeaders(i), ":") + 1))
                Exit For
            End If
        Next i

        If contentLength > 0 Then
            postData = clientSocket.ReceiveBytesN(contentLength)
            '--------- recomendacion de CoPilot ---
            postData = StrConv(postData, vbUnicode)
            'FIN --------- recomendacion de CoPilot ---
            
        End If
    End If

    ' Manejar preflight CORS (OPTIONS)
    If strMethod = "OPTIONS" Then
        Dim optResp As String
        optResp = "HTTP/1.1 204 No Content" & vbCrLf
        optResp = optResp & "Access-Control-Allow-Origin: *" & vbCrLf
        optResp = optResp & "Access-Control-Allow-Methods: GET, POST, OPTIONS" & vbCrLf
        optResp = optResp & "Access-Control-Allow-Headers: Content-Type" & vbCrLf
        optResp = optResp & "Connection: close" & vbCrLf
        optResp = optResp & vbCrLf
        clientSocket.SendString optResp
        clientSocket.Close 0 ' 1000
        Exit Sub
    End If

    ' ============================================
    ' ROUTING: API vs Archivos Estaticos
    ' ============================================
    If Left(strPath, 5) = "/api/" Then
        ' --- Rutas API (respuestas generadas en memoria) ---
        LogMsg strMethod & " " & strPath & IIf(strQueryString <> "", "?" & strQueryString, "")

        Dim strResponse As String
        strResponse = GenerarRespuestaAPI(strMethod, strPath, strQueryString, postData)
        clientSocket.SendString strResponse
        clientSocket.Close 0 ' 1000

        LogMsg "  -> API response enviada"
    Else
        ' --- Archivos estaticos ---
        ServirArchivoEstatico clientSocket, strPath
    End If

    Exit Sub

ErrorHandler:
    LogMsg "ERROR procesando peticion: " & Err.Description
    If Not clientSocket Is Nothing Then
        clientSocket.Close 0 ' 100
    End If
End Sub

'===================================================================
' SERVICIO DE ARCHIVOS ESTATICOS
'===================================================================

Private Sub ServirArchivoEstatico(ByVal clientSocket As ChilkatSocket, ByVal urlPath As String)
    On Error GoTo FileErrorHandler

    ' Ruta raiz redirige a WebLauncher.html
    If urlPath = "/" Then urlPath = "/WebLauncher.html"

    ' --- Seguridad: rechazar path traversal ---
    If InStr(urlPath, "..") > 0 Then
        LogMsg "BLOQUEADO (path traversal): " & urlPath
        Enviar403 clientSocket
        Exit Sub
    End If

    ' --- Seguridad: solo permitir archivos en raiz y subdirectorios autorizados ---
    If Not EsRutaPermitida(urlPath) Then
        LogMsg "BLOQUEADO (directorio no autorizado): " & urlPath
        Enviar404 clientSocket
        Exit Sub
    End If

    ' Construir ruta en disco
    Dim filePath As String
    filePath = mBasePath & Replace(Mid(urlPath, 2), "/", "\")  ' quitar "/" inicial y convertir separadores

    ' Verificar que el archivo existe
    If Dir(filePath) = "" Then
        LogMsg "404: " & urlPath & " -> " & filePath
        Enviar404 clientSocket
        Exit Sub
    End If

    ' Determinar MIME type
    Dim mimeType As String
    mimeType = ObtenerMIME(filePath)

    ' Leer archivo como bytes usando ADODB.Stream
    Dim adoStream As Object
    Set adoStream = CreateObject("ADODB.Stream")
    adoStream.Type = 1  ' adTypeBinary
    adoStream.Open
    adoStream.LoadFromFile filePath

    Dim fileSize As Long
    fileSize = adoStream.Size

    Dim fileData As Variant
    If fileSize > 0 Then
        fileData = adoStream.Read
    End If
    adoStream.Close
    Set adoStream = Nothing

    ' Construir y enviar headers HTTP
    Dim strHeaders As String
    strHeaders = "HTTP/1.1 200 OK" & vbCrLf
    strHeaders = strHeaders & "Content-Type: " & mimeType & vbCrLf
    strHeaders = strHeaders & "Content-Length: " & fileSize & vbCrLf
    strHeaders = strHeaders & "Connection: close" & vbCrLf
    strHeaders = strHeaders & "Access-Control-Allow-Origin: *" & vbCrLf

    ' Cache headers para recursos estaticos (imagenes: 1 hora, resto: no cache)
    If EsBinario(filePath) Then
        strHeaders = strHeaders & "Cache-Control: public, max-age=3600" & vbCrLf
    Else
        strHeaders = strHeaders & "Cache-Control: no-cache" & vbCrLf
    End If

    strHeaders = strHeaders & vbCrLf  ' Linea vacia: fin de headers

    ' Enviar: primero headers (texto), luego body (bytes)
    clientSocket.SendString strHeaders

    If fileSize > 0 Then
        clientSocket.SendBytes fileData
    End If

    clientSocket.Close 0 ' 1000

    LogMsg "200: " & urlPath & " (" & mimeType & ", " & fileSize & " bytes)"

    Exit Sub

FileErrorHandler:
    LogMsg "ERROR sirviendo " & urlPath & ": " & Err.Description
    If Not clientSocket Is Nothing Then
        Enviar500 clientSocket
    End If
    If Not adoStream Is Nothing Then
        adoStream.Close
        Set adoStream = Nothing
    End If
End Sub

Private Sub Enviar404(ByVal clientSocket As ChilkatSocket)
    Dim resp As String
    Dim notFoundPath As String
    notFoundPath = mBasePath & "404.html"

    ' --- Servir 404.html personalizado si existe ---
    If Dir(notFoundPath) <> "" Then
        Dim adoStream As Object
        Set adoStream = CreateObject("ADODB.Stream")
        adoStream.Type = 1  ' adTypeBinary
        adoStream.Open
        adoStream.LoadFromFile notFoundPath

        Dim fileSize As Long
        fileSize = adoStream.Size

        Dim fileData As Variant
        If fileSize > 0 Then fileData = adoStream.Read
        adoStream.Close
        Set adoStream = Nothing

        resp = "HTTP/1.1 404 Not Found" & vbCrLf
        resp = resp & "Content-Type: text/html; charset=utf-8" & vbCrLf
        resp = resp & "Content-Length: " & fileSize & vbCrLf
        resp = resp & "Connection: close" & vbCrLf
        resp = resp & vbCrLf

        clientSocket.SendString resp
        If fileSize > 0 Then clientSocket.SendBytes fileData

    Else
        ' --- Fallback inline si no existe 404.html ---
        Dim body As String
        body = "<!DOCTYPE html><html><body><h1>404 - No encontrado</h1></body></html>"

        resp = "HTTP/1.1 404 Not Found" & vbCrLf
        resp = resp & "Content-Type: text/html; charset=utf-8" & vbCrLf
        resp = resp & "Content-Length: " & Len(body) & vbCrLf
        resp = resp & "Connection: close" & vbCrLf
        resp = resp & vbCrLf
        resp = resp & body

        clientSocket.SendString resp
    End If

    clientSocket.Close 0 ' 1000
End Sub

Private Function EsRutaPermitida(ByVal urlPath As String) As Boolean
    ' Permitir archivos en la raiz (WebLauncher.html, favicon.ico, etc.)
    If InStr(Mid(urlPath, 2), "/") = 0 Then
        EsRutaPermitida = True
        Exit Function
    End If

    ' Permitir subdirectorios autorizados
    Dim arrDirs() As String
    arrDirs = Split(ALLOWED_DIRS, ",")

    Dim i As Long
    For i = 0 To UBound(arrDirs)
        If Left(LCase(urlPath), Len(arrDirs(i))) = LCase(arrDirs(i)) Then
            EsRutaPermitida = True
            Exit Function
        End If
    Next i

    EsRutaPermitida = False
End Function

Private Function ObtenerMIME(ByVal filePath As String) As String
    Dim ext As String
    ext = LCase(Mid(filePath, InStrRev(filePath, ".") + 1))

    Select Case ext
        ' Web
        Case "html", "htm":  ObtenerMIME = "text/html; charset=utf-8"
        Case "css":          ObtenerMIME = "text/css; charset=utf-8"
        Case "js":           ObtenerMIME = "application/javascript; charset=utf-8"

        ' Datos
        Case "json":         ObtenerMIME = "application/json; charset=utf-8"
        Case "xml":          ObtenerMIME = "application/xml; charset=utf-8"
        Case "enc":          ObtenerMIME = "application/octet-stream"

        ' Imagenes
        Case "png":          ObtenerMIME = "image/png"
        Case "jpg", "jpeg":  ObtenerMIME = "image/jpeg"
        Case "gif":          ObtenerMIME = "image/gif"
        Case "ico":          ObtenerMIME = "image/x-icon"
        Case "svg":          ObtenerMIME = "image/svg+xml"
        Case "webp":         ObtenerMIME = "image/webp"

        ' Otros
        Case "pdf":          ObtenerMIME = "application/pdf"
        Case "txt":          ObtenerMIME = "text/plain; charset=utf-8"

        Case Else:           ObtenerMIME = "application/octet-stream"
    End Select
End Function

Private Function EsBinario(ByVal filePath As String) As Boolean
    Dim ext As String
    ext = LCase(Mid(filePath, InStrRev(filePath, ".") + 1))

    Select Case ext
        Case "png", "jpg", "jpeg", "gif", "ico", "webp", "pdf", "enc"
            EsBinario = True
        Case Else
            EsBinario = False
    End Select
End Function

'===================================================================
' RESPUESTAS DE ERROR HTTP
'===================================================================

'Private Sub Enviar404(ByVal clientSocket As ChilkatSocket)
'    Dim body As String
'    body = "<!DOCTYPE html><html><body><h1>404 - No encontrado</h1></body></html>"
'
'    Dim resp As String
'    resp = "HTTP/1.1 404 Not Found" & vbCrLf
'    resp = resp & "Content-Type: text/html; charset=utf-8" & vbCrLf
'    resp = resp & "Content-Length: " & Len(body) & vbCrLf
'    resp = resp & "Connection: close" & vbCrLf
'    resp = resp & vbCrLf
'    resp = resp & body
'
'    clientSocket.SendString resp
'    clientSocket.Close 1000
'End Sub

Private Sub Enviar403(ByVal clientSocket As ChilkatSocket)
    Dim body As String
    body = "<!DOCTYPE html><html><body><h1>403 - Acceso denegado</h1></body></html>"

    Dim resp As String
    resp = "HTTP/1.1 403 Forbidden" & vbCrLf
    resp = resp & "Content-Type: text/html; charset=utf-8" & vbCrLf
    resp = resp & "Content-Length: " & Len(body) & vbCrLf
    resp = resp & "Connection: close" & vbCrLf
    resp = resp & vbCrLf
    resp = resp & body

    clientSocket.SendString resp
    clientSocket.Close 0 ' 1000
End Sub

Private Sub Enviar500(ByVal clientSocket As ChilkatSocket)
    Dim body As String
    body = "<!DOCTYPE html><html><body><h1>500 - Error interno</h1></body></html>"

    Dim resp As String
    resp = "HTTP/1.1 500 Internal Server Error" & vbCrLf
    resp = resp & "Content-Type: text/html; charset=utf-8" & vbCrLf
    resp = resp & "Content-Length: " & Len(body) & vbCrLf
    resp = resp & "Connection: close" & vbCrLf
    resp = resp & vbCrLf
    resp = resp & body

    clientSocket.SendString resp
    clientSocket.Close 0 ' 1000
End Sub

'===================================================================
' RESPUESTAS API (endpoints /api/*)
'===================================================================

Private Function GenerarRespuestaAPI(ByVal metodo As String, ByVal path As String, _
                                     ByVal queryString As String, ByVal postData As String) As String
    Dim strBody As String
    Dim strHeader As String
    Dim statusCode As String
    Dim contentType As String

    statusCode = "200 OK"
    contentType = "application/json; charset=utf-8"

    Select Case path
    Case "/api/info"
        strBody = "{" & vbCrLf
        strBody = strBody & "  ""servidor"": ""ACMSLWebServer""," & vbCrLf
        strBody = strBody & "  ""version"": ""2.0""," & vbCrLf
        strBody = strBody & "  ""timestamp"": """ & Format(Now, "yyyy-mm-dd hh:nn:ss") & """," & vbCrLf
        strBody = strBody & "  ""basePath"": """ & Replace(mBasePath, "\", "\\") & """," & vbCrLf
        strBody = strBody & "  ""variables_count"": " & colVariables.Count & vbCrLf
        strBody = strBody & "}"

    Case "/api/variable"
        If metodo = "GET" Then
            Dim varName As String
            varName = ExtraerParametro(queryString, "name")

            If varName <> "" Then
                Dim varValue As String
                varValue = ObtenerVariable(varName)

                If varValue <> "" Then
                    strBody = "{""name"":""" & varName & """,""value"":""" & varValue & """}"
                Else
                    statusCode = "404 Not Found"
                    strBody = "{""error"":""Variable no encontrada""}"
                End If
            Else
                statusCode = "400 Bad Request"
                strBody = "{""error"":""Parametro 'name' requerido""}"
            End If

        ElseIf metodo = "POST" Then
            Dim jsonName As String
            Dim jsonValue As String

            jsonName = ExtraerJSON(postData, "name")
            jsonValue = ExtraerJSON(postData, "value")

            If jsonName <> "" And jsonValue <> "" Then
                GuardarVariable jsonName, jsonValue
                strBody = "{""status"":""ok"",""message"":""Variable guardada"",""name"":""" & jsonName & """}"
            Else
                statusCode = "400 Bad Request"
                strBody = "{""error"":""JSON invalido. Formato: {name:xxx,value:yyy}""}"
            End If
        End If

    Case "/api/variables"
        strBody = "{""variables"":[" & vbCrLf

        Dim i As Long
        For i = 1 To colVariables.Count
            If i > 1 Then strBody = strBody & "," & vbCrLf
            strBody = strBody & "  {""name"":""" & colVariables(i)("name") & """,""value"":""" & colVariables(i)("value") & """}"
        Next i

        strBody = strBody & vbCrLf & "]}"

    Case "/api/openapp"
        Dim appUrl As String
        appUrl = ExtraerParametro(queryString, "url")
        If appUrl <> "" Then
            '            Dim edgeExe As String
            '            edgeExe = FindEdgePath()
            '            If edgeExe <> "" Then
            '                Dim tutDir As String
            '                'tutDir = Environ("TEMP") & "\ACMSLTutorial"
            '                tutDir = Environ("TEMP") & "\ACMSLWebLauncher"
            Dim vbsPath As String
            vbsPath = mBasePath & "OpenTutorial.vbs"
            If Dir(vbsPath) <> "" Then

                Dim wshell As Object
                Set wshell = CreateObject("WScript.Shell")
'                wshell.Run """" & edgeExe & """ --app=" & appUrl & _
'                         " --user-data-dir=""" & tutDir & """" & _
'                         " --no-first-run --no-default-browser-check", 1, False
'                ' ----------------------
                wshell.Run "cscript //nologo """ & vbsPath & """ " & appUrl, 0, False


                Set wshell = Nothing
                strBody = "{""status"":""ok"",""message"":""Opened in app mode""}"
            Else
                statusCode = "503 Service Unavailable"

'                strBody = "{""error"":""Edge not found""}"

                strBody = "{""error"":""OpenTutorial.vbs not found""}"
            End If
        Else
            statusCode = "400 Bad Request"
            strBody = "{""error"":""url parameter required""}"
        End If

    Case Else
        statusCode = "404 Not Found"
        strBody = "{""error"":""Endpoint no encontrado: " & path & """}"
    End Select

    ' Construir respuesta HTTP completa
    strHeader = "HTTP/1.1 " & statusCode & vbCrLf
    strHeader = strHeader & "Content-Type: " & contentType & vbCrLf
    strHeader = strHeader & "Content-Length: " & Len(strBody) & vbCrLf
    strHeader = strHeader & "Connection: close" & vbCrLf
    strHeader = strHeader & "Access-Control-Allow-Origin: *" & vbCrLf
    strHeader = strHeader & vbCrLf

    GenerarRespuestaAPI = strHeader & strBody
End Function

'===================================================================
' UTILIDADES: Parametros, JSON, Variables
'===================================================================

Private Function ExtraerParametro(ByVal queryString As String, ByVal paramName As String) As String
    Dim arrParams() As String
    Dim i As Long
    Dim arrPair() As String

    If queryString = "" Then
        ExtraerParametro = ""
        Exit Function
    End If

    arrParams = Split(queryString, "&")
    For i = 0 To UBound(arrParams)
        If InStr(arrParams(i), "=") > 0 Then
            arrPair = Split(arrParams(i), "=")
            If UBound(arrPair) >= 1 Then
                If Trim(arrPair(0)) = paramName Then
                    ExtraerParametro = URLDecode(Trim(arrPair(1)))
                    Exit Function
                End If
            End If
        End If
    Next i

    ExtraerParametro = ""
End Function

Private Function ExtraerJSON(ByVal jsonString As String, ByVal key As String) As String
    Dim patron As String
    Dim posStart As Long
    Dim posEnd As Long

    patron = """" & key & """:"
    posStart = InStr(jsonString, patron)

    If posStart > 0 Then
        posStart = posStart + Len(patron)

        Do While Mid(jsonString, posStart, 1) = " " Or Mid(jsonString, posStart, 1) = """"
            posStart = posStart + 1
        Loop

        posEnd = posStart
        Do While posEnd <= Len(jsonString)
            Dim c As String
            c = Mid(jsonString, posEnd, 1)
            If c = """" Or c = "," Or c = "}" Then
                Exit Do
            End If
            posEnd = posEnd + 1
        Loop

        ExtraerJSON = Trim(Mid(jsonString, posStart, posEnd - posStart))
    Else
        ExtraerJSON = ""
    End If
End Function

Private Sub GuardarVariable(ByVal nombre As String, ByVal valor As String)
    On Error Resume Next

    Dim i As Long
    For i = 1 To colVariables.Count
        If colVariables(i)("name") = nombre Then
            colVariables.Remove i
            Exit For
        End If
    Next i

    Dim varItem As Object
    Set varItem = CreateObject("Scripting.Dictionary")
    varItem("name") = nombre
    varItem("value") = valor

    colVariables.Add varItem
End Sub

Private Function ObtenerVariable(ByVal nombre As String) As String
    On Error Resume Next

    Dim i As Long
    For i = 1 To colVariables.Count
        If colVariables(i)("name") = nombre Then
            ObtenerVariable = colVariables(i)("value")
            Exit Function
        End If
    Next i

    ObtenerVariable = ""
End Function

Private Function URLDecode(ByVal strEncoded As String) As String
    Dim i As Long
    Dim strResult As String
    Dim strChar As String

    strResult = ""
    i = 1

    Do While i <= Len(strEncoded)
        strChar = Mid(strEncoded, i, 1)

        If strChar = "+" Then
            strResult = strResult & " "
            i = i + 1
        ElseIf strChar = "%" And i + 2 <= Len(strEncoded) Then
            strResult = strResult & Chr(Val("&H" & Mid(strEncoded, i + 1, 2)))
            i = i + 3
        Else
            strResult = strResult & strChar
            i = i + 1
        End If
    Loop

    URLDecode = strResult
End Function

'===================================================================
' UTILIDAD: Localizar msedge.exe
'===================================================================

Private Function FindEdgePath() As String
    Dim paths(2) As String
    paths(0) = Environ("ProgramFiles(x86)") & "\Microsoft\Edge\Application\msedge.exe"
    paths(1) = Environ("ProgramFiles") & "\Microsoft\Edge\Application\msedge.exe"
    paths(2) = Environ("LOCALAPPDATA") & "\Microsoft\Edge\Application\msedge.exe"

    Dim i As Integer
    For i = 0 To 2
        If Dir(paths(i)) <> "" Then
            FindEdgePath = paths(i)
            Exit Function
        End If
    Next i
    FindEdgePath = ""
End Function

'===================================================================
' LOG
'===================================================================

Private Sub LogMsg(ByVal msg As String)
    If msg = "" Then
        txtLog.Text = txtLog.Text & vbCrLf
    Else
        txtLog.Text = txtLog.Text & Format(Now, "hh:nn:ss") & " " & msg & vbCrLf
    End If
    txtLog.SelStart = Len(txtLog.Text)
End Sub

Private Sub cmdLimpiarLog_Click()
    txtLog.Text = ""
    LogMsg "Log limpiado"
End Sub
