#include <cstdio>

#include "yaz0.h"

namespace {

void naive_copy(std::span<uint8_t> dst, std::span<const uint8_t> src) {
    for (size_t i = 0; i < src.size(); i++) {
        dst[i] = src[i];
    }
}

} // namespace

void yaz0_decompress(std::span<const uint8_t> input, std::span<uint8_t> output) {
    size_t input_pos = 0;
    size_t output_pos = 0;

    size_t input_size = input.size();
    size_t output_size = output.size();

    while (input_pos < input_size) {
        int32_t layoutBitIndex = 0;
        uint8_t layoutBits = input[input_pos++];

        while (layoutBitIndex < 8 && input_pos < input_size && output_pos < output_size) {
            if (layoutBits & 0x80) {
                if (input_pos >= input_size) break;
                output[output_pos++] = input[input_pos++];
            } else {
                if (input_pos + 1 >= input_size) break;
                int32_t firstByte = input[input_pos++];
                int32_t secondByte = input[input_pos++];
                uint32_t bytes = static_cast<uint32_t>(firstByte << 8 | secondByte);
                uint32_t offset = (bytes & 0x0FFF) + 1;
                uint32_t length;

                if ((firstByte & 0xF0) == 0) {
                    if (input_pos >= input_size) break;
                    int32_t thirdByte = input[input_pos++];
                    length = static_cast<uint32_t>(thirdByte) + 0x12;
                } else {
                    length = ((bytes & 0xF000) >> 12) + 2;
                }

                if (offset > output_pos || output_pos + length > output_size) {
                    fprintf(stderr, "yaz0_decompress: invalid back-reference (output_pos=%zu, offset=%u, length=%u, output_size=%zu)\n",
                            output_pos, offset, length, output_size);
                    return;
                }

                naive_copy(output.subspan(output_pos, length), output.subspan(output_pos - offset, length));
                output_pos += length;
            }

            layoutBitIndex++;
            layoutBits <<= 1;
        }
    }
}
