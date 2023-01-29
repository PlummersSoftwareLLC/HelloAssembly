/*----------------------
  hash.c
  Calculate import hashes for header_tiny.asm

  Usage: ./hash LoadLibraryA name2 name3 ...

  2023-01-25  Theron Tarigo

----------------------*/

#include <stdio.h>

static unsigned int multiplier=5651;

int main (int argc, char **argv) {
  for (int i=1;i<argc;i++) {
    const char *n;
    n=argv[i];
    unsigned int a=0;
    unsigned char c;
    do {
      a*=multiplier;
      c=*n++;
      a&=0xFFFFFF00;a|=c;
    } while(c);
    printf("  pfn%s:\n",argv[i]);
    printf("    dd 0x%08X\n",a);
  }
  return 0;
}

