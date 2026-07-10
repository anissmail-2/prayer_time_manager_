package com.awkati.domain.prayer

import kotlinx.datetime.LocalDateTime

/** One prayer-bounded window of a specific day: [start, end). */
data class SegmentWindow(
    val segment: DaySegment,
    val start: LocalDateTime,
    val end: LocalDateTime,
)

/**
 * Splits a day into its five prayer-bounded segments plus the overnight
 * segment, using [today]'s Isha as the start of night and [tomorrowFajr] as
 * its end. This is the concept at the center of Awkati: the day is not a
 * blank 24-hour clock face, it is these six windows.
 */
fun PrayerTimesForDay.toSegmentWindows(tomorrowFajr: LocalDateTime): List<SegmentWindow> = listOf(
    SegmentWindow(DaySegment.FAJR_TO_SUNRISE, this[Prayer.FAJR], this[Prayer.SUNRISE]),
    SegmentWindow(DaySegment.SUNRISE_TO_DHUHR, this[Prayer.SUNRISE], this[Prayer.DHUHR]),
    SegmentWindow(DaySegment.DHUHR_TO_ASR, this[Prayer.DHUHR], this[Prayer.ASR]),
    SegmentWindow(DaySegment.ASR_TO_MAGHRIB, this[Prayer.ASR], this[Prayer.MAGHRIB]),
    SegmentWindow(DaySegment.MAGHRIB_TO_ISHA, this[Prayer.MAGHRIB], this[Prayer.ISHA]),
    SegmentWindow(DaySegment.ISHA_TO_FAJR, this[Prayer.ISHA], tomorrowFajr),
)

/** Which segment [at] falls into, if any of today's windows contain it. */
fun List<SegmentWindow>.segmentAt(at: LocalDateTime): DaySegment? =
    firstOrNull { at >= it.start && at < it.end }?.segment
