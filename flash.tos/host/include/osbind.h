/* GEMDOS calls used by the image tools (gentos, compress), mapped to POSIX */
#ifndef HOST_OSBIND_H
#define HOST_OSBIND_H
#include <stdlib.h>
#include <fcntl.h>
#include <unistd.h>
#define Fopen(n,m)        ((long)open((n), O_RDONLY))
#define Fcreate(n,a)      ((long)open((n), O_WRONLY|O_CREAT|O_TRUNC, 0644))
#define Fread(h,l,b)      ((long)read((h), (b), (l)))
#define Fwrite(h,l,b)     ((long)write((h), (b), (l)))
#define Fclose(h)         close(h)
#define Fseek(o,h,w)      ((long)lseek((h), (o), (w)))
#define Mxalloc(s,m)      malloc(s)
#define Mfree(p)          free(p)
#endif
