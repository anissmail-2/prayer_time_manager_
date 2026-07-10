package com.awkati.designsystem

import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.material3.ColorScheme
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.darkColorScheme
import androidx.compose.material3.lightColorScheme
import androidx.compose.runtime.Composable

private val LightColors: ColorScheme = lightColorScheme(
    primary = AwkatiColors.primaryLight,
    onPrimary = AwkatiColors.onPrimaryLight,
    primaryContainer = AwkatiColors.primaryContainerLight,
    onPrimaryContainer = AwkatiColors.onPrimaryContainerLight,
    secondary = AwkatiColors.accentLight,
    onSecondary = AwkatiColors.onAccentLight,
    background = AwkatiColors.backgroundLight,
    surface = AwkatiColors.surfaceLight,
    onSurface = AwkatiColors.onSurfaceLight,
    onSurfaceVariant = AwkatiColors.onSurfaceVariantLight,
    surfaceVariant = AwkatiColors.surfaceVariantLight,
    outline = AwkatiColors.outlineLight,
    error = AwkatiColors.critical,
)

private val DarkColors: ColorScheme = darkColorScheme(
    primary = AwkatiColors.primaryDark,
    onPrimary = AwkatiColors.onPrimaryDark,
    primaryContainer = AwkatiColors.primaryContainerDark,
    onPrimaryContainer = AwkatiColors.onPrimaryContainerDark,
    secondary = AwkatiColors.accentDark,
    onSecondary = AwkatiColors.onAccentDark,
    background = AwkatiColors.backgroundDark,
    surface = AwkatiColors.surfaceDark,
    onSurface = AwkatiColors.onSurfaceDark,
    onSurfaceVariant = AwkatiColors.onSurfaceVariantDark,
    surfaceVariant = AwkatiColors.surfaceVariantDark,
    outline = AwkatiColors.outlineDark,
    error = AwkatiColors.critical,
)

/**
 * Root theme. No dynamic-color (Material You) branch on purpose -- prayer
 * segment colors and the teal/gold identity are a deliberate palette, not
 * something that should shift to the user's wallpaper.
 */
@Composable
fun AwkatiTheme(
    darkTheme: Boolean = isSystemInDarkTheme(),
    content: @Composable () -> Unit,
) {
    val colorScheme = if (darkTheme) DarkColors else LightColors
    MaterialTheme(
        colorScheme = colorScheme,
        typography = AwkatiTypography,
        content = content,
    )
}
