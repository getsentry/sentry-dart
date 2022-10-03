package io.sentry.samples.flutter

import androidx.test.ext.junit.rules.ActivityScenarioRule
import androidx.test.ext.junit.runners.AndroidJUnit4
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith

@RunWith(AndroidJUnit4::class)
class MainActivityTest {

    @get:Rule
    val activityScenarioRule = ActivityScenarioRule(
        MainActivity::class.java
    )

    @Test
    fun launchActivity() {
      print("Nothing to do except launching the main activity and executing without a crash.")
    }
}
