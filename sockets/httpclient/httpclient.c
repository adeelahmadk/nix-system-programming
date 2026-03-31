#include <arpa/inet.h>
#include <netdb.h>
#include <netinet/in.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/ioctl.h>
#include <sys/socket.h> // socket
#include <sys/types.h>
#include <unistd.h>
// #include <signal.h>
#include <errno.h>
#include <fcntl.h>
#include <stdarg.h> // variadic function
// #include <sys/time.h>

#define SERVER_PORT 8000

#define MAXLINE 4096
#define SA struct sockaddr

void err_n_die(const char *fmt, ...);

int main(int argc, char *argv[]) {
  int sockfd, n;
  int sendbytes;
  struct sockaddr_in servaddr;
  char sendline[MAXLINE];
  char recvline[MAXLINE];

  if (argc != 2) {
    err_n_die("usage: %s <server address>\n", argv[0]);
  }

  if ((sockfd = socket(AF_INET, SOCK_STREAM, 0)) < 0)
    err_n_die("Error while creating the socket!");

  bzero(&servaddr, sizeof(servaddr));
  servaddr.sin_family = AF_INET;
  servaddr.sin_port = htons(SERVER_PORT); // host to network, short

  // string to binary representation for IP address
  if (inet_pton(AF_INET, argv[1], &servaddr.sin_addr) <= 0)
    err_n_die("inet_pton error for %s ", argv[1]);

  if (connect(sockfd, (SA *)&servaddr, sizeof(servaddr)) < 0)
    err_n_die("connect failed!");

  // prepare the message
  //          request  path  protocol+version
  //                |    |    |
  sprintf(sendline, "GET /index.html HTTP/1.1\r\n\r\n");
  sendbytes = strlen(sendline);

  // send the request - making sure you send it all
  // this code is a bit fragile, as it bails if only
  // some of the bytes are sent.
  // normally, you would want to retry, unless the return value was -1
  if (write(sockfd, sendline, sendbytes) != sendbytes)
    err_n_die("write error!");

  memset(recvline, 0, MAXLINE);
  // read server's response
  while ((n = read(sockfd, recvline, MAXLINE - 1)) > 0) {
    printf("%s", recvline);
  }
  close(sockfd);
  if (n < 0)
    err_n_die("read error!");

  printf("\n** Reading Completed! **\n");
  exit(0); // exit successfully
}

void err_n_die(const char *fmt, ...) {
  int errno_save;
  va_list ap;

  errno_save = errno;

  va_start(ap, fmt);
  vfprintf(stdout, fmt, ap);
  fprintf(stdout, "\n");
  fflush(stdout);

  if (errno_save != 0) {
    fprintf(stdout, "(errno = %d) : %s\n", errno_save, strerror(errno_save));
    fprintf(stdout, "\n");
    fflush(stdout);
  }
  va_end(ap);
  exit(1);
}
