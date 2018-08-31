#include <stdio.h>

main(int argc, char *argv[]) {
  FILE *file;
  int c, checksum = 0;

  if(argc != 2) {
    fprintf(stderr, "Usage: %s <ISA Option ROM file path>\n", argv[0]);
    exit(1);
  }

  if((file = fopen(argv[1], "r+b")) == NULL) {
    fprintf(stderr, "Error: Can't open file '%s'\n", argv[1]);
    exit(1);
  }

  while((c = getc(file)) != EOF)
    checksum = (checksum + c) % 256;

  printf("File checksum: 0x%x\n", checksum);

  if(fseek(file, 5L, SEEK_SET)) {
    fprintf(stderr, "Error: Can't seek file '%s'\n", argv[1]);
    exit(1);
  }

  c = getc(file);
  printf("Current value at offset 5: 0x%x\n", c);

  if(checksum) {
    c = 256 - (checksum + 256 - c) % 256;
    printf("Now writing this value at offset 5: 0x%x\n", c);

    fseek(file, 5L, SEEK_SET);
    if(putc(c, file) == EOF) {
      fprintf(stderr, "Error: Can't write file '%s'\n", argv[1]);
      exit(1);
    }
  }

  fclose(file);

  exit(0);
}
