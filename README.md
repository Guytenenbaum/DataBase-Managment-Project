# UFC Organization Database (ERD + SQL)

A relational database project for modeling the **Ultimate Fighting Championship (UFC)** organization: fighters (active/retired), weight classes, events, and fights - including business rules like PPV constraints, title fights, and “GOAT discussion” validation.


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

All queries are located under `queries/`. Each file answers a specific business question from the project spec.

### Query 1 – Extra Special Champion

**Goal:** Find fighters who are not only successful champions, but also *consistently* profitable.

**What it returns:**  
For each fighter (`Full_name`, `Nickname`) it returns:
- `WinCount` - how many championship wins they have (counted as rows in `Championship_winner`)
- `TotalMoney` - total money generated across those championship fights (sum of `Money_generated`)

**How it works:**
- Joins `Championship_winner (cw)` with `Championship_fight (cf)` to match each winner to the exact championship fight they won, using:
  - `Date`
  - `Category_Name` (fight category)
  - `Place_in_queue` (fight order within the event)
- Groups results by fighter identity (`Full_name`, `Nickname`)
- Filters to only include fighters who:
  - won **at least 2** championship fights (`COUNT(*) >= 2`)
  - generated **more than 10,000,000** total money from those fights (`SUM(Money_generated) > 10000000`)

**Interpretation:**  
A fighter appears in this result if they are a multi-time championship winner whose title fights collectively produced high revenue - an “extra special champion” by both performance and business impact.

---
### Query 2 – Active “destined for retirement” (age>32, multiple title losses, no future fight)

**Goal (matches the requirement):**  
Return **active fighters** who:
1) are **older than 32**,  
2) have **lost at least two championship (title) fights**, and  
3) are **not scheduled for any future fight**.

---

#### Supporting views used by the query

**`v1_ChampLosers` – losers in championship fights**  
Builds a row per championship fight with the *loser’s* name + nickname by:
- joining `Championship_winner` to the exact fight (`Fight`) using `(Date, Place_in_queue)`
- joining to `Fights_against` to get both participants
- selecting “the other fighter” (the opponent of the winner) via `CASE`

**`v2_LoserCounts` – title losses per fighter**  
Aggregates `v1_ChampLosers` and returns per fighter:
- `Full_name`, `Nickname`, `LossCount` (how many title fights they lost)

---

#### What Query 2 returns

For each fighter that meets the conditions, it outputs:
- `Full_name`, `Nickname`
- `Age`
- `LossCount` (number of championship/title-fight losses)

---

#### How Query 2 works

1) **Start from active fighters** (`Active a`)  
2) **Join fighter details** (`Fighter f`) to get the age  
3) **Join title-loss counts** (`v2_LoserCounts l`) to get `LossCount`  
4) **Filter by the requirements:**
- `f.Age > 32`
- `l.LossCount >= 2`
- `NOT EXISTS (...)` ensures the fighter does **not** appear in any fight whose date is in the future (`fut.Date > CAST(GETDATE() AS date)`), by checking `Fights_against` for that future fight.

**Interpretation:**  
This query finds older, active fighters who repeatedly failed in title fights (≥2 losses) and currently have **no future bout booked** - useful for identifying fighters who might be “stuck” or need matchmaking decisions.

---

### Query 3 - Rising stars (young Top-10 ranked fighters from elite MMA countries)

**Goal (matches the requirement):**  
Return fighters who:
1) are **27 or younger**,  
2) are **ranked in the Top 10** of their weight class,  
3) come from countries considered dominant in MMA: **Brazil, USA, Australia**.

---

#### How it’s built (views)

**`vq7_YoungTop10` – young Top-10 active fighters**  
Selects active fighters and joins their personal details from `Fighter`, keeping only:
- `Age <= 27`
- `Ranked BETWEEN 1 AND 10`

**Output fields:** `Full_name, Nickname, Age, Category_name, Ranked, Country`

**`vq7_YoungTop10_EliteCountries` – filter to elite countries**  
Filters `vq7_YoungTop10` to only fighters whose `Country` is one of:
- `Brazil`, `USA`, `Australia`

**`vq7_RisingStars` – final view for the query**  
A clean final projection of the same columns, used as the “rising stars” result set.


#### Final output
The query prints all rows from `vq7_RisingStars` and sorts them by:
1) `Category_name` (weight class)  
2) `Ranked` (best rank first)  
3) `Full_name` (stable alphabetical tie-break)

**Interpretation:**  
This produces a scouting-style list of young, highly ranked fighters from top MMA pipelines - useful for spotlighting future title contenders and marketing “next generation” stars.

---

### Query 4 – Title volatility per weight class (stability index)

**Goal (matches the requirement):**  
Compute a **volatility / stability measure** for each weight class based on how often the champion changes across consecutive title fights:

Volatility = (# Champion changes) / (# Title fights − 1)

Then return only categories with:
- at least **3** title fights, and
- volatility **≤ 0.8**

In addition, the output includes: number of title fights, number of changes, volatility score, number of distinct champions, and the first/last title-fight dates.

---

#### How it’s built (views)

**`vq4_TitleResults` – winners of all title fights**  
Creates a clean table of title fights and their winners by joining:
- `Championship_fight (cf)` with `Championship_winner (cw)` on `(Date, Category_Name, Place_in_queue)`.

**Output fields:** `Date, Category_Name, Place_in_queue, WinnerFull, WinnerNick`

**`vq4_TitleTimeline` – ordered timeline per weight class**  
Adds `ROW_NUMBER()` per `Category_Name` to order title fights chronologically (with `Place_in_queue` as a tie-breaker within the same date).

**Key field:** `rn` = sequential index of title fights inside each weight class.

**`vq4_TitleChangeFlags` – mark when the champion changes**  
Self-joins the timeline to the previous fight (`rn - 1`) and sets:
- `IsChange = 1` if winner differs from the previous winner
- `IsChange = 0` otherwise (and also 0 for the first fight in the category)
This is what counts “champion changes” across consecutive title fights.

**`vq4_TitleChampionCounts` – number of distinct champions**  
Counts distinct winners per category using:
- `COUNT(DISTINCT WinnerFull + '|' + WinnerNick)`

**`vq4_TitleVolatility` – compute volatility + summary stats**  
Aggregates per category:
- `TotalTitleFights` = number of title fights
- `Changes` = sum of `IsChange`
- `FirstDate`, `LastDate`
- `Volatility` = `Changes / (TotalTitleFights - 1)` (protected with `NULLIF` to avoid division by zero)
and joins `DistinctChampions`.

**`vq4_VolatileCategories` – apply required filters**  
Keeps only categories where:
- `TotalTitleFights >= 3`
- `Volatility <= 0.8`
---

#### Final output
Selects all rows from `vq4_VolatileCategories` and sorts by:
1) `Volatility DESC` (most volatile among the “allowed” ones first)  
2) `TotalTitleFights DESC`  
3) `Category_Name`

**Interpretation:**  
This query identifies weight classes where the belt is *reasonably stable* (volatility ≤ 0.8) while still capturing meaningful history (≥3 title fights). The extra fields help compare divisions by how many times the champion flipped, how many unique champions existed, and the relevant time range.

---
### Query 5 – “Popular fighter” + the events they fought in

**Definition (matches the requirement):**  
A fighter is considered **popular** if they satisfy all of the following:

1) They fought **at least 2 different opponents** (`OppCnt >= 2`)  
2) Those opponents come from **at least 2 different countries** (`OppCountryCnt >= 2`)  
3) They had a **rematch with every opponent** they fought (i.e., the *minimum* number of meetings against any opponent is at least 2 → `MinPairMeet >= 2`)  
4) Their “popularity level” (number of distinct opponents) is **greater than or equal to** the popularity level of **each opponent they fought**  
   (i.e., none of their opponents has a strictly higher `OpponentCount`)

**Final output:**  
Returns all `(Date, Full_name, Nickname)` pairs for popular fighters, sorted by date and name.

---

#### How the query works (views)

**`vq5_FighterOpponent` – directional fighter→opponent pairs**  
Turns each fight into *two* rows (A→B and B→A) using `UNION ALL`, so we can count opponents per fighter easily.

Columns:
- Fighter: `FighterFull, FighterNick`
- Opponent: `OppFull, OppNick`
- `Date`

**`vq5_PairCounts` – how many times each fighter met each opponent**  
Groups the directional pairs and counts meetings:
- `PairMeetings` = number of fights between this fighter and this opponent.


**`vq5_FighterDegree` – popularity level = number of distinct opponents**  
For each fighter:
- `OpponentCount` = `COUNT(DISTINCT opponent)`.

This is the “popularity” metric used in condition (4).


**`vq5_OpponentStats` – opponent diversity stats**  
For each fighter:
- `OppCnt` = number of distinct opponents  
- `OppCountryCnt` = number of distinct countries among those opponents  
  (via join to `Fighter` table for opponent country)


**`vq5_MinPairMeetings` – enforce “rematch with every opponent”**  
For each fighter:
- `MinPairMeet` = minimum meetings count across all their opponents.  
If `MinPairMeet >= 2`, then **every** opponent was faced at least twice.


**`vq5_DominatesOpponents` – popularity not lower than any opponent**  
Keeps fighters for whom **no opponent** has a strictly higher `OpponentCount`.  
Implemented with `NOT EXISTS` over their opponents.


**`vq5_PopularFighters` – combine all conditions**  
A fighter is popular if:
- `OppCnt >= 2`
- `OppCountryCnt >= 2`
- `MinPairMeet >= 2`
- and they appear in `vq5_DominatesOpponents`


**`vq5_PopularFighterEventDates` – final result set**  
Extracts distinct:
- `Date, Full_name, Nickname`
for every fight involving a popular fighter.


#### Interpretation
This query identifies fighters who:
- face a diverse set of opponents (and countries),
- consistently get rematches,
- and are at least as “connected” (by number of opponents) as everyone they fight.

The final table shows **when** those popular fighters appeared in events.


---
### How to run the queries
After creating and seeding the database:

**PostgreSQL**
```bash
psql -d ufc_db -f queries/champion_per_class.sql
psql -d ufc_db -f queries/crown_contenders.sql


