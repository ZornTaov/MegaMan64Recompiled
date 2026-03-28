#include <vector>
#include "zelda_debug.h"

// Mega Man 64-specific debug warp data has not been mapped yet.
// Keep the table empty so the debug UI can disable the warp controls
// instead of exposing Majora's Mask placeholder destinations.
std::vector<zelda64::AreaWarps> zelda64::game_warps{};
