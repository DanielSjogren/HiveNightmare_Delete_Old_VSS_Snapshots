# Create regex pattern for VSSadmin command
$pattern = 'Contained 1 shadow copies at creation time: (\S*\d*\s\S*\d*)[\s\S]*?' +
'Shadow Copy ID: ([{]\w*\d*[-]\w*\d*[-]\w*\d*[-]\w*\d*[-]\w*\d*[}])[\s\S]*?' +
'Original Volume: \S*[\s\S]*?' +
'Shadow Copy Volume: ([\\][\\]\S*)'

# Create a variable for available Shadow Copies
$ShadowCopies = & vssadmin list shadows /for=C: | Out-String |
  Select-String $pattern -AllMatches |
  Select-Object -Expand Matches |
  ForEach-Object {
    New-Object -Type PSObject -Property @{
      ComputerName   = $env:COMPUTERNAME
      CreationTime   = $_.Groups[1].Value
      ShadowCopyID   = $_.Groups[2].Value
      ShadowCopyPath = $_.Groups[3].Value
    } 
  }

# Mount each Shadow Copy and verify if Users have access to SAM database. If yes, then delete the snapshot
ForEach ($ShadowCopy in $ShadowCopies) {
    "ShadowCopy Creation Time: $($ShadowCopy.CreationTime)"
    "ShadowCopy ID: $($ShadowCopy.ShadowCopyID)"
    "ShadowCopy Path: $($ShadowCopy.ShadowCopyPath)"

    $ShadowPath = $ShadowCopy.ShadowCopyPath
    $SnapShotId = $ShadowCopy.ShadowCopyID
    
    $ShadowMount="C:\shadowcopy";
    If(Test-Path $ShadowMount) { (Get-Item $ShadowMount).Delete() }
    
    # Creating symlink
    $voidOutput=cd C:
    $voidOutput=cmd /c mklink /d $shadowMount $ShadowPath | Out-Null

    If (Test-Path $ShadowMount) {
        Write-Output "- Mounted Shadow Copy successfully"
        $SAMPath = "$shadowMount\Windows\System32\Config\SAM"
        If (Test-Path $SAMPath) {   
            Write-Output "-- SAM Database found, checking permissions"
            If ((Get-Acl $SAMPath).access.IdentityReference -contains "BUILTIN\Users") {
                "--- Users can read this file, deleting Shadow Copy"
                $newSession=New-PSSession
                Invoke-Command -Session $newSession -ScriptBlock{param($SnapShotId);vssadmin delete shadows /Shadow=$SnapShotId /quiet} -args $SnapShotId
                $newSession|Remove-PSSession
            } Else {
                "--- Users can't read this file"
            }
        } Else {
            Write-Output "-- SAM Database not found"
        }
    } Else {
        Write-Output "- No access to mounted Shadow Copy"
    }

    # Remove symlink
    (Get-Item $shadowMount).Delete()
}