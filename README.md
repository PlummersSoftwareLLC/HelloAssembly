# HelloAssembly

## Introduction

The smallest possible complete Windows application
From the episode "Hello, Assembly" on Dave's Garage:

<https://youtu.be/b0zxIfJJLAY>

- Current code is in the folder "Lasse"
- Original code in the folder "TinyOriginal"
- QRCode is dead code, was the exe embedded into a QRCode, kept just for posterity

The goal of this project is to make the smallest possible application, without compression, that has the following features:

- Runs a Windows message loop
- Has a title bar, minimize, maximize, and close buttons, which all work as expected
- Has a system menu with the same
- Paints the background and some text centered in the middle, equal to or larger than "Dave's Tiny App"
  
Please keep it readable and explain what you're doing in the comments!  And the smaller, the better!  

## Build instructions

### Plain MASM32

The applications can be built with plain MASM32 11.0, which can be obtained from a number of sources. Build instructions using it are:

- Current code in the Lasse directory:
  
  ```shell
  ml /coff LittleWindows.asm /link /merge:.rdata=.text /merge:.data=.text /align:16 /subsystem:windows LittleWindows.obj
  ```

  The executable will be named LittleWindows.exe.

- Original code in the TinyOriginal directory:

  ```shell
  ml /coff /I c:\masm32\include Tiny.asm /link /libpath:c:\masm32\lib /subsystem:windows
  ```

  The executable will be named Tiny.exe.

### MASM32 with Crinkler

Crinkler is a compressing linker for Windows, specifically targeted towards executables with a size of just a few kilobytes. A copy of the tool is included in this repository in the Crinkler directory. It can also be acquired from [its GitHub repository](https://github.com/runestubbe/Crinkler).

Crinkler requires the Windows SDK to be installed. Best (i.e. smallest) results have been achieved with version 10.0.20348.0 of the Windows 10 SDK. It, and other versions can be downloaded from the [Windows SDK archive page](https://developer.microsoft.com/en-us/windows/downloads/sdk-archive/) on the Microsoft website.

After installing it, the build instructions for both applications are:

- Current code in the Lasse directory:

  ```shell
  ml /c /coff LittleWindows.asm
  crinkler.exe /NODEFAULTLIB /ENTRY:start /SUBSYSTEM:WINDOWS /TINYHEADER /NOINITIALIZERS /UNSAFEIMPORT /ORDERTRIES:1000 /TINYIMPORT /LIBPATH:"C:\Program Files (x86)\Windows Kits\10\Lib\10.0.20348.0\um\x86" kernel32.lib LittleWindows.obj
  ```

  The executable will be named out.exe.

- Original code in the TinyOriginal directory:

  ```shell
  ml /c /coff /IC:\masm32\include .\Tiny.asm 
  crinkler.exe /NODEFAULTLIB /ENTRY:MainEntry /SUBSYSTEM:WINDOWS /TINYHEADER /NOINITIALIZERS /UNSAFEIMPORT /ORDERTRIES:1000 /TINYIMPORT /LIBPATH:"C:\Program Files (x86)\Windows Kits\10\Lib\10.0.20348.0\um\x86" kernel32.lib user32.lib gdi32.lib Tiny.obj
  ```

  The executable will be named out.exe.

## Current sizes

Current smallest known working executable size as of 1/3/2023 is 644 bytes. This is achieved using Crinkler with the original code in the TinyOriginal directory.

The smallest executable with plain MASM32 is 1248 bytes in size, and a build of the current code in the Lasse directory.
