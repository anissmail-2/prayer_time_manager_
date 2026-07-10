package com.awkati.ui.today

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.hilt.navigation.compose.hiltViewModel
import com.awkati.designsystem.AwkatiColors
import com.awkati.domain.prayer.DaySegment
import com.awkati.domain.prayer.SegmentWindow
import kotlinx.datetime.LocalDateTime

/**
 * The thesis screen: the day as six prayer-bounded windows, not a blank
 * 24-hour clock face. Item placement inside a segment is M1 scope -- this
 * renders the skeleton the rest of the app hangs off of.
 */
@Composable
fun TodayScreen(viewModel: TodayViewModel = hiltViewModel()) {
    val state by viewModel.uiState.collectAsState()

    Box(modifier = Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
        if (state.isLoading) {
            CircularProgressIndicator()
            return@Box
        }

        LazyColumn(
            modifier = Modifier.fillMaxSize(),
            contentPadding = androidx.compose.foundation.layout.PaddingValues(20.dp),
            verticalArrangement = Arrangement.spacedBy(12.dp),
        ) {
            item {
                Text(
                    text = "Today",
                    style = MaterialTheme.typography.headlineLarge,
                    modifier = Modifier.padding(bottom = 4.dp),
                )
            }
            items(state.windows) { window ->
                SegmentRow(window = window, isCurrent = window.segment == state.currentSegment)
            }
        }
    }
}

@Composable
private fun SegmentRow(window: SegmentWindow, isCurrent: Boolean) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(16.dp))
            .background(
                if (isCurrent) MaterialTheme.colorScheme.primaryContainer
                else MaterialTheme.colorScheme.surfaceVariant,
            )
            .padding(16.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Box(
            modifier = Modifier
                .size(10.dp)
                .clip(CircleShape)
                .background(window.segment.color()),
        )
        Spacer(modifier = Modifier.size(12.dp))
        Column(modifier = Modifier.fillMaxWidth()) {
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween,
            ) {
                Text(text = window.segment.label, style = MaterialTheme.typography.titleMedium)
                if (isCurrent) {
                    Text(
                        text = "NOW",
                        style = MaterialTheme.typography.labelMedium,
                        color = MaterialTheme.colorScheme.secondary,
                        textAlign = TextAlign.End,
                    )
                }
            }
            Text(
                text = "${window.start.formatClock()} – ${window.end.formatClock()}",
                style = MaterialTheme.typography.bodyMedium,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
            )
        }
    }
}

private fun DaySegment.color(): Color = when (this) {
    DaySegment.FAJR_TO_SUNRISE -> AwkatiColors.segmentFajr
    DaySegment.SUNRISE_TO_DHUHR -> AwkatiColors.segmentMorning
    DaySegment.DHUHR_TO_ASR -> AwkatiColors.segmentMidday
    DaySegment.ASR_TO_MAGHRIB -> AwkatiColors.segmentAfternoon
    DaySegment.MAGHRIB_TO_ISHA -> AwkatiColors.segmentEvening
    DaySegment.ISHA_TO_FAJR -> AwkatiColors.segmentNight
}

private fun LocalDateTime.formatClock(): String {
    val h = hour.toString().padStart(2, '0')
    val m = minute.toString().padStart(2, '0')
    return "$h:$m"
}
