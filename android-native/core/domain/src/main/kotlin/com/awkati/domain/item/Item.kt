package com.awkati.domain.item

import com.awkati.domain.schedule.Anchor
import com.awkati.domain.schedule.Recurrence
import kotlinx.datetime.Instant
import kotlinx.datetime.LocalDate

enum class ItemType { TASK, EVENT, IDEA }

enum class Priority { LOW, MEDIUM, HIGH }

/**
 * A plannable thing. Deliberately does not carry its own completion state —
 * see [com.awkati.domain.item.Occurrence]. Cramming per-date completion
 * onto the item itself (as `completedDates: List<String>` on the model) is
 * exactly what made TaskFlow Pro's completion tracking split-brained across
 * screens; a real join table doesn't allow that bug to exist.
 */
data class Item(
    val id: String,
    val title: String,
    val notes: String = "",
    val type: ItemType = ItemType.TASK,
    val areaId: String? = null,
    val startDate: LocalDate,
    val endDate: LocalDate? = null,
    val anchor: Anchor,
    val recurrence: Recurrence = Recurrence.None,
    val priority: Priority = Priority.MEDIUM,
    val createdAt: Instant,
    val updatedAt: Instant,
    val deletedAt: Instant? = null,
)

/**
 * One occurrence of a (possibly recurring) [Item] on one calendar date.
 * Only occurrences that have actually been completed need a row — the set
 * of *possible* occurrences is derived on demand from
 * [com.awkati.domain.schedule.occursOn], never stored.
 */
data class Occurrence(
    val itemId: String,
    val date: LocalDate,
    val completedAt: Instant? = null,
)

/** A named grouping of items — "Spaces" in TaskFlow Pro, with a real parent FK here. */
data class Area(
    val id: String,
    val name: String,
    val color: Int,
    val parentAreaId: String? = null,
)
