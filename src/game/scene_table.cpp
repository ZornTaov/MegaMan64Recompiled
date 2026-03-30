#include <string>
#include <vector>

#include "zelda_debug.h"

// Debug warp indices match the Mega Man 64 prototype debug menu (The Cutting Room Floor,
// "Proto:Mega Man 64"): STAGE runs 0 .. 0x1E (30), and SCENARIO runs 0 .. 0xF.
// `do_warp` packs: high byte = stage, bits 7-4 of low byte = scenario (entrance index).
//
// Friendly names use PSX stage rips where ST labels are known (sprites-inc / MMLS):
// ST04 Apple Market, ST06 City Hall, ST08 Uptown, ST0C Cardon Forest, ST10 Yass Plains,
// ST11 Clozer Wood, ST13 Clozer ruins, ST1A Main Gate. Other slots are labeled by index
// until the community pins them down.

namespace {

std::vector<std::string> scenario_entrances() {
    std::vector<std::string> v;
    v.reserve(16);
    for (int i = 0; i < 16; ++i) {
        v.emplace_back("Scenario " + std::to_string(i));
    }
    return v;
}

const std::vector<std::string> kScenarios = scenario_entrances();

} // namespace

std::vector<zelda64::AreaWarps> zelda64::game_warps{
    {"Title & intro",
     {
         {0, "Stage 0 — title / menu", kScenarios},
         {1, "Stage 1 — prologue (air pirate attack)", kScenarios},
         {2, "Stage 2 — Flutter (airship interior)", kScenarios},
         {3, "Stage 3 — Kattelox beach / opening", kScenarios},
     }},
    {"Kattelox Town",
     {
         {4, "Apple Market (ST04)", kScenarios},
         {5, "Old Town / Library (ST05)", kScenarios},
         {6, "City Hall (ST06)", kScenarios},
         {7, "Stage 7 — downtown block", kScenarios},
         {8, "Uptown (ST08)", kScenarios},
         {9, "Stage 9 — town (unmapped)", kScenarios},
         {10, "Stage 0x0A — town / interior", kScenarios},
         {11, "Stage 0x0B — town / interior", kScenarios},
     }},
    {"Fields & forest",
     {
         {12, "Cardon Forest (ST0C)", kScenarios},
         {13, "Stage 0x0D — overworld (unmapped)", kScenarios},
         {14, "Stage 0x0E — overworld (unmapped)", kScenarios},
         {15, "Stage 0x0F — overworld (unmapped)", kScenarios},
         {16, "Yass Plains (ST10)", kScenarios},
         {17, "Clozer Wood (ST11)", kScenarios},
         {18, "Stage 0x12 — overworld (unmapped)", kScenarios},
         {19, "Clozer Wood ruins (ST13)", kScenarios},
     }},
    {"Ruins & subgates",
     {
         {20, "Stage 20 — ruin / subgate (unmapped)", kScenarios},
         {21, "Stage 21 — ruin / subgate (unmapped)", kScenarios},
         {22, "Stage 22 — ruin / subgate (unmapped)", kScenarios},
         {23, "Stage 23 — ruin / subgate (unmapped)", kScenarios},
         {24, "Stage 24 — ruin / subgate (unmapped)", kScenarios},
         {25, "Stage 25 — ruin / subgate (unmapped)", kScenarios},
         {26, "Main Gate ruin (ST1A)", kScenarios},
     }},
    {"Finale",
     {
         {27, "Stage 27 — late game (unmapped)", kScenarios},
         {28, "Stage 28 — late game (unmapped)", kScenarios},
         {29, "Stage 29 — late game (unmapped)", kScenarios},
         {30, "Stage 30 — late game (unmapped)", kScenarios},
     }},
};
