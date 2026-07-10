package com.awkati.domain.prayer

import kotlinx.datetime.Instant
import kotlinx.datetime.LocalDate
import kotlinx.datetime.LocalDateTime
import kotlinx.datetime.TimeZone
import kotlinx.datetime.toInstant
import kotlinx.datetime.toLocalDateTime
import kotlin.time.Duration.Companion.minutes
import com.batoulapps.adhan.CalculationMethod as AdhanCalculationMethod
import com.batoulapps.adhan.CalculationParameters as AdhanCalculationParameters
import com.batoulapps.adhan.Coordinates as AdhanCoordinates
import com.batoulapps.adhan.Madhab as AdhanMadhab
import com.batoulapps.adhan.PrayerTimes as AdhanPrayerTimes
import com.batoulapps.adhan.data.DateComponents as AdhanDateComponents

data class GeoCoordinates(val latitude: Double, val longitude: Double)

/**
 * Mirrors [com.batoulapps.adhan.CalculationMethod]. Kept as our own type so
 * the vendor library's enum never leaks into the public domain API.
 */
enum class CalculationMethod {
    MUSLIM_WORLD_LEAGUE,
    EGYPTIAN,
    KARACHI,
    UMM_AL_QURA,
    DUBAI,
    MOON_SIGHTING_COMMITTEE,
    NORTH_AMERICA,
    KUWAIT,
    QATAR,
    SINGAPORE,
    OTHER,
}

enum class Madhab { SHAFI, HANAFI }

/** Per-prayer minute nudges, e.g. to match a local mosque's posted times. */
data class PrayerAdjustments(
    val fajr: Int = 0,
    val sunrise: Int = 0,
    val dhuhr: Int = 0,
    val asr: Int = 0,
    val maghrib: Int = 0,
    val isha: Int = 0,
) {
    operator fun get(prayer: Prayer): Int = when (prayer) {
        Prayer.FAJR -> fajr
        Prayer.SUNRISE -> sunrise
        Prayer.DHUHR -> dhuhr
        Prayer.ASR -> asr
        Prayer.MAGHRIB -> maghrib
        Prayer.ISHA -> isha
    }
}

/**
 * Computed prayer times for one calendar day, already adjusted and already
 * localized. This is the only form the rest of the app should ever read —
 * raw/adjusted double-application was a real bug in TaskFlow Pro (adjustments
 * were baked into the cache and then re-applied on every offline read).
 */
data class PrayerTimesForDay(
    val date: LocalDate,
    val timeZone: TimeZone,
    private val times: Map<Prayer, LocalDateTime>,
) {
    operator fun get(prayer: Prayer): LocalDateTime = times.getValue(prayer)

    /** All six markers in chronological order. */
    fun ordered(): List<Pair<Prayer, LocalDateTime>> =
        Prayer.entries.map { it to times.getValue(it) }.sortedBy { it.second }

    fun toInstant(prayer: Prayer): Instant = times.getValue(prayer).toInstant(timeZone)
}

interface PrayerTimeEngine {
    fun calculate(
        coordinates: GeoCoordinates,
        date: LocalDate,
        timeZone: TimeZone,
        method: CalculationMethod = CalculationMethod.DUBAI,
        madhab: Madhab = Madhab.SHAFI,
        adjustments: PrayerAdjustments = PrayerAdjustments(),
    ): PrayerTimesForDay
}

/**
 * Wraps Batoul Apps' `adhan` library. This is the on-device engine and the
 * *primary* source of prayer times in Awkati — unlike TaskFlow Pro, which
 * treated the network API as primary and local calculation as a fallback,
 * making the app's core feature depend on connectivity by default.
 */
class AdhanPrayerTimeEngine : PrayerTimeEngine {

    override fun calculate(
        coordinates: GeoCoordinates,
        date: LocalDate,
        timeZone: TimeZone,
        method: CalculationMethod,
        madhab: Madhab,
        adjustments: PrayerAdjustments,
    ): PrayerTimesForDay {
        val adhanCoordinates = AdhanCoordinates(coordinates.latitude, coordinates.longitude)
        val dateComponents = AdhanDateComponents(date.year, date.monthNumber, date.dayOfMonth)
        val parameters: AdhanCalculationParameters = method.toAdhan().parameters
        parameters.madhab = madhab.toAdhan()

        val raw = AdhanPrayerTimes(adhanCoordinates, dateComponents, parameters)
        val rawByPrayer = mapOf(
            Prayer.FAJR to raw.fajr,
            Prayer.SUNRISE to raw.sunrise,
            Prayer.DHUHR to raw.dhuhr,
            Prayer.ASR to raw.asr,
            Prayer.MAGHRIB to raw.maghrib,
            Prayer.ISHA to raw.isha,
        )

        val adjusted = rawByPrayer.mapValues { (prayer, javaDate) ->
            Instant.fromEpochMilliseconds(javaDate.time)
                .plus(adjustments[prayer].minutes)
                .toLocalDateTime(timeZone)
        }

        return PrayerTimesForDay(date, timeZone, adjusted)
    }
}

private fun CalculationMethod.toAdhan(): AdhanCalculationMethod = when (this) {
    CalculationMethod.MUSLIM_WORLD_LEAGUE -> AdhanCalculationMethod.MUSLIM_WORLD_LEAGUE
    CalculationMethod.EGYPTIAN -> AdhanCalculationMethod.EGYPTIAN
    CalculationMethod.KARACHI -> AdhanCalculationMethod.KARACHI
    CalculationMethod.UMM_AL_QURA -> AdhanCalculationMethod.UMM_AL_QURA
    CalculationMethod.DUBAI -> AdhanCalculationMethod.DUBAI
    CalculationMethod.MOON_SIGHTING_COMMITTEE -> AdhanCalculationMethod.MOON_SIGHTING_COMMITTEE
    CalculationMethod.NORTH_AMERICA -> AdhanCalculationMethod.NORTH_AMERICA
    CalculationMethod.KUWAIT -> AdhanCalculationMethod.KUWAIT
    CalculationMethod.QATAR -> AdhanCalculationMethod.QATAR
    CalculationMethod.SINGAPORE -> AdhanCalculationMethod.SINGAPORE
    CalculationMethod.OTHER -> AdhanCalculationMethod.OTHER
}

private fun Madhab.toAdhan(): AdhanMadhab = when (this) {
    Madhab.SHAFI -> AdhanMadhab.SHAFI
    Madhab.HANAFI -> AdhanMadhab.HANAFI
}
