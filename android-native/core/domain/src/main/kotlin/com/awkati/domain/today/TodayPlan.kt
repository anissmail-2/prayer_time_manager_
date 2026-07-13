package com.awkati.domain.today

import com.awkati.domain.item.Item
import com.awkati.domain.prayer.DaySegment
import com.awkati.domain.prayer.SegmentWindow
import com.awkati.domain.prayer.segmentAt
import com.awkati.domain.schedule.Anchor
import com.awkati.domain.schedule.occursOn
import com.awkati.domain.schedule.resolveAnchorTime
import com.awkati.domain.prayer.PrayerTimesForDay
import kotlinx.datetime.LocalDate
import kotlinx.datetime.LocalDateTime

/**
 * One item as it appears on the Today timeline: which [DaySegment] it belongs
 * to and, if it has a fixed time, when. [time] is null for segment-anchored
 * items, which sit in their segment without a clock position.
 */
data class PlannedItem(
    val item: Item,
    val segment: DaySegment?,
    val time: LocalDateTime?,
)

/**
 * The ordered set of items that occur on [date], each resolved to its time
 * and placed in a segment. This is the single query the Today screen renders,
 * combining the three domain primitives — [occursOn] (does it happen today),
 * [resolveAnchorTime] (when), and [segmentAt] (in which prayer window) — so
 * the UI layer holds no scheduling logic of its own.
 *
 * Ordering: by segment in day order (Fajr window first, Night last), then
 * within a segment timed items ascending by time, then segment-anchored items
 * by their [Anchor.Segment.order]. Soft-deleted items are excluded.
 */
fun buildTodayPlan(
    items: List<Item>,
    date: LocalDate,
    prayerTimes: PrayerTimesForDay,
    segmentWindows: List<SegmentWindow>,
): List<PlannedItem> {
    val planned = items
        .filter { it.deletedAt == null }
        .filter { occursOn(it.startDate, it.endDate, it.recurrence, date) }
        .map { item ->
            val time = resolveAnchorTime(item.anchor, date, prayerTimes)
            val segment = when (val anchor = item.anchor) {
                is Anchor.Segment -> anchor.segment
                else -> time?.let { segmentWindows.segmentAt(it) }
            }
            PlannedItem(item = item, segment = segment, time = time)
        }

    return planned.sortedWith(
        compareBy<PlannedItem> { it.segment?.ordinal ?: Int.MAX_VALUE }
            .thenBy { it.time == null } // timed items before segment-only ones
            .thenBy { it.time }
            .thenBy { (it.item.anchor as? Anchor.Segment)?.order ?: 0 },
    )
}
