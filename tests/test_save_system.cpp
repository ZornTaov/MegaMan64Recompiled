#include <algorithm>
#include <array>
#include <cstdint>
#include <cstdlib>
#include <cstdio>
#include <cstring>
#include <exception>
#include <string>
#include <vector>

#include "recomp.h"
#include "librecomp/addresses.hpp"
#include "ultramodern/error_handling.hpp"
#include "ultramodern/ultra64.h"
#include "zelda_config.h"

extern "C" void osFlashInit_recomp(uint8_t* rdram, recomp_context* ctx);
extern "C" void osFlashAllErase_recomp(uint8_t* rdram, recomp_context* ctx);
extern "C" void osFlashSectorErase_recomp(uint8_t* rdram, recomp_context* ctx);
extern "C" void osFlashWriteBuffer_recomp(uint8_t* rdram, recomp_context* ctx);
extern "C" void osFlashWriteArray_recomp(uint8_t* rdram, recomp_context* ctx);
extern "C" void osFlashReadArray_recomp(uint8_t* rdram, recomp_context* ctx);

static int failures = 0;

#define CHECK(cond) \
    do { \
        if (!(cond)) { \
            std::fprintf(stderr, "save_system CHECK failed at line %d: %s\n", __LINE__, #cond); \
            failures++; \
            return; \
        } \
    } while (0)

namespace {

constexpr uint32_t kFlashSize = 1024 * 1024 / 8;
constexpr uint32_t kPageSize = 128;
constexpr uint32_t kPageCount = kFlashSize / kPageSize;
constexpr uint32_t kTestPage = 3;

struct QuickExitException final : std::exception {};

bool g_flashram_allowed = true;
int g_send_message_calls = 0;
PTR(OSMesgQueue) g_last_queue = 0;
std::vector<char> g_save_buffer(kFlashSize, 0);
std::vector<std::string> g_error_messages{};
std::vector<std::string> g_quicksave_dialogs{};

PTR(void) ptr_from_offset(uint32_t offset) {
    return static_cast<PTR(void)>(0x80000000u + offset);
}

void reset_stub_state() {
    g_flashram_allowed = true;
    g_send_message_calls = 0;
    g_last_queue = 0;
    std::fill(g_save_buffer.begin(), g_save_buffer.end(), 0);
    g_error_messages.clear();
    g_quicksave_dialogs.clear();
}

void set_byte(uint8_t* rdram, PTR(void) addr, uint32_t offset, uint8_t value) {
    const gpr reg = static_cast<gpr>(static_cast<int32_t>(addr));
    MEM_B(offset, reg) = static_cast<int8_t>(value);
}

uint8_t get_byte(uint8_t* rdram, PTR(void) addr, uint32_t offset) {
    const gpr reg = static_cast<gpr>(static_cast<int32_t>(addr));
    return static_cast<uint8_t>(MEM_BU(offset, reg));
}

void set_word(uint8_t* rdram, PTR(void) addr, uint32_t offset, uint32_t value) {
    const gpr reg = static_cast<gpr>(static_cast<int32_t>(addr));
    MEM_W(offset, reg) = static_cast<int32_t>(value);
}

} // namespace

namespace recomp {

bool flashram_allowed() {
    return g_flashram_allowed;
}

} // namespace recomp

namespace ultramodern::error_handling {

void message_box(const char* msg) {
    g_error_messages.emplace_back(msg);
}

[[noreturn]] void quick_exit(const char* filename, int line, const char* func, int exit_status) {
    (void)filename;
    (void)line;
    (void)func;
    (void)exit_status;
    throw QuickExitException{};
}

} // namespace ultramodern::error_handling

namespace zelda64 {

void show_error_message_box(const char* title, const char* message) {
    g_quicksave_dialogs.emplace_back(std::string(title) + ": " + message);
}

} // namespace zelda64

extern "C" s32 osSendMesg(RDRAM_ARG PTR(OSMesgQueue) mq, OSMesg msg, s32 flags) {
    (void)rdram;
    (void)msg;
    (void)flags;
    g_send_message_calls++;
    g_last_queue = mq;
    return 0;
}

void save_write_ptr(const void* in, uint32_t offset, uint32_t count) {
    std::memcpy(g_save_buffer.data() + offset, in, count);
}

void save_write(RDRAM_ARG PTR(void) rdram_address, uint32_t offset, uint32_t count) {
    const gpr reg = static_cast<gpr>(static_cast<int32_t>(rdram_address));
    for (uint32_t i = 0; i < count; i++) {
        g_save_buffer[offset + i] = static_cast<char>(MEM_BU(i, reg));
    }
}

void save_read(RDRAM_ARG PTR(void) rdram_address, uint32_t offset, uint32_t count) {
    const gpr reg = static_cast<gpr>(static_cast<int32_t>(rdram_address));
    for (uint32_t i = 0; i < count; i++) {
        MEM_B(i, reg) = static_cast<int8_t>(g_save_buffer[offset + i]);
    }
}

void save_clear(uint32_t start, uint32_t size, char value) {
    std::fill_n(g_save_buffer.begin() + start, size, value);
}

static void test_flash_init() {
    reset_stub_state();
    std::vector<uint8_t> rdram(0x4000, 0);
    recomp_context ctx{};

    osFlashInit_recomp(rdram.data(), &ctx);
    CHECK(static_cast<int32_t>(ctx.r2) == recomp::flash_handle);
}

static void test_flash_sector_erase_and_bounds() {
    reset_stub_state();
    std::fill(g_save_buffer.begin(), g_save_buffer.end(), static_cast<char>(0x5A));

    std::vector<uint8_t> rdram(0x4000, 0);
    recomp_context ctx{};
    ctx.r4 = 1;
    osFlashSectorErase_recomp(rdram.data(), &ctx);

    CHECK(static_cast<int32_t>(ctx.r2) == 0);
    CHECK(std::all_of(
        g_save_buffer.begin() + kPageSize,
        g_save_buffer.begin() + (2 * kPageSize),
        [](char value) { return static_cast<unsigned char>(value) == 0xFF; }));
    CHECK(static_cast<unsigned char>(g_save_buffer[0]) == 0x5A);
    CHECK(static_cast<unsigned char>(g_save_buffer[2 * kPageSize]) == 0x5A);

    const std::vector<char> before_invalid = g_save_buffer;
    ctx.r4 = kPageCount;
    osFlashSectorErase_recomp(rdram.data(), &ctx);
    CHECK(static_cast<int32_t>(ctx.r2) == -1);
    CHECK(g_save_buffer == before_invalid);
}

static void test_flash_write_read_and_all_erase() {
    reset_stub_state();
    std::vector<uint8_t> rdram(0x4000, 0);
    recomp_context ctx{};

    const PTR(void) source_addr = ptr_from_offset(0x200);
    const PTR(void) dest_addr = ptr_from_offset(0x400);
    const PTR(void) io_msg_addr = ptr_from_offset(0x500);
    const PTR(OSMesgQueue) queue_addr = static_cast<PTR(OSMesgQueue)>(ptr_from_offset(0x600));
    const PTR(void) stack_addr = ptr_from_offset(0x800);

    std::array<uint8_t, kPageSize> page_data{};
    for (size_t i = 0; i < page_data.size(); i++) {
        page_data[i] = static_cast<uint8_t>(i);
        set_byte(rdram.data(), source_addr, static_cast<uint32_t>(i), page_data[i]);
        set_byte(rdram.data(), dest_addr, static_cast<uint32_t>(i), 0);
    }

    ctx.r4 = io_msg_addr;
    ctx.r6 = source_addr;
    ctx.r7 = queue_addr;
    osFlashWriteBuffer_recomp(rdram.data(), &ctx);
    CHECK(static_cast<int32_t>(ctx.r2) == 0);
    CHECK(g_send_message_calls == 1);
    CHECK(g_last_queue == queue_addr);

    ctx = {};
    ctx.r4 = kTestPage;
    osFlashWriteArray_recomp(rdram.data(), &ctx);
    CHECK(static_cast<int32_t>(ctx.r2) == 0);
    CHECK(std::equal(
        g_save_buffer.begin() + (kTestPage * kPageSize),
        g_save_buffer.begin() + ((kTestPage + 1) * kPageSize),
        page_data.begin()));

    ctx = {};
    ctx.r4 = io_msg_addr;
    ctx.r7 = dest_addr;
    ctx.r29 = stack_addr;
    ctx.r6 = kTestPage;
    set_word(rdram.data(), stack_addr, 0x10, 1);
    set_word(rdram.data(), stack_addr, 0x14, static_cast<uint32_t>(queue_addr));
    osFlashReadArray_recomp(rdram.data(), &ctx);
    CHECK(static_cast<int32_t>(ctx.r2) == 0);
    CHECK(g_send_message_calls == 2);
    for (size_t i = 0; i < page_data.size(); i++) {
        CHECK(get_byte(rdram.data(), dest_addr, static_cast<uint32_t>(i)) == page_data[i]);
    }

    ctx = {};
    osFlashAllErase_recomp(rdram.data(), &ctx);
    CHECK(static_cast<int32_t>(ctx.r2) == 0);
    CHECK(std::all_of(g_save_buffer.begin(), g_save_buffer.end(), [](char value) {
        return static_cast<unsigned char>(value) == 0xFF;
    }));
}

static void test_quicksave_warning_only_shows_once() {
    reset_stub_state();

    zelda64::quicksave_save();
    zelda64::quicksave_load();
    zelda64::quicksave_save();

    CHECK(g_quicksave_dialogs.size() == 1);
    CHECK(g_quicksave_dialogs[0].find("Quicksave Unavailable") != std::string::npos);
    CHECK(g_quicksave_dialogs[0].find("F5 and F7 are currently disabled") != std::string::npos);
}

int main() {
    test_flash_init();
    test_flash_sector_erase_and_bounds();
    test_flash_write_read_and_all_erase();
    test_quicksave_warning_only_shows_once();
    return failures ? EXIT_FAILURE : EXIT_SUCCESS;
}
