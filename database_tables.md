# Database Tables Definition

### Slide 1: TABLE - APP_USERS

| FIELD NAME | DATA TYPE          | DESCRIPTION                        |
| ---------- | ------------------ | ---------------------------------- |
| id         | UUID (PRIMARY KEY) | PRIMARY KEY, Supabase Auth User ID |
| email      | STRING             | UNIQUE, NOT NULL                   |
| created_at | DATETIME           | DEFAULT NOW()                      |

---

### Slide 2: TABLE - USER_METRICS

| FIELD NAME     | DATA TYPE          | DESCRIPTION      |
| -------------- | ------------------ | ---------------- |
| id             | UUID (PRIMARY KEY) | PRIMARY KEY      |
| user_id        | UUID (FOREIGN KEY) | UNIQUE, NOT NULL |
| age            | INTEGER            | NULL             |
| weight_kg      | DECIMAL            | NULL             |
| height_cm      | DECIMAL            | NULL             |
| activity_level | STRING             | DEFAULT 'low'    |

---

### Slide 3: TABLE - FOODS

| FIELD NAME   | DATA TYPE          | DESCRIPTION                        |
| ------------ | ------------------ | ---------------------------------- |
| id           | UUID (PRIMARY KEY) | PRIMARY KEY                        |
| food_key     | STRING             | UNIQUE, NOT NULL, Identifier Label |
| display_name | STRING             | NOT NULL                           |

---

### Slide 4: TABLE - FOOD_NUTRITION

| FIELD NAME     | DATA TYPE          | DESCRIPTION      |
| -------------- | ------------------ | ---------------- |
| id             | UUID (PRIMARY KEY) | PRIMARY KEY      |
| food_id        | UUID (FOREIGN KEY) | UNIQUE, NOT NULL |
| serving_size_g | DECIMAL            | NULL             |
| calories_kcal  | DECIMAL            | NULL             |
| carbs_g        | DECIMAL            | NULL             |
| protein_g      | DECIMAL            | NULL             |
| fat_g          | DECIMAL            | NULL             |

---

### Slide 5: TABLE - MEAL_LOGS

| FIELD NAME | DATA TYPE          | DESCRIPTION |
| ---------- | ------------------ | ----------- |
| id         | UUID (PRIMARY KEY) | PRIMARY KEY |
| user_id    | UUID (FOREIGN KEY) | NOT NULL    |
| food_id    | UUID (FOREIGN KEY) | NULL        |
| servings   | DECIMAL            | NOT NULL    |
| eaten_at   | DATETIME           | NOT NULL    |
| confidence | DECIMAL            | NOT NULL    |
| image_path | STRING             | NULL        |

---

### Slide 6: TABLE - WATER_LOGS

| FIELD NAME | DATA TYPE          | DESCRIPTION |
| ---------- | ------------------ | ----------- |
| id         | UUID (PRIMARY KEY) | PRIMARY KEY |
| user_id    | UUID (FOREIGN KEY) | NOT NULL    |
| amount_ml  | INTEGER            | NOT NULL    |
| logged_at  | DATETIME           | NOT NULL    |

---

### Slide 7: TABLE - USER_TODOS

| FIELD NAME | DATA TYPE          | DESCRIPTION   |
| ---------- | ------------------ | ------------- |
| id         | UUID (PRIMARY KEY) | PRIMARY KEY   |
| user_id    | UUID (FOREIGN KEY) | NOT NULL      |
| title      | STRING             | NOT NULL      |
| category   | STRING             | NOT NULL      |
| is_done    | BOOLEAN            | DEFAULT FALSE |
| todo_date  | DATE               | NOT NULL      |
| created_at | DATETIME           | DEFAULT NOW() |

---

### Slide 8: TABLE - USER_REMINDERS

| FIELD NAME    | DATA TYPE          | DESCRIPTION   |
| ------------- | ------------------ | ------------- |
| id            | UUID (PRIMARY KEY) | PRIMARY KEY   |
| user_id       | UUID (FOREIGN KEY) | NOT NULL      |
| reminder_time | TIME               | NOT NULL      |
| is_active     | BOOLEAN            | DEFAULT TRUE  |
| created_at    | DATETIME           | DEFAULT NOW() |

---

### Slide 9: TABLE - MISSED_REMINDERS

| FIELD NAME   | DATA TYPE          | DESCRIPTION |
| ------------ | ------------------ | ----------- |
| id           | UUID (PRIMARY KEY) | PRIMARY KEY |
| user_id      | UUID (FOREIGN KEY) | NOT NULL    |
| reminder_id  | UUID (FOREIGN KEY) | NOT NULL    |
| scheduled_at | DATETIME           | NOT NULL    |

---

### Slide 10: TABLE - WATER_REMINDER_EVENTS

| FIELD NAME   | DATA TYPE          | DESCRIPTION                                            |
| ------------ | ------------------ | ------------------------------------------------------ |
| id           | UUID (PRIMARY KEY) | PRIMARY KEY                                            |
| user_id      | UUID (FOREIGN KEY) | NOT NULL                                               |
| scheduled_at | DATETIME           | NOT NULL                                               |
| fired_at     | DATETIME           | NULL                                                   |
| status       | STRING             | NOT NULL (e.g., pending, completed, missed, cancelled) |

---

### Slide 11: TABLE - USER_NOTIFICATION_SETTINGS

| FIELD NAME              | DATA TYPE          | DESCRIPTION      |
| ----------------------- | ------------------ | ---------------- |
| id                      | UUID (PRIMARY KEY) | PRIMARY KEY      |
| user_id                 | UUID (FOREIGN KEY) | UNIQUE, NOT NULL |
| water_reminders_enabled | BOOLEAN            | DEFAULT TRUE     |
| water_reminder_times    | JSONB              | NOT NULL         |
| updated_at              | DATETIME           | DEFAULT NOW()    |

---

### Slide 12: TABLE - SETTINGS

| FIELD NAME | DATA TYPE          | DESCRIPTION      |
| ---------- | ------------------ | ---------------- |
| id         | UUID (PRIMARY KEY) | PRIMARY KEY      |
| key        | STRING             | UNIQUE, NOT NULL |
| value_json | JSONB              | NOT NULL         |
