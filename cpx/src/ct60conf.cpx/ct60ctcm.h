/* CT60 programmable clock module */
/* Didier MEQUIGNON - March 2005 */

#define CT60_CLOCK_READ         0
#define CT60_CLOCK_WRITE_RAM    1
#define CT60_CLOCK_WRITE_EEPROM 2
#define CT60_CLOCK_RESET        3
#define CT60_CALC_CLOCK_ERROR -2
#define CT60_NULL_CLOCK_ERROR -3
#define CYPRESS 0x0000
#define DALLAS  0x8000

#define CY_STEP83

/* DS1085 serial programmable clock registers */
#define DIVWORD   0x01
#define MUXWORD   0x02
#define DACWORD   0x08
#define ADR       0x0D
#define OFFSET    0x0E
#define RANGEWORD 0x37
#define WRITEE2   0x3F
#if 0
/* DS1085Z-10 */
#define BASE_FREQ  61400L /* KHz */
#define DEF_FREQ   97100L /* KHz */
#define DAC_STEP      10L /* KHz */
#define DAC_DEF      500L
#define OFFSET_STEP 5120L /* KHz */
/* DS1085Z-25 */
#define BASE_FREQ  51200L /* KHz */
#define DEF_FREQ  104600L /* KHz */
#define DAC_STEP      25L /* KHz */
#define DAC_DEF      600L
#define OFFSET_STEP 6400L /* KHz */
#endif
/* DS1085Z-50 */
#define BASE_FREQ  38400L /* KHz */
#define DEF_FREQ  101800L /* KHz */
#define DAC_STEP      50L /* KHz */
#define DAC_DEF      500L
#define OFFSET_STEP 6400L /* KHz */ 

/* CY27EE16ZE serial programmable clock registers */
#define CTRLMACH  0x00
#define ADRDEV8EE 0x05
#define ADRDEVPLL 0x06
#define DEFPLLCNF 0x07
#define CLKOE     0x09
#define DIV1N     0x0C
#define PINCTRL   0x10
#define WPREG     0x11
#define OSCDRV    0x12
#define INLOAD    0x13
#define ADCREG    0x14
#define CHARGEP   0x40
#define PBCOUNTER 0x41
#define QCOUNTER  0x42
#define MATRIX1   0x44
#define MATRIX2   0x45
#define MATRIX3   0x46
#define DIV2N     0x47
#define REF                 10000UL /* KHz */

#define MIN_FREQ            65000UL /* KHz */
#define MIN_FREQ_DALLAS     66000UL /* KHz */
#define MAX_FREQ_DALLAS    133000UL /* KHz */
#define MAX_FREQ_REV1_BOOT  66000UL /* KHz */
#define MAX_FREQ_REV1       75000UL /* KHz */
#define MAX_FREQ_REV6_BOOT 100000UL /* KHz */
#define MAX_FREQ_REV6      110000UL /* KHz */
