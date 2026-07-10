package com.awkati.domain.prayer

/** The five daily prayers plus sunrise, which anchors the Duha window. */
enum class Prayer {
    FAJR,
    SUNRISE,
    DHUHR,
    ASR,
    MAGHRIB,
    ISHA,
}

/** The five prayer-bounded segments of the day, in order. */
enum class DaySegment(val label: String) {
    FAJR_TO_SUNRISE("Fajr"),
    SUNRISE_TO_DHUHR("Morning"),
    DHUHR_TO_ASR("Midday"),
    ASR_TO_MAGHRIB("Afternoon"),
    MAGHRIB_TO_ISHA("Evening"),
    ISHA_TO_FAJR("Night"),
}
