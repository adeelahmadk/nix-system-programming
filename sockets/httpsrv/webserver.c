#include <fcntl.h>
#include <netinet/in.h>
#include <stdio.h>
#include <string.h>
#include <sys/sendfile.h>
#include <sys/socket.h>
#include <unistd.h>

int main() {
  int s = socket(AF_INET, SOCK_STREAM, 0);

  if (s == -1) {
    printf("Error opening socket!\n");
    return 1;
  }

  struct sockaddr_in addr = {AF_INET, 0x401f, 0};
  if (bind(s, (struct sockaddr *)&addr, sizeof(addr)) == -1) {
    printf("Error binding socket!\n");
    return 1;
  }

  listen(s, 10);

  // open a new socket to communicate with client
  int client_fd = accept(s, 0, 0);
  if (client_fd < 0) {
    printf("error opening client socket.");
    return 1;
  }

  char buffer[256] = {0};
  if (recv(client_fd, buffer, 255, 0) < 0) {
    printf("error reading request.");
    return 1;
  }

  printf("request:\n%s\n", buffer);
  // extract file name from request header
  // e.g. GET /index.html ...
  char *f = buffer + 5;
  *strchr(f, ' ') = 0;
  printf("requested filename: %s\n", f);

  int opened_fd = open(f, O_RDONLY);
  if (opened_fd < 0) {
    printf("error opening file.");
    return 1;
  }

  sendfile(client_fd, opened_fd, 0, 256);
  close(opened_fd);
  close(client_fd);
  close(s);
}
