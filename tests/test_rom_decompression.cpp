#include <algorithm>
#include <array>
#include <cstdint>
#include <cstdlib>
#include <cstring>
#include <span>
#include <vector>

#include "zelda_game.h"

static int failures = 0;

#define CHECK(cond) \
    do { \
        if (!(cond)) { \
            failures++; \
            return; \
        } \
    } while (0)

namespace {

constexpr size_t kCompressedRomSize = 0x2000000;
constexpr size_t kDecompressedRomSize = 0x2F00000;
constexpr size_t kDmaTableRomAddr = 0x1A500;

struct DmaDataEntry {
    uint32_t vrom_start;
    uint32_t vrom_end;
    uint32_t rom_start;
    uint32_t rom_end;
};

uint32_t to_big_endian(uint32_t value) {
    return ((value & 0x000000FFu) << 24)
         | ((value & 0x0000FF00u) << 8)
         | ((value & 0x00FF0000u) >> 8)
         | ((value & 0xFF000000u) >> 24);
}

void write_dma_entry(std::vector<uint8_t>& rom, size_t entry_index, const DmaDataEntry& entry) {
    const std::array<uint32_t, 4> values = {
        to_big_endian(entry.vrom_start),
        to_big_endian(entry.vrom_end),
        to_big_endian(entry.rom_start),
        to_big_endian(entry.rom_end),
    };

    const size_t offset = kDmaTableRomAddr + entry_index * sizeof(DmaDataEntry);
    std::memcpy(rom.data() + offset, values.data(), sizeof(values));
}

uint32_t read_be_u32(const std::vector<uint8_t>& data, size_t offset) {
    uint32_t value = 0;
    std::memcpy(&value, data.data() + offset, sizeof(value));
    return to_big_endian(value);
}

std::vector<uint8_t> make_valid_test_rom() {
    std::vector<uint8_t> rom(kCompressedRomSize, 0);

    rom[0x3B] = 'N';
    rom[0x3C] = 'Z';
    rom[0x3D] = 'S';
    rom[0x3E] = 'E';

    const DmaDataEntry content_entry{
        .vrom_start = 0x0001B000,
        .vrom_end = 0x0001B004,
        .rom_start = 0x00020000,
        .rom_end = 0x00000000,
    };
    write_dma_entry(rom, 0, content_entry);
    write_dma_entry(rom, 1, DmaDataEntry{});

    rom[content_entry.rom_start + 0] = 'T';
    rom[content_entry.rom_start + 1] = 'E';
    rom[content_entry.rom_start + 2] = 'S';
    rom[content_entry.rom_start + 3] = 'T';

    return rom;
}

} // namespace

static void test_rejects_wrong_rom_size() {
    std::vector<uint8_t> rom(16, 0);
    CHECK(zelda64::decompress_mm(rom).empty());
}

static void test_rejects_wrong_rom_header() {
    std::vector<uint8_t> rom(kCompressedRomSize, 0);
    rom[0x3B] = 'B';
    rom[0x3C] = 'A';
    rom[0x3D] = 'D';
    rom[0x3E] = '!';

    CHECK(zelda64::decompress_mm(rom).empty());
}

static void test_decompresses_valid_rom_and_rewrites_dma_entry() {
    const std::vector<uint8_t> rom = make_valid_test_rom();
    const std::vector<uint8_t> decompressed = zelda64::decompress_mm(rom);

    CHECK(decompressed.size() == kDecompressedRomSize);
    CHECK(std::equal(
        decompressed.begin() + 0x1B000,
        decompressed.begin() + 0x1B004,
        std::array<uint8_t, 4>{'T', 'E', 'S', 'T'}.begin()));

    CHECK(read_be_u32(decompressed, kDmaTableRomAddr + 0x00) == 0x0001B000);
    CHECK(read_be_u32(decompressed, kDmaTableRomAddr + 0x04) == 0x0001B004);
    CHECK(read_be_u32(decompressed, kDmaTableRomAddr + 0x08) == 0x0001B000);
    CHECK(read_be_u32(decompressed, kDmaTableRomAddr + 0x0C) == 0x00000000);

    CHECK(decompressed[0x1C000] == 0xFF);
    CHECK(decompressed.back() == 0xFF);
}

int main() {
    test_rejects_wrong_rom_size();
    test_rejects_wrong_rom_header();
    test_decompresses_valid_rom_and_rewrites_dma_entry();
    return failures ? EXIT_FAILURE : EXIT_SUCCESS;
}
