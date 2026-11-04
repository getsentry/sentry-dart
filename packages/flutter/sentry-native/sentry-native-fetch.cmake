# Downloads the sentry-native release zip into ${FETCHCONTENT_BASE_DIR}/sn-src
# and sets FETCHCONTENT_SOURCE_DIR_SN. Sets ${out} to FALSE when the download
# or extraction fails so the caller can fall back to git. A hash mismatch is
# fatal.
#
# The release zip has no .git metadata, so no nested submodule git dirs end up
# under a deep build dir and exceed the Windows MAX_PATH limit.
# https://github.com/getsentry/sentry-dart/issues/3969
function(sentry_native_fetch_zip out)
    set(${out} FALSE PARENT_SCOPE)
    set(src_dir "${FETCHCONTENT_BASE_DIR}/sn-src")
    set(stamp_file "${src_dir}/.sentry-native-stamp")
    set(stamp "zip;${SENTRY_NATIVE_repo};${SENTRY_NATIVE_version};${SENTRY_NATIVE_sha256}")

    set(existing_stamp "")
    if(EXISTS "${stamp_file}")
        file(READ "${stamp_file}" existing_stamp)
    endif()

    if(NOT existing_stamp STREQUAL stamp)
        set(zip_file "${FETCHCONTENT_BASE_DIR}/sn.zip")
        set(url "${SENTRY_NATIVE_repo}/releases/download/${SENTRY_NATIVE_version}/sentry-native.zip")
        message(STATUS "Downloading ${url}")
        file(DOWNLOAD "${url}" "${zip_file}" STATUS download_status TLS_VERIFY ON)
        list(GET download_status 0 download_code)
        list(GET download_status 1 download_message)
        if(NOT download_code EQUAL 0)
            file(REMOVE "${zip_file}")
            # Leave a clean tree for the git fallback to clone into.
            file(REMOVE_RECURSE "${src_dir}")
            message(WARNING "Failed to download sentry-native zip: ${download_message}")
            return()
        endif()

        file(SHA256 "${zip_file}" actual_sha256)
        if(NOT actual_sha256 STREQUAL SENTRY_NATIVE_sha256)
            file(REMOVE "${zip_file}")
            message(FATAL_ERROR "sentry-native zip hash mismatch: expected ${SENTRY_NATIVE_sha256}, got ${actual_sha256}")
        endif()

        file(REMOVE_RECURSE "${src_dir}")
        file(MAKE_DIRECTORY "${src_dir}")
        execute_process(
            COMMAND "${CMAKE_COMMAND}" -E tar xf "${zip_file}"
            WORKING_DIRECTORY "${src_dir}"
            RESULT_VARIABLE extract_result
        )
        file(REMOVE "${zip_file}")
        if(NOT extract_result EQUAL 0)
            file(REMOVE_RECURSE "${src_dir}")
            message(WARNING "Failed to extract sentry-native zip")
            return()
        endif()
        file(WRITE "${stamp_file}" "${stamp}")
    endif()

    set(FETCHCONTENT_SOURCE_DIR_SN "${src_dir}" PARENT_SCOPE)
    set(${out} TRUE PARENT_SCOPE)
endfunction()
