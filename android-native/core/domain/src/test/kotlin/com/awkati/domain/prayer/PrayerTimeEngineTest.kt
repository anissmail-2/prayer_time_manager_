package com.awkati.domain.prayer

import com.google.common.truth.Truth.assertThat
import kotlinx.datetime.LocalDate
import kotlinx.datetime.TimeZone
import org.junit.jupiter.api.Test
import org.junit.jupiter.params.ParameterizedTest
import org.junit.jupiter.params.provider.CsvSource

/**
 * These test structural invariants (ordering, plausible local-time ranges,
 * adjustments applied exactly once) rather than exact published prayer-time
 * tables, which this environment has no way to fetch and verify against.
 * Do not read "passes" here as "matches a mosque's printed calendar" —
 * that requires a real device/location acceptance pass before release.
 */
class PrayerTimeEngineTest {

    private val engine: PrayerTimeEngine = AdhanPrayerTimeEngine()
    private val abuDhabi = GeoCoordinates(latitude = 24.4539, longitude = 54.3773)
    private val gulfTz = TimeZone.of("Asia/Dubai")

    @Test
    fun `prayers are chronologically ordered across the year`() {
        val dates = listOf(
            LocalDate(2026, 1, 15),
            LocalDate(2026, 4, 15),
            LocalDate(2026, 7, 15),
            LocalDate(2026, 10, 15),
        )
        for (date in dates) {
            val times = engine.calculate(abuDhabi, date, gulfTz, method = CalculationMethod.DUBAI)
            val ordered = times.ordered().map { it.second }
            assertThat(ordered).isInOrder()
        }
    }

    @ParameterizedTest
    @CsvSource(
        "FAJR, 3, 7",
        "SUNRISE, 5, 8",
        "DHUHR, 11, 13",
        "ASR, 14, 17",
        "MAGHRIB, 17, 20",
        "ISHA, 18, 21",
    )
    fun `each prayer falls within a plausible local hour range for Abu Dhabi`(
        prayerName: String,
        earliestHour: Int,
        latestHour: Int,
    ) {
        val prayer = Prayer.valueOf(prayerName)
        val date = LocalDate(2026, 7, 10)
        val times = engine.calculate(abuDhabi, date, gulfTz, method = CalculationMethod.DUBAI)
        val hour = times[prayer].hour
        assertThat(hour).isIn(earliestHour..latestHour)
    }

    @Test
    fun `adjustments shift the specific prayer without affecting others`() {
        val date = LocalDate(2026, 7, 10)
        val unadjusted = engine.calculate(abuDhabi, date, gulfTz, method = CalculationMethod.DUBAI)
        val adjusted = engine.calculate(
            abuDhabi,
            date,
            gulfTz,
            method = CalculationMethod.DUBAI,
            adjustments = PrayerAdjustments(fajr = 5),
        )

        val fajrDeltaMinutes = adjusted[Prayer.FAJR].minute - unadjusted[Prayer.FAJR].minute +
            (adjusted[Prayer.FAJR].hour - unadjusted[Prayer.FAJR].hour) * 60
        assertThat(fajrDeltaMinutes).isEqualTo(5)

        // Untouched prayers must be identical to the minute -- adjustments
        // must not leak across prayers, and must not compound if applied
        // more than once (the double-application bug from TaskFlow Pro).
        // Sub-second jitter from the underlying astronomical calculation is
        // not meaningful for a prayer time, so compare at minute precision.
        assertThat(adjusted[Prayer.DHUHR].toMinute()).isEqualTo(unadjusted[Prayer.DHUHR].toMinute())
        assertThat(adjusted[Prayer.ISHA].toMinute()).isEqualTo(unadjusted[Prayer.ISHA].toMinute())
    }

    @Test
    fun `calculating the same day twice is idempotent`() {
        val date = LocalDate(2026, 7, 10)
        val first = engine.calculate(abuDhabi, date, gulfTz, adjustments = PrayerAdjustments(isha = 10))
        val second = engine.calculate(abuDhabi, date, gulfTz, adjustments = PrayerAdjustments(isha = 10))
        assertThat(first[Prayer.ISHA].toMinute()).isEqualTo(second[Prayer.ISHA].toMinute())
    }
}

/** (hour, minute) tuple -- the precision that's actually meaningful for a prayer time. */
private fun kotlinx.datetime.LocalDateTime.toMinute(): Pair<Int, Int> = hour to minute
