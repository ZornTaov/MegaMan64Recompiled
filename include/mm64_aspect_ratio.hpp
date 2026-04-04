#ifndef __MM64_ASPECT_RATIO_HPP__
#define __MM64_ASPECT_RATIO_HPP__

#include <algorithm>

#include "ultramodern/config.hpp"

namespace mm64 {

inline float compute_window_aspect_ratio(int width, int height, float fallback) {
    if ((width <= 0) || (height <= 0)) {
        return fallback;
    }

    return static_cast<float>(width) / static_cast<float>(height);
}

inline float compute_target_aspect_ratio(ultramodern::renderer::AspectRatio option, float original, int width, int height) {
    const float safe_original = std::max(original, 0.1f);
    const float window_aspect = compute_window_aspect_ratio(width, height, safe_original);

    switch (option) {
        case ultramodern::renderer::AspectRatio::Expand:
        case ultramodern::renderer::AspectRatio::Manual:
            // Manual is not exposed through the current config UI, so fall back to
            // the same safe widened target until a dedicated manual value is plumbed through.
            return std::max(window_aspect, safe_original);
        case ultramodern::renderer::AspectRatio::Original:
        case ultramodern::renderer::AspectRatio::OptionCount:
        default:
            return safe_original;
    }
}

} // namespace mm64

#endif
