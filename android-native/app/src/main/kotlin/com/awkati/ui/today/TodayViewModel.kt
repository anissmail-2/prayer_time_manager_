package com.awkati.ui.today

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.awkati.domain.prayer.DaySegment
import com.awkati.domain.prayer.GeoCoordinates
import com.awkati.domain.prayer.Prayer
import com.awkati.domain.prayer.PrayerTimeEngine
import com.awkati.domain.prayer.SegmentWindow
import com.awkati.domain.prayer.segmentAt
import com.awkati.domain.prayer.toSegmentWindows
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch
import kotlinx.datetime.Clock
import kotlinx.datetime.LocalDate
import kotlinx.datetime.LocalDateTime
import kotlinx.datetime.TimeZone
import kotlinx.datetime.toLocalDateTime
import javax.inject.Inject

data class TodayUiState(
    val isLoading: Boolean = true,
    val windows: List<SegmentWindow> = emptyList(),
    val currentSegment: DaySegment? = null,
    val now: LocalDateTime? = null,
)

@HiltViewModel
class TodayViewModel @Inject constructor(
    private val prayerTimeEngine: PrayerTimeEngine,
) : ViewModel() {

    private val _uiState = MutableStateFlow(TodayUiState())
    val uiState: StateFlow<TodayUiState> = _uiState.asStateFlow()

    // Placeholder until M1 wires a real on-device LocationService -- Abu
    // Dhabi, matching TaskFlow Pro's default, so this screen is meaningful
    // to look at before location settings exist.
    private val placeholderLocation = GeoCoordinates(latitude = 24.4539, longitude = 54.3773)

    init {
        loadToday()
    }

    private fun loadToday() {
        viewModelScope.launch {
            val timeZone = TimeZone.currentSystemDefault()
            val now = Clock.System.now().toLocalDateTime(timeZone)
            val today = now.date

            val todayTimes = prayerTimeEngine.calculate(placeholderLocation, today, timeZone)
            val tomorrowTimes = prayerTimeEngine.calculate(placeholderLocation, today.nextDay(), timeZone)
            val windows = todayTimes.toSegmentWindows(tomorrowFajr = tomorrowTimes[Prayer.FAJR])

            _uiState.value = TodayUiState(
                isLoading = false,
                windows = windows,
                currentSegment = windows.segmentAt(now),
                now = now,
            )
        }
    }
}

private fun LocalDate.nextDay(): LocalDate = LocalDate.fromEpochDays(toEpochDays() + 1)
