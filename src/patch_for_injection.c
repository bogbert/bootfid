#include <stdio.h>
#include <stdlib.h>

void usage(char *argv[]);
void bad_arg(char *argv[], char *arg_name, int arg_pos);
void fread_fwrite_error(char *operation, char *filename, int offset);

int main(int argc, char *argv[]) {
  FILE *file;
  int injection_offset, bootfid_offset, checksum_offset, jump_length, i, c, checksum = 0;
  char buffer[3];

  if(argc != 4) {
    usage(argv);
    exit(1);
  }

  if((injection_offset = atoi(argv[2])) <= 0) {
    bad_arg(argv, "injection offset", 2);
  }

  if((bootfid_offset = atoi(argv[3])) < (injection_offset + 3)) {
    bad_arg(argv, "bootfid offset", 3);
  }

  if((file = fopen(argv[1], "r+b")) == NULL) {
    fprintf(stderr, "Error: Can't open file '%s'\n", argv[1]);
    exit(1);
  }

  /* Read the header of bootfid to verify that the file has not been patched yet */
  if(fseek(file, (long)bootfid_offset, SEEK_SET) || (0 == fread(buffer, 3, 1, file)))
    fread_fwrite_error("read", argv[1], bootfid_offset);

  for(i = 0; i < 3; i++)
    if(buffer[i] != 'X') {
      fprintf(stderr, "Error: It seems that file '%s' has already been patched, patching it twice would break it!\n", argv[1]);
      exit(1);
    }

  /* Read the original file at injection_offset before it's overridden by the injection jump */
  if(fseek(file, (long)injection_offset, SEEK_SET) || (0 == fread(buffer, 3, 1, file)))
    fread_fwrite_error("read", argv[1], injection_offset);

  /* Save the soon to be overridden data in the header of bootfid */
  if(fseek(file, (long)bootfid_offset, SEEK_SET) || (0 == fwrite(buffer, 3, 1, file)))
    fread_fwrite_error("write", argv[1], bootfid_offset);

  /* Now, compute and write the injection jump */
  jump_length = (bootfid_offset + 4) - (injection_offset + 3);
  buffer[0] = 0xe9;
  buffer[1] = jump_length & 0xFF; /* NB: little endian, least-significant byte first */
  buffer[2] = jump_length >> 8;

  if(fseek(file, (long)injection_offset, SEEK_SET) || (0 == fwrite(buffer, 3, 1, file)))
    fread_fwrite_error("write", argv[1], injection_offset);

  /* Update the checksum */
  rewind(file);
  while((c = getc(file)) != EOF)
    checksum = (checksum + c) & 0xFF;

  printf("File checksum: 0x%x\n", checksum);

  checksum_offset = bootfid_offset + 3;
  if(fseek(file, (long)checksum_offset, SEEK_SET)) {
    fprintf(stderr, "Error: Can't seek file '%s' at offset %d\n", argv[1], checksum_offset);
    exit(1);
  }

  c = getc(file);
  printf("Current value at offset %d: 0x%x\n", checksum_offset, c);

  if(checksum) {
    c = 256 - ((checksum + 256 - c) & 0xFF);
    printf("Now writing this value at offset %d: 0x%x\n", checksum_offset, c);

    fseek(file, (long)checksum_offset, SEEK_SET);
    if(putc(c, file) == EOF) {
      fprintf(stderr, "Error: Can't write file '%s' at offset %d\n", argv[1], checksum_offset);
      exit(1);
    }
  }

  fclose(file);

  exit(0);
}

void usage(char *argv[]) {
  fprintf(stderr, "Usage: %s <ROM file path> <injection offset in base 10> <bootfid offset in base 10>\n", argv[0]);
}

void bad_arg(char *argv[], char *arg_name, int arg_pos) {
  fprintf(stderr, "Error: Bad type or value for argument '%s = %s'\n", arg_name, argv[arg_pos]);
  usage(argv);
  exit(1);
}

void fread_fwrite_error(char *operation, char *filename, int offset) {
  fprintf(stderr, "Error: Can't %s file '%s' between offset %d and %d\n", operation, filename, offset, offset + 2);
  exit(1);
}
