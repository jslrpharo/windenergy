Option Explicit

Dim shell, fso, targetArg, targetPath, targetUri, viewerPath, command
Dim logPath, logFile

If WScript.Arguments.Count = 0 Then
    WScript.Quit 1
End If

Set shell = CreateObject("WScript.Shell")
Set fso = CreateObject("Scripting.FileSystemObject")
logPath = "C:\ACMSL\WindFarmSimulator\OpenHtmleWrapper.log"
Set logFile = fso.OpenTextFile(logPath, 8, True)

targetArg = WScript.Arguments(0)
targetPath = fso.GetAbsolutePathName(targetArg)
targetUri = "file:///" & Replace(targetPath, "\", "/")
targetUri = Replace(targetUri, "%", "%25")
targetUri = Replace(targetUri, " ", "%20")
targetUri = Replace(targetUri, "#", "%23")
targetUri = Replace(targetUri, "'", "%27")

viewerPath = "C:\ACMSL\WindFarmSimulator\ViewerTutorialsWFSr12.exe"
command = """" & viewerPath & """ """ & targetUri & """"

logFile.WriteLine Now & " ARG=" & targetArg
logFile.WriteLine Now & " PATH=" & targetPath
logFile.WriteLine Now & " URI=" & targetUri
logFile.WriteLine Now & " CMD=" & command
logFile.Close

shell.Run command, 0, False
