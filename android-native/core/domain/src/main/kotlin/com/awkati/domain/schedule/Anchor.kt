package com.awkati.domain.schedule

import com.awkati.domain.prayer.DaySegment
import com.awkati.domain.prayer.Prayer
import kotlinx.datetime.LocalTime

/**
 * Where an item sits in the day. Unifying clock time, prayer-relative time,
 * and segment placement into one sealed type replaces TaskFlow Pro's three
 * separate, inconsistently-supported scheduling code paths.
 */
sealed interface Anchor {
    /** A fixed wall-clock time, e.g. a meeting at 14:00. */
    data class Clock(val time: LocalTime) : Anchor

    /** Relative to a prayer. Negative [offsetMinutes] means "before". */
    data class PrayerRelative(val prayer: Prayer, val offsetMinutes: Int) : Anchor

    /**
     * Inside a segment with no fixed time — "after Fajr: gym", ordered
     * against sibling items in the same segment by [order].
     */
    data class Segment(val segment: DaySegment, val order: Int = 0) : Anchor
}
