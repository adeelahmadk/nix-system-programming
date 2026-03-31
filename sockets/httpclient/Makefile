CC=gcc
CFLAGS= -g

all: tcpc

tcpc: httpclient.c
	$(CC) $(CFLAGS) -o $@ $^

clean:
	rm -rf *.dSYM tcpc
