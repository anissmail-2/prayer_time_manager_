package com.awkati.domain.schedule

import com.awkati.domain.prayer.PrayerTimesForDay
import kotlinx.datetime.LocalDate
import kotlinx.datetime.LocalDateTime
import kotlinx.datetime.atTime
import kotlinx.datetime.toLocalDateTime
import kotlin.time.Duration.Companion.minutes

/**
 * Resolves an [Anchor] to the concrete wall-clock time it lands at on [date],
 * given that day's computed [prayerTimes].
 *
 * Returns null for [Anchor.Segment]: a segment-anchored item ("after Fajr:
 * gym") deliberately has no fixed time — it is ordered within its segment by
 * [Anchor.Segment.order], not placed at a clock position.
 *
 * The prayer-relative branch does its offset arithmetic in the absolute time
 * domain (Instant), not by adding minutes to a LocalDateTime, so an offset
 * that crosses midnight (e.g. 90 minutes before a 00:40 Fajr) resolves to the
 * correct previous-day instant instead of silently wrapping. TaskFlow Pro's
 * prayer-relative math added minutes to a naive local time and got this wrong.
 */
fun resolveAnchorTime(
    anchor: Anchor,
    date: LocalDate,
    prayerTimes: PrayerTimesForDay,
): LocalDateTime? = when (anchor) {
    is Anchor.Clock -> date.atTime(anchor.time)
    is Anchor.PrayerRelative ->
        prayerTimes.toInstant(anchor.prayer)
            .plus(anchor.offsetMinutes.minutes)
            .toLocalDateTime(prayerTimes.timeZone)
    is Anchor.Segment -> null
}
