package com.example.health

import android.content.Context
import android.content.SharedPreferences
import org.json.JSONObject
import java.text.SimpleDateFormat
import java.util.Calendar
import java.util.Date
import java.util.Locale
import kotlin.math.roundToInt

object BackgroundStepStore {
    private const val prefsName = "FlutterSharedPreferences"
    private const val baselineKey = "flutter.steps_baseline"
    private const val baselineDateKey = "flutter.steps_baseline_date"
    private const val hourlyKey = "flutter.steps_hourly"
    private const val hourlyDateKey = "flutter.steps_hourly_date"
    private const val lastStepsKey = "flutter.steps_last_value"
    private const val dailyTotalsKey = "flutter.steps_daily_totals"
    private const val calibrationKey = "flutter.steps_calibration_factor"
    private const val backgroundEnabledKey = "flutter.steps_background_enabled"

    private val dateFormat = SimpleDateFormat("yyyy-MM-dd", Locale.US)

    fun setBackgroundEnabled(context: Context, enabled: Boolean) {
        prefs(context).edit().putBoolean(backgroundEnabledKey, enabled).apply()
    }

    fun isBackgroundEnabled(context: Context): Boolean {
        return prefs(context).getBoolean(backgroundEnabledKey, false)
    }

    fun updateFromRawStepCount(
        context: Context,
        currentSteps: Int,
        eventTimeMillis: Long = System.currentTimeMillis(),
    ): Int {
        val prefs = prefs(context)
        val eventDate = formatDate(Date(eventTimeMillis))

        val hasBaseline = prefs.contains(baselineKey)
        val baseline = if (hasBaseline) readIntLike(prefs, baselineKey, currentSteps) else currentSteps
        val baselineDate = readStringLike(prefs, baselineDateKey)
        val hasLastSteps = prefs.contains(lastStepsKey)
        val previousSteps = if (hasLastSteps) readIntLike(prefs, lastStepsKey, currentSteps) else null

        val resetDetected = (hasBaseline && currentSteps < baseline) ||
            (previousSteps != null && currentSteps < previousSteps)

        var resolvedBaseline = baseline
        if (!hasBaseline || baselineDate != eventDate || resetDetected) {
            resolvedBaseline = currentSteps
        }

        val calibration = readCalibration(prefs)
        val stepsToday = applyCalibration((currentSteps - resolvedBaseline).coerceAtLeast(0), calibration)

        val hourlyDate = readStringLike(prefs, hourlyDateKey)
        val hourlySteps = loadHourlySteps(readStringLike(prefs, hourlyKey), hourlyDate, eventDate)
        val hourOfDay = Calendar.getInstance().apply {
            timeInMillis = eventTimeMillis
        }.get(Calendar.HOUR_OF_DAY)
        val rawDelta = if (previousSteps != null && currentSteps >= previousSteps) {
            currentSteps - previousSteps
        } else {
            0
        }
        hourlySteps[hourOfDay] =
            (hourlySteps[hourOfDay] + applyCalibration(rawDelta, calibration)).coerceIn(0, 999999)

        val currentSum = hourlySteps.sum()
        if (stepsToday > currentSum) {
            hourlySteps[hourOfDay] =
                (hourlySteps[hourOfDay] + (stepsToday - currentSum)).coerceIn(0, 999999)
        }

        val dailyTotals = loadDailyTotals(readStringLike(prefs, dailyTotalsKey))
        dailyTotals[eventDate] = stepsToday
        pruneDailyTotals(dailyTotals, eventDate)

        prefs.edit()
            .putLong(baselineKey, resolvedBaseline.toLong())
            .putString(baselineDateKey, eventDate)
            .putString(hourlyDateKey, eventDate)
            .putString(hourlyKey, serializeHourlySteps(hourlySteps))
            .putLong(lastStepsKey, currentSteps.toLong())
            .putString(dailyTotalsKey, serializeDailyTotals(dailyTotals))
            .apply()

        return stepsToday
    }

    private fun prefs(context: Context): SharedPreferences {
        return context.getSharedPreferences(prefsName, Context.MODE_PRIVATE)
    }

    private fun formatDate(date: Date): String = dateFormat.format(date)

    private fun readCalibration(prefs: SharedPreferences): Double {
        val raw = prefs.all[calibrationKey]
        return when (raw) {
            is Number -> raw.toDouble()
            is String -> raw.toDoubleOrNull() ?: 1.0
            else -> 1.0
        }
    }

    private fun readIntLike(
        prefs: SharedPreferences,
        key: String,
        fallback: Int,
    ): Int {
        val raw = prefs.all[key]
        return when (raw) {
            is Int -> raw
            is Long -> raw.toInt()
            is Float -> raw.toInt()
            is Double -> raw.toInt()
            is String -> raw.toIntOrNull() ?: fallback
            else -> fallback
        }
    }

    private fun readStringLike(
        prefs: SharedPreferences,
        key: String,
    ): String? {
        val raw = prefs.all[key]
        return when (raw) {
            is String -> raw
            else -> null
        }
    }

    private fun applyCalibration(value: Int, factor: Double): Int {
        return (value * factor).roundToInt().coerceIn(0, 999999)
    }

    private fun loadHourlySteps(raw: String?, rawDate: String?, today: String): MutableList<Int> {
        if (raw.isNullOrBlank() || rawDate != today) {
            return MutableList(24) { 0 }
        }
        val parts = raw.split(",")
        if (parts.size != 24) {
            return MutableList(24) { 0 }
        }
        return parts.map { it.toIntOrNull() ?: 0 }.toMutableList()
    }

    private fun serializeHourlySteps(values: List<Int>): String {
        return values.joinToString(",") { it.toString() }
    }

    private fun loadDailyTotals(raw: String?): MutableMap<String, Int> {
        if (raw.isNullOrBlank()) {
            return mutableMapOf()
        }
        return try {
            val json = JSONObject(raw)
            val keys = json.keys()
            val map = mutableMapOf<String, Int>()
            while (keys.hasNext()) {
                val key = keys.next()
                map[key] = json.optInt(key, 0)
            }
            map
        } catch (_: Exception) {
            mutableMapOf()
        }
    }

    private fun serializeDailyTotals(values: Map<String, Int>): String {
        val json = JSONObject()
        values.toSortedMap().forEach { (key, value) ->
            json.put(key, value)
        }
        return json.toString()
    }

    private fun pruneDailyTotals(values: MutableMap<String, Int>, todayKey: String) {
        val today = runCatching { dateFormat.parse(todayKey) }.getOrNull() ?: Date()
        val cutoffTime = today.time - (29L * 24L * 60L * 60L * 1000L)
        values.entries.removeIf { (key, _) ->
            val parsed = runCatching { dateFormat.parse(key) }.getOrNull()
            parsed == null || parsed.time < cutoffTime
        }
    }
}
