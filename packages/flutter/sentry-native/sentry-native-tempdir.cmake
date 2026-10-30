# Clones sentry-native with its git dir in a short temp dir, so nested
# submodule git dirs never land under the (possibly deep) build dir.
#   tempdir         - clone into the temp dir, then copy the working tree,
#                     without .git, into the build dir
#   separate-gitdir - check the working tree out directly into the build dir
#                     with --separate-git-dir, then delete the git dir
# https://github.com/getsentry/sentry-dart/issues/3969
function(sentry_native_fetch_via_tempdir method)
    set(src_dir "${FETCHCONTENT_BASE_DIR}/sn-src")
    set(stamp_file "${src_dir}/.sentry-native-stamp")
    set(stamp "${method};${SENTRY_NATIVE_repo};${SENTRY_NATIVE_version};${sentry_native_submodules}")

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
        set(temp_dir "${temp_root}/sn-${suffix}")

        set(recurse_args)
        if(sentry_native_submodules)
            foreach(submodule IN LISTS sentry_native_submodules)
                list(APPEND recurse_args "--recurse-submodules=${submodule}")
            endforeach()
        else()
            set(recurse_args "--recurse-submodules")
        endif()

        file(REMOVE_RECURSE "${src_dir}")
        if(method STREQUAL "separate-gitdir")
            set(clone_args "--separate-git-dir=${temp_dir}" "${src_dir}")
        else()
            set(clone_args "${temp_dir}")
        endif()

        message(STATUS "Cloning sentry-native (${method}) with git dir in ${temp_dir}")
        execute_process(
            COMMAND "${GIT_EXECUTABLE}" -c advice.detachedHead=false
                clone --depth 1 --branch ${SENTRY_NATIVE_version}
                ${recurse_args} --shallow-submodules
                ${SENTRY_NATIVE_repo} ${clone_args}
            RESULT_VARIABLE clone_result
        )
        if(NOT clone_result EQUAL 0)
            file(REMOVE_RECURSE "${temp_dir}")
            message(FATAL_ERROR "Failed to clone sentry-native (${method})")
        endif()

        if(method STREQUAL "tempdir")
            # Copy rather than rename: the temp dir may be on another volume,
            # and renaming into place fails on some mounts (#3630).
            file(REMOVE_RECURSE "${temp_dir}/.git")
            file(COPY "${temp_dir}/" DESTINATION "${src_dir}")
        endif()
        file(REMOVE_RECURSE "${temp_dir}")
        file(WRITE "${stamp_file}" "${stamp}")
    endif()

    set(FETCHCONTENT_SOURCE_DIR_SN "${src_dir}" PARENT_SCOPE)
endfunction()
