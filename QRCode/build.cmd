cd /d c:\users\davep\source\repos\HelloAssembly
ml /c /coff HelloAssembly.asm
link /merge:.rdata=.text /merge:.data=.text /align:16 HelloAssembly.obj /subsystem:windows
wsl uuencode HelloAssembly.exe HelloAssembly.exe > HelloAssembly.uu
wsl qrencode -8 -o HelloAssemblyUU.png < HelloAssembly.uu
wsl qrencode -8 -o HelloAssemblyEXE.png < HelloAssembly.exe
zbarimg --raw c:\users\davep\source\repos\HelloAssembly\HelloAssemblyUU.png > temp.uu
zbarimg --raw c:\users\davep\source\repos\HelloAssembly\HelloAssemblyEXE.png > temp.exe
wsl uudecode -o finalOutput.exe temp.uu 

