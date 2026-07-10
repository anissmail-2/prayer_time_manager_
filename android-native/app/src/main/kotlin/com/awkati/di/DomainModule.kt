package com.awkati.di

import com.awkati.domain.prayer.AdhanPrayerTimeEngine
import com.awkati.domain.prayer.PrayerTimeEngine
import dagger.Module
import dagger.Provides
import dagger.hilt.InstallIn
import dagger.hilt.android.components.ViewModelComponent

/**
 * @Provides rather than @Binds so core:domain never needs a DI-annotated
 * constructor -- it stays a plain Kotlin/JVM module with zero framework
 * dependencies, Hilt included.
 */
@Module
@InstallIn(ViewModelComponent::class)
object DomainModule {

    @Provides
    fun providePrayerTimeEngine(): PrayerTimeEngine = AdhanPrayerTimeEngine()
}
