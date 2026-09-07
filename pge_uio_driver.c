#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <stdbool.h>
#include <fcntl.h>
#include <unistd.h>
#include <sys/mman.h>

#define PGE_REG_CTRL      0x0
#define PGE_REG_TRUST_CFG 0x4
#define PGE_REG_STATUS    0x8

#define PGE_STATUS_FAULT_MASK  (1 << 0)
#define PGE_STATUS_READY_MASK  (1 << 1)
#define PGE_STATUS_STALL_MASK  (1 << 2)

typedef struct {
    volatile uint32_t* base_addr;
    int uio_fd;
} pge_device_t;

int pge_init(pge_device_t* dev, const char* uio_path, size_t map_size) {
    dev->uio_fd = open(uio_path, O_RDWR | O_SYNC);
    if (dev->uio_fd < 0) {
        perror("Failed to open UIO device");
        return -1;
    }

    dev->base_addr = (volatile uint32_t*)mmap(NULL, map_size, PROT_READ | PROT_WRITE, MAP_SHARED, dev->uio_fd, 0);
    if (dev->base_addr == MAP_FAILED) {
        perror("mmap failed");
        close(dev->uio_fd);
        return -1;
    }
    return 0;
}

void pge_set_trust_ceiling(pge_device_t* dev, uint8_t ceiling) {
    dev->base_addr[PGE_REG_TRUST_CFG / 4] = (uint32_t)ceiling;
}

uint32_t pge_get_status(pge_device_t* dev) {
    return dev->base_addr[PGE_REG_STATUS / 4];
}

void pge_acknowledge_trap(pge_device_t* dev) {
    dev->base_addr[PGE_REG_CTRL / 4] = 0x1; // Assert trap_ack
}

void pge_release(pge_device_t* dev, size_t map_size) {
    if (dev->base_addr != MAP_FAILED) {
        munmap((void*)dev->base_addr, map_size);
    }
    if (dev->uio_fd >= 0) {
        close(dev->uio_fd);
    }
}
