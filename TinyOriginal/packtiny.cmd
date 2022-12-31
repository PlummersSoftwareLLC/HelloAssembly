ml /c /coff /Ic:\masm32\include Tiny.asm 
crinkler /subsystem:windows /ENTRY:MainEntry /LIBPATH:c:\masm32\lib user32.lib kernel32.lib gdi32.lib Tiny.obj
