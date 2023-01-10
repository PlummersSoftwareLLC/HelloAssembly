# This is a simple PowerShell script to replace a number of placeholders in README.md.template with their current values
# Run this script from the repository root, as in: .\tools\update-readme-sizes.ps1

# Get the file contents
$fileContent = Get-Content -Path '.\templates\README.md.template'

# Insert current date
$fileContent = $fileContent -replace '<!--size-date-->', (Get-Date).ToString('MM/dd/yyyy') 

# Insert file sizes for Lasse executables 
$fileContent = $fileContent -replace '<!--size-little-masm-->', (Get-Item .\Lasse\LittleWindows.exe).Length
$fileContent = $fileContent -replace '<!--size-little-crinkler-->', (Get-Item .\Lasse\out.exe).Length

# Insert file sizes for TinyOriginal executables 
$fileContent = $fileContent -replace '<!--size-tiny-masm-->', (Get-Item .\TinyOriginal\Tiny.exe).Length
$fileContent = $fileContent -replace '<!--size-tiny-crinkler-->', (Get-Item .\TinyOriginal\out.exe).Length

Set-Content -Value $fileContent -Path '.\README.md'