package com.sogeti.mlcameracapture.Utilities

import android.os.AsyncTask

class Async(val handler: () -> Unit) : AsyncTask<Void, Void, Void>() {

    init {
        execute()
    }

    override fun doInBackground(vararg params: Void?): Void? {
        handler()
        return null
    }
}