#include "config.h"
#include <string.h>
#include "get.h"

#ifdef NETWORK
#if 1 // #ifndef MCF547X

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

#else /* MCF547X */

static PARAM eth = 
{
	.baud = 19200,
	.client = { 192, 168, 1, 2 },
	.server = { 192, 168, 1, 1 },
	.gateway = { 0, 0, 0, 0 },
	.netmask = { 255, 255, 255, 0 },
	.netcfg = { 0, 0, 2, 0 },
	.ethaddr = { 0x00, 0xcf, 0x54, 0x75, 0xcf, 0x01 },
	.filename = "/home/firetos.hex",
};

unsigned char *board_get_ethaddr(unsigned char *ethaddr)
{
	memcpy(ethaddr, &eth.ethaddr[0], 6);
	return ethaddr;
}

unsigned char *board_get_client(unsigned char *client)
{
	memcpy(client, &eth.client[0], 4);
	return client;
}

unsigned char *board_get_server(unsigned char *server)
{
	memcpy(server, &eth.server[0], 4);
	return server;
}

unsigned char *board_get_gateway(unsigned char *gateway)
{
	memcpy(gateway, &eth.gateway[0], 4);
	return gateway;
}

unsigned char *board_get_netmask(unsigned char *netmask)
{
	memcpy(netmask, &eth.netmask[0], 4);
	return netmask;
}

char *board_get_filename(char *filename)
{
	int c, i = 0;
	while(i < FILENAME_SIZE)
	{
		c = (int)eth.filename[i];
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
	return (int)eth.netcfg[2];
}

int board_get_autoboot(void)
{
	return (int)eth.netcfg[0];
}

#endif /* MCF547X */

#endif /* NETWORK */

