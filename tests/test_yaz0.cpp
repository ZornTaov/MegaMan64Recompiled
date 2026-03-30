#include <cstring>
#include <cstdlib>

#include "yaz0.h"

static int failures = 0;

#define CHECK(cond) \
    do { \
        if (!(cond)) { \
            failures++; \
            return; \
        } \
    } while (0)

static void test_single_literal() {
    uint8_t in[] = {0x80, 0x41};
    uint8_t out[4] = {};
    yaz0_decompress(in, out);
    CHECK(out[0] == 0x41);
}

static void test_two_literals() {
    uint8_t in[] = {0xC0, 0x41, 0x42};
    uint8_t out[4] = {};
    yaz0_decompress(in, out);
    CHECK(out[0] == 0x41 && out[1] == 0x42);
}

static void test_truncated_copy_group() {
    uint8_t in[] = {0x00, 0x10};
    uint8_t out[8] = {};
    yaz0_decompress(in, out);
    CHECK(out[0] == 0);
}

static void test_invalid_backref_before_any_output() {
    uint8_t in[] = {0x00, 0x10, 0x00};
    uint8_t out[16] = {};
    yaz0_decompress(in, out);
    CHECK(out[0] == 0);
}

static void test_literal_then_valid_backref() {
    // Layout 0x80: first bit literal 'A', second bit 2-byte ref (0x10,0x00) -> offset 1, length 3 copies 'A' three times.
    uint8_t in[] = {0x80, 0x41, 0x10, 0x00};
    uint8_t out[8] = {};
    yaz0_decompress(in, out);
    CHECK(out[0] == 0x41 && out[1] == 0x41 && out[2] == 0x41 && out[3] == 0x41);
}

static void test_output_buffer_too_small_for_backref() {
    uint8_t in[] = {0x80, 0x41, 0x10, 0x00};
    uint8_t out[2] = {};
    yaz0_decompress(in, out);
    CHECK(out[0] == 0x41 && out[1] == 0);
}

int main() {
    test_single_literal();
    test_two_literals();
    test_truncated_copy_group();
    test_invalid_backref_before_any_output();
    test_literal_then_valid_backref();
    test_output_buffer_too_small_for_backref();
    return failures ? EXIT_FAILURE : EXIT_SUCCESS;
}
