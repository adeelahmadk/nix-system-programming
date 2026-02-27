# POSIX Threads

POSIX standard provide `pthread` library to run and manage parallel threads of execution.

If `pthread` is not installed in your system then use following:

```shell
sudo apt install libpthread-stubs0-dev manpages-posix manpages-posix-dev
```

While reading man pages, remember that the man page entry in Ubuntu and variants is named `pthreads`. Therefore, use following command:

```shell
man pthreads
```

## pthread API

### `pthread_t`

This type uniquely identifies a thread.

> IEEE Std 1003.1-2001/Cor 2-2004, item XBD/TC2/D6/26 is applied, adding pthread_t to the list of types that are not required to be arithmetic types, thus allowing pthread_t to be defined as a structure.
> [Stackoverflow Answer](https://stackoverflow.com/a/33285994/5892622)

## Example Programs

| Program | Description |
| ------- | ----------- |
| `threads.c` | A simple example of starting threads using `pthread` library. |
| `thread_args.c` | An example on sending arguments to threads. |
| `thread_ret.c` | An example of receiving return value from a thread. |
| `thread_join.c` | How to wait for the threads to finish. |
| `mutex.c` | Memory read/write safety through Mutex Locks. |
| `count_unex.c` | Different threads updating same memory unexculsively. |
| `count_mutex.c` | Different threads updating same memory in a mutually exculsive (Mutex) manner. |
| `false_sharing.c`  | Threads on different CPUs modify independent variables residing on the same cache line causing performance degradation due to false sharing. |
| `cacheline_align.c` | Cacheline aligning contiguously defined variables used by different threads improves performance. |
| `cacheline_align.cpp` | Cacheline alignment in C++17 and above. |
|  |  |
|  |  |
