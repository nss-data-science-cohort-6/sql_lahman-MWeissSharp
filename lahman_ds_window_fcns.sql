-- ## Question 1: Rankings
-- #### Question 1a: Warmup Question
-- Write a query which retrieves each teamid and number of wins (w) for the 2016 season. Apply three window functions to the number of wins (ordered in descending order) - ROW_NUMBER, RANK, AND DENSE_RANK. Compare the output from these three functions. What do you notice?
SELECT teamid,
	   w,
	   ROW_NUMBER() OVER(ORDER BY w DESC),
	   RANK() OVER(ORDER BY w DESC),
	   DENSE_RANK() OVER(ORDER BY w DESC)
FROM teams
WHERE yearid = 2016;

-- #### Question 1b: 
-- Which team has finished in last place in its division (i.e. with the least number of wins) the most number of times? A team's division is indicated by the divid column in the teams table.
WITH div_ranks AS (	SELECT teamid,
						   RANK() OVER(PARTITION BY divid, yearid ORDER BY w)
					FROM teams)
SELECT divid,
	   teamid,
	   COUNT(teamid) AS bottom_of_the_barrel
FROM div_ranks
WHERE rank = 11
GROUP BY divid, teamid
ORDER BY bottom_of_the_barrel DESC;

-- ## Question 2: Cumulative Sums
-- #### Question 2a: 
-- Barry Bonds has the record for the highest career home runs, with 762. Write a query which returns, for each season of Bonds' career the total number of seasons he had played and his total career home runs at the end of that season. (Barry Bonds' playerid is bondsba01.)
SELECT namefirst,
	   namelast,
	   SUM(hr) OVER(ORDER BY yearid) AS cumulative_hr,
	   DENSE_RANK() OVER(ORDER BY yearid) AS seasons_played
FROM people
	 INNER JOIN batting
	 USING(playerid)
WHERE playerid = 'bondsba01';

-- #### Question 2b:
-- How many players at the end of the 2016 season were on pace to beat Barry Bonds' record? For this question, we will consider a player to be on pace to beat Bonds' record if they have more home runs than Barry Bonds had the same number of seasons into his career. 
WITH bb AS (	SELECT namefirst,
					   namelast,
					   SUM(hr) OVER(ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW) AS cumulative_hr,
					   DENSE_RANK() OVER(ORDER BY yearid) AS seasons_played
				FROM people
					 INNER JOIN batting
					 USING(playerid)
				WHERE playerid = 'bondsba01'),
	 -- then get the same columns available for other players, plus yearid to find 2016 stats specifically
	 players AS (	SELECT namefirst,
						   namelast,
						   yearid,
						   SUM(hr) OVER(PARTITION BY playerid ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW) AS cumulative_hr,
						   DENSE_RANK() OVER(PARTITION BY playerid ORDER BY yearid) AS seasons_played
				 			--DENSE_RANK() works here even if players have multiple rows for the same year due to changing teams midseason
					FROM people
						 INNER JOIN batting
						 USING(playerid)
					WHERE (namefirst, namelast) <> ('Barry', 'Bonds'))
SELECT players.namefirst,
	   players.namelast,
	   players.cumulative_hr,
	   seasons_played,
	   bb.cumulative_hr	AS bb_cumulative_hr 
FROM players
	 INNER JOIN bb
	 USING(seasons_played) -- this allows easy comparison for players based on the time they've been playing
WHERE yearid = 2016 --specifically interested in 2016 stats
	AND  players.cumulative_hr > bb.cumulative_hr; --filter only for players ahead of BB
-- 20 players fit these criteria

-- #### Question 2c: 
-- Were there any players who 20 years into their career who had hit more home runs at that point into their career than Barry Bonds had hit 20 years into his career? 
WITH bb AS (	SELECT namefirst,
					   namelast,
					   SUM(hr) OVER(ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW) AS cumulative_hr,
					   DENSE_RANK() OVER(ORDER BY yearid) AS seasons_played
				FROM people
					 INNER JOIN batting
					 USING(playerid)
				WHERE playerid = 'bondsba01'),
	 players AS (	SELECT namefirst,
						   namelast,
						   SUM(hr) OVER(PARTITION BY playerid ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW) AS cumulative_hr,
						   DENSE_RANK() OVER(PARTITION BY playerid ORDER BY yearid) AS seasons_played
				 			--DENSE_RANK() works here even if players have multiple rows for the same year due to changing teams midseason
					FROM people
						 INNER JOIN batting
						 USING(playerid)
					WHERE (namefirst, namelast) <> ('Barry', 'Bonds'))
SELECT players.namefirst,
	   players.namelast,
	   players.cumulative_hr,
	   seasons_played,
	   bb.cumulative_hr	AS bb_cumulative_hr 
FROM players
	 INNER JOIN bb
	 USING(seasons_played) -- this allows easy comparison for players based on the time they've been playing
WHERE seasons_played = 20 --specifically interested in players 20 years into their career
	AND  players.cumulative_hr > bb.cumulative_hr; --filter only for players ahead of BB
-- Just Hank Aaron

-- ## Question 3: Anomalous Seasons
-- Find the player who had the most anomalous season in terms of number of home runs hit. To do this, find the player who has the largest gap between the number of home runs hit in a season and the 5-year moving average number of home runs if we consider the 5-year window centered at that year (the window should include that year, the two years prior and the two years after).
WITH total_hr AS(						--accounting for the fact players might play for multiple teams in a year
					SELECT playerid,
						   yearid,
						   SUM(hr) AS hr
					FROM batting
					GROUP BY playerid, yearid)
SELECT namefirst || ' ' || namelast AS full_name,
	   yearid,
	   hr,
	   AVG(hr) OVER(PARTITION BY playerid ORDER BY yearid ROWS BETWEEN 2 PRECEDING AND 2 FOLLOWING) AS five_yr_avg,
	   hr - AVG(hr) OVER(PARTITION BY playerid ORDER BY yearid ROWS BETWEEN 2 PRECEDING AND 2 FOLLOWING) AS difference,
	   ABS(hr - AVG(hr) OVER(PARTITION BY playerid ORDER BY yearid ROWS BETWEEN 2 PRECEDING AND 2 FOLLOWING)) AS abs_difference
FROM total_hr
	 INNER JOIN people
	 USING(playerid)
ORDER BY abs_difference DESC;
-- In terms of a negative anomaly (doing worse than his 5-year avg), Hank Greenberg hit 31.2 fewer HR than his average in 1936
-- In terms of positive anomaly, Brady Anderson hit 27.2 more HR than his average in 1996

-- ## Question 4: Players Playing for one Team
-- For this question, we'll just consider players that appear in the batting table.
-- #### Question 4a: 
-- Warmup: How many players played at least 10 years in the league and played for exactly one team? (For this question, exclude any players who played in the 2016 season). Who had the longest career with a single team? (You can probably answer this question without needing to use a window function.)
WITH teams_seasons AS (
						SELECT playerid,
							   COUNT(DISTINCT teamid) AS team_count,
							   COUNT(DISTINCT yearid) AS seasons_played
						FROM batting
						WHERE playerid NOT IN -- subquery to pull out all players who played in 2016
											(SELECT playerid
											 FROM batting
											 WHERE yearid = 2016)
						GROUP BY playerid
)
SELECT COUNT(playerid)
FROM teams_seasons
WHERE team_count = 1
	AND seasons_played >= 10
-- 156 players

-- #### Question 4b: 
-- Some players start and end their careers with the same team but play for other teams in between. For example, Barry Zito started his career with the Oakland Athletics, moved to the San Francisco Giants for 7 seasons before returning to the Oakland Athletics for his final season. How many players played at least 10 years in the league and start and end their careers with the same team but played for at least one other team during their career? For this question, exclude any players who played in the 2016 season.
WITH firsts AS 
				(SELECT playerid,
					   teamid,
					   yearid,
					   MIN(yearid) OVER(PARTITION BY playerid) AS first_year
				FROM batting),
	 lasts AS
	 			(SELECT playerid,
					   teamid,
					   yearid,
					   MAX(yearid) OVER(PARTITION BY playerid) AS last_year
				FROM batting),
	multi_team AS
				(SELECT playerid,
				 	    COUNT(DISTINCT teamid) AS team_count
				FROM batting
				WHERE playerid NOT IN -- subquery to pull out all players who played in 2016
									(SELECT playerid
									 FROM batting
									 WHERE yearid = 2016)
				GROUP BY playerid
				HAVING COUNT(DISTINCT yearid) >= 10
					AND COUNT(DISTINCT teamid) > 1)
SELECT COUNT(*)
-- 	   playerid,
-- 	   teamid,
-- 	   first_year,
-- 	   last_year,
-- 	   team_count
FROM firsts
	 INNER JOIN lasts
	 USING(playerid, teamid)
	 INNER JOIN multi_team
	 USING(playerid)
WHERE firsts.yearid = first_year
	AND lasts.yearid = last_year;
-- 233 players

-- ## Question 5: Streaks
-- #### Question 5a: 
-- How many times did a team win the World Series in consecutive years?
WITH ws_winners AS
				(SELECT name,
					   yearid,
					   wswin,
					   LAG(name, 1) OVER(ORDER BY yearid) AS prev_yr_wswin
				FROM teams
				WHERE wswin = 'Y')
SELECT COUNT(*)
FROM ws_winners
WHERE name = prev_yr_wswin;
-- 22 times

-- #### Question 5b: 
-- What is the longest steak of a team winning the World Series? Write a query that produces this result rather than scanning the output of your previous answer.
WITH ws_winners AS
				(SELECT name,
					   yearid,
					   wswin,
				 	   yearid - ROW_NUMBER() OVER(PARTITION BY teamid ORDER BY yearid) AS streak_group
				 	   -- Using row_number this way results in streaks having the same number assigned to them
				FROM teams
				WHERE wswin = 'Y')
SELECT name, 
	   yearid,
	   ROW_NUMBER() OVER(PARTITION BY name, streak_group ORDER BY yearid) AS streak_years
FROM ws_winners
ORDER BY streak_years DESC;
-- NY Yankees, 5 years in a row 1949-1953

-- #### Question 5c: 
-- A team made the playoffs in a year if either divwin, wcwin, or lgwin will are equal to 'Y'. Which team has the longest streak of making the playoffs? 
WITH playoff_teams AS
				(SELECT name,
					   yearid,
				 	   yearid - ROW_NUMBER() OVER(PARTITION BY teamid ORDER BY yearid) AS streak_group
				FROM teams
				WHERE divwin = 'Y'
					  OR lgwin = 'Y'
					  OR wcwin = 'Y')
SELECT name, 
	   yearid,
	   ROW_NUMBER() OVER(PARTITION BY name, streak_group ORDER BY yearid) AS streak_years
FROM playoff_teams
ORDER BY streak_years DESC;
-- NY Yankees 13 years

-- #### Question 5d: 
-- The 1994 season was shortened due to a strike. If we don't count a streak as being broken by this season, does this change your answer for the previous part?
WITH playoff_teams AS
				(SELECT name,
					   yearid,
				 	   CASE WHEN yearid < 1994 THEN yearid - ROW_NUMBER() OVER(PARTITION BY teamid ORDER BY yearid)
				 			WHEN yearid > 1994 THEN yearid - ROW_NUMBER() OVER(PARTITION BY teamid ORDER BY yearid) - 1 END
				 	   AS streak_group
				FROM teams
				WHERE divwin = 'Y'
					  OR lgwin = 'Y'
					  OR wcwin = 'Y')
SELECT name, 
	   yearid,
	   ROW_NUMBER() OVER(PARTITION BY name, streak_group ORDER BY yearid) AS streak_years
FROM playoff_teams
ORDER BY streak_years DESC;
-- This puts the ATL Braves at the top with a 14 year streak, disregarding 1994

-- ## Question 6: Manager Effectiveness
-- Which manager had the most positive effect on a team's winning percentage? To determine this, calculate the average winning percentage in the three years before the manager's first full season and compare it to the average winning percentage for that manager's 2nd through 4th full season. Consider only managers who managed at least 4 full years at the new team and teams that had been in existence for at least 3 years prior to the manager's first full season.