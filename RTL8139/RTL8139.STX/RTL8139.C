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

#include <tos.h>
#define _hz_200 ((unsigned long *)0x4BA)
#include <ext.h>
#include <stdio.h>
#include <string.h>

#include "pcixbios.h"

#include "transprt.h"
#include "port.h"
#include "uti.h"

#include "rtl8139.h"

#undef POLLING

/* ------------------------ Defines --------------------------------------- */
#define ARRAY_SIZE(arr) (sizeof(arr) / sizeof(arr[0]))
#define memtop (*(long *)0x42E)

struct eth_addr
{
  unsigned char addr[6];
};

struct eth_hdr
{
  struct eth_addr dest;
  struct eth_addr src;
#define ETHTYPE_ARP 0x0806
#define ETHTYPE_IP  0x0800
  unsigned short type;
};

/* Forward declarations. */
/* static void rtl8139if_input(struct netif *netif, struct pbuf *p); */
/* static err_t rtl8139if_output(struct netif *netif, struct pbuf *p, struct ip_addr *ipaddr); */

static unsigned int rtl8139_read_eeprom(void *ioaddr, int location, int addr_len);
static int rtl8139_mdio_read(struct rtl8139_private *rtl_8139, int phy_id, int location);
static void rtl8139_mdio_write(struct rtl8139_private *rtl_8139, int phy_id, int location, int val);

/* Maximum events (Rx packets, etc.) to handle at each interrupt. */
static int rtl8139_max_interrupt_work = 10;
unsigned char rtl8139_ip_addr[2][4] = {{0x00,0x00,0x00,0x00},{0x00,0x00,0x00,0x00}};
static int trash = 0;     
static int use_dma_alloc = 0;                
static int rtl8139_n_filters = 0;
unsigned char rtl8139_opened = 0;
unsigned char sting_opened = 0;
struct rtl8139_private rtl_8139_tp;

/* Sting */
extern long process_arp(unsigned char *arp, short length);
extern PORT	my_port;

static void *nbuf_alloc(long size)
{
  void *ret;
  if(use_dma_alloc)
  {
    ret = (void *)dma_alloc(size);
    if((long)ret >= memtop)
      return(ret);
    else
      use_dma_alloc = 0;
  }
  return((void *)Mxalloc(size, 0)); /* ST-RAM cache WT */
}

static void nbuf_free(void *addr)
{
  if(use_dma_alloc)
    dma_free(addr);
  Mfree(addr);
}

int rtl8139_set_ip_filter(long ipaddr)
{
  if(rtl8139_n_filters <= 1)
  {
    rtl8139_ip_addr[rtl8139_n_filters][3] = ipaddr & 0x000000ffUL;
    rtl8139_ip_addr[rtl8139_n_filters][2] = (ipaddr >> 8) & 0x000000ffUL;
    rtl8139_ip_addr[rtl8139_n_filters][1] = (ipaddr >> 16) & 0x000000ffUL;
    rtl8139_ip_addr[rtl8139_n_filters][0] = (ipaddr >> 24) & 0x000000ffUL;
    rtl8139_n_filters++;
    return(0);
  }
  printf("RTL8139: You cannot set more than 2 IP filters !!");
  return(-1);
}

/* The data sheet doesn't describe the Rx ring at all, so I'm guessing at the field alignments and semantics. */
static void rtl8139_rx_interrupt(struct rtl8139_private *rtl_8139_tp)
{
  unsigned char *rx_ring;
  unsigned long cur_rx;
  unsigned char mine = 1, multicast_packet= 1, arp_request_for_me = 1;
  void *ioaddr = rtl_8139_tp->mmio_addr;
  int i, j;
  rx_ring = rtl_8139_tp->rx_ring;
  cur_rx = rtl_8139_tp->cur_rx;
  while((RTL_R8(ChipCmd) & RxBufEmpty) == 0)
  {
    unsigned long ring_offset = cur_rx % RX_BUF_LEN;
    unsigned long rx_status, rx_size, pkt_size;
    unsigned char *skb;
    /* read size+status of next frame from DMA ring buffer */
    rx_status = le32_to_cpu(*(unsigned long *)(rx_ring + ring_offset));
    rx_size = rx_status >> 16;
    pkt_size = rx_size - 4;
    if(rx_size == 0xfff0UL)
      break;
    if((rx_size > (MAX_ETH_FRAME_SIZE+4)) || (!(rx_status & RxStatusOK)))
      return;
    rtl_8139_tp->stats.rx_packets++;
    skb = &rx_ring[ring_offset+4]; 
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
    if((mine || (multicast_packet && arp_request_for_me)) && sting_opened)
    { 
      struct eth_hdr *eth_hdr = (struct eth_hdr *)skb;
      IP_DGRAM *new_dgram, *dgram;
      unsigned long bytes;
      rtl_8139_tp->rx_frames_for_us++;
      switch(eth_hdr->type)
      {
        case ETHTYPE_IP:
          if((pkt_size > ETH_HDR_LEN) && ((new_dgram = KRmalloc(sizeof(IP_DGRAM))) != NULL))
          {
            pkt_size -= ETH_HDR_LEN;
            memcpy(&new_dgram->hdr, &skb[ETH_HDR_LEN], sizeof(IP_HDR));
            bytes = (new_dgram->hdr.hd_len) << 2;
            if((pkt_size >= new_dgram->hdr.length) && (bytes < new_dgram->hdr.length)
             && (bytes >= sizeof(IP_HDR)) && (bytes < pkt_size))
            {
              new_dgram->options = NULL; /* preset NULL pointer to options data */
              new_dgram->opt_length = (unsigned short)(bytes - sizeof(IP_HDR)); /* options length in bytes */
              if(new_dgram->opt_length) 
              {
                if((new_dgram->options = KRmalloc((unsigned long)new_dgram->opt_length)) == NULL)
                {
                  KRfree(new_dgram);
                  my_port.stat_dropped++;
                  break;
                }
                memcpy(new_dgram->options, &skb[ETH_HDR_LEN + sizeof(IP_HDR)], (unsigned long)new_dgram->opt_length);
              }
              new_dgram->pkt_length = new_dgram->hdr.length - (unsigned short)bytes;
              if((new_dgram->pkt_data = KRmalloc(((unsigned long)new_dgram->pkt_length + 1) & ~1)) == NULL) /* round up to even */
              {
                if(new_dgram->options != NULL)
                   KRfree(new_dgram->options);
                KRfree(new_dgram);
                my_port.stat_dropped++;
                break;
              }
              memcpy(new_dgram->pkt_data, &skb[ETH_HDR_LEN + sizeof(IP_HDR) + new_dgram->opt_length], ((unsigned long)new_dgram->pkt_length + 1) & ~1);
              new_dgram->recvd = &my_port;
              new_dgram->next = NULL; /* nothing hanging */
              /* append new dgram at the end of the dgram queue hanging from my_port.receive */
              if(my_port.receive == NULL)
                my_port.receive = new_dgram;
              else
              {
                dgram = my_port.receive;
              	while(dgram->next != NULL)
              	  dgram = dgram->next;
                dgram->next = new_dgram;
              }
              my_port.stat_rcv_data += (unsigned long)pkt_size;
            }
            break;
          }
          my_port.stat_dropped++;
          break;
        case ETHTYPE_ARP:
          if(pkt_size > ETH_HDR_LEN)
		    process_arp(&skb[ETH_HDR_LEN], (short)(pkt_size - ETH_HDR_LEN));
          break;
        default:
          break;
      }
    }
    cur_rx = (cur_rx + rx_size + 4 + 3) & ~3;
    RTL_W16_F(RxBufPtr, (unsigned short)cur_rx - 16);
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
  while((long)tx_left > 0)
  {
    unsigned long entry = dirty_tx % NUM_TX_DESC;
    unsigned long txstatus = RTL_R32(TxStatus0 + (entry * sizeof(unsigned long))); 
    if(!(txstatus & (TxStatOK | TxUnderrun | TxAborted)))
      break;  /* It still hasn't been Txed */
    /* Note: TxCarrierLost is always asserted at 100mbps. */
    if(txstatus & (TxOutOfWindow | TxAborted))
    {
      /* There was an major error, log it. */
/*     printf("RTL8139: Transmit error, Tx status %8.8x.\r\n", txstatus); */
      rtl_8139_tp->stats.tx_errors++;
      if(txstatus & TxAborted)
      {
        rtl_8139_tp->stats.tx_aborted_errors++;
        RTL_W32(TxConfig, TxClearAbt | (TX_DMA_BURST << TxDMAShift));
      }
      if(txstatus & TxCarrierLost)
        rtl_8139_tp->stats.tx_carrier_errors++;
      if(txstatus & TxOutOfWindow)
        rtl_8139_tp->stats.tx_window_errors++;
    }
    else
    {
      if(txstatus & TxUnderrun)
      {
        /* Add 64 to the Tx FIFO threshold. */
        if(rtl_8139_tp->tx_flag < 0x00300000UL)
          rtl_8139_tp->tx_flag += 0x00020000UL;
        rtl_8139_tp->stats.tx_fifo_errors++;
      }
      rtl_8139_tp->stats.collisions += (txstatus >> 24) & 15;
      rtl_8139_tp->stats.tx_packets++;
    }
    dirty_tx++;
    tx_left--;
  }
#ifdef RTL8139_DEBUG
  if(rtl_8139_tp->cur_tx - dirty_tx > NUM_TX_DESC)
  {
/*    printf("RTL8139: Out-of-sync dirty pointer, %ld vs. %ld.\r\n", dirty_tx, rtl_8139_tp->cur_tx); */
    dirty_tx += NUM_TX_DESC;
  }
#endif /* RTL8139_DEBUG */
  /* only wake the queue if we did work, and the queue is stopped */
  if(rtl_8139_tp->dirty_tx != dirty_tx)
    rtl_8139_tp->dirty_tx = dirty_tx;
}                                            

/* The interrupt handler does all of the Rx thread work and cleans up after the Tx thread. */
int cdecl rtl8139_interrupt(struct rtl8139_private *rtl_8139_tp)
{
  int boguscnt = rtl8139_max_interrupt_work; 
  unsigned short status = 0, link_changed = 0; /* avoid bogus "uninit" warning */
  void *ioaddr = rtl_8139_tp->mmio_addr;
  int i;
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
    else
      udelay(100); /* try to fix CTPCI freezes */
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
      link_changed = RTL_R16(CSCR) & CSCR_LinkChangeBit;
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
  if(boguscnt <= 0)
  {
/*    printf("RTL8139: Too much work at interrupt, IntrStatus=0x%4.4x.\r\n", status); */
    /* Clear all interrupt sources. */
    RTL_W16(IntrStatus, 0xffff);
  }
  if((status != 0xFFFF) && (status & PCIErr))
  {
    short sr = fast_read_config_word(rtl_8139_tp->handle, PCISR);
    write_config_word(rtl_8139_tp->handle, PCISR, sr);
    printf("RTL8139: PCI ERROR SR %#04x\r\n", sr);
  }
  if(link_changed);
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
  long mii_cmd = (0xf6 << 10) | ((long)phy_id << 5) | (long)location;
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
     retval = (retval << 1) | ((readb(mdio_addr) & MDIO_DATA_IN) ? 1 : 0);
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

static unsigned int rtl8139_read_eeprom(void *ioaddr, int location, int addr_len)
{
  int i;
  unsigned int retval = 0;
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
  int i;
  unsigned char tmp;
  unsigned long rx_mode;
  /* Soft reset the chip. */
  RTL_W8(ChipCmd, (RTL_R8(ChipCmd) & ChipCmdClear) | CmdReset);
  delay(100);
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
    printf("RTL8139: Setting %s%s-duplex based on auto-negotiated partner ability %4.4x.\r\n", mii_reg5 == 0 ? "" :
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
  delay(10);
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
#ifdef POLLING
  RTL_W16(IntrMask, 0x0000);
#else
  /* Enable all known interrupts by setting the interrupt mask. */
  RTL_W16_F(IntrMask, rtl8139_intr_mask);
#endif
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

static int rtl8139_send_packet(const char *buffer, size_t size, const char *buffer2, size_t size2)
{
  void *ioaddr = rtl_8139_tp.mmio_addr;
  unsigned char *buff;
  int entry, level;
  if((rtl_8139_tp.cur_tx - rtl_8139_tp.dirty_tx) >= NUM_TX_DESC)
  {
    if((jiffies - rtl_8139_tp.trans_start) > TX_TIMEOUT)
      rtl8129_tx_timeout(&rtl_8139_tp); /* timeout */
    else
      return(0);
  }
  level = splx(7); /* mask interrupts */
  if((rtl_8139_tp.ctpci_dma_lock != NULL) && rtl_8139_tp.ctpci_dma_lock(1))
  {
    splx(level); /* restore interrupts */
    return(0);
  }
  /* Calculate the next Tx descriptor entry. */
  entry = rtl_8139_tp.cur_tx % NUM_TX_DESC;
  buff = rtl_8139_tp.tx_buf[entry];
  if(buff != NULL)
  {
    memcpy(buff, buffer, size);
    if((buffer2 != NULL) && size2)
    {
      memcpy(&buff[size], buffer2, size2);
      size += size2;
    }
  }
  RTL_W32(TxAddr0 + (entry * 4), rtl_8139_tp.tx_buf[entry]);
  rtl_8139_tp.cur_tx++;                                                                                
  /* Note: the chip doesn't have auto-pad! */
  RTL_W32(TxStatus0 + (entry * sizeof(unsigned long)), rtl_8139_tp.tx_flag | (size >= ETH_ZLEN ? size : ETH_ZLEN));
  rtl_8139_tp.trans_start = jiffies;
  if(rtl_8139_tp.ctpci_dma_lock != NULL)
    rtl_8139_tp.ctpci_dma_lock(0);
  splx(level); /* restore interrupts */
  return(size);                                                                                        
}

int rtl8139_eth_start(void)
{
  unsigned long pio_start = 0, pio_len = 0;
  unsigned long pio_base_addr = 0xFFFFFFFFUL;
  unsigned long mmio_start = 0, mmio_len = 0;
  unsigned long mmio_base_addr = 0xFFFFFFFFUL;
  unsigned long dma_start = 0, dma_len = 0, dma_offset = 0;
  unsigned long dma_base_addr = 0xFFFFFFFFUL;
  PCI_RSC_DESC *pci_rsc_desc;
  unsigned char tmp8;
  int i, option, addr_len;
  short index = 0;
  long handle, handle_bridge = -1, err;
  static int board_idx = 0;
  unsigned long tmp, id;
  void *ioaddr = NULL;
  do
  {
    handle = find_pci_device(0x0000FFFFL, index++);
    if(handle >= 0)
    {
      err = read_config_longword(handle, PCIIDR, &id);
      if((err >= 0) && ((id & 0xFFFFUL) == 0x10B5) && ((id >> 16) == 0x9054)) /* bridge PLX 9054 CTPCI */
        handle_bridge = handle;
      if((err >= 0) && ((id & 0xFFFFUL) == RTL8139_VENDOR_ID) && ((id >> 16) == RTL8139_DEVICE_ID))
        break;
    }
  }
  while(handle >= 0);
  if(handle < 0)
    return(-1);
  printf("\r\n");
  if(handle_bridge >= 0)
  {
    pci_rsc_desc = (PCI_RSC_DESC *)get_resource(handle_bridge);
    if((long)pci_rsc_desc >= 0)
    {
      unsigned short flags;
      do
      {
        if(!(pci_rsc_desc->flags & FLG_IO))
        {
          if(dma_base_addr == 0xFFFFFFFFUL)
          {
            dma_base_addr = pci_rsc_desc->start;
            dma_start = pci_rsc_desc->offset + pci_rsc_desc->start;
            dma_len = pci_rsc_desc->length;
            if(!((dma_start == 0) && (memtop < (dma_start+dma_len))))
              use_dma_alloc = 1;
/*            printf("RTL8139: PCI BRIDGE DMA start %#lx length %#lx\r\n", dma_start, dma_len); */
          }
        }
        flags = pci_rsc_desc->flags;
        pci_rsc_desc = (PCI_RSC_DESC *)((unsigned long)pci_rsc_desc->next + (unsigned long)pci_rsc_desc);
      }
      while(!(flags & FLG_LAST));
    }
  }
  pci_rsc_desc = (PCI_RSC_DESC *)get_resource(handle);
  if((long)pci_rsc_desc >= 0)
  {
    unsigned short flags;
    do
    {
/*      printf("PCI RTL8139 descriptors: flags %#x start %#lx \r\n offset %#lx dmaoffset %#lx length %#lx",
       pci_rsc_desc->flags, pci_rsc_desc->start, pci_rsc_desc->offset, pci_rsc_desc->dmaoffset, pci_rsc_desc->length); */
      if(!(pci_rsc_desc->flags & FLG_IO))
      {
        if(mmio_base_addr == 0xFFFFFFFFUL)
        {
          mmio_base_addr = pci_rsc_desc->start;
          mmio_start = pci_rsc_desc->offset + pci_rsc_desc->start;
          mmio_len = pci_rsc_desc->length;
          dma_offset = pci_rsc_desc->dmaoffset;
        }
      }
      else
      {
        if(pio_base_addr == 0xFFFFFFFFUL)
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
  if((pio_base_addr == 0xFFFFFFFFUL) || (mmio_base_addr == 0xFFFFFFFFUL))
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
    printf("RTL8139: Invalid PCI region size(s), aborting\r\n");
    return(-1);
  }
  err = dma_lock(-1); /* CTPCI */
  if((err == 0) || (err == 1))
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
    printf("RTL8139: PIO not enabled, Cfg1=%02X, aborting\r\n", tmp8);
    return(-1);
  }
  if((tmp8 & Cfg1_MMIO) == 0)
  {
    printf("RTL8139: MMIO not enabled, Cfg1=%02X, aborting\r\n", tmp8);
    return(-1);
  }
  /* identify chip attached to board */
  /* tmp = RTL_R8(ChipVersion); */
  tmp = RTL_R32(TxConfig);
  tmp = ((tmp & 0x7c000000UL) + ((tmp & 0x00800000UL) << 2)) >> 24;
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
      unsigned int mii_status = rtl8139_mdio_read(&rtl_8139_tp, phy, 1);
      if(mii_status != 0xffff  &&  mii_status != 0x0000)
      {
        rtl_8139_tp.phys[phy_idx++] = phy;
        rtl_8139_tp.advertising = rtl8139_mdio_read(&rtl_8139_tp, phy, 4);
        printf("RTL8139: MII transceiver %d status 0x%4.4x advertising %4.4x.\r\n", phy, mii_status, rtl_8139_tp.advertising);
      }
    }
    if(phy_idx == 0)
    {
      printf("RTL8139: No MII transceivers found! Assuming SYM transceiver.\r\n");
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
    printf("RTL8139: Media type forced to Full Duplex.\r\n");
    /* Changing the MII-advertised media because might prevent  re-connection. */
    rtl_8139_tp.duplex_lock = 1;
  }
  if(rtl_8139_tp.default_port)
  {
    printf("RTL8139: Forcing %dMbs %s-duplex operation.\r\n", (option & 0x0C ? 100 : 10), (option & 0x0A ? "full" : "half"));
    rtl8139_mdio_write(&rtl_8139_tp, rtl_8139_tp.phys[0], 0, ((option & 0x20) ? 0x2000 : 0) | /* 100mbps? */ ((option & 0x10) ? 0x0100 : 0)); /* Full duplex? */
  }
  addr_len = (rtl8139_read_eeprom(ioaddr, 0, 8) == 0x8129) ? 8 : 6;
  for(i = 0; i < 3; ((unsigned short *)(rtl_8139_tp.dev_addr))[i] = le16_to_cpu(rtl8139_read_eeprom(ioaddr, i + 7, addr_len)), i++);
  printf("RTL8139: %s at 0x%lx, %2.2x:%2.2x:%2.2x:%2.2x:%2.2x:%2.2x\r\n", board_info[0].name, rtl_8139_tp.mmio_addr,
   rtl_8139_tp.dev_addr[0], rtl_8139_tp.dev_addr[1], rtl_8139_tp.dev_addr[2], rtl_8139_tp.dev_addr[3], rtl_8139_tp.dev_addr[4], rtl_8139_tp.dev_addr[5]);
#ifndef POLLING
  hook_interrupt(handle, rtl8139_interrupt, &rtl_8139_tp);
  rtl_8139_tp.must_free_irq = 1;
#endif
  rtl_8139_tp.tx_bufs = nbuf_alloc(TX_BUF_TOT_LEN);
  rtl_8139_tp.rx_ring = nbuf_alloc(RX_BUF_TOT_LEN);
  if((rtl_8139_tp.tx_bufs == NULL) || (rtl_8139_tp.rx_ring == NULL))
  {
#ifndef POLLING
    unhook_interrupt(handle);
#endif
    if(rtl_8139_tp.tx_bufs)
      nbuf_free(rtl_8139_tp.tx_bufs);
    if(rtl_8139_tp.rx_ring)
      nbuf_free(rtl_8139_tp.rx_ring);
    printf("RTL8139: EXIT, out of memory\r\n");
    return(-1);
  }
  printf("RTL8139: TX buffers at %#lx, RX buffers at %#lx, DMA offset %#lx\r\n", rtl_8139_tp.tx_bufs, rtl_8139_tp.rx_ring, dma_offset);
  rtl_8139_tp.tx_bufs_dma = (unsigned long)rtl_8139_tp.tx_bufs - dma_offset; 
  rtl_8139_tp.rx_ring_dma = (unsigned long)rtl_8139_tp.rx_ring - dma_offset;
  rtl_8139_tp.full_duplex = rtl_8139_tp.duplex_lock;
  rtl_8139_tp.tx_flag = (TX_FIFO_THRESH << 11) & 0x003f0000UL;
  rtl_8139_tp.twistie = 1;
/* Initialize the Rx and Tx rings */
  rtl_8139_tp.cur_rx = 0;
  rtl_8139_tp.cur_tx = 0;
  rtl_8139_tp.dirty_tx = 0;
  for(i = 0; i < NUM_TX_DESC; i++)
    rtl_8139_tp.tx_buf[i] = &rtl_8139_tp.tx_bufs[i * TX_BUF_SIZE];
  rtl8139_hw_start(&rtl_8139_tp);     
  printf("RTL8139: ioaddr %#lx handle %#lx %s-duplex.\r\n", mmio_start, handle, rtl_8139_tp.full_duplex ? "full" : "half");
  rtl8139_opened = 1;
  if(pio_start);
  return(0);
}

void rtl8139_eth_stop(void)
{
  void *ioaddr = rtl_8139_tp.mmio_addr;
  short level = splx(7); /* mask interrupts */
  /* Stop the chip's Tx and Rx DMA processes. */
  RTL_W8(ChipCmd, (RTL_R8(ChipCmd) & ChipCmdClear));
  /* Disable interrupts by clearing the interrupt mask. */
  RTL_W16(IntrMask, 0x0000);
  /* Update the error counts. */
  rtl_8139_tp.stats.rx_missed_errors += (int)RTL_R32(RxMissed);
  RTL_W32(RxMissed, 0);
#ifndef POLLING
  if(rtl_8139_tp.must_free_irq)
  { 
    unhook_interrupt(rtl_8139_tp.handle);
    rtl_8139_tp.must_free_irq = 0;
  }
#endif
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
  splx(level); /* restore interrupts */
  rtl8139_opened = 0;
}

/*-----------------------------------------------------------------------------------*/

long ei_probe1(void)	/* fills dev_addr */
{
  return(rtl8139_eth_start());
}

long ei_open(void)
{
  long ret = 0;
  if(!rtl8139_n_filters)
    rtl8139_set_ip_filter(my_port.ip_addr);
  if(!rtl8139_opened)
    ret = rtl8139_eth_start();
  if(!ret && rtl8139_opened)
    sting_opened = 1;
  return(0);
}

long ei_close(void)
{
  rtl8139_eth_stop();
  rtl8139_n_filters = 0;
  sting_opened = 0;  
  return(0);
}

unsigned char *ei_dev_addr(void)
{
  return(&rtl_8139_tp.dev_addr[0]);
}

long ei_start_xmit(unsigned char *PktFrstPortion, unsigned short lenFrst, unsigned char *PktScndPortion, unsigned short lenScnd)
{
  if(rtl8139_opened && sting_opened)
    return(rtl8139_send_packet(PktFrstPortion, (size_t)lenFrst, PktScndPortion, (size_t)lenScnd) ? 0 : 1); /* 0: OK */
  return(1); /* error */
}

extern void ei_interrupt(void)
{
#ifdef POLLING
  rtl8139_interrupt(&rtl_8139_tp);
#endif
}

void *get_stats(void) /* access to driver statistics (experimental) */
{
  void *ioaddr = rtl_8139_tp.mmio_addr;
  if(rtl8139_opened && sting_opened)
  {
    /* Update the error counts. */
    rtl_8139_tp.stats.rx_missed_errors += (int)RTL_R32(RxMissed);
    RTL_W32(RxMissed, 0);
  }
  return(&rtl_8139_tp.stats);
}

