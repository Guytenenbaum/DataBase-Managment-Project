# UFC Organization Database (ERD + SQL)

A relational database project for modeling the **Ultimate Fighting Championship (UFC)** organization: fighters (active/retired), weight classes, events, and fights — including business rules like PPV constraints, title fights, and “GOAT discussion” validation.


---

## What this database tracks

### Fighters
- A fighter is identified by **(full_name, nickname)**.
- Stored attributes:
  - record: wins / losses / draws
  - country of origin
  - age (in years)
- A fighter is **either**:
  - **Active fighter** (rank, weight class, is_current_champion)
  - **Retired fighter** (hall_of_fame, in_goat_discussion)

### Weight classes
- Identified by **category_name** (e.g., Lightweight, Heavyweight, etc.).
- Stored attributes:
  - minimum_weight, maximum_weight
  - champion (at most one; can be NULL if vacant)

### Events
- Identified uniquely by **event_date** (1–1).
- Stored attributes:
  - venue
  - is_ppv (pay-per-view)
  - is_blockbuster (“breaks the bank”)
  - a **guest retired fighter** invited to hype the crowd

### Fights
- Each fight includes **exactly two active fighters** in the **same weight class**.
- Fight types:
  - **title fight** (for the belt)
  - **regular fight**
- A fight is identified by: **(event_date + fighter_a + fighter_b)**

---

## Business rules enforced

Some rules can be shown in the ERD, and others must be enforced in **DDL / constraints / triggers**:

### Fighter-type rules
- A fighter cannot be both **active** and **retired** (mutual exclusivity).
- Retired fighter:
  - `in_goat_discussion = TRUE` ⇒ `hall_of_fame = TRUE`  
  (GOAT discussion is impossible without Hall of Fame membership.)

### Weight class rules
- Each fighter belongs to **exactly one** weight class (active fighters).
- Each weight class has **at most one champion**.
- Belt can be **vacant** (e.g., champion retired).

### Event rules
- `is_blockbuster = TRUE` ⇒ `is_ppv = TRUE`  
  (An event can’t be a blockbuster if it isn’t PPV.)
- Guest fighter rule:
  - If `is_ppv = TRUE`, the invited retired fighter must be **Hall of Fame**
  - If `is_ppv = FALSE`, the invited retired fighter can be any retired fighter

### Fight rules
- Exactly **two fighters** per fight.
- A fighter **cannot fight themselves**.
- Both fighters must be **active**, and in the **same weight class**.
- In a single event, each fighter can appear in **at most one fight**.

### Champion derivation (query-level logic)
The “current champion” for a weight class can be derived by:
- Finding the **latest title fight** in that weight class
- Taking the **winner**
- If no title fight exists, or the winner retired → champion is **vacant**

---

## Queries

All queries are located under `queries/` (or the folder you use). Each file answers a specific business question from the project spec.

### 1) Current champion per weight class
**Goal:** Return the current champion for every weight class.  
**Idea:** The champion is determined by the **latest title fight** in that weight class. The winner is the champion **unless** they retired (then the belt is considered **vacant**).  
**Output (typical):**
- weight_class
- champion_name (or NULL / “Vacant”)
- last_title_fight_date (optional)

File: `queries/champion_per_class.sql`

---

### 2) “Crown contenders” (title-fight candidates)
**Goal:** When the current champion is considered “old”, suggest the best candidates to fight for the belt.  
**Idea (typical):**
- filter to the champion’s weight class
- exclude the current champion
- sort by rank (and optionally win rate / total wins as tie-breakers)
- return top N contenders

**Parameters you might support:**
- age threshold (e.g., `>= 35`)
- top N results (e.g., `LIMIT 5`)

File: `queries/crown_contenders.sql`

---

### 3) Event & PPV validation / analytics (optional)
**Goal:** Help inspect that the data follows constraints (PPV/blockbuster, guest fighter rules, etc.) and/or provide event-level insights.  
Examples:
- list all PPV events and their Hall-of-Fame guest
- find blockbuster events that are not PPV (should be none)
- count fights per event, title fights per year, etc.

File: `queries/analytics.sql` (or your file name)

---

### How to run the queries
After creating and seeding the database:

**PostgreSQL**
```bash
psql -d ufc_db -f queries/champion_per_class.sql
psql -d ufc_db -f queries/crown_contenders.sql

## Repository structure (recommended)

