package com.awkati.domain.schedule

import com.google.common.truth.Truth.assertThat
import kotlinx.datetime.LocalDate
import org.junit.jupiter.api.Nested
import org.junit.jupiter.api.Test
import java.time.DayOfWeek

class RecurrenceEngineTest {

    @Nested
    inner class Bounds {
        @Test
        fun `never occurs before startDate`() {
            val start = LocalDate(2026, 3, 10)
            assertThat(occursOn(start, null, Recurrence.Daily, LocalDate(2026, 3, 9))).isFalse()
        }

        @Test
        fun `endDate is inclusive`() {
            val start = LocalDate(2026, 3, 1)
            val end = LocalDate(2026, 3, 10)
            assertThat(occursOn(start, end, Recurrence.Daily, LocalDate(2026, 3, 10))).isTrue()
            assertThat(occursOn(start, end, Recurrence.Daily, LocalDate(2026, 3, 11))).isFalse()
        }
    }

    @Nested
    inner class NoneRecurrence {
        @Test
        fun `occurs only on startDate`() {
            val start = LocalDate(2026, 5, 1)
            assertThat(occursOn(start, null, Recurrence.None, start)).isTrue()
            assertThat(occursOn(start, null, Recurrence.None, start.plusDays(1))).isFalse()
        }

        @Test
        fun `occurs on a future startDate, not on the day it was created`() {
            // A one-time item scheduled for tomorrow must not leak onto today.
            // This exact regression (prayer-relative once items anchoring to
            // createdAt instead of the requested date) shipped in TaskFlow Pro.
            val tomorrow = LocalDate(2026, 7, 11)
            assertThat(occursOn(tomorrow, null, Recurrence.None, LocalDate(2026, 7, 10))).isFalse()
            assertThat(occursOn(tomorrow, null, Recurrence.None, tomorrow)).isTrue()
        }
    }

    @Nested
    inner class DailyRecurrence {
        @Test
        fun `occurs every day from startDate`() {
            val start = LocalDate(2026, 1, 1)
            repeat(30) { offset ->
                assertThat(occursOn(start, null, Recurrence.Daily, start.plusDays(offset.toLong()))).isTrue()
            }
        }
    }

    @Nested
    inner class WeeklyRecurrence {
        @Test
        fun `falls back to startDate's weekday when no days specified`() {
            val start = LocalDate(2026, 3, 2) // a Monday
            assertThat(start.dayOfWeek).isEqualTo(DayOfWeek.MONDAY)
            assertThat(occursOn(start, null, Recurrence.Weekly(), LocalDate(2026, 3, 9))).isTrue() // next Monday
            assertThat(occursOn(start, null, Recurrence.Weekly(), LocalDate(2026, 3, 10))).isFalse() // Tuesday
        }

        @Test
        fun `honors an explicit day set`() {
            val start = LocalDate(2026, 3, 2) // Monday
            val recurrence = Recurrence.Weekly(days = setOf(DayOfWeek.TUESDAY, DayOfWeek.THURSDAY))
            assertThat(occursOn(start, null, recurrence, LocalDate(2026, 3, 3))).isTrue() // Tue
            assertThat(occursOn(start, null, recurrence, LocalDate(2026, 3, 5))).isTrue() // Thu
            assertThat(occursOn(start, null, recurrence, LocalDate(2026, 3, 2))).isFalse() // Mon, not selected
        }

        @Test
        fun `every-other-week interval is anchored to startDate's week`() {
            val start = LocalDate(2026, 3, 2) // Monday, week 1
            val recurrence = Recurrence.Weekly(days = setOf(DayOfWeek.MONDAY), interval = 2)
            assertThat(occursOn(start, null, recurrence, LocalDate(2026, 3, 2))).isTrue()   // week 1: yes
            assertThat(occursOn(start, null, recurrence, LocalDate(2026, 3, 9))).isFalse()  // week 2: no
            assertThat(occursOn(start, null, recurrence, LocalDate(2026, 3, 16))).isTrue()  // week 3: yes
            assertThat(occursOn(start, null, recurrence, LocalDate(2026, 3, 23))).isFalse() // week 4: no
        }
    }

    @Nested
    inner class MonthlyRecurrence {
        @Test
        fun `falls back to startDate's day-of-month`() {
            val start = LocalDate(2026, 1, 15)
            assertThat(occursOn(start, null, Recurrence.Monthly(), LocalDate(2026, 2, 15))).isTrue()
            assertThat(occursOn(start, null, Recurrence.Monthly(), LocalDate(2026, 2, 14))).isFalse()
        }

        @Test
        fun `day 31 clamps to the last day of a shorter month`() {
            val start = LocalDate(2026, 1, 31)
            val recurrence = Recurrence.Monthly(daysOfMonth = setOf(31))
            // April has 30 days.
            assertThat(occursOn(start, null, recurrence, LocalDate(2026, 4, 30))).isTrue()
            assertThat(occursOn(start, null, recurrence, LocalDate(2026, 4, 29))).isFalse()
            // February 2026 is not a leap year: 28 days.
            assertThat(occursOn(start, null, recurrence, LocalDate(2026, 2, 28))).isTrue()
        }

        @Test
        fun `first Monday pattern`() {
            val start = LocalDate(2026, 1, 5) // first Monday of Jan 2026
            val recurrence = Recurrence.Monthly(pattern = MonthlyPattern(MonthlyPattern.Ordinal.FIRST, DayOfWeek.MONDAY))
            assertThat(occursOn(start, null, recurrence, LocalDate(2026, 2, 2))).isTrue()  // first Monday of Feb
            assertThat(occursOn(start, null, recurrence, LocalDate(2026, 2, 9))).isFalse() // second Monday
        }

        @Test
        fun `last Friday pattern`() {
            val start = LocalDate(2026, 1, 30) // last Friday of Jan 2026
            val recurrence = Recurrence.Monthly(pattern = MonthlyPattern(MonthlyPattern.Ordinal.LAST, DayOfWeek.FRIDAY))
            assertThat(occursOn(start, null, recurrence, LocalDate(2026, 2, 27))).isTrue()  // last Friday of Feb
            assertThat(occursOn(start, null, recurrence, LocalDate(2026, 2, 20))).isFalse()
        }
    }

    @Nested
    inner class YearlyRecurrence {
        @Test
        fun `occurs on the anniversary`() {
            val start = LocalDate(2020, 6, 15)
            assertThat(occursOn(start, null, Recurrence.Yearly, LocalDate(2027, 6, 15))).isTrue()
            assertThat(occursOn(start, null, Recurrence.Yearly, LocalDate(2027, 6, 14))).isFalse()
        }

        @Test
        fun `Feb 29 clamps to Feb 28 outside leap years`() {
            val start = LocalDate(2024, 2, 29) // 2024 is a leap year
            assertThat(occursOn(start, null, Recurrence.Yearly, LocalDate(2028, 2, 29))).isTrue() // leap year: exact
            assertThat(occursOn(start, null, Recurrence.Yearly, LocalDate(2026, 2, 28))).isTrue() // non-leap: clamped
            assertThat(occursOn(start, null, Recurrence.Yearly, LocalDate(2026, 3, 1))).isFalse()
        }
    }
}

private fun LocalDate.plusDays(days: Long): LocalDate =
    kotlinx.datetime.LocalDate.fromEpochDays(this.toEpochDays() + days.toInt())
