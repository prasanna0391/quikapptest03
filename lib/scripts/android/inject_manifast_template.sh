#!/bin/bash

# Define the target directory
TARGET_DIR="android/app/src/main"
TARGET_FILE="${TARGET_DIR}/AndroidManifest_template.xml"

# Ensure the target directory exists
mkdir -p "$TARGET_DIR"

# Use cat EOF to inject the content
cat <<EOF > "$TARGET_FILE"
<?xml version="1.0" encoding="utf-8"?>
<manifest xmlns:android="http://schemas.android.com/apk/res/android"
    package="com.garbcode.garbcodeapp">

    <!--PERMISSIONS-->

    <application
        android:name=".MainApplication"
        android:label="My Flutter App"
        android:icon="@mipmap/ic_launcher"
        android:usesCleartextTraffic="true"
        android:roundIcon="@mipmap/ic_launcher"
        android:theme="@style/LaunchTheme">

        <activity
            android:name=".MainActivity"
            android:exported="true"
            android:launchMode="singleTop"
            android:theme="@style/LaunchTheme"
            android:configChanges="orientation|keyboardHidden|keyboard|screenSize|locale|layoutDirection|fontScale|screenLayout|density|uiMode"
            android:hardwareAccelerated="true"
            android:windowSoftInputMode="adjustResize">

            <meta-data
                android:name="io.flutter.embedding.android.NormalTheme"
                android:resource="@style/NormalTheme" />

            <intent-filter>
                <action android:name="android.intent.action.MAIN" />
                <category android:name="android.intent.category.LAUNCHER" />
            </intent-filter>

        </activity>

        <meta-data
            android:name="flutterEmbedding"
            android:value="2" />

    </application>
</manifest>
EOF

echo "AndroidManifest.xml successfully created/updated at $TARGET_FILE"