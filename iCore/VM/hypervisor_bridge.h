#pragma once
#include <stdint.h>
#include <stddef.h>

typedef int          hv_return_t;
typedef uint64_t     hv_vcpu_t;
typedef uint64_t     hv_gpaddr_t;
typedef uint64_t     hv_ipa_t;

#define HV_SUCCESS 0

/* VM lifecycle */
extern hv_return_t hv_vm_create(void *config);
extern hv_return_t hv_vm_destroy(void);
extern hv_return_t hv_vm_map(void *uva, hv_gpaddr_t gpa, size_t size, uint64_t flags);
extern hv_return_t hv_vm_unmap(hv_gpaddr_t gpa, size_t size);

/* vCPU exit info — opaque forward declaration */
typedef struct hv_vcpu_exit hv_vcpu_exit_t;

/* vCPU lifecycle */
extern hv_return_t hv_vcpu_create(hv_vcpu_t *vcpu, hv_vcpu_exit_t **exit, void *config);
extern hv_return_t hv_vcpu_destroy(hv_vcpu_t vcpu);
extern hv_return_t hv_vcpu_run(hv_vcpu_t vcpu);
extern hv_return_t hv_vcpu_get_reg(hv_vcpu_t vcpu, uint32_t reg, uint64_t *value);
extern hv_return_t hv_vcpu_set_reg(hv_vcpu_t vcpu, uint32_t reg, uint64_t value);

/* Memory protection flags */
#define HV_MEMORY_READ  (1ULL << 0)
#define HV_MEMORY_WRITE (1ULL << 1)
#define HV_MEMORY_EXEC  (1ULL << 2)

/* ARM64 register indices (hv_reg_t enum values) */
#define HV_REG_X0    0
#define HV_REG_X1    1
#define HV_REG_PC   32
#define HV_REG_CPSR 33
