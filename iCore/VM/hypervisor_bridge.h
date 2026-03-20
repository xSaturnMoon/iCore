#pragma once
#include <stdint.h>
#include <stddef.h>

// Manually declare only the hv_* functions we need.
// Do NOT define HV_SUCCESS or HV_MEMORY_* — Darwin already has them.
// Do NOT include Hypervisor/Hypervisor.h — it doesn't exist in iOS SDK.

typedef uint64_t hv_vcpu_t;
typedef int32_t  hv_return_t;

typedef struct {
    uint64_t syndrome;
    uint64_t physical_address;
    uint64_t pc;
    uint8_t  is_data_abort;
} hv_vcpu_exit_mmio_t;

typedef struct {
    uint32_t reason;
    hv_vcpu_exit_mmio_t mmio;
} hv_vcpu_exit_t;

#ifdef __cplusplus
extern "C" {
#endif

hv_return_t hv_vm_create(void* _Nullable config);
hv_return_t hv_vm_destroy(void);
hv_return_t hv_vm_map(void* _Nonnull uva, uint64_t gpa, size_t size, uint64_t flags);
hv_return_t hv_vm_unmap(uint64_t gpa, size_t size);
hv_return_t hv_vcpu_create(hv_vcpu_t* _Nonnull vcpu,
                            hv_vcpu_exit_t* _Nullable * _Nullable exit,
                            void* _Nullable config);
hv_return_t hv_vcpu_destroy(hv_vcpu_t vcpu);
hv_return_t hv_vcpu_run(hv_vcpu_t vcpu);
hv_return_t hv_vcpu_get_reg(hv_vcpu_t vcpu, uint32_t reg, uint64_t* _Nonnull value);
hv_return_t hv_vcpu_set_reg(hv_vcpu_t vcpu, uint32_t reg, uint64_t value);

#ifdef __cplusplus
}
#endif
