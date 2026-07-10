package com.awkati.domain.schedule

import kotlinx.datetime.DateTimeUnit
import kotlinx.datetime.LocalDate
import kotlinx.datetime.daysUntil
import kotlinx.datetime.minus
import kotlinx.datetime.plus

/**
 * Whether an item recurring per [recurrence], starting [startDate] and
 * optionally ending [endDate] (inclusive), occurs on [onDate].
 *
 * This is the single authoritative recurrence check for the whole app.
 * TaskFlow Pro had two: `Task.shouldShowToday` and a second, independently
 * maintained copy in `TodoService`, which disagreed on weekly fallback,
 * end-date inclusivity, and prayer-relative one-time items — producing
 * tasks that appeared in one screen and not another. There must only ever
 * be one `occursOn`; every screen, widget, and notification scheduler
 * calls this and nothing else.
 */
fun occursOn(startDate: LocalDate, endDate: LocalDate?, recurrence: Recurrence, onDate: LocalDate): Boolean {
    if (onDate < startDate) return false
    if (endDate != null && onDate > endDate) return false

    return when (recurrence) {
        is Recurrence.None -> onDate == startDate
        is Recurrence.Daily -> true
        is Recurrence.Weekly -> occursWeekly(startDate, recurrence, onDate)
        is Recurrence.Monthly -> occursMonthly(startDate, recurrence, onDate)
        is Recurrence.Yearly -> occursYearly(startDate, onDate)
    }
}

private fun occursWeekly(startDate: LocalDate, recurrence: Recurrence.Weekly, onDate: LocalDate): Boolean {
    val days = recurrence.days.ifEmpty { setOf(startDate.dayOfWeek) }
    if (onDate.dayOfWeek !in days) return false
    if (recurrence.interval <= 1) return true

    // Anchor weeks on the Monday of startDate's week so "every N weeks" is
    // stable no matter which weekday within the week is selected.
    val startWeekStart = startDate.minus(startDate.dayOfWeek.value - 1L, DateTimeUnit.DAY)
    val onWeekStart = onDate.minus(onDate.dayOfWeek.value - 1L, DateTimeUnit.DAY)
    val weeksBetween = startWeekStart.daysUntil(onWeekStart) / 7
    return weeksBetween % recurrence.interval == 0
}

private fun occursMonthly(startDate: LocalDate, recurrence: Recurrence.Monthly, onDate: LocalDate): Boolean {
    recurrence.pattern?.let { pattern ->
        return onDate.dayOfWeek == pattern.dayOfWeek && matchesOrdinal(onDate, pattern.ordinal)
    }
    val targetDay = recurrence.daysOfMonth?.firstOrNull() ?: startDate.dayOfMonth
    return onDate.dayOfMonth == clampDayToMonth(targetDay, onDate)
}

private fun matchesOrdinal(date: LocalDate, ordinal: MonthlyPattern.Ordinal): Boolean {
    if (ordinal == MonthlyPattern.Ordinal.LAST) {
        val nextOccurrence = date.plus(7, DateTimeUnit.DAY)
        return nextOccurrence.monthNumber != date.monthNumber
    }
    val weekOfMonth = (date.dayOfMonth - 1) / 7 + 1
    val target = when (ordinal) {
        MonthlyPattern.Ordinal.FIRST -> 1
        MonthlyPattern.Ordinal.SECOND -> 2
        MonthlyPattern.Ordinal.THIRD -> 3
        MonthlyPattern.Ordinal.FOURTH -> 4
        MonthlyPattern.Ordinal.LAST -> error("handled above")
    }
    return weekOfMonth == target
}

private fun occursYearly(startDate: LocalDate, onDate: LocalDate): Boolean {
    if (startDate.monthNumber != onDate.monthNumber) return false
    return onDate.dayOfMonth == clampDayToMonth(startDate.dayOfMonth, onDate)
}

/** Clamps [day] to the last valid day of [reference]'s month, e.g. 31 -> 30 in April. */
private fun clampDayToMonth(day: Int, reference: LocalDate): Int {
    val firstOfMonth = LocalDate(reference.year, reference.monthNumber, 1)
    val firstOfNextMonth = firstOfMonth.plus(1, DateTimeUnit.MONTH)
    val lastDayOfMonth = firstOfNextMonth.minus(1, DateTimeUnit.DAY).dayOfMonth
    return day.coerceAtMost(lastDayOfMonth)
}
