/* Licensed under Apache 2.0 (C) 2023 Firezone, Inc. */
package dev.firezone.android.core.di

import android.content.Context
import android.content.SharedPreferences
import androidx.core.content.getSystemService
import dagger.Module
import dagger.Provides
import dagger.hilt.InstallIn
import dagger.hilt.android.qualifiers.ApplicationContext
import dagger.hilt.components.SingletonComponent
import dev.firezone.android.core.data.Repository
import dev.firezone.android.core.data.RepositoryImpl
import kotlinx.coroutines.CoroutineDispatcher

@Module
@InstallIn(SingletonComponent::class)
class DataModule {
    @Provides
    internal fun provideRepository(
        @ApplicationContext context: Context,
        @IoDispatcher coroutineDispatcher: CoroutineDispatcher,
        sharedPreferences: SharedPreferences,
    ): Repository =
        RepositoryImpl(
            context,
            coroutineDispatcher,
            sharedPreferences,
            (
                context.getSystemService(Context.RESTRICTIONS_SERVICE)
                    as android.content.RestrictionsManager
            ).applicationRestrictions,
        )
}
