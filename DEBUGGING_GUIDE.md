# Waky Debugging Guide

## Recent Fixes Applied

I've added extensive logging throughout the app to diagnose why alarms aren't showing up. Here's what was fixed:

### 1. **Fixed Deprecated API**
- Removed deprecated `stopButton` parameter in iOS 26.1
- Now using simple `AlarmPresentation.Alert(title:)` initializer

### 2. **Added Comprehensive Logging**
The app now logs every step of the alarm scheduling process:
- Authorization state and requests
- Schedule validation
- Alarm configuration details
- Success/failure messages with error details

### 3. **Simplified Alarm Presentation**
- Matches the example project pattern exactly
- Uses basic alert without custom buttons initially

## How to Test with Logs

### Step 1: Install the Latest Build
The app has been rebuilt for your device. Install it:

```bash
# Using Xcode (easiest way)
1. Open Waky.xcodeproj in Xcode
2. Select your device "Bruh" from the device dropdown
3. Click Run (▶️)
```

### Step 2: Watch Console for Logs

**In Xcode:**
1. With your device connected and app running
2. Open **View → Debug Area → Activate Console** (Cmd+Shift+C)
3. Filter for "Waky" in the console search box

**Or use Console.app:**
1. Open **Console.app** (Applications → Utilities)
2. Select your device "Bruh" on the left
3. Filter: `subsystem:com.trile.Waky`

### Step 3: Create a Test Alarm

Tap the **+** button → **"Test Alarm (2 min)"**

You should see these logs:

```
=== SCHEDULING TEST ALARM ===
Test alarm schedule: relative(Relative(...))
Test alarm ID: XXXXXXXX-XXXX-XXXX-XXXX-XXXXXXXXXXXX
Calling scheduleAlarm with ID: XXXXXXXX-XXXX-XXXX-XXXX-XXXXXXXXXXXX
📝 scheduleAlarm called with ID: XXXXXXXX-XXXX-XXXX-XXXX-XXXXXXXXXXXX
🔐 Requesting authorization...
Current authorization state: authorized (or notDetermined)
Authorization result: true
✅ Authorized! Scheduling alarm...
✅ Alarm scheduled successfully: Alarm(...)
Alarm state: scheduled
📍 Adding alarm to alarmsMap on MainActor
📍 alarmsMap now has 1 alarms
```

### Step 4: Create a Regular Alarm

Tap **+** button → **"New Alarm"**
1. Enter a label (e.g., "Wake Up")
2. Set time to 1-2 minutes from now
3. Tap **Save**

Expected logs:

```
=== SCHEDULING ALARM ===
Label: Wake Up
Selected date: 2026-01-28 02:30:00 +0000
Selected days: []
Alarm ID: XXXXXXXX-XXXX-XXXX-XXXX-XXXXXXXXXXXX
✅ Schedule created: relative(Relative(...))
Calling scheduleAlarm with ID: XXXXXXXX-XXXX-XXXX-XXXX-XXXXXXXXXXXX
[... authorization and scheduling logs ...]
✅ Alarm scheduled successfully
📍 alarmsMap now has 2 alarms
```

## What the Logs Tell Us

### ✅ Success Scenario:
```
✅ Authorized! Scheduling alarm...
✅ Alarm scheduled successfully: Alarm(...)
Alarm state: scheduled
📍 alarmsMap now has X alarms
```
→ Alarm is scheduled correctly and should appear in the list

### ❌ Authorization Failed:
```
Current authorization state: denied
❌ Not authorized to schedule alarms.
```
→ **Fix:** Go to Settings → Waky → Enable "Alarms"

### ❌ Schedule Invalid:
```
❌ ERROR: Invalid schedule - userInput.schedule is nil
```
→ Problem with date/time picker - shouldn't happen with current code

### ❌ Scheduling Error:
```
❌ ERROR encountered when scheduling alarm: Error Domain=...
Error code: XXX
```
→ Share the full error details - this is the key diagnostic info

## Common Issues and Fixes

### Issue: Alarm doesn't appear in list after saving

**Check logs for:**
- `📍 alarmsMap now has X alarms` - Should increment
- `Alarm state: scheduled` - Confirms alarm is scheduled

**If you see the success logs but NO alarm in UI:**
- This means the UI binding isn't working
- Check that ContentView is observing `viewModel.alarmsMap` changes
- Try force-closing and reopening the app

**If you DON'T see success logs:**
- Authorization likely failed
- Look for error messages in the logs

### Issue: "Not authorized to schedule alarms"

**Fix:**
1. Go to **Settings** app on your iPhone
2. Scroll to **Waky**
3. Find **Alarms** permission
4. Enable it
5. Restart Waky app
6. Try scheduling again

### Issue: Alarm scheduled but doesn't trigger

**Verify in logs:**
- `Alarm state: scheduled` ✅
- Alarm appears in the list ✅
- Wait for the alarm time...

**If alarm still doesn't trigger:**
- Check Do Not Disturb / Focus mode
- Check device isn't in Low Power Mode
- Verify iOS 26+ on your device
- Try the Test Alarm (2 min) for quick testing

### Issue: Empty error - Error Domain=com.apple.AlarmKit.Alarm Code=X

This is the key diagnostic! Different error codes mean:
- **Code 1**: Authorization issue
- **Code 2**: Invalid configuration
- **Code 3**: Scheduling conflict
- **Other**: Share the full error for diagnosis

## What to Share if Still Not Working

Please share:
1. **Full console logs** from when you tap "Save" on an alarm
2. **Screenshots** of:
   - The main Waky screen (showing alarm list)
   - Settings → Waky (showing permissions)
3. **iOS version** on your device
4. **Any error messages** you see

## Next Debugging Steps

If alarms still don't work after checking logs:

1. **Compare with Example App**: Try running the Example_Code_AlarmKit project on your device to verify AlarmKit works at all
2. **Check Entitlements**: Verify Waky.entitlements is linked in Xcode
3. **Clean Build**: Xcode → Product → Clean Build Folder, then rebuild
4. **Reset Permissions**: Delete app, reinstall, grant permissions fresh

The extensive logging should reveal exactly where the process is failing!
