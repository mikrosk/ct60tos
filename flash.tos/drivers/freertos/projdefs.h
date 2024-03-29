/*
	FreeRTOS.org V4.1.3 - Copyright (C) 2003-2006 Richard Barry.

	This file is part of the FreeRTOS.org distribution.

	FreeRTOS.org is free software; you can redistribute it and/or modify
	it under the terms of the GNU General Public License as published by
	the Free Software Foundation; either version 2 of the License, or
	(at your option) any later version.

	FreeRTOS.org is distributed in the hope that it will be useful,
	but WITHOUT ANY WARRANTY; without even the implied warranty of
	MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
	GNU General Public License for more details.

	You should have received a copy of the GNU General Public License
	along with FreeRTOS.org; if not, write to the Free Software
	Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA

	A special exception to the GPL can be applied should you wish to distribute
	a combined work that includes FreeRTOS.org, without being obliged to provide
	the source code for any proprietary components.  See the licensing section 
	of http://www.FreeRTOS.org for full details of how and when the exception
	can be applied.

	***************************************************************************
	See http://www.FreeRTOS.org for documentation, latest information, license 
	and contact details.  Please ensure to read the configuration and relevant 
	port sections of the online documentation.
	***************************************************************************
*/

#ifndef PROJDEFS_H
#define PROJDEFS_H

/* Defines to prototype to which task functions must conform. */
typedef void (*pdTASK_CODE)( void * );

#define pdTRUE		( 1 )
#define pdFALSE		( 0 )

#define pdPASS									( 1 )
#define pdFAIL									( 0 )
#define errQUEUE_EMPTY							( 0 )
#define errQUEUE_FULL							( 0 )

/* Error definitions. */
#define errCOULD_NOT_ALLOCATE_REQUIRED_MEMORY	( -1 )
#define errNO_TASK_TO_RUN						( -2 )
#define errQUEUE_BLOCKED						( -4 )
#define errQUEUE_YIELD							( -5 )
#define errQUEUE_HANDLE             ( -6 )

#endif /* PROJDEFS_H */



