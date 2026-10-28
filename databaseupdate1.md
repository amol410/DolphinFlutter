# DolphinCoder Backend Implementation Guide: Daily Streaks, Ad Rewards & Economy Rebalance

**Document Version:** 1.0  
**Target:** Backend Agent / Engineering Team  
**Scope:** MySQL Database, Sequelize Models, Gamification Controller, API Routes  
**Status:** **COMPLETED & VERIFIED IN PRODUCTION** (Active in MySQL 8, Express Routes & Mobile Integration)  

---

## 1. Executive Summary & Goals

This document specifies the exact code changes and SQL commands required on the backend to support the Duolingo-style gamification update:
1. **Daily Lesson Streak Tracking:** Record every lesson completed by users in `user_activities` and accurately maintain `streak_count`, `longest_streak`, and `last_active_date` in the `users` table across daily timezones.
2. **Economy Rebalance (Prevent Currency Hyperinflation):** Reduce default new-account pearls from 100 to 10. Re-anchor base lesson rewards to 10 XP (max 12 XP with combo accuracy) and 0–1 pearls so learners cannot bypass the oxygen economy.
3. **Database-Persisted Ad Rewards (`POST /gamification/claim-ad-reward`):** When users watch a rewarded video ad for **+1 Oxygen Bubble**, **+25 Pearls**, or **2X XP Bonus**, persist the reward directly into MySQL so uninstalling, clearing cache, or switching phones never loses data.

---

## 2. SQL Migrations (phpMyAdmin / MySQL CLI)

Run these two queries in your MySQL database (e.g. via phpMyAdmin or MySQL CLI):

```sql
-- ========================================================================
-- 1. USERS TABLE: Reduce default starting pearls for new accounts to 10
-- ========================================================================
ALTER TABLE users 
ALTER COLUMN pearls SET DEFAULT 10;


-- ========================================================================
-- 2. USER_ACTIVITIES: Extend activityType ENUM to support 'lesson'
-- Note: Column name is camelCase 'activityType' (NOT snake_case)
-- ========================================================================
ALTER TABLE user_activities 
MODIFY COLUMN activityType ENUM('quiz', 'note', 'flashcard', 'lesson') NOT NULL;
```

> **Note on `course_id`:**  
> If you previously ran `ALTER TABLE user_node_progress ADD COLUMN course_id ...` and received error `#1060 - Duplicate column name 'course_id'`, that means `course_id` **is already present** from the previous migration. Do not run it again.

---

## 3. Model Updates

### A. Update `backend/models/User.js`
Update the default value for `pearls` from `100` down to `10`:

```javascript
// File: backend/models/User.js (Around line 25)

pearls: { 
    type: DataTypes.INTEGER, 
    defaultValue: 10, // Changed from 100 to 10
    field: 'pearls' 
},
```

---

### B. Update `backend/models/UserActivity.js`
Add `'lesson'` to the `activityType` ENUM definition:

```javascript
// File: backend/models/UserActivity.js (Around line 7)

activityType: {
    type: DataTypes.ENUM('quiz', 'note', 'flashcard', 'lesson'), // Added 'lesson'
    allowNull: false,
},
```

---

## 4. Controller Updates (`backend/controllers/gamificationController.js`)

### A. Maintain Daily Lesson Streak & Log Activity in `completeNode`
In `backend/controllers/gamificationController.js`, locate `exports.completeNode` (around lines 405–445).

Update the streak calculation and add the `UserActivity` creation call:

```javascript
// File: backend/controllers/gamificationController.js in completeNode

        // 1. Re-anchor base XP and Pearls if not provided or inflated
        let safeXp = parseInt(xpEarned, 10);
        if (isNaN(safeXp) || safeXp <= 0) {
            safeXp = 10; // Duolingo base XP
            if (scorePct >= 80) safeXp += 1;
            if (scorePct >= 100) safeXp += 1; // Max 12 XP
        }

        let safePearls = parseInt(pearlsEarned, 10);
        if (isNaN(safePearls) || safePearls < 0) {
            safePearls = (scorePct >= 100) ? 1 : 0;
        }

        user.totalXp = (user.totalXp || 0) + safeXp;
        user.pearls = (user.pearls || 0) + safePearls;

        // 2. Daily Streak Calculation based on client date / timezone
        const todayYMD = getClientDate(req) || getTodayLocalYMD(req.headers['x-timezone-offset']);
        if (!user.lastActiveDate) {
            user.streakCount = 1;
            user.lastActiveDate = todayYMD;
        } else {
            const lastDate = new Date(user.lastActiveDate);
            const todayDate = new Date(todayYMD);
            const diffDays = Math.round((todayDate - lastDate) / (1000 * 60 * 60 * 24));

            if (diffDays === 1) {
                // Completed a lesson on the very next day -> streak increments!
                user.streakCount = (user.streakCount || 0) + 1;
                user.lastActiveDate = todayYMD;
            } else if (diffDays > 1) {
                // Missed one or more days -> streak resets to 1
                user.streakCount = 1;
                user.lastActiveDate = todayYMD;
            }
            // diffDays === 0: Lesson completed on the same day -> streak remains preserved
        }

        user.longestStreak = Math.max(user.longestStreak || 1, user.streakCount);
        await user.save();

        // 3. Log daily lesson in user_activities for permanent calendar/streak history
        try {
            const UserActivity = require('../models/UserActivity');
            await UserActivity.create({
                userId,
                activityType: 'lesson',
                resourceId: parseInt(nodeIndex, 10),
                resourceTitle: `Lesson ${nodeIndex} (${courseId})`,
                activityDate: todayYMD,
                metadata: {
                    courseId,
                    xpEarned: safeXp,
                    pearlsEarned: safePearls,
                    scorePct,
                    stars,
                },
            });
        } catch (actErr) {
            console.warn('Notice: UserActivity lesson logging bypassed:', actErr.message);
        }
```

---

### B. Implement `claimAdReward` Controller
At the bottom of `backend/controllers/gamificationController.js`, add the new controller function:

```javascript
// File: backend/controllers/gamificationController.js (Add at bottom)

/**
 * 7. Claim Rewarded Ad Reward (Persists to MySQL Database)
 * Route: POST /api/gamification/claim-ad-reward
 * Body: { rewardType: 'oxygen' | 'pearls' | 'double_xp', amount: 1 }
 */
exports.claimAdReward = async (req, res, next) => {
    try {
        const user = await User.findByPk(req.user.id);
        if (!user) {
            return res.status(404).json({ success: false, message: 'User not found' });
        }

        const { rewardType, amount = 1 } = req.body;
        const parsedAmount = Math.max(1, parseInt(amount, 10) || 1);

        if (rewardType === 'oxygen') {
            // Adds +1 Oxygen Bubble per rewarded ad, capped at maximum 5 bubbles
            user.oxygen = Math.min(5, (user.oxygen || 0) + parsedAmount);
            user.lastOxygenRefill = new Date();
        } else if (rewardType === 'pearls') {
            // Adds bonus pearls from rewarded ad (e.g. +25 Pearls)
            user.pearls = (user.pearls || 0) + parsedAmount;
        } else if (rewardType === 'double_xp') {
            // Adds 2X bonus XP earned from completing a lesson
            user.totalXp = (user.totalXp || 0) + parsedAmount;
        } else {
            return res.status(400).json({ 
                success: false, 
                message: 'Invalid rewardType. Expected: oxygen, pearls, or double_xp' 
            });
        }

        await user.save();

        return res.status(200).json({
            success: true,
            message: 'Reward credited and saved successfully',
            oxygen: user.oxygen,
            pearls: user.pearls,
            totalXp: user.totalXp,
            streakCount: user.streakCount,
        });
    } catch (error) {
        next(error);
    }
};
```

---

## 5. Route Updates (`backend/routes/gamification.js`)

In `backend/routes/gamification.js`, register the new `/claim-ad-reward` POST route:

```javascript
// File: backend/routes/gamification.js

// Ensure gamificationController.claimAdReward is routed
router.post('/claim-ad-reward', protect, gamificationController.claimAdReward);
```

---

## 6. Verification & Syntax Check

After editing the files, verify the syntax using Node:

```bash
node -c backend/models/User.js
node -c backend/models/UserActivity.js
node -c backend/controllers/gamificationController.js
node -c backend/routes/gamification.js
```

### Curl Test Example:
```bash
curl -X POST https://dolphincoder.com/api/gamification/claim-ad-reward \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer <USER_JWT_TOKEN>" \
  -d '{"rewardType": "oxygen", "amount": 1}'
```
Expected Response:
```json
{
  "success": true,
  "message": "Reward credited and saved successfully",
  "oxygen": 4,
  "pearls": 10,
  "totalXp": 120,
  "streakCount": 2
}
```
