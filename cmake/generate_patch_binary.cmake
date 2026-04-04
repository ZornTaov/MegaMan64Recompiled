if(NOT DEFINED INPUT_FILE OR NOT DEFINED OUTPUT_C OR NOT DEFINED OUTPUT_H OR NOT DEFINED SYMBOL_NAME OR NOT DEFINED FILE_TO_C)
    message(FATAL_ERROR "generate_patch_binary.cmake requires INPUT_FILE, OUTPUT_C, OUTPUT_H, SYMBOL_NAME, and FILE_TO_C.")
endif()

if(NOT EXISTS "${INPUT_FILE}")
    message(FATAL_ERROR "Patch binary not found: ${INPUT_FILE}")
endif()

get_filename_component(OUTPUT_C_DIR "${OUTPUT_C}" DIRECTORY)
get_filename_component(OUTPUT_H_DIR "${OUTPUT_H}" DIRECTORY)
if(OUTPUT_C_DIR)
    file(MAKE_DIRECTORY "${OUTPUT_C_DIR}")
endif()
if(OUTPUT_H_DIR)
    file(MAKE_DIRECTORY "${OUTPUT_H_DIR}")
endif()

file(SIZE "${INPUT_FILE}" INPUT_SIZE)

if(INPUT_SIZE EQUAL 0)
    file(WRITE "${OUTPUT_C}"
        "extern const char ${SYMBOL_NAME}[1];\n"
        "const char ${SYMBOL_NAME}[1] = { 0 };\n"
    )
    file(WRITE "${OUTPUT_H}"
        "#ifdef __cplusplus\n"
        "  extern \"C\" {\n"
        "#endif\n"
        "extern const char ${SYMBOL_NAME}[1];\n"
        "#ifdef __cplusplus\n"
        "  }\n"
        "#endif\n"
    )
else()
    execute_process(
        COMMAND "${FILE_TO_C}" "${INPUT_FILE}" "${SYMBOL_NAME}" "${OUTPUT_C}" "${OUTPUT_H}"
        RESULT_VARIABLE FILE_TO_C_RESULT
    )
    if(NOT FILE_TO_C_RESULT EQUAL 0)
        message(FATAL_ERROR "file_to_c failed for ${INPUT_FILE} with exit code ${FILE_TO_C_RESULT}")
    endif()
endif()
