package com.awkati.domain.prayer

import com.google.common.truth.Truth.assertThat
import kotlinx.datetime.LocalDate
import kotlinx.datetime.TimeZone
import org.junit.jupiter.api.Test

class SegmentsTest {

    private val engine: PrayerTimeEngine = AdhanPrayerTimeEngine()
    private val abuDhabi = GeoCoordinates(latitude = 24.4539, longitude = 54.3773)
    private val gulfTz = TimeZone.of("Asia/Dubai")

    @Test
    fun `six segments tile the day with no gaps or overlaps`() {
        val today = engine.calculate(abuDhabi, LocalDate(2026, 7, 10), gulfTz)
        val tomorrow = engine.calculate(abuDhabi, LocalDate(2026, 7, 11), gulfTz)

        val windows = today.toSegmentWindows(tomorrowFajr = tomorrow[Prayer.FAJR])
        assertThat(windows).hasSize(6)

        for (i in 0 until windows.size - 1) {
            assertThat(windows[i].end).isEqualTo(windows[i + 1].start)
        }
        assertThat(windows.first().start).isEqualTo(today[Prayer.FAJR])
        assertThat(windows.last().end).isEqualTo(tomorrow[Prayer.FAJR])
    }

    @Test
    fun `segmentAt resolves a time to exactly one segment`() {
        val today = engine.calculate(abuDhabi, LocalDate(2026, 7, 10), gulfTz)
        val tomorrow = engine.calculate(abuDhabi, LocalDate(2026, 7, 11), gulfTz)
        val windows = today.toSegmentWindows(tomorrowFajr = tomorrow[Prayer.FAJR])

        val justAfterDhuhr = today[Prayer.DHUHR]
        assertThat(windows.segmentAt(justAfterDhuhr)).isEqualTo(DaySegment.DHUHR_TO_ASR)

        val justBeforeFajr = today[Prayer.FAJR]
        assertThat(windows.segmentAt(justBeforeFajr)).isEqualTo(DaySegment.FAJR_TO_SUNRISE)
    }
}
