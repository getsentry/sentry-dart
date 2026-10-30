# Clones sentry-native with its git dir in a short temp dir, so nested
# submodule git dirs never land under the (possibly deep) build dir.
#   tempdir         - clone into the temp dir, then copy the working tree,
#                     without .git, into the build dir
#   tempdir-move    - same, but move the top-level entries instead of copying;
#                     falls back to copying when the move fails, such as
#                     across volumes
#   separate-gitdir - check the working tree out directly into the build dir
#                     with --separate-git-dir, then delete the git dir
# https://github.com/getsentry/sentry-dart/issues/3969
function(_sentry_native_now_ms out)
    string(TIMESTAMP now "%s%f")
    math(EXPR now "${now} / 1000")
    set(${out} ${now} PARENT_SCOPE)
endfunction()

function(_sentry_native_phase name start_ms)
    _sentry_native_now_ms(now)
    math(EXPR elapsed "${now} - ${start_ms}")
    message(STATUS "sentry-native phase ${name}: ${elapsed} ms")
endfunction()

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
        _sentry_native_now_ms(phase_start)
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
        _sentry_native_phase(clone ${phase_start})

        if(method STREQUAL "tempdir")
            # Copy rather than rename: the temp dir may be on another volume,
            # and renaming into place fails on some mounts (#3630).
            _sentry_native_now_ms(phase_start)
            file(REMOVE_RECURSE "${temp_dir}/.git")
            _sentry_native_phase(delete-git ${phase_start})
            _sentry_native_now_ms(phase_start)
            file(COPY "${temp_dir}/" DESTINATION "${src_dir}")
            _sentry_native_phase(copy ${phase_start})
        elseif(method STREQUAL "tempdir-move")
            _sentry_native_now_ms(phase_start)
            file(MAKE_DIRECTORY "${src_dir}")
            file(GLOB entries LIST_DIRECTORIES true RELATIVE "${temp_dir}" "${temp_dir}/*")
            list(REMOVE_ITEM entries ".git")
            set(moved 0)
            set(copied 0)
            foreach(entry IN LISTS entries)
                file(RENAME "${temp_dir}/${entry}" "${src_dir}/${entry}" RESULT rename_result)
                if(rename_result EQUAL 0)
                    math(EXPR moved "${moved} + 1")
                else()
                    file(COPY "${temp_dir}/${entry}" DESTINATION "${src_dir}")
                    math(EXPR copied "${copied} + 1")
                endif()
            endforeach()
            _sentry_native_phase("move (${moved} moved, ${copied} copied)" ${phase_start})
        endif()
        _sentry_native_now_ms(phase_start)
        file(REMOVE_RECURSE "${temp_dir}")
        _sentry_native_phase(delete-temp ${phase_start})
        file(WRITE "${stamp_file}" "${stamp}")
    endif()

    set(FETCHCONTENT_SOURCE_DIR_SN "${src_dir}" PARENT_SCOPE)
endfunction()
