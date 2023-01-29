yasm -fbin -o .headersize.exe nothing.asm
yasm -fbin -o HelloWindows.exe HelloWindows.asm
yasm -fbin -o HelloCompat.exe HelloWindows.asm -DWINECOMPAT
dir .headersize.exe HelloWindows.exe
pause
