package io.sentry.flutter

import android.content.Context
import android.content.pm.PackageInfo
import android.os.Build
import io.sentry.EventProcessor
import io.sentry.Hint
import io.sentry.SentryEvent
import io.sentry.SentryLevel
import io.sentry.SentryOptions
import io.sentry.protocol.DebugImage
import io.sentry.protocol.DebugMeta
import java.io.BufferedInputStream
import java.io.EOFException
import java.io.File
import java.io.IOException
import java.io.InputStream
import java.io.RandomAccessFile
import java.nio.ByteBuffer
import java.nio.ByteOrder
import java.security.MessageDigest
import java.util.Properties
import java.util.UUID
import java.util.zip.ZipFile

/**
 * Resolves the ProGuard UUID of an app minified by R8 from its R8 map ID, so
 * Java/Kotlin frames can be deobfuscated without the Sentry Android Gradle
 * Plugin (SAGP).
 *
 * R8 writes the same map ID into the header of `mapping.txt`
 * (`# pg_map_id: <id>`) and into the `~~R8{"backend":"dex",...,"pg-map-id":...}`
 * marker in every DEX file. sentry_dart_plugin uploads the mapping under
 * [uuidFromMapId] of the former; this reads the latter at runtime.
 *
 * The DEX header (checksum, signature) can't be used instead: Google Play's
 * automatic protection rewrites `classes.dex`, which changes both.
 */
internal object R8ProguardUuid {
  private const val CACHE_FILE_NAME = "io.sentry.flutter.r8-proguard-uuid"
  private const val DEBUG_META_PROPERTIES = "sentry-debug-meta.properties"
  private const val SAGP_PROGUARD_UUIDS = "io.sentry.ProguardUuids"
  private const val PROGUARD_IMAGE_TYPE = "proguard"

  /**
   * Configures the ProGuard UUID of [options], in order of precedence:
   * 1. An explicitly set [SentryOptions.proguardUuid]: left as is.
   * 2. SAGP's `io.sentry.ProguardUuids`: left for the native SDK to apply,
   *    since SAGP uploads the mapping under that UUID.
   * 3. The UUID of the R8 map ID in `classes.dex`.
   * 4. Otherwise nothing (ProGuard, DexGuard or no minification).
   *
   * Call from the options configuration of `SentryAndroid.init`. A result
   * cached for this app release, or a stored (uncompressed) `classes.dex`, is
   * applied before this returns. A compressed `classes.dex` is read on a
   * background thread, so events captured before it finishes, on the first
   * launch after an install or update, go out without the ProGuard image.
   */
  fun configure(
    context: Context,
    options: SentryOptions,
  ) {
    if (!options.proguardUuid.isNullOrEmpty()) {
      return
    }
    val logger = options.logger
    if (hasSagpProguardUuid(context)) {
      logger.log(SentryLevel.DEBUG, "Using the ProGuard UUID of the Sentry Android Gradle Plugin.")
      return
    }

    val holder = UuidHolder()
    options.addEventProcessor(MultipleProguardImagesProcessor(holder))

    val releaseKey =
      try {
        releaseKey(context)
      } catch (e: Exception) {
        logger.log(SentryLevel.WARNING, "Failed to read the app's package info.", e)
        return
      }
    val cache = Cache(File(context.cacheDir, CACHE_FILE_NAME))
    cache.read(releaseKey)?.let {
      apply(options, holder, it)
      return
    }

    val apkPath = context.applicationInfo.sourceDir
    val fromTail =
      try {
        readMapIdsFromStoredDex(apkPath)
      } catch (e: Exception) {
        logger.log(SentryLevel.DEBUG, "Failed to read the stored classes.dex.", e)
        null
      }
    if (fromTail != null) {
      val uuids = fromTail.map(::uuidFromMapId)
      cache.write(releaseKey, uuids)
      apply(options, holder, uuids)
      return
    }

    // Compressed: a full read can take 150 ms or more for a large app.
    Thread({
      try {
        val uuids = readMapIdsFromApk(apkPath).map(::uuidFromMapId)
        // Also caches a miss, so a build without an R8 marker isn't scanned
        // again on every launch.
        cache.write(releaseKey, uuids)
        apply(options, holder, uuids)
      } catch (e: Exception) {
        logger.log(SentryLevel.WARNING, "Failed to read the R8 map ID.", e)
      }
    }, "SentryR8MapIdReader").apply {
      isDaemon = true
      start()
    }
  }

  private fun apply(
    options: SentryOptions,
    holder: UuidHolder,
    uuids: List<String>,
  ) {
    when {
      uuids.isEmpty() -> options.logger.log(SentryLevel.DEBUG, "No R8 map ID found in classes.dex.")
      uuids.size == 1 -> if (options.proguardUuid.isNullOrEmpty()) options.proguardUuid = uuids[0]
      else -> holder.uuids = uuids
    }
  }

  private fun hasSagpProguardUuid(context: Context): Boolean =
    try {
      context.assets.open(DEBUG_META_PROPERTIES).use { input ->
        val properties = Properties().apply { load(input) }
        !properties.getProperty(SAGP_PROGUARD_UUIDS).isNullOrBlank()
      }
    } catch (_: IOException) {
      false
    }

  /** Identifies the installed build: an update or reinstall invalidates the cache. */
  private fun releaseKey(context: Context): String {
    val info: PackageInfo = context.packageManager.getPackageInfo(context.packageName, 0)
    val versionCode =
      if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
        info.longVersionCode
      } else {
        @Suppress("DEPRECATION")
        info.versionCode.toLong()
      }
    return "${info.versionName}+$versionCode@${info.lastUpdateTime}"
  }

  internal class UuidHolder {
    @Volatile
    var uuids: List<String> = emptyList()
  }

  /**
   * With several distinct `"backend":"dex"` map IDs (rare), the native SDK
   * can only carry one ProGuard UUID, so each one is added as its own image.
   */
  internal class MultipleProguardImagesProcessor(
    private val holder: UuidHolder,
  ) : EventProcessor {
    override fun process(
      event: SentryEvent,
      hint: Hint,
    ): SentryEvent {
      val uuids = holder.uuids
      if (uuids.isEmpty()) return event
      val debugMeta = event.debugMeta ?: DebugMeta()
      val images = debugMeta.images ?: mutableListOf()
      for (uuid in uuids) {
        if (images.none { it.type == PROGUARD_IMAGE_TYPE && it.uuid == uuid }) {
          images.add(
            DebugImage().apply {
              type = PROGUARD_IMAGE_TYPE
              this.uuid = uuid
            },
          )
        }
      }
      debugMeta.images = images
      event.debugMeta = debugMeta
      return event
    }
  }

  // region DEX marker

  private const val MARKER_PREFIX = "~~R8{"
  private const val MAX_MARKER_LENGTH = 4096
  private const val MAX_STRING_IDS = 1 shl 24
  private const val DEX_HEADER_SIZE = 0x70
  private const val STRING_IDS_SIZE_OFFSET = 0x38
  private const val TILDE = '~'.code

  private val backendRegex = Regex("\"backend\"\\s*:\\s*\"dex\"")
  private val mapIdRegex = Regex("\"pg-map-id\"\\s*:\\s*\"([0-9a-fA-F]+)\"")

  /**
   * Returns the distinct map IDs of the `~~R8` markers with `"backend":"dex"`.
   * Markers with `"backend":"cf"` come from libraries that were minified
   * before being added to the app. Filtering on the whole marker also skips
   * literals like `"~~R8{"` that the SDK's own code puts into the string
   * table.
   */
  fun mapIdsOf(markers: List<String>): List<String> =
    markers
      .filter { it.startsWith(MARKER_PREFIX) && backendRegex.containsMatchIn(it) }
      .mapNotNull { mapIdRegex.find(it)?.groupValues?.get(1)?.lowercase() }
      .distinct()

  /** Reads `classes.dex` of the APK at [apkPath] in full. The app's marker is in every DEX file. */
  fun readMapIdsFromApk(apkPath: String): List<String> =
    ZipFile(apkPath).use { zip ->
      val entry = zip.getEntry("classes.dex") ?: return emptyList()
      zip.getInputStream(entry).use { mapIdsOf(readR8MarkersFromStream(it)) }
    }

  /**
   * Reads the map IDs from the end of the string table when `classes.dex` is
   * stored uncompressed, as Play delivers it (under 1 ms for a 10 MB DEX).
   * Returns null if it's compressed or can't be located, so the caller falls
   * back to [readMapIdsFromApk].
   */
  fun readMapIdsFromStoredDex(apkPath: String): List<String>? =
    RandomAccessFile(apkPath, "r").use { file ->
      val dexOffset = ZipLocator.storedEntryOffset(file, "classes.dex") ?: return null
      mapIdsOf(readR8MarkersFromTail(file, dexOffset))
    }

  /**
   * Strings in a DEX are sorted, so the `~~` markers sit near the end of the
   * string table. Walks it backwards from the last string until one sorts
   * before `~`. Strings that sort after `~` (non-ASCII) can come last, so
   * those are skipped, and there's no fixed window: apps carry 19+ markers.
   */
  fun readR8MarkersFromTail(
    file: RandomAccessFile,
    dexOffset: Long,
  ): List<String> {
    val header = ByteArray(DEX_HEADER_SIZE)
    file.seek(dexOffset)
    file.readFully(header)
    val (stringIdsSize, stringIdsOffset) = parseHeader(header)

    val ids = ByteArray(stringIdsSize * 4)
    file.seek(dexOffset + stringIdsOffset)
    file.readFully(ids)
    val idBuffer = ByteBuffer.wrap(ids).order(ByteOrder.LITTLE_ENDIAN)

    val markers = mutableListOf<String>()
    val buffer = ByteArray(MAX_MARKER_LENGTH + 5)
    for (index in stringIdsSize - 1 downTo 0) {
      val dataOffset = idBuffer.getInt(index * 4).toLong() and 0xffffffffL
      file.seek(dexOffset + dataOffset)
      val read = file.read(buffer)
      if (read <= 0) throw EOFException()
      var pos = 0
      // Skip the ULEB128 UTF-16 length.
      while (pos < read && buffer[pos].toInt() and 0x80 != 0) pos++
      pos++
      if (pos >= read) continue
      val first = buffer[pos].toInt() and 0xff
      if (first == 0) {
        // The empty string sorts first; nothing before it.
        break
      }
      if (first < TILDE) break
      if (first > TILDE) continue // non-ASCII or DEL, sorts after '~'
      val end = (pos until read).firstOrNull { buffer[it].toInt() == 0 } ?: read
      markers.add(String(buffer, pos, end - pos, Charsets.ISO_8859_1))
    }
    return markers.filter { it.startsWith(MARKER_PREFIX) }
  }

  /**
   * Returns every string starting with `~~R8{` in the DEX read from [input],
   * in a single forward pass: the string IDs, then the string data in offset
   * order. Only the first byte of most strings is looked at.
   */
  fun readR8MarkersFromStream(input: InputStream): List<String> {
    val reader = StreamReader(BufferedInputStream(input))
    val (stringIdsSize, stringIdsOffset) = parseHeader(reader.readBytes(DEX_HEADER_SIZE))

    reader.skipTo(stringIdsOffset)
    val ids = ByteBuffer.wrap(reader.readBytes(stringIdsSize * 4)).order(ByteOrder.LITTLE_ENDIAN)
    val offsets = LongArray(stringIdsSize) { ids.getInt(it * 4).toLong() and 0xffffffffL }
    offsets.sort()

    val markers = mutableListOf<String>()
    for (offset in offsets) {
      if (offset < reader.position) continue // duplicate or malformed
      reader.skipTo(offset)
      reader.skipUleb128()
      if (reader.read() != TILDE) continue
      val string = reader.readCString(MAX_MARKER_LENGTH)
      if (string.startsWith(MARKER_PREFIX)) markers.add(string)
    }
    return markers
  }

  private fun parseHeader(header: ByteArray): Pair<Int, Long> {
    if (String(header, 0, 3, Charsets.ISO_8859_1) != "dex") {
      throw IOException("Not a DEX file")
    }
    val buffer = ByteBuffer.wrap(header).order(ByteOrder.LITTLE_ENDIAN)
    val size = buffer.getInt(STRING_IDS_SIZE_OFFSET)
    val offset = buffer.getInt(STRING_IDS_SIZE_OFFSET + 4).toLong() and 0xffffffffL
    if (size !in 0..MAX_STRING_IDS || offset < DEX_HEADER_SIZE) {
      throw IOException("Invalid DEX string IDs")
    }
    return size to offset
  }

  /** Reads a DEX forward, tracking the position. */
  private class StreamReader(
    private val input: InputStream,
  ) {
    var position = 0L
      private set

    fun read(): Int {
      val b = input.read()
      if (b < 0) throw EOFException()
      position++
      return b
    }

    fun readBytes(count: Int): ByteArray {
      val bytes = ByteArray(count)
      var read = 0
      while (read < count) {
        val n = input.read(bytes, read, count - read)
        if (n < 0) throw EOFException()
        read += n
      }
      position += count
      return bytes
    }

    fun skipTo(offset: Long) {
      var remaining = offset - position
      while (remaining > 0) {
        val skipped = input.skip(remaining)
        if (skipped <= 0) {
          read()
          remaining--
        } else {
          position += skipped
          remaining -= skipped
        }
      }
    }

    fun skipUleb128() {
      repeat(5) { if (read() and 0x80 == 0) return }
      throw IOException("Invalid ULEB128")
    }

    /** Reads the rest of a NUL-terminated `~` string. Markers are ASCII. */
    fun readCString(maxLength: Int): String {
      val builder = StringBuilder("~")
      while (builder.length < maxLength) {
        val b = read()
        if (b == 0) break
        builder.append(b.toChar())
      }
      return builder.toString()
    }
  }

  // endregion

  // region UUID

  /** The namespace sentry-cli uses for ProGuard UUIDs: uuid5(NAMESPACE_DNS, "guardsquare.com"). */
  val proguardNamespace: UUID =
    uuid5(UUID.fromString("6ba7b810-9dad-11d1-80b4-00c04fd430c8"), "guardsquare.com")

  /**
   * The UUID sentry_dart_plugin uploads the mapping under:
   * uuid5(uuid5(NAMESPACE_DNS, "guardsquare.com"), mapId). Must match the
   * plugin's `proguardUuidFromMapId`.
   */
  fun uuidFromMapId(mapId: String): String = uuid5(proguardNamespace, mapId.lowercase()).toString()

  private fun uuid5(
    namespace: UUID,
    name: String,
  ): UUID {
    val digest = MessageDigest.getInstance("SHA-1")
    digest.update(
      ByteBuffer
        .allocate(16)
        .putLong(namespace.mostSignificantBits)
        .putLong(namespace.leastSignificantBits)
        .array(),
    )
    val hash = digest.digest(name.toByteArray(Charsets.UTF_8))
    hash[6] = ((hash[6].toInt() and 0x0f) or 0x50).toByte() // version 5
    hash[8] = ((hash[8].toInt() and 0x3f) or 0x80).toByte() // RFC 4122 variant
    val bytes = ByteBuffer.wrap(hash, 0, 16)
    return UUID(bytes.long, bytes.long)
  }

  // endregion

  /** Line 1: the release key. Line 2: the UUIDs, comma separated (empty if none). */
  private class Cache(
    private val file: File,
  ) {
    fun read(releaseKey: String): List<String>? =
      try {
        val lines = file.readLines()
        if (lines.isNotEmpty() && lines[0] == releaseKey) {
          lines.getOrNull(1).orEmpty().split(',').filter { it.isNotBlank() }
        } else {
          null
        }
      } catch (_: IOException) {
        null
      }

    fun write(
      releaseKey: String,
      uuids: List<String>,
    ) {
      try {
        // Overwrites the entry of a previous release.
        file.writeText("$releaseKey\n${uuids.joinToString(",")}")
      } catch (_: IOException) {
        // Only costs a rescan on the next launch.
      }
    }
  }
}

/** Finds where a stored (uncompressed) ZIP entry's data starts, without decompressing anything. */
internal object ZipLocator {
  private const val EOCD_SIGNATURE = 0x06054b50
  private const val CENTRAL_SIGNATURE = 0x02014b50
  private const val LOCAL_SIGNATURE = 0x04034b50
  private const val EOCD_SIZE = 22
  private const val MAX_COMMENT = 0xffff
  private const val METHOD_STORED = 0

  /**
   * Returns the data offset of [name] if it's stored, or null if it's
   * compressed, missing or in a ZIP64 archive.
   */
  fun storedEntryOffset(
    file: RandomAccessFile,
    name: String,
  ): Long? {
    val length = file.length()
    val tailSize = minOf(length, (EOCD_SIZE + MAX_COMMENT).toLong()).toInt()
    val tail = ByteArray(tailSize)
    file.seek(length - tailSize)
    file.readFully(tail)
    val tailBuffer = ByteBuffer.wrap(tail).order(ByteOrder.LITTLE_ENDIAN)
    val eocd =
      (tailSize - EOCD_SIZE downTo 0).firstOrNull { tailBuffer.getInt(it) == EOCD_SIGNATURE }
        ?: return null
    val entries = tailBuffer.getShort(eocd + 10).toInt() and 0xffff
    val centralSize = tailBuffer.getInt(eocd + 12).toLong() and 0xffffffffL
    val centralOffset = tailBuffer.getInt(eocd + 16).toLong() and 0xffffffffL
    if (centralOffset == 0xffffffffL || centralSize > Int.MAX_VALUE) return null

    val central = ByteArray(centralSize.toInt())
    file.seek(centralOffset)
    file.readFully(central)
    val buffer = ByteBuffer.wrap(central).order(ByteOrder.LITTLE_ENDIAN)
    val nameBytes = name.toByteArray(Charsets.UTF_8)
    var pos = 0
    repeat(entries) {
      if (pos + 46 > central.size || buffer.getInt(pos) != CENTRAL_SIGNATURE) return null
      val method = buffer.getShort(pos + 10).toInt() and 0xffff
      val nameLength = buffer.getShort(pos + 28).toInt() and 0xffff
      val extraLength = buffer.getShort(pos + 30).toInt() and 0xffff
      val commentLength = buffer.getShort(pos + 32).toInt() and 0xffff
      val localOffset = buffer.getInt(pos + 42).toLong() and 0xffffffffL
      if (nameLength == nameBytes.size &&
        central.copyOfRange(pos + 46, pos + 46 + nameLength).contentEquals(nameBytes)
      ) {
        if (method != METHOD_STORED || localOffset == 0xffffffffL) return null
        val local = ByteArray(30)
        file.seek(localOffset)
        file.readFully(local)
        val localBuffer = ByteBuffer.wrap(local).order(ByteOrder.LITTLE_ENDIAN)
        if (localBuffer.getInt(0) != LOCAL_SIGNATURE) return null
        val localName = localBuffer.getShort(26).toInt() and 0xffff
        val localExtra = localBuffer.getShort(28).toInt() and 0xffff
        return localOffset + 30 + localName + localExtra
      }
      pos += 46 + nameLength + extraLength + commentLength
    }
    return null
  }
}
