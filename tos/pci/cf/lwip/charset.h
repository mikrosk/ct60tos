#ifndef __CHARSET_H__
#define __CHARSET_H__

/* Translation table ISO-8859-1 -> PETSCII */
static const unsigned char petscii[256] = {
    0x00,0x01,0x02,0x03,0x04,0x05,0x06,0x07,0x14,0x09,0x0D,0x11,0x93,0x0A,0x0E,0x0F, 
    0x10,0x0B,0x12,0x13,0x08,0x15,0x16,0x17,0x18,0x19,0x1A,0x1B,0x1C,0x1D,0x1E,0x1F,
    0x20,0x21,0x22,0x23,0x24,0x25,0x26,0x27,0x28,0x29,0x2A,0x2B,0x2C,0x2D,0x2E,0x2F,
    0x30,0x31,0x32,0x33,0x34,0x35,0x36,0x37,0x38,0x39,0x3A,0x3B,0x3C,0x3D,0x3E,0x3F,
    0x40,0xC1,0xC2,0xC3,0xC4,0xC5,0xC6,0xC7,0xC8,0xC9,0xCA,0xCB,0xCC,0xCD,0xCE,0xCF,
    0xD0,0xD1,0xD2,0xD3,0xD4,0xD5,0xD6,0xD7,0xD8,0xD9,0xDA,0x5B,0x5C,0x5D,0x5E,0x5F,
    0xC0,0x41,0x42,0x43,0x44,0x45,0x46,0x47,0x48,0x49,0x4A,0x4B,0x4C,0x4D,0x4E,0x4F,
    0x50,0x51,0x52,0x53,0x54,0x55,0x56,0x57,0x58,0x59,0x5A,0xDB,0xDC,0xDD,0xDE,0xDF,
    0x80,0x81,0x82,0x83,0x84,0x85,0x86,0x87,0x88,0x89,0x8A,0x8B,0x8C,0x8D,0x8E,0x8F,
    0x90,0x91,0x92,0x0C,0x94,0x95,0x96,0x97,0x98,0x99,0x9A,0x9B,0x9C,0x9D,0x9E,0x9F,
    0xA0,0xA1,0xA2,0xA3,0xA4,0xA5,0xA6,0xA7,0xA8,0xA9,0xAA,0xAB,0xAC,0xAD,0xAE,0xAF,
    0xB0,0xB1,0xB2,0xB3,0xB4,0xB5,0xB6,0xB7,0xB8,0xB9,0xBA,0xBB,0xBC,0xBD,0xBE,0xBF,
    0x60,0x61,0x62,0x63,0x64,0x65,0x66,0x67,0x68,0x69,0x6A,0x6B,0x6C,0x6D,0x6E,0x6F,
    0x70,0x71,0x72,0x73,0x74,0x75,0x76,0x77,0x78,0x79,0x7A,0x7B,0x7C,0x7D,0x7E,0x7F,
    0xE0,0xE1,0xE2,0xE3,0xE4,0xE5,0xE6,0xE7,0xE8,0xE9,0xEA,0xEB,0xEC,0xED,0xEE,0xEF,
    0xF0,0xF1,0xF2,0xF3,0xF4,0xF5,0xF6,0xF7,0xF8,0xF9,0xFA,0xFB,0xFC,0xFD,0xFE,0xFF
};


static const unsigned char charset[] = {
	0x3c, 0x66, 0x6e, 
	0x6e, 0x60, 0x62, 0x3c, 00, 00, 00, 0x3c, 0x6, 0x3e, 
	0x66, 0x3e, 00, 00, 0x60, 0x60, 0x7c, 0x66, 0x66, 0x7c, 
	00, 00, 00, 0x3c, 0x60, 0x60, 0x60, 0x3c, 00, 00, 
	0x6, 0x6, 0x3e, 0x66, 0x66, 0x3e, 00, 00, 00, 0x3c, 
	0x66, 0x7e, 0x60, 0x3c, 00, 00, 0xe, 0x18, 0x3e, 0x18, 
	0x18, 0x18, 00, 00, 00, 0x3e, 0x66, 0x66, 0x3e, 0x6, 
	0x7c, 00, 0x60, 0x60, 0x7c, 0x66, 0x66, 0x66, 00, 00, 
	0x18, 00, 0x38, 0x18, 0x18, 0x3c, 00, 00, 0x6, 00, 
	0x6, 0x6, 0x6, 0x6, 0x3c, 00, 0x60, 0x60, 0x6c, 0x78, 
	0x6c, 0x66, 00, 00, 0x38, 0x18, 0x18, 0x18, 0x18, 0x3c, 
	00, 00, 00, 0x66, 0x7f, 0x7f, 0x6b, 0x63, 00, 00, 
	00, 0x7c, 0x66, 0x66, 0x66, 0x66, 00, 00, 00, 0x3c, 
	0x66, 0x66, 0x66, 0x3c, 00, 00, 00, 0x7c, 0x66, 0x66, 
	0x7c, 0x60, 0x60, 00, 00, 0x3e, 0x66, 0x66, 0x3e, 0x6, 
	0x6, 00, 00, 0x7c, 0x66, 0x60, 0x60, 0x60, 00, 00, 
	00, 0x3e, 0x60, 0x3c, 0x6, 0x7c, 00, 00, 0x18, 0x7e, 
	0x18, 0x18, 0x18, 0xe, 00, 00, 00, 0x66, 0x66, 0x66, 
	0x66, 0x3e, 00, 00, 00, 0x66, 0x66, 0x66, 0x3c, 0x18, 
	00, 00, 00, 0x63, 0x6b, 0x7f, 0x3e, 0x36, 00, 00, 
	00, 0x66, 0x3c, 0x18, 0x3c, 0x66, 00, 00, 00, 0x66, 
	0x66, 0x66, 0x3e, 0xc, 0x78, 00, 00, 0x7e, 0xc, 0x18, 
	0x30, 0x7e, 00, 0x3c, 0x30, 0x30, 0x30, 0x30, 0x30, 0x3c, 
	00, 0xc, 0x12, 0x30, 0x7c, 0x30, 0x62, 0xfc, 00, 0x3c, 
	0xc, 0xc, 0xc, 0xc, 0xc, 0x3c, 00, 00, 0x18, 0x3c, 
	0x7e, 0x18, 0x18, 0x18, 0x18, 00, 0x10, 0x30, 0x7f, 0x7f, 
	0x30, 0x10, 00, 00, 00, 00, 00, 00, 00, 00, 
	00, 0x18, 0x18, 0x18, 0x18, 00, 00, 0x18, 00, 0x66, 
	0x66, 0x66, 00, 00, 00, 00, 00, 0x66, 0x66, 0xff, 
	0x66, 0xff, 0x66, 0x66, 00, 0x18, 0x3e, 0x60, 0x3c, 0x6, 
	0x7c, 0x18, 00, 0x62, 0x66, 0xc, 0x18, 0x30, 0x66, 0x46, 
	00, 0x3c, 0x66, 0x3c, 0x38, 0x67, 0x66, 0x3f, 00, 0x6, 
	0xc, 0x18, 00, 00, 00, 00, 00, 0xc, 0x18, 0x30, 
	0x30, 0x30, 0x18, 0xc, 00, 0x30, 0x18, 0xc, 0xc, 0xc, 
	0x18, 0x30, 00, 00, 0x66, 0x3c, 0xff, 0x3c, 0x66, 00, 
	00, 00, 0x18, 0x18, 0x7e, 0x18, 0x18, 00, 00, 00, 
	00, 00, 00, 00, 0x18, 0x18, 0x30, 00, 00, 00, 
	0x7e, 00, 00, 00, 00, 00, 00, 00, 00, 00, 
	0x18, 0x18, 00, 00, 0x3, 0x6, 0xc, 0x18, 0x30, 0x60, 
	00, 0x3c, 0x66, 0x6e, 0x76, 0x66, 0x66, 0x3c, 00, 0x18, 
	0x18, 0x38, 0x18, 0x18, 0x18, 0x7e, 00, 0x3c, 0x66, 0x6, 
	0xc, 0x30, 0x60, 0x7e, 00, 0x3c, 0x66, 0x6, 0x1c, 0x6, 
	0x66, 0x3c, 00, 0x6, 0xe, 0x1e, 0x66, 0x7f, 0x6, 0x6, 
	00, 0x7e, 0x60, 0x7c, 0x6, 0x6, 0x66, 0x3c, 00, 0x3c, 
	0x66, 0x60, 0x7c, 0x66, 0x66, 0x3c, 00, 0x7e, 0x66, 0xc, 
	0x18, 0x18, 0x18, 0x18, 00, 0x3c, 0x66, 0x66, 0x3c, 0x66, 
	0x66, 0x3c, 00, 0x3c, 0x66, 0x66, 0x3e, 0x6, 0x66, 0x3c, 
	00, 00, 00, 0x18, 00, 00, 0x18, 00, 00, 00, 
	00, 0x18, 00, 00, 0x18, 0x18, 0x30, 0xe, 0x18, 0x30, 
	0x60, 0x30, 0x18, 0xe, 00, 00, 00, 0x7e, 00, 0x7e, 
	00, 00, 00, 0x70, 0x18, 0xc, 0x6, 0xc, 0x18, 0x70, 
	00, 0x3c, 0x66, 0x6, 0xc, 0x18, 00, 0x18, 00, 00, 
	00, 00, 0xff, 0xff, 00, 00, 00, 0x18, 0x3c, 0x66, 
	0x7e, 0x66, 0x66, 0x66, 00, 0x7c, 0x66, 0x66, 0x7c, 0x66, 
	0x66, 0x7c, 00, 0x3c, 0x66, 0x60, 0x60, 0x60, 0x66, 0x3c, 
	00, 0x78, 0x6c, 0x66, 0x66, 0x66, 0x6c, 0x78, 00, 0x7e, 
	0x60, 0x60, 0x78, 0x60, 0x60, 0x7e, 00, 0x7e, 0x60, 0x60, 
	0x78, 0x60, 0x60, 0x60, 00, 0x3c, 0x66, 0x60, 0x6e, 0x66, 
	0x66, 0x3c, 00, 0x66, 0x66, 0x66, 0x7e, 0x66, 0x66, 0x66, 
	00, 0x3c, 0x18, 0x18, 0x18, 0x18, 0x18, 0x3c, 00, 0x1e, 
	0xc, 0xc, 0xc, 0xc, 0x6c, 0x38, 00, 0x66, 0x6c, 0x78, 
	0x70, 0x78, 0x6c, 0x66, 00, 0x60, 0x60, 0x60, 0x60, 0x60, 
	0x60, 0x7e, 00, 0x63, 0x77, 0x7f, 0x6b, 0x63, 0x63, 0x63, 
	00, 0x66, 0x76, 0x7e, 0x7e, 0x6e, 0x66, 0x66, 00, 0x3c, 
	0x66, 0x66, 0x66, 0x66, 0x66, 0x3c, 00, 0x7c, 0x66, 0x66, 
	0x7c, 0x60, 0x60, 0x60, 00, 0x3c, 0x66, 0x66, 0x66, 0x66, 
	0x3c, 0xe, 00, 0x7c, 0x66, 0x66, 0x7c, 0x78, 0x6c, 0x66, 
	00, 0x3c, 0x66, 0x60, 0x3c, 0x6, 0x66, 0x3c, 00, 0x7e, 
	0x18, 0x18, 0x18, 0x18, 0x18, 0x18, 00, 0x66, 0x66, 0x66, 
	0x66, 0x66, 0x66, 0x3c, 00, 0x66, 0x66, 0x66, 0x66, 0x66, 
	0x3c, 0x18, 00, 0x63, 0x63, 0x63, 0x6b, 0x7f, 0x77, 0x63, 
	00, 0x66, 0x66, 0x3c, 0x18, 0x3c, 0x66, 0x66, 00, 0x66, 
	0x66, 0x66, 0x3c, 0x18, 0x18, 0x18, 00, 0x7e, 0x6, 0xc, 
	0x18, 0x30, 0x60, 0x7e, 00, 0x18, 0x18, 0x18, 0xff, 0xff, 
	0x18, 0x18, 0x18, 0xc0, 0xc0, 0x30, 0x30, 0xc0, 0xc0, 0x30, 
	0x30, 0x18, 0x18, 0x18, 0x18, 0x18, 0x18, 0x18, 0x18, 0x33, 
	0x33, 0xcc, 0xcc, 0x33, 0x33, 0xcc, 0xcc, 0x33, 0x99, 0xcc, 
	0x66, 0x33, 0x99, 0xcc, 0x66, 00, 00, 00, 00, 00, 
	00, 00, 00, 0xf0, 0xf0, 0xf0, 0xf0, 0xf0, 0xf0, 0xf0, 
	0xf0, 00, 00, 00, 00, 0xff, 0xff, 0xff, 0xff, 0xff, 
	00, 00, 00, 00, 00, 00, 00, 00, 00, 00, 
	00, 00, 00, 00, 0xff, 0xc0, 0xc0, 0xc0, 0xc0, 0xc0, 
	0xc0, 0xc0, 0xc0, 0xcc, 0xcc, 0x33, 0x33, 0xcc, 0xcc, 0x33, 
	0x33, 0x3, 0x3, 0x3, 0x3, 0x3, 0x3, 0x3, 0x3, 00, 
	00, 00, 00, 0xcc, 0xcc, 0x33, 0x33, 0xcc, 0x99, 0x33, 
	0x66, 0xcc, 0x99, 0x33, 0x66, 0x3, 0x3, 0x3, 0x3, 0x3, 
	0x3, 0x3, 0x3, 0x18, 0x18, 0x18, 0x1f, 0x1f, 0x18, 0x18, 
	0x18, 00, 00, 00, 00, 0xf, 0xf, 0xf, 0xf, 0x18, 
	0x18, 0x18, 0x1f, 0x1f, 00, 00, 00, 00, 00, 00, 
	0xf8, 0xf8, 0x18, 0x18, 0x18, 00, 00, 00, 00, 00, 
	00, 0xff, 0xff, 00, 00, 00, 0x1f, 0x1f, 0x18, 0x18, 
	0x18, 0x18, 0x18, 0x18, 0xff, 0xff, 00, 00, 00, 00, 
	00, 00, 0xff, 0xff, 0x18, 0x18, 0x18, 0x18, 0x18, 0x18, 
	0xf8, 0xf8, 0x18, 0x18, 0x18, 0xc0, 0xc0, 0xc0, 0xc0, 0xc0, 
	0xc0, 0xc0, 0xc0, 0xe0, 0xe0, 0xe0, 0xe0, 0xe0, 0xe0, 0xe0, 
	0xe0, 0x7, 0x7, 0x7, 0x7, 0x7, 0x7, 0x7, 0x7, 0xff, 
	0xff, 00, 00, 00, 00, 00, 00, 0xff, 0xff, 0xff, 
	00, 00, 00, 00, 00, 00, 00, 00, 00, 00, 
	0xff, 0xff, 0xff, 0x1, 0x3, 0x6, 0x6c, 0x78, 0x70, 0x60, 
	00, 00, 00, 00, 00, 0xf0, 0xf0, 0xf0, 0xf0, 0xf, 
	0xf, 0xf, 0xf, 00, 00, 00, 00, 0x18, 0x18, 0x18, 
	0xf8, 0xf8, 00, 00, 00, 0xf0, 0xf0, 0xf0, 0xf0, 00, 
	00, 00, 00, 0xf0, 0xf0, 0xf0, 0xf0, 0xf, 0xf, 0xf, 
	0xf, 0xc3, 0x99, 0x91, 0x91, 0x9f, 0x99, 0xc3, 0xff, 0xff, 
	0xff, 0xc3, 0xf9, 0xc1, 0x99, 0xc1, 0xff, 0xff, 0x9f, 0x9f, 
	0x83, 0x99, 0x99, 0x83, 0xff, 0xff, 0xff, 0xc3, 0x9f, 0x9f, 
	0x9f, 0xc3, 0xff, 0xff, 0xf9, 0xf9, 0xc1, 0x99, 0x99, 0xc1, 
	0xff, 0xff, 0xff, 0xc3, 0x99, 0x81, 0x9f, 0xc3, 0xff, 0xff, 
	0xf1, 0xe7, 0xc1, 0xe7, 0xe7, 0xe7, 0xff, 0xff, 0xff, 0xc1, 
	0x99, 0x99, 0xc1, 0xf9, 0x83, 0xff, 0x9f, 0x9f, 0x83, 0x99, 
	0x99, 0x99, 0xff, 0xff, 0xe7, 0xff, 0xc7, 0xe7, 0xe7, 0xc3, 
	0xff, 0xff, 0xf9, 0xff, 0xf9, 0xf9, 0xf9, 0xf9, 0xc3, 0xff, 
	0x9f, 0x9f, 0x93, 0x87, 0x93, 0x99, 0xff, 0xff, 0xc7, 0xe7, 
	0xe7, 0xe7, 0xe7, 0xc3, 0xff, 0xff, 0xff, 0x99, 0x80, 0x80, 
	0x94, 0x9c, 0xff, 0xff, 0xff, 0x83, 0x99, 0x99, 0x99, 0x99, 
	0xff, 0xff, 0xff, 0xc3, 0x99, 0x99, 0x99, 0xc3, 0xff, 0xff, 
	0xff, 0x83, 0x99, 0x99, 0x83, 0x9f, 0x9f, 0xff, 0xff, 0xc1, 
	0x99, 0x99, 0xc1, 0xf9, 0xf9, 0xff, 0xff, 0x83, 0x99, 0x9f, 
	0x9f, 0x9f, 0xff, 0xff, 0xff, 0xc1, 0x9f, 0xc3, 0xf9, 0x83, 
	0xff, 0xff, 0xe7, 0x81, 0xe7, 0xe7, 0xe7, 0xf1, 0xff, 0xff, 
	0xff, 0x99, 0x99, 0x99, 0x99, 0xc1, 0xff, 0xff, 0xff, 0x99, 
	0x99, 0x99, 0xc3, 0xe7, 0xff, 0xff, 0xff, 0x9c, 0x94, 0x80, 
	0xc1, 0xc9, 0xff, 0xff, 0xff, 0x99, 0xc3, 0xe7, 0xc3, 0x99, 
	0xff, 0xff, 0xff, 0x99, 0x99, 0x99, 0xc1, 0xf3, 0x87, 0xff, 
	0xff, 0x81, 0xf3, 0xe7, 0xcf, 0x81, 0xff, 0xc3, 0xcf, 0xcf, 
	0xcf, 0xcf, 0xcf, 0xc3, 0xff, 0xf3, 0xed, 0xcf, 0x83, 0xcf, 
	0x9d, 0x3, 0xff, 0xc3, 0xf3, 0xf3, 0xf3, 0xf3, 0xf3, 0xc3, 
	0xff, 0xff, 0xe7, 0xc3, 0x81, 0xe7, 0xe7, 0xe7, 0xe7, 0xff, 
	0xef, 0xcf, 0x80, 0x80, 0xcf, 0xef, 0xff, 0xff, 0xff, 0xff, 
	0xff, 0xff, 0xff, 0xff, 0xff, 0xe7, 0xe7, 0xe7, 0xe7, 0xff, 
	0xff, 0xe7, 0xff, 0x99, 0x99, 0x99, 0xff, 0xff, 0xff, 0xff, 
	0xff, 0x99, 0x99, 00, 0x99, 00, 0x99, 0x99, 0xff, 0xe7, 
	0xc1, 0x9f, 0xc3, 0xf9, 0x83, 0xe7, 0xff, 0x9d, 0x99, 0xf3, 
	0xe7, 0xcf, 0x99, 0xb9, 0xff, 0xc3, 0x99, 0xc3, 0xc7, 0x98, 
	0x99, 0xc0, 0xff, 0xf9, 0xf3, 0xe7, 0xff, 0xff, 0xff, 0xff, 
	0xff, 0xf3, 0xe7, 0xcf, 0xcf, 0xcf, 0xe7, 0xf3, 0xff, 0xcf, 
	0xe7, 0xf3, 0xf3, 0xf3, 0xe7, 0xcf, 0xff, 0xff, 0x99, 0xc3, 
	00, 0xc3, 0x99, 0xff, 0xff, 0xff, 0xe7, 0xe7, 0x81, 0xe7, 
	0xe7, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xe7, 0xe7, 
	0xcf, 0xff, 0xff, 0xff, 0x81, 0xff, 0xff, 0xff, 0xff, 0xff, 
	0xff, 0xff, 0xff, 0xff, 0xe7, 0xe7, 0xff, 0xff, 0xfc, 0xf9, 
	0xf3, 0xe7, 0xcf, 0x9f, 0xff, 0xc3, 0x99, 0x91, 0x89, 0x99, 
	0x99, 0xc3, 0xff, 0xe7, 0xe7, 0xc7, 0xe7, 0xe7, 0xe7, 0x81, 
	0xff, 0xc3, 0x99, 0xf9, 0xf3, 0xcf, 0x9f, 0x81, 0xff, 0xc3, 
	0x99, 0xf9, 0xe3, 0xf9, 0x99, 0xc3, 0xff, 0xf9, 0xf1, 0xe1, 
	0x99, 0x80, 0xf9, 0xf9, 0xff, 0x81, 0x9f, 0x83, 0xf9, 0xf9, 
	0x99, 0xc3, 0xff, 0xc3, 0x99, 0x9f, 0x83, 0x99, 0x99, 0xc3, 
	0xff, 0x81, 0x99, 0xf3, 0xe7, 0xe7, 0xe7, 0xe7, 0xff, 0xc3, 
	0x99, 0x99, 0xc3, 0x99, 0x99, 0xc3, 0xff, 0xc3, 0x99, 0x99, 
	0xc1, 0xf9, 0x99, 0xc3, 0xff, 0xff, 0xff, 0xe7, 0xff, 0xff, 
	0xe7, 0xff, 0xff, 0xff, 0xff, 0xe7, 0xff, 0xff, 0xe7, 0xe7, 
	0xcf, 0xf1, 0xe7, 0xcf, 0x9f, 0xcf, 0xe7, 0xf1, 0xff, 0xff, 
	0xff, 0x81, 0xff, 0x81, 0xff, 0xff, 0xff, 0x8f, 0xe7, 0xf3, 
	0xf9, 0xf3, 0xe7, 0x8f, 0xff, 0xc3, 0x99, 0xf9, 0xf3, 0xe7, 
	0xff, 0xe7, 0xff, 0xff, 0xff, 0xff, 00, 00, 0xff, 0xff, 
	0xff, 0xe7, 0xc3, 0x99, 0x81, 0x99, 0x99, 0x99, 0xff, 0x83, 
	0x99, 0x99, 0x83, 0x99, 0x99, 0x83, 0xff, 0xc3, 0x99, 0x9f, 
	0x9f, 0x9f, 0x99, 0xc3, 0xff, 0x87, 0x93, 0x99, 0x99, 0x99, 
	0x93, 0x87, 0xff, 0x81, 0x9f, 0x9f, 0x87, 0x9f, 0x9f, 0x81, 
	0xff, 0x81, 0x9f, 0x9f, 0x87, 0x9f, 0x9f, 0x9f, 0xff, 0xc3, 
	0x99, 0x9f, 0x91, 0x99, 0x99, 0xc3, 0xff, 0x99, 0x99, 0x99, 
	0x81, 0x99, 0x99, 0x99, 0xff, 0xc3, 0xe7, 0xe7, 0xe7, 0xe7, 
	0xe7, 0xc3, 0xff, 0xe1, 0xf3, 0xf3, 0xf3, 0xf3, 0x93, 0xc7, 
	0xff, 0x99, 0x93, 0x87, 0x8f, 0x87, 0x93, 0x99, 0xff, 0x9f, 
	0x9f, 0x9f, 0x9f, 0x9f, 0x9f, 0x81, 0xff, 0x9c, 0x88, 0x80, 
	0x94, 0x9c, 0x9c, 0x9c, 0xff, 0x99, 0x89, 0x81, 0x81, 0x91, 
	0x99, 0x99, 0xff, 0xc3, 0x99, 0x99, 0x99, 0x99, 0x99, 0xc3, 
	0xff, 0x83, 0x99, 0x99, 0x83, 0x9f, 0x9f, 0x9f, 0xff, 0xc3, 
	0x99, 0x99, 0x99, 0x99, 0xc3, 0xf1, 0xff, 0x83, 0x99, 0x99, 
	0x83, 0x87, 0x93, 0x99, 0xff, 0xc3, 0x99, 0x9f, 0xc3, 0xf9, 
	0x99, 0xc3, 0xff, 0x81, 0xe7, 0xe7, 0xe7, 0xe7, 0xe7, 0xe7, 
	0xff, 0x99, 0x99, 0x99, 0x99, 0x99, 0x99, 0xc3, 0xff, 0x99, 
	0x99, 0x99, 0x99, 0x99, 0xc3, 0xe7, 0xff, 0x9c, 0x9c, 0x9c, 
	0x94, 0x80, 0x88, 0x9c, 0xff, 0x99, 0x99, 0xc3, 0xe7, 0xc3, 
	0x99, 0x99, 0xff, 0x99, 0x99, 0x99, 0xc3, 0xe7, 0xe7, 0xe7, 
	0xff, 0x81, 0xf9, 0xf3, 0xe7, 0xcf, 0x9f, 0x81, 0xff, 0xe7, 
	0xe7, 0xe7, 00, 00, 0xe7, 0xe7, 0xe7, 0x3f, 0x3f, 0xcf, 
	0xcf, 0x3f, 0x3f, 0xcf, 0xcf, 0xe7, 0xe7, 0xe7, 0xe7, 0xe7, 
	0xe7, 0xe7, 0xe7, 0xcc, 0xcc, 0x33, 0x33, 0xcc, 0xcc, 0x33, 
	0x33, 0xcc, 0x66, 0x33, 0x99, 0xcc, 0x66, 0x33, 0x99, 0xff, 
	0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xf, 0xf, 0xf, 
	0xf, 0xf, 0xf, 0xf, 0xf, 0xff, 0xff, 0xff, 0xff, 00, 
	00, 00, 00, 00, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 
	0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 00, 0x3f, 
	0x3f, 0x3f, 0x3f, 0x3f, 0x3f, 0x3f, 0x3f, 0x33, 0x33, 0xcc, 
	0xcc, 0x33, 0x33, 0xcc, 0xcc, 0xfc, 0xfc, 0xfc, 0xfc, 0xfc, 
	0xfc, 0xfc, 0xfc, 0xff, 0xff, 0xff, 0xff, 0x33, 0x33, 0xcc, 
	0xcc, 0x33, 0x66, 0xcc, 0x99, 0x33, 0x66, 0xcc, 0x99, 0xfc, 
	0xfc, 0xfc, 0xfc, 0xfc, 0xfc, 0xfc, 0xfc, 0xe7, 0xe7, 0xe7, 
	0xe0, 0xe0, 0xe7, 0xe7, 0xe7, 0xff, 0xff, 0xff, 0xff, 0xf0, 
	0xf0, 0xf0, 0xf0, 0xe7, 0xe7, 0xe7, 0xe0, 0xe0, 0xff, 0xff, 
	0xff, 0xff, 0xff, 0xff, 0x7, 0x7, 0xe7, 0xe7, 0xe7, 0xff, 
	0xff, 0xff, 0xff, 0xff, 0xff, 00, 00, 0xff, 0xff, 0xff, 
	0xe0, 0xe0, 0xe7, 0xe7, 0xe7, 0xe7, 0xe7, 0xe7, 00, 00, 
	0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 00, 00, 0xe7, 0xe7, 
	0xe7, 0xe7, 0xe7, 0xe7, 0x7, 0x7, 0xe7, 0xe7, 0xe7, 0x3f, 
	0x3f, 0x3f, 0x3f, 0x3f, 0x3f, 0x3f, 0x3f, 0x1f, 0x1f, 0x1f, 
	0x1f, 0x1f, 0x1f, 0x1f, 0x1f, 0xf8, 0xf8, 0xf8, 0xf8, 0xf8, 
	0xf8, 0xf8, 0xf8, 00, 00, 0xff, 0xff, 0xff, 0xff, 0xff, 
	0xff, 00, 00, 00, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 
	0xff, 0xff, 0xff, 0xff, 00, 00, 00, 0xfe, 0xfc, 0xf9, 
	0x93, 0x87, 0x8f, 0x9f, 0xff, 0xff, 0xff, 0xff, 0xff, 0xf, 
	0xf, 0xf, 0xf, 0xf0, 0xf0, 0xf0, 0xf0, 0xff, 0xff, 0xff, 
	0xff, 0xe7, 0xe7, 0xe7, 0x7, 0x7, 0xff, 0xff, 0xff, 0xf, 
	0xf, 0xf, 0xf, 0xff, 0xff, 0xff, 0xff, 0xf, 0xf, 0xf, 
	0xf, 0xf0, 0xf0, 0xf0, 0xf0,



	0x3c, 0x66, 0x6e, 0x6e, 0x60, 0x62, 0x3c, 
	00, 0x18, 0x3c, 0x66, 0x7e, 0x66, 0x66, 0x66, 00, 0x7c, 
	0x66, 0x66, 0x7c, 0x66, 0x66, 0x7c, 00, 0x3c, 0x66, 0x60, 
	0x60, 0x60, 0x66, 0x3c, 00, 0x78, 0x6c, 0x66, 0x66, 0x66, 
	0x6c, 0x78, 00, 0x7e, 0x60, 0x60, 0x78, 0x60, 0x60, 0x7e, 
	00, 0x7e, 0x60, 0x60, 0x78, 0x60, 0x60, 0x60, 00, 0x3c, 
	0x66, 0x60, 0x6e, 0x66, 0x66, 0x3c, 00, 0x66, 0x66, 0x66, 
	0x7e, 0x66, 0x66, 0x66, 00, 0x3c, 0x18, 0x18, 0x18, 0x18, 
	0x18, 0x3c, 00, 0x1e, 0xc, 0xc, 0xc, 0xc, 0x6c, 0x38, 
	00, 0x66, 0x6c, 0x78, 0x70, 0x78, 0x6c, 0x66, 00, 0x60, 
	0x60, 0x60, 0x60, 0x60, 0x60, 0x7e, 00, 0x63, 0x77, 0x7f, 
	0x6b, 0x63, 0x63, 0x63, 00, 0x66, 0x76, 0x7e, 0x7e, 0x6e, 
	0x66, 0x66, 00, 0x3c, 0x66, 0x66, 0x66, 0x66, 0x66, 0x3c, 
	00, 0x7c, 0x66, 0x66, 0x7c, 0x60, 0x60, 0x60, 00, 0x3c, 
	0x66, 0x66, 0x66, 0x66, 0x3c, 0xe, 00, 0x7c, 0x66, 0x66, 
	0x7c, 0x78, 0x6c, 0x66, 00, 0x3c, 0x66, 0x60, 0x3c, 0x6, 
	0x66, 0x3c, 00, 0x7e, 0x18, 0x18, 0x18, 0x18, 0x18, 0x18, 
	00, 0x66, 0x66, 0x66, 0x66, 0x66, 0x66, 0x3c, 00, 0x66, 
	0x66, 0x66, 0x66, 0x66, 0x3c, 0x18, 00, 0x63, 0x63, 0x63, 
	0x6b, 0x7f, 0x77, 0x63, 00, 0x66, 0x66, 0x3c, 0x18, 0x3c, 
	0x66, 0x66, 00, 0x66, 0x66, 0x66, 0x3c, 0x18, 0x18, 0x18, 
	00, 0x7e, 0x6, 0xc, 0x18, 0x30, 0x60, 0x7e, 00, 0x3c, 
	0x30, 0x30, 0x30, 0x30, 0x30, 0x3c, 00, 0xc, 0x12, 0x30, 
	0x7c, 0x30, 0x62, 0xfc, 00, 0x3c, 0xc, 0xc, 0xc, 0xc, 
	0xc, 0x3c, 00, 00, 0x18, 0x3c, 0x7e, 0x18, 0x18, 0x18, 
	0x18, 00, 0x10, 0x30, 0x7f, 0x7f, 0x30, 0x10, 00, 00, 
	00, 00, 00, 00, 00, 00, 00, 0x18, 0x18, 0x18, 
	0x18, 00, 00, 0x18, 00, 0x66, 0x66, 0x66, 00, 00, 
	00, 00, 00, 0x66, 0x66, 0xff, 0x66, 0xff, 0x66, 0x66, 
	00, 0x18, 0x3e, 0x60, 0x3c, 0x6, 0x7c, 0x18, 00, 0x62, 
	0x66, 0xc, 0x18, 0x30, 0x66, 0x46, 00, 0x3c, 0x66, 0x3c, 
	0x38, 0x67, 0x66, 0x3f, 00, 0x6, 0xc, 0x18, 00, 00, 
	00, 00, 00, 0xc, 0x18, 0x30, 0x30, 0x30, 0x18, 0xc, 
	00, 0x30, 0x18, 0xc, 0xc, 0xc, 0x18, 0x30, 00, 00, 
	0x66, 0x3c, 0xff, 0x3c, 0x66, 00, 00, 00, 0x18, 0x18, 
	0x7e, 0x18, 0x18, 00, 00, 00, 00, 00, 00, 00, 
	0x18, 0x18, 0x30, 00, 00, 00, 0x7e, 00, 00, 00, 
	00, 00, 00, 00, 00, 00, 0x18, 0x18, 00, 00, 
	0x3, 0x6, 0xc, 0x18, 0x30, 0x60, 00, 0x3c, 0x66, 0x6e, 
	0x76, 0x66, 0x66, 0x3c, 00, 0x18, 0x18, 0x38, 0x18, 0x18, 
	0x18, 0x7e, 00, 0x3c, 0x66, 0x6, 0xc, 0x30, 0x60, 0x7e, 
	00, 0x3c, 0x66, 0x6, 0x1c, 0x6, 0x66, 0x3c, 00, 0x6, 
	0xe, 0x1e, 0x66, 0x7f, 0x6, 0x6, 00, 0x7e, 0x60, 0x7c, 
	0x6, 0x6, 0x66, 0x3c, 00, 0x3c, 0x66, 0x60, 0x7c, 0x66, 
	0x66, 0x3c, 00, 0x7e, 0x66, 0xc, 0x18, 0x18, 0x18, 0x18, 
	00, 0x3c, 0x66, 0x66, 0x3c, 0x66, 0x66, 0x3c, 00, 0x3c, 
	0x66, 0x66, 0x3e, 0x6, 0x66, 0x3c, 00, 00, 00, 0x18, 
	00, 00, 0x18, 00, 00, 00, 00, 0x18, 00, 00, 
	0x18, 0x18, 0x30, 0xe, 0x18, 0x30, 0x60, 0x30, 0x18, 0xe, 
	00, 00, 00, 0x7e, 00, 0x7e, 00, 00, 00, 0x70, 
	0x18, 0xc, 0x6, 0xc, 0x18, 0x70, 00, 0x3c, 0x66, 0x6, 
	0xc, 0x18, 00, 0x18, 00, 00, 00, 00, 0xff, 0xff, 
	00, 00, 00, 0x8, 0x1c, 0x3e, 0x7f, 0x7f, 0x1c, 0x3e, 
	00, 0x18, 0x18, 0x18, 0x18, 0x18, 0x18, 0x18, 0x18, 00, 
	00, 00, 0xff, 0xff, 00, 00, 00, 00, 00, 0xff, 
	0xff, 00, 00, 00, 00, 00, 0xff, 0xff, 00, 00, 
	00, 00, 00, 00, 00, 00, 00, 0xff, 0xff, 00, 
	00, 0x30, 0x30, 0x30, 0x30, 0x30, 0x30, 0x30, 0x30, 0xc, 
	0xc, 0xc, 0xc, 0xc, 0xc, 0xc, 0xc, 00, 00, 00, 
	0xe0, 0xf0, 0x38, 0x18, 0x18, 0x18, 0x18, 0x1c, 0xf, 0x7, 
	00, 00, 00, 0x18, 0x18, 0x38, 0xf0, 0xe0, 00, 00, 
	00, 0xc0, 0xc0, 0xc0, 0xc0, 0xc0, 0xc0, 0xff, 0xff, 0xc0, 
	0xe0, 0x70, 0x38, 0x1c, 0xe, 0x7, 0x3, 0x3, 0x7, 0xe, 
	0x1c, 0x38, 0x70, 0xe0, 0xc0, 0xff, 0xff, 0xc0, 0xc0, 0xc0, 
	0xc0, 0xc0, 0xc0, 0xff, 0xff, 0x3, 0x3, 0x3, 0x3, 0x3, 
	0x3, 00, 0x3c, 0x7e, 0x7e, 0x7e, 0x7e, 0x3c, 00, 00, 
	00, 00, 00, 00, 0xff, 0xff, 00, 0x36, 0x7f, 0x7f, 
	0x7f, 0x3e, 0x1c, 0x8, 00, 0x60, 0x60, 0x60, 0x60, 0x60, 
	0x60, 0x60, 0x60, 00, 00, 00, 0x7, 0xf, 0x1c, 0x18, 
	0x18, 0xc3, 0xe7, 0x7e, 0x3c, 0x3c, 0x7e, 0xe7, 0xc3, 00, 
	0x3c, 0x7e, 0x66, 0x66, 0x7e, 0x3c, 00, 0x18, 0x18, 0x66, 
	0x66, 0x18, 0x18, 0x3c, 00, 0x6, 0x6, 0x6, 0x6, 0x6, 
	0x6, 0x6, 0x6, 0x8, 0x1c, 0x3e, 0x7f, 0x3e, 0x1c, 0x8, 
	00, 0x18, 0x18, 0x18, 0xff, 0xff, 0x18, 0x18, 0x18, 0xc0, 
	0xc0, 0x30, 0x30, 0xc0, 0xc0, 0x30, 0x30, 0x18, 0x18, 0x18, 
	0x18, 0x18, 0x18, 0x18, 0x18, 00, 00, 0x3, 0x3e, 0x76, 
	0x36, 0x36, 00, 0xff, 0x7f, 0x3f, 0x1f, 0xf, 0x7, 0x3, 
	0x1, 00, 00, 00, 00, 00, 00, 00, 00, 0xf0, 
	0xf0, 0xf0, 0xf0, 0xf0, 0xf0, 0xf0, 0xf0, 00, 00, 00, 
	00, 0xff, 0xff, 0xff, 0xff, 0xff, 00, 00, 00, 00, 
	00, 00, 00, 00, 00, 00, 00, 00, 00, 00, 
	0xff, 0xc0, 0xc0, 0xc0, 0xc0, 0xc0, 0xc0, 0xc0, 0xc0, 0xcc, 
	0xcc, 0x33, 0x33, 0xcc, 0xcc, 0x33, 0x33, 0x3, 0x3, 0x3, 
	0x3, 0x3, 0x3, 0x3, 0x3, 00, 00, 00, 00, 0xcc, 
	0xcc, 0x33, 0x33, 0xff, 0xfe, 0xfc, 0xf8, 0xf0, 0xe0, 0xc0, 
	0x80, 0x3, 0x3, 0x3, 0x3, 0x3, 0x3, 0x3, 0x3, 0x18, 
	0x18, 0x18, 0x1f, 0x1f, 0x18, 0x18, 0x18, 00, 00, 00, 
	00, 0xf, 0xf, 0xf, 0xf, 0x18, 0x18, 0x18, 0x1f, 0x1f, 
	00, 00, 00, 00, 00, 00, 0xf8, 0xf8, 0x18, 0x18, 
	0x18, 00, 00, 00, 00, 00, 00, 0xff, 0xff, 00, 
	00, 00, 0x1f, 0x1f, 0x18, 0x18, 0x18, 0x18, 0x18, 0x18, 
	0xff, 0xff, 00, 00, 00, 00, 00, 00, 0xff, 0xff, 
	0x18, 0x18, 0x18, 0x18, 0x18, 0x18, 0xf8, 0xf8, 0x18, 0x18, 
	0x18, 0xc0, 0xc0, 0xc0, 0xc0, 0xc0, 0xc0, 0xc0, 0xc0, 0xe0, 
	0xe0, 0xe0, 0xe0, 0xe0, 0xe0, 0xe0, 0xe0, 0x7, 0x7, 0x7, 
	0x7, 0x7, 0x7, 0x7, 0x7, 0xff, 0xff, 00, 00, 00, 
	00, 00, 00, 0xff, 0xff, 0xff, 00, 00, 00, 00, 
	00, 00, 00, 00, 00, 00, 0xff, 0xff, 0xff, 0x3, 
	0x3, 0x3, 0x3, 0x3, 0x3, 0xff, 0xff, 00, 00, 00, 
	00, 0xf0, 0xf0, 0xf0, 0xf0, 0xf, 0xf, 0xf, 0xf, 00, 
	00, 00, 00, 0x18, 0x18, 0x18, 0xf8, 0xf8, 00, 00, 
	00, 0xf0, 0xf0, 0xf0, 0xf0, 00, 00, 00, 00, 0xf0, 
	0xf0, 0xf0, 0xf0, 0xf, 0xf, 0xf, 0xf, 0xc3, 0x99, 0x91, 
	0x91, 0x9f, 0x99, 0xc3, 0xff, 0xe7, 0xc3, 0x99, 0x81, 0x99, 
	0x99, 0x99, 0xff, 0x83, 0x99, 0x99, 0x83, 0x99, 0x99, 0x83, 
	0xff, 0xc3, 0x99, 0x9f, 0x9f, 0x9f, 0x99, 0xc3, 0xff, 0x87, 
	0x93, 0x99, 0x99, 0x99, 0x93, 0x87, 0xff, 0x81, 0x9f, 0x9f, 
	0x87, 0x9f, 0x9f, 0x81, 0xff, 0x81, 0x9f, 0x9f, 0x87, 0x9f, 
	0x9f, 0x9f, 0xff, 0xc3, 0x99, 0x9f, 0x91, 0x99, 0x99, 0xc3, 
	0xff, 0x99, 0x99, 0x99, 0x81, 0x99, 0x99, 0x99, 0xff, 0xc3, 
	0xe7, 0xe7, 0xe7, 0xe7, 0xe7, 0xc3, 0xff, 0xe1, 0xf3, 0xf3, 
	0xf3, 0xf3, 0x93, 0xc7, 0xff, 0x99, 0x93, 0x87, 0x8f, 0x87, 
	0x93, 0x99, 0xff, 0x9f, 0x9f, 0x9f, 0x9f, 0x9f, 0x9f, 0x81, 
	0xff, 0x9c, 0x88, 0x80, 0x94, 0x9c, 0x9c, 0x9c, 0xff, 0x99, 
	0x89, 0x81, 0x81, 0x91, 0x99, 0x99, 0xff, 0xc3, 0x99, 0x99, 
	0x99, 0x99, 0x99, 0xc3, 0xff, 0x83, 0x99, 0x99, 0x83, 0x9f, 
	0x9f, 0x9f, 0xff, 0xc3, 0x99, 0x99, 0x99, 0x99, 0xc3, 0xf1, 
	0xff, 0x83, 0x99, 0x99, 0x83, 0x87, 0x93, 0x99, 0xff, 0xc3, 
	0x99, 0x9f, 0xc3, 0xf9, 0x99, 0xc3, 0xff, 0x81, 0xe7, 0xe7, 
	0xe7, 0xe7, 0xe7, 0xe7, 0xff, 0x99, 0x99, 0x99, 0x99, 0x99, 
	0x99, 0xc3, 0xff, 0x99, 0x99, 0x99, 0x99, 0x99, 0xc3, 0xe7, 
	0xff, 0x9c, 0x9c, 0x9c, 0x94, 0x80, 0x88, 0x9c, 0xff, 0x99, 
	0x99, 0xc3, 0xe7, 0xc3, 0x99, 0x99, 0xff, 0x99, 0x99, 0x99, 
	0xc3, 0xe7, 0xe7, 0xe7, 0xff, 0x81, 0xf9, 0xf3, 0xe7, 0xcf, 
	0x9f, 0x81, 0xff, 0xc3, 0xcf, 0xcf, 0xcf, 0xcf, 0xcf, 0xc3, 
	0xff, 0xf3, 0xed, 0xcf, 0x83, 0xcf, 0x9d, 0x3, 0xff, 0xc3, 
	0xf3, 0xf3, 0xf3, 0xf3, 0xf3, 0xc3, 0xff, 0xff, 0xe7, 0xc3, 
	0x81, 0xe7, 0xe7, 0xe7, 0xe7, 0xff, 0xef, 0xcf, 0x80, 0x80, 
	0xcf, 0xef, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 
	0xff, 0xe7, 0xe7, 0xe7, 0xe7, 0xff, 0xff, 0xe7, 0xff, 0x99, 
	0x99, 0x99, 0xff, 0xff, 0xff, 0xff, 0xff, 0x99, 0x99, 00, 
	0x99, 00, 0x99, 0x99, 0xff, 0xe7, 0xc1, 0x9f, 0xc3, 0xf9, 
	0x83, 0xe7, 0xff, 0x9d, 0x99, 0xf3, 0xe7, 0xcf, 0x99, 0xb9, 
	0xff, 0xc3, 0x99, 0xc3, 0xc7, 0x98, 0x99, 0xc0, 0xff, 0xf9, 
	0xf3, 0xe7, 0xff, 0xff, 0xff, 0xff, 0xff, 0xf3, 0xe7, 0xcf, 
	0xcf, 0xcf, 0xe7, 0xf3, 0xff, 0xcf, 0xe7, 0xf3, 0xf3, 0xf3, 
	0xe7, 0xcf, 0xff, 0xff, 0x99, 0xc3, 00, 0xc3, 0x99, 0xff, 
	0xff, 0xff, 0xe7, 0xe7, 0x81, 0xe7, 0xe7, 0xff, 0xff, 0xff, 
	0xff, 0xff, 0xff, 0xff, 0xe7, 0xe7, 0xcf, 0xff, 0xff, 0xff, 
	0x81, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 
	0xe7, 0xe7, 0xff, 0xff, 0xfc, 0xf9, 0xf3, 0xe7, 0xcf, 0x9f, 
	0xff, 0xc3, 0x99, 0x91, 0x89, 0x99, 0x99, 0xc3, 0xff, 0xe7, 
	0xe7, 0xc7, 0xe7, 0xe7, 0xe7, 0x81, 0xff, 0xc3, 0x99, 0xf9, 
	0xf3, 0xcf, 0x9f, 0x81, 0xff, 0xc3, 0x99, 0xf9, 0xe3, 0xf9, 
	0x99, 0xc3, 0xff, 0xf9, 0xf1, 0xe1, 0x99, 0x80, 0xf9, 0xf9, 
	0xff, 0x81, 0x9f, 0x83, 0xf9, 0xf9, 0x99, 0xc3, 0xff, 0xc3, 
	0x99, 0x9f, 0x83, 0x99, 0x99, 0xc3, 0xff, 0x81, 0x99, 0xf3, 
	0xe7, 0xe7, 0xe7, 0xe7, 0xff, 0xc3, 0x99, 0x99, 0xc3, 0x99, 
	0x99, 0xc3, 0xff, 0xc3, 0x99, 0x99, 0xc1, 0xf9, 0x99, 0xc3, 
	0xff, 0xff, 0xff, 0xe7, 0xff, 0xff, 0xe7, 0xff, 0xff, 0xff, 
};
#endif /* __CHARSET_H__ */
