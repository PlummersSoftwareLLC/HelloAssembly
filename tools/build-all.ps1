# This script builds both plain MASM32 and Crinkler versions of both the Lasse and TinyOriginal programs
# The script assumes that MASM32 and the Windows SDK are installed in their default directories
# Run this script from the repository root, as in: .\tools\build-all.ps1

# Build Lasse executables
Set-Location .\Lasse
c:\masm32\bin\ml /coff LittleWindows.asm /link /merge:.rdata=.text /merge:.data=.text /align:4 /subsystem:windows LittleWindows.obj
c:\masm32\bin\ml /c /coff LittleWindows.asm
..\Crinkler\crinkler.exe /NODEFAULTLIB /ENTRY:start /SUBSYSTEM:WINDOWS /TINYHEADER /NOINITIALIZERS /UNSAFEIMPORT /ORDERTRIES:1000 /TINYIMPORT /LIBPATH:"C:\Program Files (x86)\Windows Kits\10\Lib\10.0.20348.0\um\x86" kernel32.lib LittleWindows.obj

# Build TinyOriginal executables
Set-Location ..\TinyOriginal
c:\masm32\bin\ml /c /coff /IC:\masm32\include Tiny.asm
..\Crinkler\crinkler.exe /ENTRY:MainEntry /SUBSYSTEM:WINDOWS /TINYHEADER /NOINITIALIZERS /UNSAFEIMPORT /ORDERTRIES:2000 /TINYIMPORT /LIBPATH:"C:\Program Files (x86)\Windows Kits\10\Lib\10.0.20348.0\um\x86" kernel32.lib user32.lib gdi32.lib Tiny.obj /OUT:tiny.exe

Set-Location ..