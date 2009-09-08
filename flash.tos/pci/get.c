#include "config.h"
#include "get.h"

#ifdef NETWORK

unsigned char *board_get_ethaddr(unsigned char *ethaddr)
{
	int i;
	for(i = 0; i < 6; i++)
		ethaddr[i] = ((PARAM *)PARAMS_ADDRESS)->ethaddr[i];
	return ethaddr;
}

unsigned char *board_get_client(unsigned char *client)
{
	int i;
	for(i = 0; i < 4; i++)
		client[i] = ((PARAM *)PARAMS_ADDRESS)->client[i];
	return client;
}

unsigned char *board_get_server(unsigned char *server)
{
	int i;
	for(i = 0; i < 4; i++)
		server[i] = ((PARAM *)PARAMS_ADDRESS)->server[i];
	return server;
}

unsigned char *board_get_gateway(unsigned char *gateway)
{
	int i;
	for(i = 0; i < 4; i++)
		gateway[i] = ((PARAM *)PARAMS_ADDRESS)->gateway[i];
	return gateway;
}

unsigned char *board_get_netmask(unsigned char *netmask)
{
	int i;
	for(i = 0; i < 4; i++)
		netmask[i] = ((PARAM *)PARAMS_ADDRESS)->netmask[i];
	return netmask;
}

char *board_get_filename(char *filename)
{
	int c, i = 0;
	while(i < FILENAME_SIZE)
	{
		c = ((PARAM *)PARAMS_ADDRESS)->filename[i];
		filename[i] = (char)c;
		i++;
		if(c == '\0')
			i = FILENAME_SIZE;
	}
	filename[i] = '\0';
	return filename;
}

int board_get_filetype(void)
{
	return((PARAM *)PARAMS_ADDRESS)->netcfg[2];
}

int board_get_autoboot(void)
{
	return((PARAM *)PARAMS_ADDRESS)->netcfg[0];
}

#endif /* NETWORK */

