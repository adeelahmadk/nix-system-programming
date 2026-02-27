#define _GNU_SOURCE
#include <pthread.h>
#include <stdalign.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>

#define THRESHOLD (1000000000UL)

void *thread_func(void *arg) {
  uint64_t *counter = (uint64_t *)arg;
  while (*counter < THRESHOLD) {
    (*counter)++;
  }
  return NULL;
}

int main() {
  uint64_t counter1 = 0;
  uint64_t counter2 = 0;

  printf("&counter1: %p\n", &counter1);
  printf("&counter2: %p\n", &counter2);

  pthread_t t1, t2;
  pthread_create(&t1, NULL, thread_func, &counter1);
  pthread_create(&t2, NULL, thread_func, &counter2);

  pthread_join(t1, NULL);
  pthread_join(t2, NULL);

  printf("counter1: %lu\n", counter1);
  printf("counter2: %lu\n", counter2);

  return EXIT_SUCCESS;
}
