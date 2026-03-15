#include <stdint.h>

#define UART_BASE       0x40000000u
#define UART_STATUS_REG (*(volatile uint32_t *)(UART_BASE + 0x00u))
#define UART_DATA_REG   (*(volatile uint32_t *)(UART_BASE + 0x00u))

static void uart_send_char(char c)
{
    /* Wait while TX busy (status bit 0 == 1) */
    while (UART_STATUS_REG & 0x1u) {
        /* busy wait */
    }
    UART_DATA_REG = (uint32_t)(uint8_t)c;
}

static void uart_send_string(const char *s)
{
    while (*s) {
        uart_send_char(*s++);
    }
}

int main(void)
{
    uart_send_string("Hello\n");
    return 0;
}
