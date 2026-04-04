if(NOT DEFINED SOURCE_FILE OR NOT DEFINED OUTPUT_FILE)
    message(FATAL_ERROR "generate_patch_overlay_header.cmake requires SOURCE_FILE and OUTPUT_FILE.")
endif()

if(NOT EXISTS "${SOURCE_FILE}")
    message(FATAL_ERROR "Patch overlay source not found: ${SOURCE_FILE}")
endif()

get_filename_component(OUTPUT_DIR "${OUTPUT_FILE}" DIRECTORY)
if(OUTPUT_DIR)
    file(MAKE_DIRECTORY "${OUTPUT_DIR}")
endif()

file(READ "${SOURCE_FILE}" SOURCE_CONTENTS)

if(SOURCE_CONTENTS MATCHES "const size_t num_sections = 0;")
    file(WRITE "${OUTPUT_FILE}"
        "#pragma once\n"
        "#include <cstddef>\n"
        "#include \"librecomp/sections.h\"\n"
        "\n"
        "static SectionTableEntry section_table[] = {\n"
        "    { 0 },\n"
        "};\n"
        "const size_t num_sections = 0;\n"
    )
else()
    file(TO_CMAKE_PATH "${SOURCE_FILE}" SOURCE_FILE_CMAKE_PATH)
    file(WRITE "${OUTPUT_FILE}"
        "#pragma once\n"
        "#include \"${SOURCE_FILE_CMAKE_PATH}\"\n"
    )
endif()
