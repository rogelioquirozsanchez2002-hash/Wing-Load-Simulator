'==============================================================================
' Wing Load Sim -> SolidWorks Link
'
' Reads the wing_load_export.json file produced by the "Export for SolidWorks"
' button in the web simulator, updates the active part's global variables to
' match the optimized spar geometry, rebuilds, and colors the spar body
' green / amber / red based on the factor of safety.
'
' SETUP (one-time, see SOLIDWORKS_SETUP.md for full step-by-step):
'   1. In your part, open Equations (Tools > Equations) and add three GLOBAL
'      VARIABLES named exactly:  "SparWidth"  "SparHeight"  "WallThickness"
'      (values in millimeters). Link your sketch dimensions to them, e.g.
'      D1@Sketch1 = "SparWidth", D2@Sketch1 = "SparHeight", etc.
'   2. Name the solid body that represents the spar "Spar" in the FeatureManager
'      tree (right-click the body under Solid Bodies > Rename).
'   3. Edit JSON_PATH below to point at wherever your browser downloads to.
'
' USAGE:
'   Tools > Macro > Run (or assign to a toolbar button) with the part open.
'==============================================================================

Option Explicit

' >>> EDIT THIS to your Downloads folder / wherever the exported file lands
Const JSON_PATH As String = "C:\Users\YOURNAME\Downloads\wing_load_export.json"
Const SPAR_BODY_NAME As String = "Spar"

Sub main()

    Dim swApp As Object
    Dim swModel As Object
    Dim swEqnMgr As Object
    Dim swExt As Object

    Set swApp = Application.SldWorks
    Set swModel = swApp.ActiveDoc

    If swModel Is Nothing Then
        MsgBox "Open the wing spar part before running this macro.", vbExclamation
        Exit Sub
    End If

    ' ---- 1. Read and parse the exported JSON (minimal hand-rolled parser;
    '         the export schema is fixed/flat so this avoids needing an
    '         external JSON library reference) ----
    Dim jsonText As String
    jsonText = ReadFile(JSON_PATH)
    If jsonText = "" Then
        MsgBox "Could not read: " & JSON_PATH & vbCrLf & _
               "Update JSON_PATH at the top of the macro to match your Downloads folder.", vbCritical
        Exit Sub
    End If

    Dim sparWidth As Double, sparHeight As Double, wallThickness As Double
    Dim fsValue As Double, status As String
    Dim r As Double, g As Double, b As Double

    sparWidth = ExtractNumber(jsonText, "sparWidth")
    sparHeight = ExtractNumber(jsonText, "sparHeight")
    wallThickness = ExtractNumber(jsonText, "wallThickness")
    fsValue = ExtractNumber(jsonText, "factorOfSafety")
    status = ExtractString(jsonText, "status")

    Dim rgbArr() As Double
    rgbArr = ExtractRGB(jsonText)
    r = rgbArr(0): g = rgbArr(1): b = rgbArr(2)

    ' ---- 2. Push values into the part's global variables ----
    Set swExt = swModel.Extension
    Set swEqnMgr = swExt.GetEquationMgr
    UpdateGlobalVariable swEqnMgr, "SparWidth", sparWidth
    UpdateGlobalVariable swEqnMgr, "SparHeight", sparHeight
    UpdateGlobalVariable swEqnMgr, "WallThickness", wallThickness

    swModel.EditRebuild3

    ' ---- 3. Color the spar body by structural status ----
    Dim swPart As Object
    Set swPart = swModel
    Dim bodies As Variant
    bodies = swPart.GetBodies2(0, True) ' 0 = swSolidBody

    Dim i As Integer
    Dim found As Boolean
    found = False
    If Not IsEmpty(bodies) Then
        For i = 0 To UBound(bodies)
            Dim swBody As Object
            Set swBody = bodies(i)
            If swBody.Name = SPAR_BODY_NAME Then
                Dim matProps(8) As Double
                matProps(0) = 0.1        ' Ambient
                matProps(1) = r          ' Diffuse R
                matProps(2) = g          ' Diffuse G
                matProps(3) = b          ' Diffuse B
                matProps(4) = 0.4        ' Specular
                matProps(5) = 0.4        ' Specular (unused slot in some versions)
                matProps(6) = 0.4        ' Shininess
                matProps(7) = 0#         ' Transparency
                matProps(8) = 0#         ' Emission
                swBody.MaterialPropertyValues = matProps
                found = True
            End If
        Next i
    End If

    swModel.GraphicsRedraw2

    If found Then
        MsgBox "Updated." & vbCrLf & _
               "Spar: " & sparWidth & " x " & sparHeight & " x " & wallThickness & " mm" & vbCrLf & _
               "FS = " & fsValue & "  ->  status: " & UCase(status), vbInformation
    Else
        MsgBox "Dimensions updated, but no solid body named '" & SPAR_BODY_NAME & "' was found to color." & vbCrLf & _
               "Rename your spar body to '" & SPAR_BODY_NAME & "' in the FeatureManager tree.", vbExclamation
    End If

End Sub

' ---------------------------------------------------------------------------
' Helpers
' ---------------------------------------------------------------------------

Function ReadFile(path As String) As String
    On Error GoTo fail
    Dim f As Integer
    f = FreeFile
    Open path For Input As #f
    Dim content As String, line As String
    Do While Not EOF(f)
        Line Input #f, line
        content = content & line & vbCrLf
    Loop
    Close #f
    ReadFile = content
    Exit Function
fail:
    ReadFile = ""
End Function

' Extracts a numeric value for "key": 123.45 from flat/nested JSON text
Function ExtractNumber(json As String, key As String) As Double
    Dim pattern As String
    Dim pos As Long, startPos As Long, endPos As Long
    Dim searchKey As String
    searchKey = """" & key & """"
    pos = InStr(json, searchKey)
    If pos = 0 Then
        ExtractNumber = 0
        Exit Function
    End If
    startPos = InStr(pos, json, ":") + 1
    endPos = startPos
    Do While endPos <= Len(json) And InStr("0123456789.-", Mid(json, endPos, 1)) = 0
        startPos = startPos + 1
        endPos = endPos + 1
    Loop
    Do While endPos <= Len(json) And InStr("0123456789.-", Mid(json, endPos, 1)) > 0
        endPos = endPos + 1
    Loop
    ExtractNumber = CDbl(Mid(json, startPos, endPos - startPos))
End Function

' Extracts a quoted string value for "key": "value"
Function ExtractString(json As String, key As String) As String
    Dim pos As Long, startQ As Long, endQ As Long
    Dim searchKey As String
    searchKey = """" & key & """"
    pos = InStr(json, searchKey)
    If pos = 0 Then
        ExtractString = ""
        Exit Function
    End If
    startQ = InStr(pos + Len(searchKey), json, """") + 1
    endQ = InStr(startQ, json, """")
    ExtractString = Mid(json, startQ, endQ - startQ)
End Function

' Extracts the 3-number statusColorRGB01 array
Function ExtractRGB(json As String) As Double()
    Dim result(2) As Double
    Dim pos As Long, startPos As Long, endPos As Long
    pos = InStr(json, """statusColorRGB01""")
    If pos = 0 Then
        result(0) = 0.5: result(1) = 0.5: result(2) = 0.5
        ExtractRGB = result
        Exit Function
    End If
    startPos = InStr(pos, json, "[") + 1
    endPos = InStr(pos, json, "]")
    Dim raw As String
    raw = Mid(json, startPos, endPos - startPos)
    Dim parts() As String
    parts = Split(raw, ",")
    Dim i As Integer
    For i = 0 To 2
        result(i) = CDbl(Trim(Replace(parts(i), vbCrLf, "")))
    Next i
    ExtractRGB = result
End Function

Sub UpdateGlobalVariable(eqnMgr As Object, varName As String, newValue As Double)
    Dim n As Integer
    n = eqnMgr.GetCount
    Dim i As Integer
    For i = 0 To n - 1
        Dim eqnText As String
        eqnText = eqnMgr.Equation(i)
        If InStr(eqnText, """" & varName & """") > 0 Then
            eqnMgr.Equation(i) = """" & varName & """" & " = " & newValue & "mm"
            Exit Sub
        End If
    Next i
    ' Not found -- add it fresh (SolidWorks appends to the active configuration)
    eqnMgr.Add2 -1, """" & varName & """" & " = " & newValue & "mm", False
End Sub
