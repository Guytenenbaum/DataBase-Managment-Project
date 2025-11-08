--Query 1- extra special champion
SELECT  cw.Full_name,
        cw.Nickname,
        COUNT(*)                       AS WinCount,
        SUM(cf.Money_generated)        AS TotalMoney
FROM    Championship_winner cw
            JOIN    Championship_fight  cf
                    ON cf.Date           = cw.Date
                        AND cf.Category_Name  = cw.Category_name_fight
                        AND cf.Place_in_queue = cw.Place_in_queue
GROUP BY cw.Full_name, cw.Nickname
HAVING  COUNT(*) >= 2
   AND  SUM(cf.Money_generated) > 10000000;


/* View 2.1 – losers in championship fights */
CREATE OR ALTER VIEW v1_ChampLosers AS
SELECT  CASE
            WHEN fa.Full_name1 = cw.Full_name THEN fa.Full_name2
            ELSE fa.Full_name1
            END AS Loser ,
        CASE
            WHEN fa.Full_name1 = cw.Full_name THEN fa.Nickname2
            ELSE fa.Nickname1
            END AS LoserNick
FROM    Championship_winner cw
            JOIN    Fight             f   ON f.Date = cw.Date
    AND f.Place_in_queue = cw.Place_in_queue
            JOIN    Fights_against    fa  ON fa.Date = f.Date
    AND fa.Place_in_queue = f.Place_in_queue;
GO

/* V2 – count how many title-losses each fighter has */
CREATE OR ALTER VIEW v2_LoserCounts AS
SELECT  Loser       AS Full_name ,
        LoserNick   AS Nickname ,
        COUNT(*)    AS LossCount
FROM    v1_ChampLosers
GROUP BY Loser , LoserNick;
GO


--Query 2:
SELECT  a.Full_name ,
        a.Nickname ,
        f.Age ,
        l.LossCount
FROM    Active   AS a
            JOIN    Fighter  AS f ON f.Full_name = a.Full_name
    AND f.Nickname  = a.Nickname
            JOIN    v2_LoserCounts AS l
                    ON l.Full_name = a.Full_name
                        AND l.Nickname  = a.Nickname
WHERE   f.Age > 32
  AND   l.LossCount >= 2
  AND   NOT EXISTS (
    SELECT 1
    FROM   Fight fut
    WHERE  fut.Date > CAST(GETDATE() AS date)
      AND  EXISTS (
        SELECT 1
        FROM   Fights_against fa
        WHERE  fa.Date = fut.Date
          AND (fa.Full_name1 = a.Full_name
            OR fa.Full_name2 = a.Full_name)
    ));
GO

--Query 3:
CREATE OR ALTER VIEW vq7_YoungTop10 AS
SELECT
    a.Full_name,
    a.Nickname,
    f.Age,
    a.Category_name,
    a.Ranked,
    f.Country
FROM Active AS a
         JOIN Fighter AS f
              ON f.Full_name = a.Full_name
                  AND f.Nickname = a.Nickname
WHERE f.Age <= 27
  AND a.Ranked BETWEEN 1 AND 10;
GO


CREATE OR ALTER VIEW vq7_YoungTop10_EliteCountries AS
SELECT *
FROM vq7_YoungTop10
WHERE Country IN ('Brazil','USA','Australia');
GO


CREATE OR ALTER VIEW vq7_RisingStars AS
SELECT
    Full_name,
    Nickname,
    Age,
    Category_name,
    Ranked,
    Country
FROM vq7_YoungTop10_EliteCountries;
GO


SELECT * FROM vq7_RisingStars
ORDER BY Category_name, Ranked, Full_name;

/*Query 4:*/

CREATE OR ALTER VIEW vq4_TitleResults AS
SELECT
    cf.Date,
    cf.Category_Name,
    cf.Place_in_queue,
    cw.Full_name AS WinnerFull,
    cw.Nickname  AS WinnerNick
FROM Championship_fight  cf
         JOIN Championship_winner cw
              ON cw.Date = cf.Date
                  AND cw.Category_name_fight = cf.Category_Name
                  AND cw.Place_in_queue = cf.Place_in_queue;
GO


CREATE OR ALTER VIEW vq4_TitleTimeline AS
SELECT
    r.Date,
    r.Category_Name,
    r.Place_in_queue,
    r.WinnerFull,
    r.WinnerNick,
    ROW_NUMBER() OVER (
        PARTITION BY r.Category_Name
        ORDER BY r.Date, r.Place_in_queue
        ) AS rn
FROM vq4_TitleResults r;
GO


CREATE OR ALTER VIEW vq4_TitleChangeFlags AS
SELECT
    cur.Category_Name,
    cur.Date,
    cur.Place_in_queue,
    cur.WinnerFull,
    cur.WinnerNick,
    cur.rn,
    CASE
        WHEN prev.rn IS NULL THEN 0
        WHEN prev.WinnerFull <> cur.WinnerFull OR prev.WinnerNick <> cur.WinnerNick THEN 1
        ELSE 0
        END AS IsChange
FROM vq4_TitleTimeline cur
         LEFT JOIN vq4_TitleTimeline prev
                   ON prev.Category_Name = cur.Category_Name
                       AND prev.rn = cur.rn - 1;
GO


CREATE OR ALTER VIEW vq4_TitleChampionCounts AS
SELECT
    Category_Name,
    COUNT(DISTINCT WinnerFull + '|' + WinnerNick) AS DistinctChampions
FROM vq4_TitleResults
GROUP BY Category_Name;
GO


CREATE OR ALTER VIEW vq4_TitleVolatility AS
WITH agg AS (
    SELECT
        Category_Name,
        COUNT(*)        AS TotalTitleFights,
        SUM(IsChange)   AS Changes,
        MIN(Date)       AS FirstDate,
        MAX(Date)       AS LastDate
    FROM vq4_TitleChangeFlags
    GROUP BY Category_Name
)
SELECT
    a.Category_Name,
    a.TotalTitleFights,
    a.Changes,
    CAST(a.Changes AS float) / NULLIF(a.TotalTitleFights - 1, 0) AS Volatility,
    c.DistinctChampions,
    a.FirstDate,
    a.LastDate
FROM agg a
         JOIN vq4_TitleChampionCounts c
              ON c.Category_Name = a.Category_Name;
GO


CREATE OR ALTER VIEW vq4_VolatileCategories AS
SELECT
    Category_Name,
    TotalTitleFights,
    Changes,
    Volatility,
    DistinctChampions,
    FirstDate,
    LastDate
FROM vq4_TitleVolatility
WHERE TotalTitleFights >= 3
  AND Volatility <= 0.8;
GO


SELECT *
FROM vq4_VolatileCategories
ORDER BY Volatility DESC, TotalTitleFights DESC, Category_Name;



/*Query 5*/
CREATE OR ALTER VIEW vq5_FighterOpponent AS
SELECT fa.Full_name1 AS FighterFull, fa.Nickname1 AS FighterNick,
       fa.Full_name2 AS OppFull,    fa.Nickname2 AS OppNick,
       fa.[Date]
FROM Fights_against fa
UNION ALL
SELECT fa.Full_name2, fa.Nickname2,
       fa.Full_name1, fa.Nickname1,
       fa.[Date]
FROM Fights_against fa;
GO


CREATE OR ALTER VIEW vq5_PairCounts AS
SELECT FighterFull, FighterNick, OppFull, OppNick,
       COUNT(*) AS PairMeetings
FROM vq5_FighterOpponent
GROUP BY FighterFull, FighterNick, OppFull, OppNick;
GO


CREATE OR ALTER VIEW vq5_FighterDegree AS
SELECT FighterFull, FighterNick,
       COUNT(DISTINCT (OppFull + '|' + OppNick)) AS OpponentCount
FROM vq5_FighterOpponent
GROUP BY FighterFull, FighterNick;
GO


CREATE OR ALTER VIEW vq5_OpponentStats AS
SELECT
    fo.FighterFull,
    fo.FighterNick,
    COUNT(DISTINCT (fo.OppFull + '|' + fo.OppNick)) AS OppCnt,
    COUNT(DISTINCT fOpp.Country)                    AS OppCountryCnt
FROM vq5_FighterOpponent fo
         JOIN Fighter fOpp
              ON fOpp.Full_name = fo.OppFull AND fOpp.Nickname = fo.OppNick
GROUP BY fo.FighterFull, fo.FighterNick;
GO


CREATE OR ALTER VIEW vq5_MinPairMeetings AS
SELECT
    pc.FighterFull,
    pc.FighterNick,
    MIN(pc.PairMeetings) AS MinPairMeet
FROM vq5_PairCounts pc
GROUP BY pc.FighterFull, pc.FighterNick;
GO


CREATE OR ALTER VIEW vq5_DominatesOpponents AS
SELECT dF.FighterFull, dF.FighterNick
FROM vq5_FighterDegree dF
WHERE NOT EXISTS (
    SELECT 1
    FROM vq5_FighterOpponent fo
             JOIN vq5_FighterDegree dO
                  ON dO.FighterFull = fo.OppFull
                      AND dO.FighterNick = fo.OppNick
    WHERE fo.FighterFull = dF.FighterFull
      AND fo.FighterNick = dF.FighterNick
      AND dO.OpponentCount > dF.OpponentCount
);
GO


CREATE OR ALTER VIEW vq5_PopularFighters AS
SELECT os.FighterFull, os.FighterNick
FROM vq5_OpponentStats     os
         JOIN vq5_MinPairMeetings   mp ON mp.FighterFull = os.FighterFull AND mp.FighterNick = os.FighterNick
         JOIN vq5_DominatesOpponents d ON d.FighterFull  = os.FighterFull AND d.FighterNick  = os.FighterNick
WHERE os.OppCnt >= 2
  AND os.OppCountryCnt >= 2
  AND mp.MinPairMeet >= 2;
GO


CREATE OR ALTER VIEW vq5_PopularFighterEventDates AS
SELECT DISTINCT
    fo.[Date],
    pf.FighterFull  AS Full_name,
    pf.FighterNick  AS Nickname
FROM vq5_FighterOpponent fo
         JOIN vq5_PopularFighters pf
              ON pf.FighterFull = fo.FighterFull
                  AND pf.FighterNick = fo.FighterNick;
GO

SELECT * FROM vq5_PopularFighterEventDates ORDER BY [Date], Full_name;

