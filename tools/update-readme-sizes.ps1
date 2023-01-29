# This is a simple PowerShell script to replace a number of placeholders in README.md.template with their current values
# Run this script from the repository root, as in: .\tools\update-readme-sizes.ps1

# Get the file contents
$fileContent = Get-Content -Path '.\templates\readme\README.md.template'

# Insert current date
$fileContent = $fileContent -replace '<!--size-date-->', (Get-Date).ToString('MM/dd/yyyy') 

# Insert file sizes for Lasse executables 
$fileContent = $fileContent -replace '<!--size-little-masm-->', (Get-Item .\Lasse\LittleWindows.exe).Length
$fileContent = $fileContent -replace '<!--size-little-crinkler-->', (Get-Item .\Lasse\out.exe).Length

# Insert file sizes for Theron executable 
$fileContent = $fileContent -replace '<!--size-hello-yasm-->', (Get-Item .\Theron\HelloWindows.exe).Length

# Insert file sizes for TinyOriginal executable 
$fileContent = $fileContent -replace '<!--size-tiny-crinkler-->', (Get-Item .\TinyOriginal\tiny.exe).Length

Set-Content -Value $fileContent -Path '.\README.md'