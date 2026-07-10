package com.awkati.designsystem

import androidx.compose.ui.graphics.Color

/**
 * Deep teal (mosque-dome / night-before-fajr) as the primary hue, warm gold
 * as the single accent reserved for "next prayer" / "now" emphasis. Chosen
 * once here and only here — screens must reference these tokens, never a
 * raw Color literal (that discipline is what a lint rule in M0 enforces;
 * TaskFlow Pro's dark theme existed but screens bypassed it everywhere).
 */
object AwkatiColors {
    // Light theme
    val primaryLight = Color(0xFF0F766E)
    val onPrimaryLight = Color(0xFFFFFFFF)
    val primaryContainerLight = Color(0xFFB0F1E6)
    val onPrimaryContainerLight = Color(0xFF00201B)

    val accentLight = Color(0xFFB45309) // gold: next-prayer / now emphasis only
    val onAccentLight = Color(0xFFFFFFFF)

    val surfaceLight = Color(0xFFFFFFFF)
    val backgroundLight = Color(0xFFF6F8F7)
    val onSurfaceLight = Color(0xFF1F2A2E)
    val onSurfaceVariantLight = Color(0xFF5C6B6D)
    val outlineLight = Color(0xFFD8E0DE)
    val surfaceVariantLight = Color(0xFFEDF2F0)

    // Dark theme -- not a naive inversion; contrast and the accent are
    // re-checked against the dark ground, not derived by formula.
    val primaryDark = Color(0xFF3CBFAB)
    val onPrimaryDark = Color(0xFF00382F)
    val primaryContainerDark = Color(0xFF00504420)
    val onPrimaryContainerDark = Color(0xFFB0F1E6)

    val accentDark = Color(0xFFE0A83E)
    val onAccentDark = Color(0xFF3F2900)

    val surfaceDark = Color(0xFF162225)
    val backgroundDark = Color(0xFF101A1C)
    val onSurfaceDark = Color(0xFFE4ECEA)
    val onSurfaceVariantDark = Color(0xFF93A5A3)
    val outlineDark = Color(0xFF24373A)
    val surfaceVariantDark = Color(0xFF0C1416)

    // Semantic -- independent of the accent hue, same in both themes.
    val success = Color(0xFF15803D)
    val warning = Color(0xFFB45309)
    val critical = Color(0xFFB91C1C)

    /**
     * One color per [com.awkati.domain.prayer.DaySegment], used consistently
     * for segment chips/stripes on the Today timeline. Deliberately distinct
     * from the single teal/gold brand accent -- these are informational,
     * not decorative.
     */
    val segmentFajr = Color(0xFF6D5DA8) // pre-dawn violet
    val segmentMorning = Color(0xFFD98A3D) // sunrise amber
    val segmentMidday = Color(0xFF2E8B8B) // high-sun teal
    val segmentAfternoon = Color(0xFFC4692B) // late-day copper
    val segmentEvening = Color(0xFFB0473F) // maghrib red
    val segmentNight = Color(0xFF2B3A67) // night indigo
}
