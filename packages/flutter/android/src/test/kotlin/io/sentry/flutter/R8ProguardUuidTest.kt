package io.sentry.flutter

import io.sentry.Hint
import io.sentry.SentryEvent
import io.sentry.protocol.DebugImage
import io.sentry.protocol.DebugMeta
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Rule
import org.junit.Test
import org.junit.rules.TemporaryFolder
import java.io.ByteArrayInputStream
import java.io.ByteArrayOutputStream
import java.io.File
import java.io.RandomAccessFile
import java.nio.ByteBuffer
import java.nio.ByteOrder
import java.util.zip.CRC32
import java.util.zip.ZipEntry
import java.util.zip.ZipOutputStream

class R8ProguardUuidTest {
  @get:Rule
  val tmp = TemporaryFolder()

  private val appMapId = "f9245ea8f32c0d479b2e12eac7d01f87792e3464ee8d263e8a365d7651196605"
  private val appUuid = "072e7281-9c81-34d3-8619-c4ae24deb47b"
  private val shortMapId = "1bab4a8"
  private val shortUuid = "6b578c6e-74aa-3dc4-88ce-0d13d6802d5b"

  private fun marker(
    backend: String,
    mapId: String,
  ) = "~~R8{\"backend\":\"$backend\",\"compilation-mode\":\"release\"," +
    "\"pg-map-id\":\"$mapId\",\"r8-mode\":\"full\",\"version\":\"8.6.17\"}"

  /** Strings like a real app's: library markers, our own literals, non-ASCII strings after '~'. */
  private fun appStrings(vararg extra: String) =
    listOf(
      "",
      "Lcom/example/Foo;",
      "pg-map-id",
      "\"pg-map-id\":\"",
      "~~R8{",
      "~~D8{\"backend\":\"dex\",\"min-api\":21}",
      "é",
      "日本",
      "\u007f",
    ) + (1..19).map { marker("cf", "%064x".format(it)) } + extra

  @Test
  fun `derives the UUID like the Sentry Android Gradle Plugin`() {
    // SAGP uploads under UUID.nameUUIDFromBytes(pg_map_hash), which equals
    // the 64 hex pg_map_id on current R8.
    assertEquals(
      java.util.UUID.nameUUIDFromBytes(appMapId.toByteArray(Charsets.UTF_8)).toString(),
      R8ProguardUuid.uuidFromMapId(appMapId),
    )
  }

  @Test
  fun `derives the UUID of a 64 hex map ID`() {
    assertEquals(appUuid, R8ProguardUuid.uuidFromMapId(appMapId))
  }

  @Test
  fun `derives the UUID of a 7 hex map ID`() {
    assertEquals(shortUuid, R8ProguardUuid.uuidFromMapId(shortMapId))
  }

  @Test
  fun `lowercases the map ID`() {
    assertEquals(appUuid, R8ProguardUuid.uuidFromMapId(appMapId.uppercase()))
  }

  @Test
  fun `reads only the dex backend map ID from a stored DEX`() {
    val apk = apk(dex(appStrings(marker("dex", appMapId))), stored = true)

    assertEquals(listOf(appMapId), R8ProguardUuid.readMapIdsFromStoredDex(apk.path))
  }

  @Test
  fun `reads only the dex backend map ID from a compressed DEX`() {
    val apk = apk(dex(appStrings(marker("dex", appMapId))), stored = false)

    assertEquals(listOf(appMapId), R8ProguardUuid.readMapIdsFromApk(apk.path))
  }

  @Test
  fun `does not read a compressed DEX from the tail`() {
    val apk = apk(dex(appStrings(marker("dex", appMapId))), stored = false)

    assertNull(R8ProguardUuid.readMapIdsFromStoredDex(apk.path))
  }

  @Test
  fun `reads a 7 hex map ID`() {
    val apk = apk(dex(appStrings(marker("dex", shortMapId))), stored = true)

    assertEquals(listOf(shortMapId), R8ProguardUuid.readMapIdsFromStoredDex(apk.path))
  }

  @Test
  fun `returns no map ID without a dex backend marker`() {
    val dex = dex(appStrings())
    val stored = apk(dex, stored = true)
    val compressed = apk(dex, stored = false)

    assertEquals(emptyList<String>(), R8ProguardUuid.readMapIdsFromStoredDex(stored.path))
    assertEquals(emptyList<String>(), R8ProguardUuid.readMapIdsFromApk(compressed.path))
  }

  @Test
  fun `returns each distinct dex backend map ID`() {
    val strings =
      appStrings(
        marker("dex", appMapId),
        marker("dex", shortMapId),
        marker("dex", appMapId) + " ",
      )

    assertEquals(
      setOf(appMapId, shortMapId),
      R8ProguardUuid.readMapIdsFromStoredDex(apk(dex(strings), stored = true).path)!!.toSet(),
    )
    assertEquals(
      setOf(appMapId, shortMapId),
      R8ProguardUuid.readMapIdsFromApk(apk(dex(strings), stored = false).path).toSet(),
    )
  }

  @Test
  fun `tail and full read find the same markers`() {
    val bytes = dex(appStrings(marker("dex", appMapId)))
    val file = tmp.newFile().apply { writeBytes(bytes) }

    val tail = RandomAccessFile(file, "r").use { R8ProguardUuid.readR8MarkersFromTail(it, 0) }
    val full = R8ProguardUuid.readR8MarkersFromStream(ByteArrayInputStream(bytes))

    assertEquals(full.toSet(), tail.toSet())
    assertEquals(21, full.size) // 19 cf, 1 dex, our own "~~R8{" literal
  }

  @Test
  fun `adds one proguard image per map ID`() {
    val holder = R8ProguardUuid.UuidHolder().apply { uuids = listOf(appUuid, shortUuid) }
    val event =
      SentryEvent().apply {
        debugMeta =
          DebugMeta().apply {
            images =
              mutableListOf(
                DebugImage().apply {
                  type = "proguard"
                  uuid = appUuid
                },
              )
          }
      }

    R8ProguardUuid.MultipleProguardImagesProcessor(holder).process(event, Hint())

    assertEquals(listOf(appUuid, shortUuid), event.debugMeta!!.images!!.map { it.uuid })
  }

  @Test
  fun `adds no image without map IDs`() {
    val event = SentryEvent()

    val processor = R8ProguardUuid.MultipleProguardImagesProcessor(R8ProguardUuid.UuidHolder())

    processor.process(event, Hint())

    assertNull(event.debugMeta)
  }

  /** A minimal DEX: header, sorted string IDs, then the string data. */
  private fun dex(strings: List<String>): ByteArray {
    val sorted = strings.distinct().sorted() // UTF-16 order, as in a DEX
    val idsOffset = 0x70
    val data = ByteArrayOutputStream()
    val dataOffset = idsOffset + sorted.size * 4
    val offsets = mutableListOf<Int>()
    for (string in sorted) {
      offsets.add(dataOffset + data.size())
      var length = string.length
      while (length >= 0x80) {
        data.write((length and 0x7f) or 0x80)
        length = length ushr 7
      }
      data.write(length)
      data.write(string.toByteArray(Charsets.UTF_8))
      data.write(0)
    }
    val buffer = ByteBuffer.allocate(dataOffset + data.size()).order(ByteOrder.LITTLE_ENDIAN)
    buffer.put("dex\n035\u0000".toByteArray(Charsets.ISO_8859_1))
    buffer.putInt(0x38, sorted.size)
    buffer.putInt(0x3c, idsOffset)
    buffer.position(idsOffset)
    offsets.forEach { buffer.putInt(it) }
    buffer.put(data.toByteArray())
    return buffer.array()
  }

  private fun apk(
    dex: ByteArray,
    stored: Boolean,
  ): File {
    val file = tmp.newFile()
    ZipOutputStream(file.outputStream()).use { zip ->
      zip.putNextEntry(ZipEntry("AndroidManifest.xml"))
      zip.write(ByteArray(100))
      zip.closeEntry()
      val entry = ZipEntry("classes.dex")
      if (stored) {
        entry.method = ZipEntry.STORED
        entry.size = dex.size.toLong()
        entry.crc = CRC32().apply { update(dex) }.value
      }
      zip.putNextEntry(entry)
      zip.write(dex)
      zip.closeEntry()
    }
    return file
  }
}
