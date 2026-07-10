package com.awkati.domain.schedule

import java.time.DayOfWeek

/**
 * How an item repeats. `startDate` and `endDate` live on the owning item,
 * not here — recurrence only describes the *pattern*, occursOn() combines
 * it with the item's start/end to answer "does this occur on date X".
 */
sealed interface Recurrence {
    data object None : Recurrence
    data object Daily : Recurrence

    /**
     * @param days empty means "the weekday of the item's start date"
     * @param interval 1 = every week, 2 = every other week, etc., anchored
     *   on the Monday of the week containing the item's start date
     */
    data class Weekly(val days: Set<DayOfWeek> = emptySet(), val interval: Int = 1) : Recurrence

    /**
     * Exactly one of [daysOfMonth] or [pattern] should be set; if both are
     * null, falls back to the day-of-month of the item's start date.
     * Days beyond the length of a given month are clamped (day 31 shows on
     * the last day of a 30-day month).
     */
    data class Monthly(val daysOfMonth: Set<Int>? = null, val pattern: MonthlyPattern? = null) : Recurrence

    /** Anniversary of the start date; Feb 29 clamps to Feb 28 outside leap years. */
    data object Yearly : Recurrence
}

/** e.g. "the first Monday" or "the last Friday" of the month. */
data class MonthlyPattern(val ordinal: Ordinal, val dayOfWeek: DayOfWeek) {
    enum class Ordinal { FIRST, SECOND, THIRD, FOURTH, LAST }
}
