ml /c /coff /IC:\masm32\include .\Tiny.asm 
crinkler.exe /ENTRY:MainEntry /SUBSYSTEM:WINDOWS /TINYHEADER /NOINITIALIZERS /UNSAFEIMPORT /ORDERTRIES:2000 /TINYIMPORT /LIBPATH:"C:\Program Files (x86)\Windows Kits\10\Lib\10.0.20348.0\um\x86" kernel32.lib user32.lib gdi32.lib Tiny.obj /OUT:tiny.exe


