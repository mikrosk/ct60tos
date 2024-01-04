#include "config.h"
#include <mint/osbind.h>
#include <string.h>
#include "ct60.h"
#include "get.h"
#include "../include/ramcf68k.h"

#define board_printf

#define mac_addr *(unsigned long *)(mac_address)
#define client_ip_addr *(unsigned long *)(ip_address)
#define server_ip_addr *(unsigned long *)(server_ip_address)


