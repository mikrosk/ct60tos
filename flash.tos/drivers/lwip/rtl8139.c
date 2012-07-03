/*
 * Copyright (c) 2001, Swedish Institute of Computer Science.
 * All rights reserved. 
 *
 * Redistribution and use in source and binary forms, with or without 
 * modification, are permitted provided that the following conditions 
 * are met: 
 * 1. Redistributions of source code must retain the above copyright 
 *    notice, this list of conditions and the following disclaimer. 
 * 2. Redistributions in binary form must reproduce the above copyright 
 *    notice, this list of conditions and the following disclaimer in the 
 *    documentation and/or other materials provided with the distribution. 
 * 3. Neither the name of the Institute nor the names of its contributors 
 *    may be used to endorse or promote products derived from this software 
 *    without specific prior written permission. 
 *
 * THIS SOFTWARE IS PROVIDED BY THE INSTITUTE AND CONTRIBUTORS ``AS IS'' AND 
 * ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE 
 * IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE 
 * ARE DISCLAIMED.  IN NO EVENT SHALL THE INSTITUTE OR CONTRIBUTORS BE LIABLE 
 * FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL 
 * DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS 
 * OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) 
 * HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT 
 * LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY 
 * OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF 
 * SUCH DAMAGE. 
 *
 */

/*
        A RealTek RTL-8139 Fast Ethernet driver for Linux.
 
        Maintained by Jeff Garzik <jgarzik@mandrakesoft.com>
        Copyright 2000,2001 Jeff Garzik
 
        Much code comes from Donald Becker's rtl8139.c driver,
        versions 1.13 and older.  This driver was originally based
        on rtl8139.c version 1.07.  Header of rtl8139.c version 1.13:
 
        -----<snip>-----
 
                Written 1997-2001 by Donald Becker.
                This software may be used and distributed according to the
                terms of the GNU General Public License (GPL), incorporated
                herein by reference.  Drivers based on or derived from this
                code fall under the GPL and must retain the authorship,
                copyright and license notice.  This file is not a complete
                program and may only be used when the entire operating
                system is licensed under the GPL.
 
                This driver is for boards based on the RTL8129 and RTL8139
                PCI ethernet chips.
 
                The author may be reached as becker@scyld.com, or C/O Scyld
                Computing Corporation 410 Severn Ave., Suite 210 Annapolis
                MD 21403
                Support and updates available at
                http://www.scyld.com/network/rtl8139.html
                Twister-tuning table provided by Kinston
                <shangh@realtek.com.tw>.
 
        -----<snip>-----
        This software may be used and distributed according to the terms
        of the GNU General Public License, incorporated herein by reference.
 
        Contributors:
 
                Donald Becker - he wrote the original driver, kudos to him!
                (but please don't e-mail him for support, this isn't his driver)
 
                Tigran Aivazian - bug fixes, skbuff free cleanup
 
                Martin Mares - suggestions for PCI cleanup
 
                David S. Miller - PCI DMA and softnet updates
 
                Ernst Gill - fixes ported from BSD driver
 
                Daniel Kobras - identified specific locations of
                        posted MMIO write bugginess
 
                Gerard Sharp - bug fix, testing and feedback

                David Ford - Rx ring wrap fix

                Dan DeMaggio - swapped RTL8139 cards with me, and allowed me
                to find and fix a crucial bug on older chipsets.
 
                Donald Becker/Chris Butterworth/Marcus Westergren -
                Noticed various Rx packet size-related buglets.
 
                Santiago Garcia Mantinan - testing and feedback
 
                Jens David - 2.2.x kernel backports
 
                Martin Dennett - incredibly helpful insight on undocumented
                features of the 8139 chips
 
                Jean-Jacques Michel - bug fix
 
                Tobias Ringström - Rx interrupt status checking suggestion
 
                Andrew Morton - Clear blocked signals, avoid
                buffer overrun setting current->comm.

--------------------------------------------------------------------------- */

/* ------------------------ System includes ------------------------------- */
#include <mint/osbind.h>
#include <mint/sysvars.h>
#include <string.h>

/* ------------------------ Platform includes ----------------------------- */
#include "config.h"
#include "pcixbios.h"
#include "mod_devicetable.h"
#include "pci_ids.h"

/* ------------------------ FreeRTOS includes ----------------------------- */
#include "../freertos/FreeRTOS.h"
#include "../freertos/task.h"
#include "../freertos/queue.h"
#include "../freertos/semphr.h"

/* ------------------------ lwIP includes --------------------------------- */
#include "opt.h"
#include "def.h"
#include "mem.h"
#include "pbuf.h"
#include "sys.h"
#include "stats.h"
//#include "perf.h"
#include "etharp.h"
#include "debug.h"

#include "rtl8139.h"

/* ------------------------ Defines --------------------------------------- */
#define ARRAY_SIZE(arr) (sizeof(arr) / (sizeof(arr)[0]))

#define TASK_PRIORITY   (30)

#if defined(LWIP) && defined(FREERTOS)

struct rtl8139if {
  struct netif *netif;        /* lwIP network interface */
  struct eth_addr *ethaddr;
};

typedef struct
{
  long ident;
  union
  {
    long l;
    short i[2];
    char c[4];
  } v;
} COOKIE;

#ifdef USE_RX_BUFFERS
struct memory
{
  void *mem;
};
#endif

struct pci_device_id rtl8139_eth_pci_table[] = {
  { RTL8139_VENDOR_ID, RTL8139_DEVICE_ID, PCI_ANY_ID, PCI_ANY_ID, 0, 0, 0 },
  { 0, 0, 0, 0, 0, 0, 0 }
};

/* Forward declarations. */
static void rtl8139if_input(struct netif *netif, struct pbuf *p);
static err_t rtl8139if_output(struct netif *netif, struct pbuf *p, struct ip_addr *ipaddr);

static int rtl8139_read_eeprom(void *ioaddr, int location, int addr_len);
static int rtl8139_mdio_read(struct rtl8139_private *rtl_8139, int phy_id, int location);
static void rtl8139_mdio_write(struct rtl8139_private *rtl_8139, int phy_id, int location, int val);

/* Maximum events (Rx packets, etc.) to handle at each interrupt. */
static int rtl8139_max_interrupt_work = 10;
static unsigned char rtl8139_ip_addr[2][4];                     
static int rtl8139_n_filters;
static unsigned char rtl8139_opened;
static struct rtl8139_private rtl_8139_tp;
extern portBASE_TYPE xNeedSwitchPCI;

#ifdef USE_RX_BUFFERS

static void rtl8139_initialize_rx_buffer(struct rtl8139_private *rtl_8139_tp)
{
  struct rx_buffer_t *fifo_rx_buffer = (struct rx_buffer_t *)&rtl_8139_tp->rx_buffer;
  struct rx_slot_t *tmp;
  int i;
  tmp = fifo_rx_buffer->first = fifo_rx_buffer->add = fifo_rx_buffer->extract = nbuf_alloc(sizeof(struct rx_slot_t));
  for(i = 0; i < (MAX_RX_BUFFER_ENTRIES - 1); i++)
  { 
     tmp->next = nbuf_alloc(sizeof(struct rx_slot_t));
     tmp->read = 0x01;
     tmp->length = 0;
     tmp->data =  nbuf_alloc(PKT_BUF_SZ);
     tmp = tmp->next;
  }
  tmp->next = fifo_rx_buffer->first;
  tmp->read = 0x01;
  tmp->data = nbuf_alloc(PKT_BUF_SZ);
}

static void rtl8139_dealloc_rx_buffer(struct rtl8139_private *rtl_8139_tp)
{
  struct rx_buffer_t *fifo_rx_buffer = (struct rx_buffer_t *)&rtl_8139_tp->rx_buffer;
  struct rx_slot_t *tmp = fifo_rx_buffer->first->next, *actual;
  int i;
  for(i = 0;i < (MAX_RX_BUFFER_ENTRIES - 1); i++)
  {
    actual = tmp->next;
    if(tmp->data != NULL)
      nbuf_free(tmp->data);
     nbuf_free(tmp);
     tmp = actual;
   }  
   if(fifo_rx_buffer->first->data != NULL)
     nbuf_free(fifo_rx_buffer->first->data);
   nbuf_free(fifo_rx_buffer->first);
}

static int rtl8139_add_frame_to_buffer(struct rtl8139_private *rtl_8139_tp, unsigned char *data, int len)
{
  struct rx_buffer_t *fifo_rx_buffer = (struct rx_buffer_t *)&rtl_8139_tp->rx_buffer;
  /* If the packet in the position that we're writting hasn't still been read is 
     because we're receiving too much packets, so we need to drop it. */ 
  if(fifo_rx_buffer->add->read !=  0x00)
  {
    fifo_rx_buffer->add->length = len;
    memcpy(fifo_rx_buffer->add->data,data, len);
    fifo_rx_buffer->add->read = 0x00;
    fifo_rx_buffer->add = fifo_rx_buffer->add->next;
    return(0);
  }
  /* The packet is dropped */
  return(-1);
}

static int rtl8139_extract_frame_of_buffer(struct rtl8139_private *rtl_8139_tp, void *data)
{
  struct rx_buffer_t *fifo_rx_buffer = (struct rx_buffer_t *)&rtl_8139_tp->rx_buffer;
  struct rx_slot_t *tmp = fifo_rx_buffer->extract;
  ((struct memory *)data)->mem = tmp->data;
  tmp->read = 0x01;
  fifo_rx_buffer->extract = fifo_rx_buffer->extract->next;
  return(tmp->length);
}

#endif /* USE_RX_BUFFERS */

int rtl8139_obtain_mac_address(unsigned char *mac)
{
  int i;
  for(i = 0; i < 6; i++)
    mac[i] = rtl_8139_tp.dev_addr[i];
  return(0);
}

int rtl8139_set_ip_filter(long ipaddr)
{
  if(rtl8139_n_filters <= 1)
  {
    rtl8139_ip_addr[rtl8139_n_filters][3] = ipaddr & 0x000000ff;
    rtl8139_ip_addr[rtl8139_n_filters][2] = (ipaddr >> 8) & 0x000000ff;
    rtl8139_ip_addr[rtl8139_n_filters][1] = (ipaddr >> 16) & 0x000000ff;
    rtl8139_ip_addr[rtl8139_n_filters][0] = (ipaddr >> 24) & 0x000000ff;
    rtl8139_n_filters++;
    return(0);
  }
  board_printf("RTL8139: You cannot set more than 2 IP filters !!");
  return(-1);
}

/* The data sheet doesn't describe the Rx ring at all, so I'm guessing at the field alignments and semantics. */
static void rtl8139_rx_interrupt(struct rtl8139_private *rtl_8139_tp)
{
  unsigned char *rx_ring;
  unsigned short cur_rx;
  unsigned char mine = 1, multicast_packet= 1, arp_request_for_me = 1;
  void *ioaddr = rtl_8139_tp->mmio_addr;
  int i, j;
  rx_ring = rtl_8139_tp->rx_ring;
  cur_rx = rtl_8139_tp->cur_rx;
  while((RTL_R8(ChipCmd) & RxBufEmpty) == 0)
  {
    int ring_offset = cur_rx % RX_BUF_LEN;
    unsigned long rx_status;
    unsigned int rx_size, pkt_size;
    unsigned char *skb;
    /* read size+status of next frame from DMA ring buffer */
    rx_status = le32_to_cpu(*(unsigned long *)(rx_ring + ring_offset));
    rx_size = rx_status >> 16;
    pkt_size = rx_size - 4;
    if(rx_size == 0xfff0)
      break;
    if((rx_size > (MAX_ETH_FRAME_SIZE+4)) || (!(rx_status & RxStatusOK)))
      return;
    skb = &rx_ring[ring_offset+4]; 
#if LINK_STATS
    lwip_stats.link.recv++;
#endif
    for(i = 0; i < 6; i++)
    {
      if(skb[i] == rtl_8139_tp->dev_addr[i])
        continue;
      else
      {
        mine = 0;
        break;
      }
    }
    if(mine)
      goto accept_frame;
    if((skb[12] == 0x08) && (skb[13] == 0x06))
    {
      for(j = 0; j < rtl8139_n_filters; j++)
      {
        for(i = 0; i < 4;i++)
        {
          if(skb[38+i] == rtl8139_ip_addr[j][i])
            continue;
          else
          {
            arp_request_for_me = 0;
            break;
          }
        }
      }
    }
    else
      arp_request_for_me = 0;
    for(i = 0; i < 6; i++)
    {
      if(skb[i] == 0xff)
        continue;
      else
      {
        multicast_packet = 0;
        break;
      }
    }
accept_frame:
    if(mine || (multicast_packet && arp_request_for_me))
    { 
      extern short OldBoot;
#ifdef USE_RX_BUFFERS
      if((rtl8139_add_frame_to_buffer(rtl_8139_tp, skb, pkt_size) == 0) && (rtl_8139_tp->rx_sem != NULL))
      {
        if(OldBoot)
          xNeedSwitchPCI = pdFALSE;
        xNeedSwitchPCI = xSemaphoreGiveFromISR(rtl_8139_tp->rx_sem, xNeedSwitchPCI);
      }
#else
      if(rtl_8139_tp->rx_queue != NULL)
      {
        unsigned long msg[2];
        msg[0] = (unsigned long)pkt_size;
        msg[1] = (unsigned long)skb;
        if(OldBoot)
          xNeedSwitchPCI = pdFALSE;
        xNeedSwitchPCI = xQueueSendFromISR(rtl_8139_tp->rx_queue, &msg, xNeedSwitchPCI);
      }
#endif /* USE_RX_BUFFERS */
      rtl_8139_tp->rx_frames_for_us++;
    }
    cur_rx = (cur_rx + rx_size + 4 + 3) & ~3;
    RTL_W16_F(RxBufPtr, cur_rx - 16);
    mine = multicast_packet = arp_request_for_me = 1;
  }
  rtl_8139_tp->cur_rx = cur_rx;
}               

static void rtl8139_tx_interrupt(struct rtl8139_private *rtl_8139_tp)
{
  void *ioaddr = rtl_8139_tp->mmio_addr;
  unsigned long dirty_tx, tx_left;
  dirty_tx = rtl_8139_tp->dirty_tx;
  tx_left = rtl_8139_tp->cur_tx - dirty_tx;
  while(tx_left > 0)
  {
    int entry = dirty_tx % NUM_TX_DESC;
    int txstatus = RTL_R32(TxStatus0 + (entry * sizeof(unsigned long)));
    if (!(txstatus & (TxStatOK | TxUnderrun | TxAborted)))
      break;  /* It still hasn't been Txed */
    /* Note: TxCarrierLost is always asserted at 100mbps. */
    if(txstatus & (TxOutOfWindow | TxAborted))
    {
      /* There was an major error, log it. */
//      board_printf("RTL8139: Transmit error, Tx status %8.8x.\r\n", txstatus);
#if LINK_STATS
      lwip_stats.link.err++; /* tx error */
#endif
      if(txstatus & TxAborted)
      {
#if LINK_STATS
//        tx_aborted_errors++;
#endif
        RTL_W32(TxConfig, TxClearAbt | (TX_DMA_BURST << TxDMAShift));
      }
#if LINK_STATS
//      if(txstatus & TxCarrierLost)
//        tx_carrier_errors++;
//      if(txstatus & TxOutOfWindow)
//        tx_window_errors++;
#if ETHER_STATS
//      if((txstatus & 0x0f000000) == 0x0f000000)
//        collisions16++;
#endif
#endif
    }
    else
    {
      if(txstatus & TxUnderrun)
      {
        /* Add 64 to the Tx FIFO threshold. */
        if(rtl_8139_tp->tx_flag < 0x00300000)
          rtl_8139_tp->tx_flag += 0x00020000;
#if LINK_STATS
//        tx_fifo_errors++;
#endif
      }
#if LINK_STATS
//      collisions += (txstatus >> 24) & 15;
      lwip_stats.link.xmit++;
#endif
    }
    /* Free the original skb. */
    dirty_tx++;
    tx_left--;
  }
#ifdef RTL8139_DEBUG
  if(rtl_8139_tp->cur_tx - dirty_tx > NUM_TX_DESC)
  {
//    board_printf("RTL8139: Out-of-sync dirty pointer, %ld vs. %ld.\r\n", dirty_tx, rtl_8139_tp->cur_tx);
    dirty_tx += NUM_TX_DESC;
  }
#endif /* RTL8139_DEBUG */
  /* only wake the queue if we did work, and the queue is stopped */
  if(rtl_8139_tp->dirty_tx != dirty_tx)
    rtl_8139_tp->dirty_tx = dirty_tx;
}                                                                  

/* The interrupt handler does all of the Rx thread work and cleans up after the Tx thread. */
int rtl8139_interrupt(struct rtl8139_private *rtl_8139_tp)
{
  int boguscnt = rtl8139_max_interrupt_work; 
  void *ioaddr = rtl_8139_tp->mmio_addr;
  int status = 0, link_changed = 0; /* avoid bogus "uninit" warning */
  do
  {
    if(rtl_8139_tp->ctpci_dma_lock != NULL)
    {
      int i = 0;
      while((i <= 100) && rtl_8139_tp->ctpci_dma_lock(1))
      {
        udelay(1); /* try to fix CTPCI freezes */
        i++;
      }
    }
    status = RTL_R16(IntrStatus);
    /* h/w no longer present (hotplug?) or major error, bail */
    if(status == 0xFFFF)
    {
      if(rtl_8139_tp->ctpci_dma_lock != NULL)
        rtl_8139_tp->ctpci_dma_lock(0);
      break;
    }
    /* Acknowledge all of the current interrupt sources ASAP, but an first get an additional status bit from CSCR. */
    if(status & RxUnderrun)
      link_changed = RTL_R16 (CSCR) & CSCR_LinkChangeBit;
    RTL_W16_F(IntrStatus, (status & RxFIFOOver) ? (status | RxOverflow) : status);
    if((status & (PCIErr | PCSTimeout | RxUnderrun | RxOverflow | RxFIFOOver | TxErr | TxOK | RxErr | RxOK)) == 0)
    {
      if(rtl_8139_tp->ctpci_dma_lock != NULL)
        rtl_8139_tp->ctpci_dma_lock(0);
      break;
    }
    if(status & (RxOK | RxUnderrun | RxOverflow | RxFIFOOver))
      rtl8139_rx_interrupt(rtl_8139_tp);  
    if(status & (TxOK | TxErr))
      rtl8139_tx_interrupt(rtl_8139_tp);   
    if(rtl_8139_tp->ctpci_dma_lock != NULL)
      rtl_8139_tp->ctpci_dma_lock(0);
    boguscnt--;
  }
  while(boguscnt > 0);  
  if((status != 0xFFFF) && (status & PCIErr))
  {
#ifdef PCI_XBIOS
    short sr = fast_read_config_word(rtl_8139_tp->handle, PCISR);
    write_config_word(rtl_8139_tp->handle, PCISR, sr);
#else
    short sr = Fast_read_config_word(rtl_8139_tp->handle, PCISR);
    Write_config_word(rtl_8139_tp->handle, PCISR, sr);
#endif
//    board_printf("RTL8139: PCI ERROR SR %#04x\r\n", sr);
  }
  if(boguscnt <= 0)
  {
//    board_printf("RTL8139: Too much work at interrupt, IntrStatus=0x%4.4x.\r\n", status);
    /* Clear all interrupt sources. */
    RTL_W16(IntrStatus, 0xffff);
  }
  return(1);
}

/* Syncronize the MII management interface by shifting 32 one bits out. */                                    
static void rtl8139_mdio_sync(void *mdio_addr)
{
  int i;
  for(i = 32; i >= 0; i--)
  {
    writeb(MDIO_WRITE1, mdio_addr);
    rtl8139_mdio_delay(mdio_addr);
    writeb(MDIO_WRITE1 | MDIO_CLK, mdio_addr);
    rtl8139_mdio_delay(mdio_addr);
  }
}

static int rtl8139_mdio_read(struct rtl8139_private *rtl_8139_tp, int phy_id, int location)
{
  void *mdio_addr = (void *)((unsigned long)rtl_8139_tp->mmio_addr + Config4);
  int mii_cmd = (0xf6 << 10) | (phy_id << 5) | location;
  int retval = 0;
  int i;
  if(phy_id > 31)
    /* Really a 8139.  Use internal registers. */
    return location < 8 && mii_2_8139_map[location] ? readw((unsigned long)rtl_8139_tp->mmio_addr + mii_2_8139_map[location]) : 0;
   rtl8139_mdio_sync(mdio_addr);
   /* Shift the read command bits out. */
   for(i = 15; i >= 0; i--)
   {
     int dataval = (mii_cmd & (1 << i)) ? MDIO_DATA_OUT : 0;
     writeb(MDIO_DIR | dataval, mdio_addr);
     rtl8139_mdio_delay(mdio_addr);
     writeb(MDIO_DIR | dataval | MDIO_CLK, mdio_addr);
     rtl8139_mdio_delay(mdio_addr);
   }
   /* Read the two transition, 16 data, and wire-idle bits. */
   for(i = 19; i > 0; i--)
   {
     writeb(0, mdio_addr);
     rtl8139_mdio_delay(mdio_addr);
     retval = (retval << 1) | ((readb((unsigned long)mdio_addr) & MDIO_DATA_IN) ? 1 : 0);
     writeb(MDIO_CLK, mdio_addr);
     rtl8139_mdio_delay(mdio_addr);
   }
   return((retval >> 1) & 0xffff);
}

static void rtl8139_mdio_write(struct rtl8139_private *rtl_8139_tp, int phy_id, int location, int value)
{
  void *mdio_addr = (void *)((unsigned long)rtl_8139_tp->mmio_addr + Config4);
  int mii_cmd = (0x5002 << 16) | (phy_id << 23) | (location << 18) | value;
  int i;
  if(phy_id > 31)
  {      /* Really a 8139.  Use internal registers. */
    void *ioaddr = rtl_8139_tp->mmio_addr;
    if(location == 0)
    {
      RTL_W8_F(Cfg9346, Cfg9346_Unlock);
      switch(rtl_8139_tp->AutoNegoAbility)
      {
        case 1: RTL_W16(NWayAdvert, AutoNegoAbility10half); break;
        case 2: RTL_W16(NWayAdvert, AutoNegoAbility10full); break;
        case 4: RTL_W16(NWayAdvert, AutoNegoAbility100half); break;
        case 8: RTL_W16(NWayAdvert, AutoNegoAbility100full); break;
        default: break;
      }
      RTL_W16_F(BasicModeCtrl, AutoNegotiationEnable|AutoNegotiationRestart);
      RTL_W8_F(Cfg9346, Cfg9346_Lock);
    }
    else if(location < 8 && mii_2_8139_map[location])
      RTL_W16_F(mii_2_8139_map[location], value);
  }
  else
  {
    rtl8139_mdio_sync(mdio_addr);
    /* Shift the command bits out. */
    for(i = 31; i >= 0; i--)
    {
      int dataval = (mii_cmd & (1 << i)) ? MDIO_WRITE1 : MDIO_WRITE0;
      writeb(dataval, mdio_addr);
      rtl8139_mdio_delay(mdio_addr);
      writeb(dataval | MDIO_CLK, mdio_addr);
      rtl8139_mdio_delay(mdio_addr);
    }
    /* Clear out extra bits. */
    for(i = 2; i > 0; i--)
    {
      writeb(0, mdio_addr);
      rtl8139_mdio_delay(mdio_addr);
      writeb(MDIO_CLK, mdio_addr);
      rtl8139_mdio_delay(mdio_addr);
    }
  }
}

/* Serial EEPROM section. */
 
/*  EEPROM_Ctrl bits. */
#define EE_SHIFT_CLK    0x04    /* EEPROM shift clock. */
#define EE_CS                   0x08    /* EEPROM chip select. */
#define EE_DATA_WRITE   0x02    /* EEPROM chip data in. */
#define EE_WRITE_0              0x00
#define EE_WRITE_1              0x02
#define EE_DATA_READ    0x01    /* EEPROM chip data out. */
#define EE_ENB                  (0x80 | EE_CS)
 
/* Delay between EEPROM clock transitions.
   No extra delay is needed with 33Mhz PCI, but 66Mhz may change this.
 */
 
#define rtl8139_eeprom_delay()  readl(ee_addr)
 
/* The EEPROM commands include the alway-set leading bit. */
#define EE_WRITE_CMD    (5)
#define EE_READ_CMD     (6)
#define EE_ERASE_CMD    (7)

static int rtl8139_read_eeprom(void *ioaddr, int location, int addr_len)
{
  int i;
  unsigned retval = 0;
  void *ee_addr = (void *)((unsigned long)ioaddr + Cfg9346);
  int read_cmd = location | (EE_READ_CMD << addr_len);
  writeb(EE_ENB & ~EE_CS, ee_addr);
  writeb(EE_ENB, ee_addr);
  rtl8139_eeprom_delay();
  /* Shift the read command bits out. */
  for(i = 4 + addr_len; i >= 0; i--)
  {
    int dataval = (read_cmd & (1 << i)) ? EE_DATA_WRITE : 0;
    writeb(EE_ENB | dataval, ee_addr);
    rtl8139_eeprom_delay();
    writeb(EE_ENB | dataval | EE_SHIFT_CLK, ee_addr);
    rtl8139_eeprom_delay();
  }
  writeb(EE_ENB, ee_addr);
  rtl8139_eeprom_delay();
  for(i = 16; i > 0; i--)
  {
    writeb(EE_ENB | EE_SHIFT_CLK, ee_addr);
    rtl8139_eeprom_delay();
    retval = (retval << 1) | ((readb(ee_addr) & EE_DATA_READ) ? 1 : 0);
    writeb(EE_ENB, ee_addr);
    rtl8139_eeprom_delay();
  }
  /* Terminate the EEPROM access. */
  writeb(~EE_CS, ee_addr);
  rtl8139_eeprom_delay();
  return(retval);
}

/* Start the hardware at open or resume. */
static void rtl8139_hw_start(struct rtl8139_private *rtl_8139_tp)
{
  void *ioaddr = rtl_8139_tp->mmio_addr;
  unsigned long i;
  unsigned char tmp;
  int rx_mode;
  /* Soft reset the chip. */
  RTL_W8(ChipCmd, (RTL_R8(ChipCmd) & ChipCmdClear) | CmdReset);
  vTaskDelay((100*configTICK_RATE_HZ)/1000);
  /* Check that the chip has finished the reset. */
  for(i = 1000; i > 0; i--)
  {
    if((RTL_R8(ChipCmd) & CmdReset) == 0)
      break;
  }
  /* unlock Config[01234] and BMCR register writes */
  RTL_W8_F(Cfg9346, Cfg9346_Unlock);
  /* Restore our idea of the MAC address. */
  RTL_W32_F(MAC0 + 0, cpu_to_le32(*(unsigned long *)(rtl_8139_tp->dev_addr + 0)));
  RTL_W32_F(MAC0 + 4, cpu_to_le32(*(unsigned long *)(rtl_8139_tp->dev_addr + 4)));
  /* Must enable Tx/Rx before setting transfer thresholds! */
  RTL_W8_F(ChipCmd, (RTL_R8(ChipCmd) & ChipCmdClear) | CmdRxEnb | CmdTxEnb);
  RTL_W32_F(RxConfig, rtl8139_rx_config | (RTL_R32(RxConfig) & rtl_chip_info[rtl_8139_tp->chipset].RxConfigMask));
  /* Check this value: the documentation for IFG contradicts ifself. */
  RTL_W32(TxConfig, (TX_DMA_BURST << TxDMAShift));
  rtl_8139_tp->cur_rx = 0;
  /* This is check_duplex() */
  if((rtl_8139_tp->phys[0] >= 0) || (rtl_8139_tp->drv_flags & HAS_MII_XCVR))
  {
    unsigned short mii_reg5 = rtl8139_mdio_read(rtl_8139_tp, rtl_8139_tp->phys[0], 5);
    if(mii_reg5 == 0xffff); /* Not there */
    else if(((mii_reg5 & 0x0100) == 0x0100) || ((mii_reg5 & 0x00C0) == 0x0040))
      rtl_8139_tp->full_duplex = 1;
    board_printf("RTL8139: Setting %s%s-duplex based on auto-negotiated partner ability %4.4x.\r\n", mii_reg5 == 0 ? "" :
     (mii_reg5 & 0x0180) ? "100mbps " : "10mbps ", rtl_8139_tp->full_duplex ? "full" : "half", mii_reg5);
  }
  if(rtl_8139_tp->chipset >= CH_8139A)
  {
    tmp = RTL_R8(Config1) & Config1Clear;
    tmp |= Cfg1_Driver_Load;
    tmp |= (rtl_8139_tp->chipset == CH_8139B) ? 3 : 1; /* Enable PM/VPD */
    RTL_W8_F(Config1, tmp);
  }
  else
  {
    unsigned char foo = RTL_R8(Config1) & Config1Clear;
    RTL_W8(Config1, rtl_8139_tp->full_duplex ? (foo|0x60) : (foo|0x20));
  }
  if(rtl_8139_tp->chipset >= CH_8139B)
  {
    tmp = RTL_R8(Config4) & ~(1<<2);
    /* chip will clear Rx FIFO overflow automatically */
    tmp |= (1<<7);
    RTL_W8(Config4, tmp);
    /* disable magic packet scanning, which is enabled when PM is enabled above (Config1) */
    RTL_W8(Config3, RTL_R8(Config3) & ~(1<<5));
  }
  /* Lock Config[01234] and BMCR register writes */
  RTL_W8_F(Cfg9346, Cfg9346_Lock);
  vTaskDelay((10*configTICK_RATE_HZ)/1000);
  /* init Rx ring buffer DMA address */
  RTL_W32_F(RxBuf, rtl_8139_tp->rx_ring_dma);
  /* init Tx buffer DMA addresses */
  for(i = 0; i < NUM_TX_DESC; i++)
    RTL_W32_F(TxAddr0 + (i * 4), rtl_8139_tp->tx_bufs_dma + (rtl_8139_tp->tx_buf[i] - rtl_8139_tp->tx_bufs));
  RTL_W32_F(RxMissed, 0);
  /* Set rx mode */
  rx_mode = AcceptBroadcast | AcceptMyPhys | AcceptAllPhys;
  /* We can safely update without stopping the chip. */
  RTL_W32_F(RxConfig, rtl8139_rx_config | rx_mode | (RTL_R32(RxConfig) & rtl_chip_info[rtl_8139_tp->chipset].RxConfigMask));
  /* no early-rx interrupts */
  RTL_W16(MultiIntr, RTL_R16(MultiIntr) & MultiIntrClear);
  /* make sure RxTx has started */
  RTL_W8_F(ChipCmd, (RTL_R8(ChipCmd) & ChipCmdClear) | CmdRxEnb | CmdTxEnb);
  /* Enable all known interrupts by setting the interrupt mask. */
  RTL_W16_F(IntrMask, rtl8139_intr_mask);
  rtl_8139_tp->trans_start = jiffies;
}

static void rtl8129_tx_timeout(struct rtl8139_private *rtl_8139_tp)
{
  void *ioaddr = rtl_8139_tp->mmio_addr;
  /* Disable interrupts by clearing the interrupt mask. */
  RTL_W16(IntrMask, 0x0000);
  rtl_8139_tp->dirty_tx = rtl_8139_tp->cur_tx = 0;
  rtl8139_hw_start(rtl_8139_tp);
}

static int rtl8139_send_packet(const char *buffer, size_t size)
{
  void *ioaddr = rtl_8139_tp.mmio_addr;
  unsigned char *buff;
  int entry;
  if((rtl_8139_tp.cur_tx - rtl_8139_tp.dirty_tx) >= NUM_TX_DESC)
  {
    if((jiffies - rtl_8139_tp.trans_start) > TX_TIMEOUT)
      rtl8129_tx_timeout(&rtl_8139_tp); /* timeout */
    else
      return(0);
  }
  vPortEnterCritical();
  if((rtl_8139_tp.ctpci_dma_lock != NULL) && rtl_8139_tp.ctpci_dma_lock(1))
  {
    vPortExitCritical();
    return(0);
  }
  /* Calculate the next Tx descriptor entry. */
  entry = rtl_8139_tp.cur_tx % NUM_TX_DESC;
  buff = rtl_8139_tp.tx_buf[entry];
  if(buff != NULL)
    memcpy(buff, buffer, size);
  RTL_W32(TxAddr0 + (entry * 4), rtl_8139_tp.tx_buf[entry]);
  rtl_8139_tp.cur_tx++;                                                                                
  /* Note: the chip doesn't have auto-pad! */
  RTL_W32(TxStatus0 + (entry * sizeof(unsigned long)), rtl_8139_tp.tx_flag | (size >= ETH_ZLEN ? size : ETH_ZLEN));
  rtl_8139_tp.trans_start = jiffies;
  if(rtl_8139_tp.ctpci_dma_lock != NULL)
    rtl_8139_tp.ctpci_dma_lock(0);
  vPortExitCritical();
  return(size);                                                                                        
}

unsigned long rtl8139_read_timer(void)
{
  void *ioaddr = rtl_8139_tp.mmio_addr;
  return(RTL_R32(Timer));
}

#ifndef PCI_XBIOS
static COOKIE *get_cookie(long id)
{
  COOKIE *p= *(COOKIE **)0x5a0;
  while(p)
  {
    if(p->ident == id)
      return(p);
    if(!p->ident)
      return((COOKIE *)0);
    p++;
  }
  return((COOKIE *)0);
}
#endif

err_t rtl8139_eth_start(long handle, const struct pci_device_id *ent)
{
  unsigned long pio_start = 0, pio_len = 0;
  unsigned long pio_base_addr = 0xFFFFFFFF;
  unsigned long mmio_start = 0, mmio_len = 0, dma_offset = 0;
  unsigned long mmio_base_addr = 0xFFFFFFFF;
  PCI_RSC_DESC *pci_rsc_desc;
  unsigned char tmp8;
  int i, option, addr_len;
  static int board_idx = 0;
  unsigned long tmp;
  void *ioaddr = NULL;
#ifdef PCI_XBIOS
  pci_rsc_desc = (PCI_RSC_DESC *)get_resource(handle);
#else
  COOKIE *p = get_cookie('_PCI'); 
  PCI_COOKIE *bios_cookie = (PCI_COOKIE *)p->v.l;
  if(bios_cookie == NULL)   /* faster than XBIOS calls */
    return(-1);  
  tab_funcs_pci = &bios_cookie->routine[0];
  pci_rsc_desc = (PCI_RSC_DESC *)Get_resource(handle);
#endif
  if((long)pci_rsc_desc >= 0)
  {
    unsigned short flags;
    do
    {
//      board_printf("RTL8139: PCI descriptors: flags 0x%04x start 0x%08lx \r\n offset 0x%08lx dmaoffset 0x%08lx length 0x%08lx",
//       pci_rsc_desc->flags, pci_rsc_desc->start, pci_rsc_desc->offset, pci_rsc_desc->dmaoffset, pci_rsc_desc->length);
      if(!(pci_rsc_desc->flags & FLG_IO))
      {
        if(mmio_base_addr == 0xFFFFFFFF)
        {
          mmio_base_addr = pci_rsc_desc->start;
          mmio_start = pci_rsc_desc->offset + pci_rsc_desc->start;
          mmio_len = pci_rsc_desc->length;
          dma_offset = pci_rsc_desc->dmaoffset;
        }
      }
      else
      {
        if(pio_base_addr == 0xFFFFFFFF)
        {
          pio_base_addr = pci_rsc_desc->start;
          pio_start = pci_rsc_desc->offset + pci_rsc_desc->start;
          pio_len = pci_rsc_desc->length;
        }
      }
      flags = pci_rsc_desc->flags;
      pci_rsc_desc = (PCI_RSC_DESC *)((unsigned long)pci_rsc_desc->next + (unsigned long)pci_rsc_desc);
    }
    while(!(flags & FLG_LAST));
  }
  if((pio_base_addr == 0xFFFFFFFF) || (mmio_base_addr == 0xFFFFFFFF))
    return(-1);
  ioaddr = (void *)mmio_start;
  memset(&rtl_8139_tp, 0, sizeof(struct rtl8139_private));
  rtl_8139_tp.handle = handle;
  rtl_8139_tp.mmio_len = mmio_len;
  /* set this immediately, we need to know before we talk to the chip directly */
  if(pio_len == RTL8139B_IO_SIZE)
    rtl_8139_tp.chipset = CH_8139B;
  /* check for weird/broken PCI region reporting */
  if((pio_len < RTL_MIN_IO_SIZE) || (mmio_len < RTL_MIN_IO_SIZE))
  {
    board_printf("RTL8139: Invalid PCI region size(s), aborting\r\n");
    return(-1);
  }
  nbuf_init();
#ifdef USE_RX_BUFFERS
  rtl8139_initialize_rx_buffer(&rtl_8139_tp);
#endif
  tmp = dma_lock(-1); /* CTPCI */
  if((tmp == 0) || (tmp == 1))
    rtl_8139_tp.ctpci_dma_lock = (void *)dma_lock(-2); /* function exist */
  /* Soft reset the chip. */
  RTL_W8(ChipCmd, (RTL_R8(ChipCmd) & ChipCmdClear) | CmdReset);
  /* Check that the chip has finished the reset. */
  for(i = 1000; i > 0; i--)
  {
    if((RTL_R8(ChipCmd) & CmdReset) == 0)
      break;
    else
      udelay(10);
  }
  /* Bring the chip out of low-power mode. */
  if(rtl_8139_tp.chipset == CH_8139B)
  {
    RTL_W8(Config1, RTL_R8(Config1) & ~(1<<4));
    RTL_W8(Config4, RTL_R8(Config4) & ~(1<<2));
  }
  else
  {
    /* handle RTL8139A and RTL8139 cases */
    /* XXX from becker driver. is this right?? */
    RTL_W8(Config1, 0);
  }
  /* make sure chip thinks PIO and MMIO are enabled */
  tmp8 = RTL_R8(Config1);
  if((tmp8 & Cfg1_PIO) == 0)
  {
    board_printf("RTL8139: PIO not enabled, Cfg1=%02X, aborting\r\n", tmp8);
    return(-1);
  }
  if((tmp8 & Cfg1_MMIO) == 0)
  {
    board_printf("RTL8139: MMIO not enabled, Cfg1=%02X, aborting\r\n", tmp8);
    return(-1);
  }
  /* identify chip attached to board */
  /* tmp = RTL_R8(ChipVersion); */
  tmp = RTL_R32(TxConfig);
  tmp = ((tmp & 0x7c000000) + ((tmp & 0x00800000) << 2)) >>24;
  rtl_8139_tp.drv_flags = board_info[0].hw_flags;
  rtl_8139_tp.mmio_addr = ioaddr;
  for(i = ARRAY_SIZE(rtl_chip_info) - 1; i >= 0; i--)
  {
    if(tmp == rtl_chip_info[i].version)
       rtl_8139_tp.chipset = i;
  }
  if(rtl_8139_tp.chipset > (ARRAY_SIZE(rtl_chip_info) - 2))
    rtl_8139_tp.chipset = ARRAY_SIZE(rtl_chip_info) - 2;
  /* Find the connected MII xcvrs. */
  if(rtl_8139_tp.drv_flags & HAS_MII_XCVR)
  {
    int phy, phy_idx = 0;
    for(phy = 0; phy < 32 && phy_idx < sizeof(rtl_8139_tp.phys); phy++)
    {
      int mii_status = rtl8139_mdio_read(&rtl_8139_tp, phy, 1);
      if(mii_status != 0xffff && mii_status != 0x0000)
      {
        rtl_8139_tp.phys[phy_idx++] = phy;
        rtl_8139_tp.advertising = rtl8139_mdio_read(&rtl_8139_tp, phy, 4);
        board_printf("RTL8139: MII transceiver %d status 0x%4.4x advertising %4.4x.\r\n", phy, mii_status, rtl_8139_tp.advertising);
      }
    }
    if(phy_idx == 0)
    {
      board_printf("RTL8139: No MII transceivers found!  Assuming SYM transceiver.\r\n");
      rtl_8139_tp.phys[0] = 32;
    }
  }
  else
    rtl_8139_tp.phys[0] = 32;
  /* Put the chip into low-power mode. */
  RTL_W8_F(Cfg9346, Cfg9346_Unlock);
  tmp = RTL_R8(Config1) & Config1Clear;
  tmp |= (rtl_8139_tp.chipset == CH_8139B) ? 3 : 1; /* Enable PM/VPD */
  RTL_W8_F(Config1, tmp);
  RTL_W8_F(HltClk, 'H'); /* 'R' would leave the clock running. */
  /* The lower four bits are the media type. */
  option = (board_idx >= MAX_UNITS) ? 0 : media[board_idx];
  rtl_8139_tp.AutoNegoAbility = option&0xF;
  if(option > 0)
  {
    rtl_8139_tp.full_duplex = (option & 0x210) ? 1 : 0;
    rtl_8139_tp.default_port = option & 0xFF;
    if(rtl_8139_tp.default_port)
      rtl_8139_tp.medialock = 1;
  }
  if(board_idx < MAX_UNITS  &&  full_duplex[board_idx] > 0)
      rtl_8139_tp.full_duplex = full_duplex[board_idx];
  if(rtl_8139_tp.full_duplex)
  {
    board_printf("RTL8139: Media type forced to Full Duplex.\r\n");
    /* Changing the MII-advertised media because might prevent  re-connection. */
    rtl_8139_tp.duplex_lock = 1;
  }
  if(rtl_8139_tp.default_port)
  {
    board_printf("RTL8139: Forcing %dMbs %s-duplex operation.\r\n", (option & 0x0C ? 100 : 10), (option & 0x0A ? "full" : "half"));
    rtl8139_mdio_write(&rtl_8139_tp, rtl_8139_tp.phys[0], 0, ((option & 0x20) ? 0x2000 : 0) | /* 100mbps? */ ((option & 0x10) ? 0x0100 : 0)); /* Full duplex? */
  }
  addr_len = rtl8139_read_eeprom(ioaddr, 0, 8) == 0x8129 ? 8 : 6;
  for(i = 0; i < 3; ((unsigned short *)(rtl_8139_tp.dev_addr))[i] = le16_to_cpu(rtl8139_read_eeprom(ioaddr, i + 7, addr_len)), i++);
  board_printf("RTL8139: %s at 0x%lx, %2.2x:%2.2x:%2.2x:%2.2x:%2.2x:%2.2x\r\n", board_info[0].name, rtl_8139_tp.mmio_addr,
   rtl_8139_tp.dev_addr[0], rtl_8139_tp.dev_addr[1], rtl_8139_tp.dev_addr[2], rtl_8139_tp.dev_addr[3], rtl_8139_tp.dev_addr[4], rtl_8139_tp.dev_addr[5]);
#ifdef PCI_XBIOS
  hook_interrupt(handle, rtl8139_interrupt, &rtl_8139_tp);
#else
  Hook_interrupt(handle, (void *)rtl8139_interrupt, (unsigned long *)&rtl_8139_tp);
#endif /* PCI_BIOS */
  rtl_8139_tp.must_free_irq = 1;
  rtl_8139_tp.tx_bufs = nbuf_alloc(TX_BUF_TOT_LEN);
  rtl_8139_tp.rx_ring = nbuf_alloc(RX_BUF_TOT_LEN);
  if((rtl_8139_tp.tx_bufs == NULL) || (rtl_8139_tp.rx_ring == NULL))
  {
#ifdef PCI_XBIOS
    unhook_interrupt(handle);
#else              
    Unhook_interrupt(handle);
#endif /* PCI_BIOS */
    if(rtl_8139_tp.tx_bufs)
      nbuf_free(rtl_8139_tp.tx_bufs);
    if(rtl_8139_tp.rx_ring)
      nbuf_free(rtl_8139_tp.rx_ring);
    board_printf("RTL8139: EXIT, out of memory\r\n");
    return(-1);
  }
  /* board_printf("RTL8139: TX buffers at %#lx, RX buffers at %#lx, DMA offset %#lx\r\n", rtl_8139_tp.tx_bufs, rtl_8139_tp.rx_ring, dma_offset); */
  rtl_8139_tp.tx_bufs_dma = (unsigned long)rtl_8139_tp.tx_bufs - dma_offset; 
  rtl_8139_tp.rx_ring_dma = (unsigned long)rtl_8139_tp.rx_ring - dma_offset;
  rtl_8139_tp.full_duplex = rtl_8139_tp.duplex_lock;
  rtl_8139_tp.tx_flag = (TX_FIFO_THRESH << 11) & 0x003f0000;
  rtl_8139_tp.twistie = 1;
/* Initialize the Rx and Tx rings */
  rtl_8139_tp.cur_rx = 0;
  rtl_8139_tp.cur_tx = 0;
  rtl_8139_tp.dirty_tx = 0;
  for(i = 0; i < NUM_TX_DESC; i++)
    rtl_8139_tp.tx_buf[i] = &rtl_8139_tp.tx_bufs[i * TX_BUF_SIZE];
  rtl8139_hw_start(&rtl_8139_tp);     
  board_printf("RTL8139: ioaddr %#lx handle %#lx %s-duplex.\r\n", mmio_start, handle, rtl_8139_tp.full_duplex ? "full" : "half");
  rtl8139_opened = 1;
  return(0);
}

void rtl8139_eth_stop(void)
{
  void *ioaddr = rtl_8139_tp.mmio_addr;
  vPortEnterCritical();
  /* Stop the chip's Tx and Rx DMA processes. */
  RTL_W8(ChipCmd, (RTL_R8(ChipCmd) & ChipCmdClear));
  /* Disable interrupts by clearing the interrupt mask. */
  RTL_W16(IntrMask, 0x0000);
  RTL_W32(RxMissed, 0);
  if(rtl_8139_tp.must_free_irq)
  { 
#ifdef PCI_XBIOS
    unhook_interrupt(rtl_8139_tp.handle);
#else              
    Unhook_interrupt(rtl_8139_tp.handle);
#endif /* PCI_BIOS */
    rtl_8139_tp.must_free_irq = 0;
  }
  rtl_8139_tp.cur_tx = 0;
  rtl_8139_tp.dirty_tx = 0;
  if(rtl_8139_tp.rx_ring != NULL)
  {
    nbuf_free(rtl_8139_tp.rx_ring);
    rtl_8139_tp.rx_ring = NULL;
  }
  if(rtl_8139_tp.tx_bufs != NULL)
  {
    nbuf_free(rtl_8139_tp.tx_bufs);
    rtl_8139_tp.tx_bufs = NULL;
  }
  /* Green! Put the chip in low-power mode. */
  RTL_W8(Cfg9346, Cfg9346_Unlock);
  RTL_W8(Config1, 0x03);
  RTL_W8(HltClk, 'H');   /* 'R' would leave the clock running. */
  vPortExitCritical();
  if(rtl_8139_tp.task != NULL)
  {
    sys_arch_thread_remove(rtl_8139_tp.task);
    rtl_8139_tp.task = NULL;
  }
  if(rtl_8139_tp.tx_sem != NULL)
  {
    vQueueDelete((xQueueHandle)rtl_8139_tp.tx_sem);
    rtl_8139_tp.tx_sem = NULL;
  }
#ifdef USE_RX_BUFFERS
  if(rtl_8139_tp.rx_sem != NULL)
  {
    vQueueDelete((xQueueHandle)rtl_8139_tp.rx_sem);
    rtl_8139_tp.rx_sem = NULL;
  }
  if(rtl8139_opened)
    rtl8139_dealloc_rx_buffer(&rtl_8139_tp);
#else
  if(rtl_8139_tp.rx_queue != NULL)
  {
    vQueueDelete(rtl_8139_tp.rx_queue);
    rtl_8139_tp.rx_queue = NULL;
  }
#endif /* USE_RX_BUFFERS */
  if(rtl_8139_tp.rtl8139if != NULL)
  {
    mem_free(rtl_8139_tp.rtl8139if);
    rtl_8139_tp.rtl8139if = NULL;
  }
  rtl8139_opened = 0;
}

/*-----------------------------------------------------------------------------------*/
/*
 * rtl8139if_low_level_output():
 *
 * Should do the actual transmission of the packet. The packet is
 * contained in the pbuf that is passed to the function. This pbuf
 * might be chained.
 *
 */
/*-----------------------------------------------------------------------------------*/
err_t rtl8139if_low_level_output(struct netif *rtl8139if, struct pbuf *p)
{
  struct pbuf *q;
  static unsigned char buf[PKT_BUF_SZ];
  unsigned char *bufptr;
#if ETH_PAD_SIZE
  pbuf_header(p, -ETH_PAD_SIZE);    /* drop the padding word */
#endif
  while(xSemaphoreAltTake(rtl_8139_tp.tx_sem, portMAX_DELAY) != pdTRUE);
  /* initiate transfer */
  bufptr = buf;  
  for(q = p; q != NULL; q = q->next)
  {
    /* Send the data from the pbuf to the interface, one pbuf at a time. The size of the data in each pbuf is kept in the ->len variable. */
    memcpy(bufptr, q->payload, q->len);
    bufptr += q->len;
  }
  /* signal that packet should be sent */
  while(rtl8139_send_packet((const char *)buf,p->tot_len) == 0);
  xSemaphoreAltGive(rtl_8139_tp.tx_sem);
#if ETH_PAD_SIZE
  pbuf_header(p, ETH_PAD_SIZE);
#endif
  return(ERR_OK);
}

/*-----------------------------------------------------------------------------------*/
/*
 * rtl8139if_input():
 *
 * This function should be called when a packet is ready to be read
 * from the interface. It uses the function rtl8139if_low_level_input() that
 * should handle the actual reception of bytes from the network
 * interface.
 *
 */
/*-----------------------------------------------------------------------------------*/
static void rtl8139if_input(struct netif *netif, struct pbuf *p)
{
  struct eth_hdr *eth_hdr = p->payload;
  LWIP_ASSERT("eth_input: p != NULL ", p != NULL);
  switch(htons(eth_hdr->type))
  {
    case ETHTYPE_IP:
      /* Pass to ARP layer. */
      etharp_ip_input(netif, p);
      /* Skip Ethernet header. */
      pbuf_header(p, (s16_t) - sizeof(struct eth_hdr));
      /* Pass to network layer. */
      netif->input(p, netif);
      break;
    case ETHTYPE_ARP:
      /* Pass to ARP layer. */
      etharp_arp_input(netif, (struct eth_addr *)netif->hwaddr, p);
      break;
    default:
      pbuf_free(p);
      break;
  }
}

/*-----------------------------------------------------------------------------------*/
/*
 * rtl8139_rx_task():
 *
 * Receive Frame interrupt task.
 *
 */
/*-----------------------------------------------------------------------------------*/
static void rtl8139_rx_task(void *arg)
{
  struct rtl8139if *rtl8139if = (struct rtl8139if *)arg;
  struct pbuf *p, *q;
#ifdef USE_RX_BUFFERS
  struct memory receive_buffer;
#else
  unsigned long msg[2];
#endif
  unsigned char *bufptr;
  u16_t len;
  while(1)
  {
    /* Obtain the size of the packet and put it into the "len" variable. */
#ifdef USE_RX_BUFFERS
    while(xSemaphoreAltTake(rtl_8139_tp.rx_sem, portMAX_DELAY) != pdTRUE);
    len = (u16_t)rtl8139_extract_frame_of_buffer(&rtl_8139_tp, &receive_buffer); 
#else
    while(xQueueAltReceive(rtl_8139_tp.rx_queue, &msg, portMAX_DELAY) != pdPASS);
    len = (u16_t)msg[0];
#endif /* USE_RX_BUFFERS */
    /* We allocate a pbuf chain of pbufs from the pool. */
    p = pbuf_alloc(PBUF_LINK, len, PBUF_POOL); 
    if(p != NULL)
    {
#if ETH_PAD_SIZE
      pbuf_header(p, -ETH_PAD_SIZE);
#endif
      /* We iterate over the pbuf chain until we have read the entire packet into the pbuf. */
#ifdef USE_RX_BUFFERS
      bufptr = receive_buffer.mem;
#else
      bufptr = (unsigned char *)msg[1];
#endif /* USE_RX_BUFFERS */
      for(q = p; q != NULL; q = q->next)
      {
        /* Read enough bytes to fill this pbuf in the chain. The avaliable data in the pbuf is given by the q->len variable. */
        memcpy(q->payload, bufptr, q->len);
        bufptr += q->len;
      }
#if ETH_PAD_SIZE
      pbuf_header(p, ETH_PAD_SIZE);
#endif
      /* Ethernet frame received. Handling it is not device dependent and therefore done in another function */
      rtl8139if_input(rtl8139if->netif, p);        
    }
    else
       board_printf("RTL8139: pbuf_alloc out of memory!!!\r\n");  
  }
}
/*-----------------------------------------------------------------------------------*/
/*
 * rtl8139if_output():
 *
 * This function is called by the TCP/IP stack when an IP packet
 * should be sent. It calls the function called rtl8139if_low_level_output() to
 * do the actuall transmission of the packet.
 *
 */
/*-----------------------------------------------------------------------------------*/
static err_t rtl8139if_output(struct netif *netif, struct pbuf *p, struct ip_addr *ipaddr)
{
  return(etharp_output(netif, ipaddr, p));
}

/*-----------------------------------------------------------------------------------*/
void rtl8139_ifetharp_timer(int signo)
{
  etharp_tmr();
  sys_timeout(ARP_TMR_INTERVAL, (sys_timeout_handler)rtl8139_ifetharp_timer, NULL);
}

/*-----------------------------------------------------------------------------------*/
/*
 * rtl8139if_init():
 *
 * Should be called at the beginning of the program to set up the
 * network interface. It calls the function rtl8139if_low_level_init() to do the
 * actual setup of the hardware.
 *
 */
/*-----------------------------------------------------------------------------------*/
err_t rtl8139if_init(struct netif *netif)
{
  struct rtl8139if *rtl8139if;
  if(!rtl8139_opened) /* rtl8139_eth_start called before by the PCI scan */
    return(ERR_MEM);
  rtl_8139_tp.rtl8139if = rtl8139if = mem_malloc(sizeof(struct rtl8139if));
  if(rtl8139if == NULL)
  {
    rtl8139_eth_stop();
    return(ERR_MEM);
  }
  rtl8139if->netif = netif;
  netif->state = rtl8139if;
  netif->name[0] = 'e';
  netif->name[1] = 'n';
  netif->hwaddr_len = ETH_ADDR_LEN;
  netif->mtu = RTL_MTU;
  netif->flags = NETIF_FLAG_BROADCAST;
  netif->output = rtl8139if_output;
  netif->linkoutput = rtl8139if_low_level_output;
  rtl8139if->ethaddr = (struct eth_addr *)&(netif->hwaddr[0]);
  netif->hwaddr_len = 6;
  /* Obtain MAC address from network interface. */
  rtl8139_obtain_mac_address(rtl8139if->ethaddr->addr);
  /* We set an IP filter to the ethernet card */
  rtl8139_set_ip_filter(netif->ip_addr.addr);
//  board_printf("RTL8139: MAC %x:%x:%x:%x:%x:%x \r\n",rtl8139if->ethaddr->addr[0],rtl8139if->ethaddr->addr[1],rtl8139if->ethaddr->addr[2],rtl8139if->ethaddr->addr[3],rtl8139if->ethaddr->addr[4],rtl8139if->ethaddr->addr[5]);
  /* Create RX semaphore */
  vSemaphoreCreateBinary(rtl_8139_tp.tx_sem);
#ifdef USE_RX_BUFFERS
  /* Create RX semaphore */
  vSemaphoreCreateBinary(rtl_8139_tp.rx_sem);
  if((rtl_8139_tp.tx_sem != NULL) && (rtl_8139_tp.rx_sem != NULL))
  {
    xSemaphoreAltTake(rtl_8139_tp.rx_sem, 1);
#else
  if((rtl_8139_tp.tx_sem != NULL) && (rtl_8139_tp.rx_queue = xQueueCreate(64, sizeof(unsigned long) * 2)) != NULL)
  {
#endif /* USE_RX_BUFFERS */
    rtl_8139_tp.task = sys_thread_new(rtl8139_rx_task, rtl8139if, TASK_PRIORITY);
    if(rtl_8139_tp.task == NULL)
    {
      rtl8139_eth_stop();
      return(ERR_MEM);
    }    
  }
  else
  {
    rtl8139_eth_stop();
    return(ERR_MEM);
  }
  etharp_init();
  sys_timeout(ARP_TMR_INTERVAL, (sys_timeout_handler)rtl8139_ifetharp_timer, NULL);
  rtl8139_opened = 2;
  return(ERR_OK);
}

/*-----------------------------------------------------------------------------------*/
void rtl8139if_close(void)
{
  /* Closing the RTL8139 card */
  rtl8139_eth_stop();
}

#endif /* defined(LWIP) && defined(FREERTOS) */

