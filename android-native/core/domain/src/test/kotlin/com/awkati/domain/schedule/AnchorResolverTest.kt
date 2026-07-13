package com.awkati.domain.schedule

import com.awkati.domain.prayer.AdhanPrayerTimeEngine
import com.awkati.domain.prayer.DaySegment
import com.awkati.domain.prayer.GeoCoordinates
import com.awkati.domain.prayer.Prayer
import com.awkati.domain.prayer.PrayerTimeEngine
import com.google.common.truth.Truth.assertThat
import kotlinx.datetime.LocalDate
import kotlinx.datetime.LocalTime
import kotlinx.datetime.TimeZone
import org.junit.jupiter.api.Test

class AnchorResolverTest {

    private val engine: PrayerTimeEngine = AdhanPrayerTimeEngine()
    private val abuDhabi = GeoCoordinates(latitude = 24.4539, longitude = 54.3773)
    private val gulfTz = TimeZone.of("Asia/Dubai")
    private val date = LocalDate(2026, 7, 10)
    private val prayerTimes = engine.calculate(abuDhabi, date, gulfTz)

    @Test
    fun `clock anchor resolves to that time on the date`() {
        val resolved = resolveAnchorTime(Anchor.Clock(LocalTime(14, 30)), date, prayerTimes)
        assertThat(resolved).isNotNull()
        assertThat(resolved!!.date).isEqualTo(date)
        assertThat(resolved.hour).isEqualTo(14)
        assertThat(resolved.minute).isEqualTo(30)
    }

    @Test
    fun `prayer-relative anchor with positive offset lands after the prayer`() {
        val dhuhr = prayerTimes[Prayer.DHUHR]
        val resolved = resolveAnchorTime(
            Anchor.PrayerRelative(Prayer.DHUHR, offsetMinutes = 15),
            date,
            prayerTimes,
        )
        assertThat(resolved).isNotNull()
        // 15 minutes after Dhuhr, to the minute.
        val deltaMinutes = (resolved!!.hour - dhuhr.hour) * 60 + (resolved.minute - dhuhr.minute)
        assertThat(deltaMinutes).isEqualTo(15)
    }

    @Test
    fun `prayer-relative anchor with negative offset lands before the prayer`() {
        val maghrib = prayerTimes[Prayer.MAGHRIB]
        val resolved = resolveAnchorTime(
            Anchor.PrayerRelative(Prayer.MAGHRIB, offsetMinutes = -20),
            date,
            prayerTimes,
        )
        val deltaMinutes = (resolved!!.hour - maghrib.hour) * 60 + (resolved.minute - maghrib.minute)
        assertThat(deltaMinutes).isEqualTo(-20)
    }

    @Test
    fun `large negative offset before Fajr crosses to the previous day`() {
        val fajr = prayerTimes[Prayer.FAJR]
        // A pre-reminder far enough before Fajr to land on the previous date.
        val minutesToMidnight = fajr.hour * 60 + fajr.minute
        val offset = -(minutesToMidnight + 30) // 30 min before midnight of the prior day
        val resolved = resolveAnchorTime(
            Anchor.PrayerRelative(Prayer.FAJR, offsetMinutes = offset),
            date,
            prayerTimes,
        )
        assertThat(resolved).isNotNull()
        // Must be the previous calendar day, not a same-day wrap.
        assertThat(resolved!!.date).isLessThan(date)
    }

    @Test
    fun `segment anchor has no fixed time`() {
        val resolved = resolveAnchorTime(
            Anchor.Segment(DaySegment.SUNRISE_TO_DHUHR, order = 2),
            date,
            prayerTimes,
        )
        assertThat(resolved).isNull()
    }
}
