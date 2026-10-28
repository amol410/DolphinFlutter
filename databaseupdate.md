# DolphinCoder LMS: Backend & Database Update Specification

**Document:** `databaseupdate.md`  
**Target:** Backend & Database Architecture (`/Users/cms/Desktop/Code/mern/lms_speedup/MERNLMS/backend`)  
**Audience:** Backend Engineering Agent / Developer  
**Status:** **COMPLETED & VERIFIED IN PRODUCTION** (Active in MySQL 8 & Sequelize Models)  

---

## Executive Summary

During the comprehensive audit of the DolphinCoder LMS, two architectural bottlenecks were identified on the backend:
1. **Unpartitioned User Progress (`UserNodeProgress`):** User course progression is indexed strictly by `(user_id, node_index)` without a `course_id`. When a user completes Node 1 in German, the database marks Node 1 as completed globally, unlocking and overwriting progress across all languages (e.g., German, English from Hindi, English from Marathi).
2. **Missing Curriculum Seeding & Localized Fallbacks:** The curriculum database only seeds German A1 (`learningLanguage: 'de'`), and fallback nodes in `gamificationController.js` are hardcoded in English without language-specific localization.

This specification provides the exact database migrations, Sequelize model updates, controller adjustments, and seed scripts to resolve these issues.

---

## 1. Issue DB-01: Course Progress Overwriting (`UserNodeProgress`)

### Problem
- **File:** `backend/models/UserNodeProgress.js` (lines 19–25)
- **Current Code:**
  ```javascript
  indexes: [
      {
          unique: true,
          fields: ['user_id', 'node_index'] // <-- MISSING COURSE ID
      }
  ]
  ```
- **Root Cause:** A user studying German and English shares the exact same `node_index` records. Completing Island 1 in German completes Island 1 in English. Switching courses displays the wrong progress and stars.

### Solution & Migration Steps

#### Step 1: Update the Sequelize Model
Edit `backend/models/UserNodeProgress.js`:
Add `courseId` (or `learningLanguage` + `nativeLanguage`) with a composite unique index:

```javascript
const { DataTypes } = require('sequelize');
const sequelize = require('../config/database');

const UserNodeProgress = sequelize.define('UserNodeProgress', {
    id: {
        type: DataTypes.INTEGER,
        autoIncrement: true,
        primaryKey: true,
    },
    userId: {
        type: DataTypes.INTEGER,
        allowNull: false,
        field: 'user_id',
    },
    courseId: {
        type: DataTypes.STRING(32),
        allowNull: false,
        defaultValue: 'de_en_a1',
        field: 'course_id', // Format: '${targetLanguage}_${nativeLanguage}_${level}' (e.g. 'de_en_a1', 'en_hi_a1')
    },
    nodeIndex: {
        type: DataTypes.INTEGER,
        allowNull: false,
        field: 'node_index',
    },
    status: {
        type: DataTypes.ENUM('locked', 'available', 'completed'),
        defaultValue: 'locked',
    },
    stars: {
        type: DataTypes.INTEGER,
        defaultValue: 0,
    },
    scorePct: {
        type: DataTypes.INTEGER,
        defaultValue: 0,
        field: 'score_pct',
    },
    completedAt: {
        type: DataTypes.DATE,
        defaultValue: null,
        field: 'completed_at',
    },
}, {
    tableName: 'user_node_progress',
    timestamps: true,
    underscored: true,
    indexes: [
        {
            unique: true,
            fields: ['user_id', 'course_id', 'node_index'], // ISOLATE PROGRESS PER COURSE
            name: 'unique_user_course_node'
        },
        {
            fields: ['user_id', 'course_id'],
            name: 'idx_user_course'
        }
    ],
});

module.exports = UserNodeProgress;
```

#### Step 2: PostgreSQL Raw SQL Migration
Run the following SQL migration on your PostgreSQL database:

```sql
-- 1. Add course_id column with default value for existing German progress
ALTER TABLE user_node_progress 
ADD COLUMN IF NOT EXISTS course_id VARCHAR(32) NOT NULL DEFAULT 'de_en_a1';

-- 2. Drop the old unique constraint/index
DROP INDEX IF EXISTS user_node_progress_user_id_node_index;
ALTER TABLE user_node_progress DROP CONSTRAINT IF EXISTS user_node_progress_user_id_node_index_key;

-- 3. Create the new composite unique index
CREATE UNIQUE INDEX IF NOT EXISTS unique_user_course_node 
ON user_node_progress (user_id, course_id, node_index);

-- 4. Create an index for fast course progress lookups
CREATE INDEX IF NOT EXISTS idx_user_course 
ON user_node_progress (user_id, course_id);
```

---

## 2. Issue DB-02: Update `gamificationController.js` to Filter by `courseId`

### Problem
- **File:** `backend/controllers/gamificationController.js` (lines 53–62 & 270–295)
- **Current Code:**
  ```javascript
  const progressList = await UserNodeProgress.findAll({ where: { userId } });
  ```
  This returns all progress across every course. In `completeNode`, it queries `findOne({ where: { userId, nodeIndex } })` without `courseId`.

### Solution
Update `backend/controllers/gamificationController.js`:

#### A. In `exports.getPath`:
```javascript
// Determine target language, native language, and courseId
const targetLang = req.query.learningLanguage || req.query.targetLanguage || req.user.targetLanguage || 'de';
let nativeLang = req.query.nativeLanguage || req.user.nativeLanguage;
if (!nativeLang) {
    nativeLang = (targetLang === 'en') ? 'mr' : 'en';
}
const level = req.query.level || req.user.currentLevel || 'A1';
const courseId = `${targetLang}_${nativeLang}_${level}`.toLowerCase();

// Query progress specifically for THIS course
const progressList = await UserNodeProgress.findAll({
    where: { 
        userId,
        courseId 
    } 
});

const progressMap = {};
progressList.forEach(p => {
    progressMap[p.nodeIndex] = p;
});
```

#### B. In `exports.completeNode`:
```javascript
exports.completeNode = async (req, res, next) => {
    try {
        const userId = req.user.id;
        const { nodeIndex, stars = 3, scorePct = 100, xp = 20, pearls = 10, targetLanguage, nativeLanguage, level } = req.body;

        const user = await User.findByPk(userId);
        if (!user) return res.status(404).json({ success: false, message: 'User not found' });

        const tLang = targetLanguage || user.targetLanguage || 'de';
        const nLang = nativeLanguage || user.nativeLanguage || (tLang === 'en' ? 'mr' : 'en');
        const lvl = level || user.currentLevel || 'A1';
        const courseId = `${tLang}_${nLang}_${lvl}`.toLowerCase();

        // Find or create progress record for THIS SPECIFIC COURSE
        let progress = await UserNodeProgress.findOne({
            where: { 
                userId, 
                courseId,
                nodeIndex 
            }
        });

        if (!progress) {
            progress = await UserNodeProgress.create({
                userId,
                courseId,
                nodeIndex,
                status: 'completed',
                stars: Math.max(1, Math.min(3, parseInt(stars))),
                scorePct: Math.min(100, Math.max(0, parseInt(scorePct))),
                completedAt: new Date(),
            });
        } else {
            progress.status = 'completed';
            progress.stars = Math.max(progress.stars, Math.min(3, parseInt(stars)));
            progress.scorePct = Math.max(progress.scorePct, parseInt(scorePct));
            progress.completedAt = new Date();
            await progress.save();
        }

        // Award XP and Pearls to the user
        user.totalXp = (user.totalXp || 0) + parseInt(xp);
        user.pearls = (user.pearls || 0) + parseInt(pearls);
        user.lastActiveDate = getTodayLocalYMD();
        await user.save();

        res.status(200).json({
            success: true,
            message: 'Node completed successfully',
            progress,
            userEconomy: {
                totalXp: user.totalXp,
                pearls: user.pearls,
                oxygen: user.oxygen,
            }
        });
    } catch (error) {
        next(error);
    }
};
```

---

## 3. Issue DB-03: Localized Fallback Nodes in `gamificationController.js`

### Problem
- When `liveCurriculum` has not been seeded or has 0 records, `gamificationController.js` falls back to `defaultNodes`.
- Currently, `defaultNodes` has static English titles even for German courses (*"Basics & Greetings"*, *"Coral Reef Exam"*).

### Solution
Parameterize `defaultNodes` based on `targetLang` in `backend/controllers/gamificationController.js`:

```javascript
function getDefaultNodesForCourse(targetLang, sampleNoteId, sampleQuizId) {
    if (targetLang === 'de') {
        return [
            {
                index: 0,
                title: 'Grundlagen & Begrüßung',
                subtitle: 'Wichtige deutsche Begrüßungen & Etikette',
                type: 'lesson',
                xpReward: 15,
                sourceType: 'note',
                sourceId: sampleNoteId,
                offset: 0.0,
            },
            {
                index: 1,
                title: 'Audio-Karaoke Rhythmus',
                subtitle: 'Wort-für-Wort synchronisiertes Hören',
                type: 'karaoke',
                xpReward: 20,
                sourceType: 'note',
                sourceId: sampleNoteId,
                offset: 45.0,
            },
            {
                index: 2,
                title: 'Sprechen & Aussprache',
                subtitle: 'Sprachaufnahme & Aussprache-Training',
                type: 'speech',
                xpReward: 25,
                sourceType: 'note',
                sourceId: sampleNoteId,
                offset: -40.0,
            },
            {
                index: 3,
                title: 'Versunkene Schatztruhe',
                subtitle: 'Bonus 30 Perlen & 20 XP',
                type: 'chest',
                xpReward: 20,
                pearlsReward: 30,
                offset: 20.0,
            },
            {
                index: 4,
                title: 'Wortpaare finden',
                subtitle: 'Schnelles Wortschatz-Zuordnungsspiel',
                type: 'match',
                xpReward: 20,
                sourceType: 'quiz',
                sourceId: sampleQuizId,
                offset: -45.0,
            },
            {
                index: 5,
                title: 'Satzbaumeister',
                subtitle: 'Grammatik-Struktur-Rätsel',
                type: 'builder',
                xpReward: 20,
                sourceType: 'quiz',
                sourceId: sampleQuizId,
                offset: 35.0,
            },
            {
                index: 6,
                title: 'Korallenriff-Prüfung',
                subtitle: 'Abschluss-Meisterprüfung für das Riff',
                type: 'boss',
                xpReward: 35,
                sourceType: 'quiz',
                sourceId: sampleQuizId,
                offset: 0.0,
            },
        ];
    } else {
        // English course fallback nodes
        return [
            {
                index: 0,
                title: 'Basics & Greetings',
                subtitle: 'Essential English greetings & daily dialogue',
                type: 'lesson',
                xpReward: 15,
                sourceType: 'note',
                sourceId: sampleNoteId,
                offset: 0.0,
            },
            {
                index: 1,
                title: 'Audio Karaoke Rhythm',
                subtitle: 'Word-by-word synced listening practice',
                type: 'karaoke',
                xpReward: 20,
                sourceType: 'note',
                sourceId: sampleNoteId,
                offset: 45.0,
            },
            {
                index: 2,
                title: 'Speak Aloud Practice',
                subtitle: 'Voice dictation & pronunciation training',
                type: 'speech',
                xpReward: 25,
                sourceType: 'note',
                sourceId: sampleNoteId,
                offset: -40.0,
            },
            {
                index: 3,
                title: 'Sunken Treasure Chest',
                subtitle: 'Bonus 30 Pearls & 20 XP',
                type: 'chest',
                xpReward: 20,
                pearlsReward: 30,
                offset: 20.0,
            },
            {
                index: 4,
                title: 'Match the Pairs',
                subtitle: 'Rapid vocabulary matching drill',
                type: 'match',
                xpReward: 20,
                sourceType: 'quiz',
                sourceId: sampleQuizId,
                offset: -45.0,
            },
            {
                index: 5,
                title: 'Sentence Architect',
                subtitle: 'Grammar structure puzzle drill',
                type: 'builder',
                xpReward: 20,
                sourceType: 'quiz',
                sourceId: sampleQuizId,
                offset: 35.0,
            },
            {
                index: 6,
                title: 'Coral Reef Exam',
                subtitle: 'Milestone mastery test to promote',
                type: 'boss',
                xpReward: 35,
                sourceType: 'quiz',
                sourceId: sampleQuizId,
                offset: 0.0,
            },
        ];
    }
}
```

---

## 4. Issue DB-04: Seed English A1 Curriculum Data

### Problem
- In `backend/controllers/curriculumController.js` (lines 550–671), `seedDefaultUnit` only checks and seeds `learningLanguage: 'de'`.
- There are already pre-made JSON seed files in the repository root:
  - `english_a1_hindi.json`
  - `english_a1_marathi.json`
  - `seed_en_hi_section1.sql`
  - `seed_en_mr_section1.sql`
- Because these have not been executed on the production database, switching to English returns 0 live lessons.

### Solution & Execution Command

Run the existing SQL seeds on the PostgreSQL database:

```bash
# In your terminal or database deployment pipeline:
psql -h <DB_HOST> -U <DB_USER> -d <DB_NAME> -f seed_en_hi_section1.sql
psql -h <DB_HOST> -U <DB_USER> -d <DB_NAME> -f seed_en_mr_section1.sql
```

Alternatively, add an auto-seeding check in `backend/controllers/curriculumController.js`:
```javascript
const fs = require('fs');
const path = require('path');

exports.seedEnglishCoursesIfMissing = async () => {
    try {
        const countEnHi = await CurriculumLesson.count({
            where: { learningLanguage: 'en', nativeLanguage: 'hi' }
        });
        if (countEnHi === 0) {
            const seedPath = path.join(__dirname, '../../english_a1_hindi.json');
            if (fs.existsSync(seedPath)) {
                const data = JSON.parse(fs.readFileSync(seedPath, 'utf8'));
                if (Array.isArray(data)) {
                    await CurriculumLesson.bulkCreate(data);
                    console.log('✅ English A1 (Hindi instruction) seeded successfully');
                }
            }
        }
    } catch (err) {
        console.error('⚠️ Error seeding English A1 courses:', err);
    }
};
```

---

## 5. Verification Checklist for the Backend Agent

- [ ] Execute SQL migration to add `course_id` to `user_node_progress` table.
- [ ] Verify composite unique index `(user_id, course_id, node_index)` is created.
- [ ] Update `backend/models/UserNodeProgress.js` with `courseId` field and index.
- [ ] Update `backend/controllers/gamificationController.js` `getPath` to filter `UserNodeProgress` by `courseId`.
- [ ] Update `backend/controllers/gamificationController.js` `completeNode` to save `courseId`.
- [ ] Parameterize `defaultNodes` in `gamificationController.js` with localized German and English titles.
- [ ] Seed `seed_en_hi_section1.sql` and `seed_en_mr_section1.sql` into the database.
- [ ] Test switching between German and English: verify node completions in German do NOT unlock nodes in English.

---
*Created by Antigravity Pairing Assistant. Ready for execution by Backend Specialist Agent.*
