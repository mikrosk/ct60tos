/* Batch runner: executes the command lines of a script file, one per line,
 * and reports each exit code on the console.  Meant to be autostarted inside
 * an emulator whose console output is captured by the host.
 *
 *   ; comment
 *   cd C:\SRC          change drive and directory
 *   C:\BIN\TOOL.TTP a  run a program, args after the first space
 *
 * Execution stops at the first non-zero exit code.
 */

#include <mint/osbind.h>
#include <stdio.h>
#include <string.h>

static char line[256];

static long run(char *cmd)
{
	char tail[130];
	char *args;
	int len;

	args = strchr(cmd, ' ');
	if (args != NULL)
		*args++ = '\0';
	else
		args = "";

	len = (int)strlen(args);
	if (len > 125)
		len = 125;
	tail[0] = (char)len;
	memcpy(tail + 1, args, len);
	tail[len + 1] = '\0';

	return Pexec(0, cmd, tail, NULL);
}

int main(int argc, char *argv[])
{
	const char *script = (argc > 1) ? argv[1] : "C:\\BUILD.TXT";
	FILE *f;
	long rc = 0;

	if ((f = fopen(script, "r")) == NULL) {
		printf("###ERR cannot open %s\r\n", script);
		printf("###DONE -1\r\n");
		return 1;
	}

	while (fgets(line, sizeof(line), f) != NULL) {
		char *p = line + strlen(line);
		while (p > line && (p[-1] == '\n' || p[-1] == '\r' || p[-1] == ' '))
			*--p = '\0';
		p = line;
		while (*p == ' ' || *p == '\t')
			p++;
		if (*p == '\0' || *p == ';')
			continue;

		if (strncmp(p, "cd ", 3) == 0) {
			p += 3;
			if (p[0] != '\0' && p[1] == ':')
				Dsetdrv((p[0] & ~0x20) - 'A');
			printf("###CD %s\r\n", p);
			rc = Dsetpath(p);
			if (rc != 0) {
				printf("###RC %ld\r\n", rc);
				break;
			}
			continue;
		}

		printf("###RUN %s\r\n", p);
		fflush(stdout);
		rc = run(p);
		printf("###RC %ld\r\n", rc);
		fflush(stdout);
		if (rc != 0)
			break;
	}

	fclose(f);
	printf("###DONE %ld\r\n", rc);
	fflush(stdout);
	return (int)rc;
}
