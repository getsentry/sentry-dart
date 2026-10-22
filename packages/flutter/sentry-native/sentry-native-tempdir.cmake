# Clones sentry-native into a short temp dir and copies the working tree,
# without .git, into the build dir. Nested submodule git dirs then never land
# under the (possibly deep) build dir.
# https://github.com/getsentry/sentry-dart/issues/3969
function(sentry_native_fetch_via_tempdir)
    set(src_dir "${FETCHCONTENT_BASE_DIR}/sentry-native-src")
    set(stamp_file "${src_dir}/.sentry-native-stamp")
    set(stamp "${SENTRY_NATIVE_repo};${SENTRY_NATIVE_version};${sentry_native_submodules}")

    set(existing_stamp "")
    if(EXISTS "${stamp_file}")
        file(READ "${stamp_file}" existing_stamp)
    endif()

    if(NOT existing_stamp STREQUAL stamp)
        find_package(Git REQUIRED)

        if(WIN32)
            file(TO_CMAKE_PATH "$ENV{TEMP}" temp_root)
        elseif(NOT "$ENV{TMPDIR}" STREQUAL "")
            set(temp_root "$ENV{TMPDIR}")
        else()
            set(temp_root "/tmp")
        endif()
        string(RANDOM LENGTH 8 suffix)
        set(clone_dir "${temp_root}/sn-${suffix}")

        set(recurse_args)
        if(sentry_native_submodules)
            foreach(submodule IN LISTS sentry_native_submodules)
                list(APPEND recurse_args "--recurse-submodules=${submodule}")
            endforeach()
        else()
            set(recurse_args "--recurse-submodules")
        endif()

        message(STATUS "Cloning sentry-native into ${clone_dir}")
        execute_process(
            COMMAND "${GIT_EXECUTABLE}" -c advice.detachedHead=false
                clone --depth 1 --branch ${SENTRY_NATIVE_version}
                ${recurse_args} --shallow-submodules
                ${SENTRY_NATIVE_repo} "${clone_dir}"
            RESULT_VARIABLE clone_result
        )
        if(NOT clone_result EQUAL 0)
            file(REMOVE_RECURSE "${clone_dir}")
            message(FATAL_ERROR "Failed to clone sentry-native into ${clone_dir}")
        endif()

        # Copy rather than rename: the temp dir may be on another volume, and
        # renaming into place fails on some mounts (#3630).
        file(REMOVE_RECURSE "${clone_dir}/.git")
        file(REMOVE_RECURSE "${src_dir}")
        file(COPY "${clone_dir}/" DESTINATION "${src_dir}")
        file(REMOVE_RECURSE "${clone_dir}")
        file(WRITE "${stamp_file}" "${stamp}")
    endif()

    set(FETCHCONTENT_SOURCE_DIR_SENTRY-NATIVE "${src_dir}" PARENT_SCOPE)
endfunction()
