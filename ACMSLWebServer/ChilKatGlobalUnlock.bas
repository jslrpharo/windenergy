Attribute VB_Name = "ChilKatGlobalUnlock"
' The Chilkat API can be unlocked for a fully-functional 30-day trial by passing any
' string to the UnlockBundle method.  A program can unlock once at the start. Once unlocked,
' all subsequently instantiated objects are created in the unlocked state.
'
' After licensing Chilkat, replace the "Anything for 30-day trial" with the purchased unlock code.
' To verify the purchased unlock code was recognized, examine the contents of the LastErrorText
' property after unlocking.  For example:
Dim glob As New ChilkatGlobal

Public Function CheckGlobalChilKat() As Boolean

Dim success As Long
success = glob.UnlockBundle("JSLNDR.CB1102022_CRNkqvmyoD4D")
If (success <> 1) Then
    Debug.Print glob.LastErrorText
    Exit Function
End If

Dim status As Long
status = glob.UnlockStatus
If (status = 2) Then
    Debug.Print "Unlocked using purchased unlock code."
    CheckGlobalChilKat = True
Else
    Debug.Print "Unlocked in trial mode."
End If
'
'' The LastErrorText can be examined in the success case to see if it was unlocked in
'' trial more, or with a purchased unlock code.
'Debug.Print glob.LastErrorText

End Function

