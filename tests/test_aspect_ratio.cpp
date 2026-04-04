#include <cmath>
#include <cstdlib>

#include "mm64_aspect_ratio.hpp"

static int failures = 0;

#define CHECK(cond) \
    do { \
        if (!(cond)) { \
            failures++; \
            return; \
        } \
    } while (0)

namespace {

bool nearly_equal(float lhs, float rhs) {
    return std::fabs(lhs - rhs) < 0.0001f;
}

} // namespace

static void test_original_mode_preserves_original_ratio() {
    const float result = mm64::compute_target_aspect_ratio(
        ultramodern::renderer::AspectRatio::Original, 4.0f / 3.0f, 1920, 1080);
    CHECK(nearly_equal(result, 4.0f / 3.0f));
}

static void test_expand_mode_uses_window_ratio_when_wider() {
    const float result = mm64::compute_target_aspect_ratio(
        ultramodern::renderer::AspectRatio::Expand, 4.0f / 3.0f, 1920, 1080);
    CHECK(nearly_equal(result, 16.0f / 9.0f));
}

static void test_expand_mode_never_squeezes_below_original() {
    const float result = mm64::compute_target_aspect_ratio(
        ultramodern::renderer::AspectRatio::Expand, 4.0f / 3.0f, 1024, 1024);
    CHECK(nearly_equal(result, 4.0f / 3.0f));
}

static void test_invalid_window_size_falls_back_to_original() {
    const float result = mm64::compute_target_aspect_ratio(
        ultramodern::renderer::AspectRatio::Expand, 4.0f / 3.0f, 1920, 0);
    CHECK(nearly_equal(result, 4.0f / 3.0f));
}

static void test_manual_mode_uses_safe_widescreen_fallback() {
    const float result = mm64::compute_target_aspect_ratio(
        ultramodern::renderer::AspectRatio::Manual, 4.0f / 3.0f, 2560, 1440);
    CHECK(nearly_equal(result, 16.0f / 9.0f));
}

int main() {
    test_original_mode_preserves_original_ratio();
    test_expand_mode_uses_window_ratio_when_wider();
    test_expand_mode_never_squeezes_below_original();
    test_invalid_window_size_falls_back_to_original();
    test_manual_mode_uses_safe_widescreen_fallback();
    return failures ? EXIT_FAILURE : EXIT_SUCCESS;
}
