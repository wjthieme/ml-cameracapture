package com.sogeti.mlcameracapture.Utilities

import android.content.Context
import android.content.Context.MODE_PRIVATE

enum class Preferences {

    CurrentCategory, CropSquare;

    companion object {
        val kPreferencesName = "MLCameraCapturePreferences"
    }

    fun set(context: Context?, value: Any?) {
        if (context == null) return
        val editor = context.getSharedPreferences(kPreferencesName, MODE_PRIVATE).edit()
        if (value == null) { editor.remove(name) }
        if (value is String) { editor.putString(name, value) }
        if (value is Boolean) { editor.putBoolean(name, value) }
        if (value is Int) { editor.putInt(name, value) }
        if (value is Float) { editor.putFloat(name, value) }
        if (value is Long) { editor.putLong(name, value) }
        editor.apply()
    }

    fun getString(context: Context?): String? {
        if (context == null) return null
        val preferences = context.getSharedPreferences(kPreferencesName, MODE_PRIVATE)
        return preferences.getString(name, null)
    }

    fun getBool(context: Context?): Boolean {
        if (context == null) return false
        val preferences = context.getSharedPreferences(kPreferencesName, MODE_PRIVATE)
        return preferences.getBoolean(name, false)
    }

    fun getInt(context: Context?): Int {
        if (context == null) return 0
        val preferences = context.getSharedPreferences(kPreferencesName, MODE_PRIVATE)
        return preferences.getInt(name, 0)
    }

    fun getFloat(context: Context?): Float {
        if (context == null) return 0f
        val preferences = context.getSharedPreferences(kPreferencesName, MODE_PRIVATE)
        return preferences.getFloat(name, 0f)
    }

    fun getLong(context: Context?): Long {
        if (context == null) return 0
        val preferences = context.getSharedPreferences(kPreferencesName, MODE_PRIVATE)
        return preferences.getLong(name, 0)
    }

}