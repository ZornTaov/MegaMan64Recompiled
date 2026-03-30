#include <atomic>
#include <cstdint>
#include <cstdio>

#include "recomp.h"
#include "zelda_config.h"
#include "zelda_support.h"

namespace {
    // The runtime hooks needed for a safe full-state quicksave are not available
    // in this project yet, so keep the public entry points as explicit no-ops.
    constexpr bool quicksave_supported = false;
    constexpr const char* quicksave_unsupported_message =
        "Quicksave is not supported in this build yet. F5 and F7 are currently disabled.";
    std::atomic_bool quicksave_warning_shown = false;

    void show_quicksave_unsupported_message() {
        if (!quicksave_supported && !quicksave_warning_shown.exchange(true)) {
            fprintf(stderr, "%s\n", quicksave_unsupported_message);
            zelda64::show_error_message_box("Quicksave Unavailable", quicksave_unsupported_message);
        }
    }
}

void zelda64::quicksave_save() {
    show_quicksave_unsupported_message();
}

void zelda64::quicksave_load() {
    show_quicksave_unsupported_message();
}

extern "C" void recomp_handle_quicksave_actions(uint8_t* rdram, recomp_context* ctx) {
    (void)rdram;
    (void)ctx;
}

extern "C" void recomp_handle_quicksave_actions_main(uint8_t* rdram, recomp_context* ctx) {
    (void)rdram;
    (void)ctx;
}
