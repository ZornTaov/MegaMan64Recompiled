#include "ovl_patches.hpp"

#include "librecomp/overlays.hpp"

#ifndef MM64_HAS_RECOMPILED_PATCHES
#define MM64_HAS_RECOMPILED_PATCHES 0
#endif

#if MM64_HAS_RECOMPILED_PATCHES
#include "../../RecompiledPatches/patches_bin.h"
#include "generated_patch_overlays.hpp"
#endif

void zelda64::register_patches() {
#if MM64_HAS_RECOMPILED_PATCHES
    recomp::overlays::register_patches(mm_patches_bin, sizeof(mm_patches_bin), section_table, num_sections);
#endif
}
