/* This file exist because it's impossible to
   use TOS trap out of CF68KLIB !!!
 */
#include "config.h"
#include "../freertos/FreeRTOS.h"
#include "../freertos/task.h"
#include "../../include/vars.h"
#include "asm.h"
#include "fs.h"
#include "mem.h"
#include "console.h"
#include "gemerror.h"

