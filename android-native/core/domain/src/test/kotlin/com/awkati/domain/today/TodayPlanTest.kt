package com.awkati.domain.today

import com.awkati.domain.item.Item
import com.awkati.domain.item.ItemType
import com.awkati.domain.prayer.AdhanPrayerTimeEngine
import com.awkati.domain.prayer.DaySegment
import com.awkati.domain.prayer.GeoCoordinates
import com.awkati.domain.prayer.Prayer
import com.awkati.domain.prayer.PrayerTimeEngine
import com.awkati.domain.prayer.toSegmentWindows
import com.awkati.domain.schedule.Anchor
import com.awkati.domain.schedule.Recurrence
import com.google.common.truth.Truth.assertThat
import kotlinx.datetime.Instant
import kotlinx.datetime.LocalDate
import kotlinx.datetime.LocalTime
import kotlinx.datetime.TimeZone
import org.junit.jupiter.api.Test

class TodayPlanTest {

    private val engine: PrayerTimeEngine = AdhanPrayerTimeEngine()
    private val abuDhabi = GeoCoordinates(latitude = 24.4539, longitude = 54.3773)
    private val gulfTz = TimeZone.of("Asia/Dubai")
    private val date = LocalDate(2026, 7, 10)
    private val prayerTimes = engine.calculate(abuDhabi, date, gulfTz)
    private val tomorrow = engine.calculate(abuDhabi, LocalDate(2026, 7, 11), gulfTz)
    private val windows = prayerTimes.toSegmentWindows(tomorrowFajr = tomorrow[Prayer.FAJR])

    private val epoch = Instant.parse("2026-01-01T00:00:00Z")

    private fun item(
        id: String,
        anchor: Anchor,
        startDate: LocalDate = date,
        endDate: LocalDate? = null,
        recurrence: Recurrence = Recurrence.None,
        deletedAt: Instant? = null,
    ) = Item(
        id = id,
        title = id,
        type = ItemType.TASK,
        startDate = startDate,
        endDate = endDate,
        anchor = anchor,
        recurrence = recurrence,
        createdAt = epoch,
        updatedAt = epoch,
        deletedAt = deletedAt,
    )

    @Test
    fun `only items occurring on the date are included`() {
        val items = listOf(
            item("today-once", Anchor.Clock(LocalTime(9, 0))),
            item("tomorrow-once", Anchor.Clock(LocalTime(9, 0)), startDate = LocalDate(2026, 7, 11)),
            item("daily", Anchor.Clock(LocalTime(10, 0)), startDate = LocalDate(2026, 1, 1), recurrence = Recurrence.Daily),
        )
        val plan = buildTodayPlan(items, date, prayerTimes, windows)
        assertThat(plan.map { it.item.id }).containsExactly("today-once", "daily")
    }

    @Test
    fun `soft-deleted items are excluded`() {
        val items = listOf(
            item("live", Anchor.Clock(LocalTime(9, 0))),
            item("deleted", Anchor.Clock(LocalTime(9, 30)), deletedAt = epoch),
        )
        val plan = buildTodayPlan(items, date, prayerTimes, windows)
        assertThat(plan.map { it.item.id }).containsExactly("live")
    }

    @Test
    fun `items are ordered chronologically across the day`() {
        val items = listOf(
            item("evening", Anchor.Clock(LocalTime(20, 0))),
            item("morning", Anchor.Clock(LocalTime(7, 0))),
            item("afterDhuhr", Anchor.PrayerRelative(Prayer.DHUHR, 15)),
        )
        val plan = buildTodayPlan(items, date, prayerTimes, windows)
        assertThat(plan.map { it.item.id }).containsExactly("morning", "afterDhuhr", "evening").inOrder()
    }

    @Test
    fun `timed items sort before segment-anchored items in the same segment`() {
        // 13:00 is between Dhuhr (~12:26) and Asr (~15:42) in Abu Dhabi in
        // July, so both land in the Dhuhr->Asr window; the clock item has a
        // time and the segment item does not, so the timed one comes first.
        val items = listOf(
            item("idea", Anchor.Segment(DaySegment.DHUHR_TO_ASR, order = 0)),
            item("timed", Anchor.Clock(LocalTime(13, 0))),
        )
        val plan = buildTodayPlan(items, date, prayerTimes, windows)
        val dhuhrSegment = plan.filter { it.segment == DaySegment.DHUHR_TO_ASR }
        assertThat(dhuhrSegment.map { it.item.id }).containsExactly("timed", "idea").inOrder()
    }

    @Test
    fun `a clock item is assigned to the segment its time falls in`() {
        // 13:00 sits in the Dhuhr->Asr window for this location and date.
        val plan = buildTodayPlan(
            listOf(item("midday", Anchor.Clock(LocalTime(13, 0)))),
            date,
            prayerTimes,
            windows,
        )
        assertThat(plan.single().segment).isEqualTo(DaySegment.DHUHR_TO_ASR)
    }

    @Test
    fun `endDate is inclusive when selecting occurrences`() {
        val recurring = item(
            "recurring",
            Anchor.Clock(LocalTime(9, 0)),
            startDate = LocalDate(2026, 7, 1),
            endDate = date, // ends today
            recurrence = Recurrence.Daily,
        )
        val plan = buildTodayPlan(listOf(recurring), date, prayerTimes, windows)
        assertThat(plan.map { it.item.id }).containsExactly("recurring")
    }
}
