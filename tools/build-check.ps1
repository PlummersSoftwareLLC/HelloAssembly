# This script builds both plain MASM32 and Crinkler versions of both the Lasse and TinyOriginal programs,
# runs each of them so they can be checked for functionality, and asks if execution is successful. If all
# succeed, it updates the REAMDE.md with current file sizes.
# The script assumes that MASM32 and the Windows SDK are installed in their default directories.
# Run this script from the repository root, as in: .\tools\build-check.ps1

Function RunExecutable {
	[CmdletBinding()]
	Param(
		[Parameter(Mandatory = $true)]
		$Path
	)

    Write-Host "`nStarting executable $Path..."
    Start-Process -FilePath $Path

	$answer = $null
	while ($answer -ne 'y' -and $answer -ne 'n') {
		$answer = Read-Host -Prompt "Did the executable work? [y/n]"
	}

	if ($answer -eq 'n') {
        Write-Host "Executable $Path failed!" 
		$false
	}
    else {
        $true
    }
}

# Clean up any obj and exe files
Remove-Item .\Lasse\*.obj,.\Lasse\*.exe,.\Theron\*.exe,.\TinyOriginal\*.obj,.\TinyOriginal\*.exe -ErrorAction Ignore

# Build all executables
.\tools\build-all.ps1

# Test and check each executable
$success = RunExecutable ".\Lasse\LittleWindows.exe" 
$success = (RunExecutable ".\Lasse\out.exe") -and $success
$success = (RunExecutable ".\Theron\HelloWindows.exe") -and $success
$success = (RunExecutable ".\TinyOriginal\tiny.exe") -and $success

Write-Host ""

# Update README.md if all went well
if ($success) {
    Write-Host "All good, updating current sizes!"
    .\tools\update-readme-sizes.ps1
}
else {
    Write-Host "Skipping update of current sizes, as at least one executable failed to run."
}
